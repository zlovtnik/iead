-- src/utils/rate_limiter.lua
-- Production-ready rate limiting with Redis support and in-memory fallback

local json_utils = require("src.utils.json")

local rate_limiter = {}

-- Configuration
local config = {
  -- Rate limiting settings
  max_attempts = 5,
  window_seconds = 15 * 60, -- 15 minutes
  
  -- Redis configuration (when available)
  redis = {
    enabled = false,
    host = "127.0.0.1",
    port = 6379,
    db = 0,
    timeout = 1000, -- 1 second timeout
    pool_size = 10
  },
  
  -- In-memory cleanup settings
  cleanup_interval = 5 * 60, -- Clean up every 5 minutes
  max_memory_entries = 10000  -- Limit memory usage
}

-- Storage backends
local backends = {}

-- In-memory storage backend with cleanup
backends.memory = {
  store = {},
  last_cleanup = os.time(),
  
  -- Get attempts for identifier
  get = function(self, key)
    return self.store[key] or {}
  end,
  
  -- Set attempts for identifier
  set = function(self, key, attempts)
    self.store[key] = attempts
    self:cleanup_if_needed()
  end,
  
  -- Delete entry for identifier
  delete = function(self, key)
    self.store[key] = nil
  end,
  
  -- Cleanup old entries and enforce memory limits
  cleanup_if_needed = function(self)
    local current_time = os.time()
    
    -- Only cleanup if enough time has passed
    if current_time - self.last_cleanup < config.cleanup_interval then
      return
    end
    
    self.last_cleanup = current_time
    local entries_count = 0
    
    -- Remove expired entries
    for key, attempts in pairs(self.store) do
      local filtered_attempts = {}
      
      for _, attempt_time in ipairs(attempts) do
        if current_time - attempt_time < config.window_seconds then
          table.insert(filtered_attempts, attempt_time)
        end
      end
      
      if #filtered_attempts > 0 then
        self.store[key] = filtered_attempts
        entries_count = entries_count + 1
      else
        self.store[key] = nil
      end
    end
    
    -- If still too many entries, remove oldest ones
    if entries_count > config.max_memory_entries then
      local keys_by_oldest = {}
      for key, attempts in pairs(self.store) do
        local oldest_time = attempts[1] or current_time
        table.insert(keys_by_oldest, {key = key, oldest = oldest_time})
      end
      
      table.sort(keys_by_oldest, function(a, b) return a.oldest < b.oldest end)
      
      local to_remove = entries_count - config.max_memory_entries
      for i = 1, to_remove do
        if keys_by_oldest[i] then
          self.store[keys_by_oldest[i].key] = nil
        end
      end
    end
  end
}

-- Redis storage backend
backends.redis = {
  client = nil,
  connected = false,
  
  -- Initialize Redis connection
  init = function(self)
    if self.connected then
      return true
    end
    
    local ok, redis = pcall(require, "redis")
    if not ok then
      return false, "Redis module not available"
    end
    
    local ok, client = pcall(redis.connect, config.redis.host, config.redis.port)
    if not ok then
      return false, "Failed to connect to Redis: " .. tostring(client)
    end
    
    -- Test connection
    local ok, result = pcall(function() return client:ping() end)
    if not ok or result ~= "PONG" then
      return false, "Redis connection test failed"
    end
    
    self.client = client
    self.connected = true
    return true
  end,
  
  -- Get attempts for identifier
  get = function(self, key)
    if not self.connected and not self:init() then
      return {}
    end
    
    local ok, result = pcall(function()
      return self.client:lrange(key, 0, -1)
    end)
    
    if not ok then
      self.connected = false
      return {}
    end
    
    local attempts = {}
    for _, timestamp_str in ipairs(result or {}) do
      local timestamp = tonumber(timestamp_str)
      if timestamp then
        table.insert(attempts, timestamp)
      end
    end
    
    return attempts
  end,
  
  -- Add attempt for identifier
  add_attempt = function(self, key, timestamp)
    if not self.connected and not self:init() then
      return false
    end
    
    local ok, err = pcall(function()
      -- Add new attempt
      self.client:lpush(key, tostring(timestamp))
      
      -- Set expiration
      self.client:expire(key, config.window_seconds)
      
      -- Remove old attempts (keep only within window)
      local cutoff = timestamp - config.window_seconds
      self.client:lrem(key, 0, function(val)
        return tonumber(val) and tonumber(val) < cutoff
      end)
    end)
    
    if not ok then
      self.connected = false
      return false
    end
    
    return true
  end,
  
  -- Delete entry for identifier
  delete = function(self, key)
    if not self.connected and not self:init() then
      return false
    end
    
    local ok, err = pcall(function()
      self.client:del(key)
    end)
    
    if not ok then
      self.connected = false
      return false
    end
    
    return true
  end
}

-- Current backend (defaults to memory)
local current_backend = backends.memory

-- Initialize rate limiter with configuration
function rate_limiter.init(user_config)
  if user_config then
    -- Merge user config with defaults
    for key, value in pairs(user_config) do
      if type(value) == "table" and config[key] then
        for subkey, subvalue in pairs(value) do
          config[key][subkey] = subvalue
        end
      else
        config[key] = value
      end
    end
  end
  
  -- Try to initialize Redis if enabled
  if config.redis.enabled then
    local success, err = backends.redis:init()
    if success then
      current_backend = backends.redis
      print("Rate limiter: Using Redis backend")
    else
      print("Rate limiter: Redis initialization failed, falling back to memory: " .. (err or "unknown error"))
      current_backend = backends.memory
    end
  else
    current_backend = backends.memory
    print("Rate limiter: Using memory backend")
  end
end

-- Check if request is allowed (not rate limited)
function rate_limiter.check_rate_limit(identifier)
  if not identifier or identifier == "" then
    return false, "Invalid identifier"
  end
  
  local current_time = os.time()
  local key = "rate_limit:" .. identifier
  
  -- Get current attempts
  local attempts = current_backend:get(key)
  
  -- Filter attempts within the time window
  local valid_attempts = {}
  for _, attempt_time in ipairs(attempts) do
    if current_time - attempt_time < config.window_seconds then
      table.insert(valid_attempts, attempt_time)
    end
  end
  
  -- Check if rate limit exceeded
  if #valid_attempts >= config.max_attempts then
    local oldest_attempt = valid_attempts[1] or current_time
    local time_until_reset = config.window_seconds - (current_time - oldest_attempt)
    return false, string.format("Rate limit exceeded. Try again in %d seconds", time_until_reset)
  end
  
  -- Record this attempt
  table.insert(valid_attempts, current_time)
  
  -- Store updated attempts
  if current_backend == backends.redis then
    current_backend:add_attempt(key, current_time)
  else
    current_backend:set(key, valid_attempts)
  end
  
  return true, nil
end

-- Clear rate limit for identifier (e.g., on successful authentication)
function rate_limiter.clear_rate_limit(identifier)
  if not identifier or identifier == "" then
    return false
  end
  
  local key = "rate_limit:" .. identifier
  
  if current_backend == backends.redis then
    return current_backend:delete(key)
  else
    current_backend:delete(key)
    return true
  end
end

-- Get rate limit status for identifier
function rate_limiter.get_rate_limit_status(identifier)
  if not identifier or identifier == "" then
    return nil, "Invalid identifier"
  end
  
  local current_time = os.time()
  local key = "rate_limit:" .. identifier
  
  -- Get current attempts
  local attempts = current_backend:get(key)
  
  -- Filter attempts within the time window
  local valid_attempts = {}
  for _, attempt_time in ipairs(attempts) do
    if current_time - attempt_time < config.window_seconds then
      table.insert(valid_attempts, attempt_time)
    end
  end
  
  local remaining = math.max(0, config.max_attempts - #valid_attempts)
  local reset_time = nil
  
  if #valid_attempts > 0 then
    local oldest_attempt = valid_attempts[1]
    reset_time = oldest_attempt + config.window_seconds
  end
  
  return {
    identifier = identifier,
    attempts = #valid_attempts,
    max_attempts = config.max_attempts,
    remaining = remaining,
    window_seconds = config.window_seconds,
    reset_time = reset_time,
    is_limited = remaining == 0
  }
end

-- Get current configuration
function rate_limiter.get_config()
  return config
end

-- Get current backend type
function rate_limiter.get_backend_type()
  if current_backend == backends.redis then
    return "redis"
  else
    return "memory"
  end
end

return rate_limiter
