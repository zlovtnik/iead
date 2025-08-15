-- src/application/middlewares/rate_limit_middleware.lua
-- Enhanced rate limiting middleware for authentication endpoints

local json_utils = require("src.utils.json")
local log = require("src.utils.log")

local rate_limiter = {}

-- Rate limiting configuration
local RATE_LIMIT_CONFIG = {
    auth_endpoints = {
        max_attempts = 5,
        window_seconds = 15 * 60, -- 15 minutes
        identifier_types = {"ip", "username"}
    },
    api_endpoints = {
        max_attempts = 100,
        window_seconds = 60, -- 1 minute
        identifier_types = {"ip"}
    },
    global = {
        max_attempts = 1000,
        window_seconds = 60, -- 1 minute per IP
        identifier_types = {"ip"}
    }
}

-- In-memory storage for rate limiting
-- In production, this should be Redis for distributed rate limiting
local rate_limit_store = {}

-- Clean up expired entries periodically
local last_cleanup = os.time()
local CLEANUP_INTERVAL = 5 * 60 -- 5 minutes

-- Extract client IP address
-- @param client table The client connection
-- @return string The client IP address
local function get_client_ip(client)
    if not client or not client.headers then
        return "unknown"
    end
    
    -- Check for forwarded IP headers (from reverse proxy)
    local forwarded_ip = client.headers["X-Forwarded-For"] or 
                        client.headers["x-forwarded-for"] or
                        client.headers["X-Real-IP"] or
                        client.headers["x-real-ip"]
    
    if forwarded_ip then
        -- Take first IP if comma-separated list
        return forwarded_ip:match("^([^,]+)")
    end
    
    -- Fallback to direct connection IP
    return client.ip or "unknown"
end

-- Check if cleanup is needed and perform it
local function cleanup_expired_entries()
    local current_time = os.time()
    
    if current_time - last_cleanup < CLEANUP_INTERVAL then
        return
    end
    
    last_cleanup = current_time
    
    for key, attempts in pairs(rate_limit_store) do
        if attempts.window_start and 
           current_time - attempts.window_start > RATE_LIMIT_CONFIG.auth_endpoints.window_seconds then
            rate_limit_store[key] = nil
        end
    end
end

-- Check rate limit for identifier
-- @param identifier string Unique identifier for rate limiting
-- @param config table Rate limiting configuration
-- @return boolean true if allowed, false if rate limited
-- @return number remaining attempts
function rate_limiter.check_rate_limit(identifier, config)
    if not identifier or not config then
        return false, 0
    end
    
    cleanup_expired_entries()
    
    local current_time = os.time()
    local key = "rate_limit:" .. identifier
    
    -- Get or initialize attempts record
    local attempts = rate_limit_store[key]
    if not attempts then
        attempts = {
            count = 0,
            window_start = current_time
        }
        rate_limit_store[key] = attempts
    end
    
    -- Check if window has expired
    if current_time - attempts.window_start >= config.window_seconds then
        attempts.count = 0
        attempts.window_start = current_time
    end
    
    -- Check if limit exceeded
    if attempts.count >= config.max_attempts then
        return false, 0
    end
    
    -- Increment attempt count
    attempts.count = attempts.count + 1
    
    return true, config.max_attempts - attempts.count
end

-- Record failed attempt
-- @param identifier string Unique identifier
-- @param config table Rate limiting configuration
function rate_limiter.record_attempt(identifier, config)
    if not identifier or not config then
        return
    end
    
    local current_time = os.time()
    local key = "rate_limit:" .. identifier
    
    local attempts = rate_limit_store[key]
    if not attempts then
        attempts = {
            count = 1,
            window_start = current_time
        }
        rate_limit_store[key] = attempts
    else
        if current_time - attempts.window_start >= config.window_seconds then
            attempts.count = 1
            attempts.window_start = current_time
        else
            attempts.count = attempts.count + 1
        end
    end
end

-- Reset rate limit for identifier (successful auth)
-- @param identifier string Unique identifier
function rate_limiter.reset_rate_limit(identifier)
    if not identifier then
        return
    end
    
    local key = "rate_limit:" .. identifier
    rate_limit_store[key] = nil
end

-- Middleware for authentication endpoints
-- @param client table Client connection
-- @param params table Request parameters
-- @param next function Next middleware function
function rate_limiter.auth_rate_limit_middleware(client, params, next)
    local config = RATE_LIMIT_CONFIG.auth_endpoints
    local identifiers = {}
    
    -- Collect identifiers for rate limiting
    table.insert(identifiers, "ip:" .. get_client_ip(client))
    
    if params and params.username then
        table.insert(identifiers, "username:" .. params.username)
    end
    
    -- Check rate limits for all identifiers
    for _, identifier in ipairs(identifiers) do
        local allowed, remaining = rate_limiter.check_rate_limit(identifier, config)
        
        if not allowed then
            log.warn("Rate limit exceeded", {
                identifier = identifier,
                ip = get_client_ip(client),
                endpoint = "auth"
            })
            
            json_utils.send_json_response(client, 429, {
                error = "Rate Limit Exceeded",
                code = "RATE_LIMIT_EXCEEDED",
                message = "Too many authentication attempts. Please try again in " .. 
                         math.ceil(config.window_seconds / 60) .. " minutes",
                retry_after = config.window_seconds,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            })
            return
        end
    end
    
    -- Continue to next middleware
    if next then
        next()
    end
end

-- Middleware for general API endpoints
-- @param client table Client connection
-- @param params table Request parameters
-- @param next function Next middleware function
function rate_limiter.api_rate_limit_middleware(client, params, next)
    local config = RATE_LIMIT_CONFIG.api_endpoints
    local identifier = "api_ip:" .. get_client_ip(client)
    
    local allowed, remaining = rate_limiter.check_rate_limit(identifier, config)
    
    if not allowed then
        log.warn("API rate limit exceeded", {
            identifier = identifier,
            ip = get_client_ip(client)
        })
        
        json_utils.send_json_response(client, 429, {
            error = "Rate Limit Exceeded",
            code = "API_RATE_LIMIT_EXCEEDED",
            message = "Too many API requests. Please slow down",
            retry_after = config.window_seconds,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
        return
    end
    
    -- Add rate limit headers
    if client and client.headers then
        client.response_headers = client.response_headers or {}
        client.response_headers["X-RateLimit-Limit"] = tostring(config.max_attempts)
        client.response_headers["X-RateLimit-Remaining"] = tostring(remaining)
        client.response_headers["X-RateLimit-Reset"] = tostring(os.time() + config.window_seconds)
    end
    
    -- Continue to next middleware
    if next then
        next()
    end
end

-- Global rate limiting middleware
-- @param client table Client connection
-- @param params table Request parameters
-- @param next function Next middleware function
function rate_limiter.global_rate_limit_middleware(client, params, next)
    local config = RATE_LIMIT_CONFIG.global
    local identifier = "global_ip:" .. get_client_ip(client)
    
    local allowed, remaining = rate_limiter.check_rate_limit(identifier, config)
    
    if not allowed then
        log.warn("Global rate limit exceeded", {
            identifier = identifier,
            ip = get_client_ip(client)
        })
        
        json_utils.send_json_response(client, 429, {
            error = "Rate Limit Exceeded",
            code = "GLOBAL_RATE_LIMIT_EXCEEDED",
            message = "Too many requests. Please try again later",
            retry_after = config.window_seconds,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
        return
    end
    
    -- Continue to next middleware
    if next then
        next()
    end
end

-- Function to check if rate limit applies to specific endpoint
-- @param endpoint string The endpoint path
-- @return string The rate limit type or nil
function rate_limiter.get_rate_limit_type(endpoint)
    if not endpoint then
        return nil
    end
    
    -- Auth endpoints
    if endpoint:match("^/auth/") or endpoint:match("/login") or endpoint:match("/logout") then
        return "auth"
    end
    
    -- API endpoints
    if endpoint:match("^/api/") then
        return "api"
    end
    
    return "global"
end

-- Configuration functions
function rate_limiter.set_config(new_config)
    if type(new_config) == "table" then
        for category, settings in pairs(new_config) do
            if RATE_LIMIT_CONFIG[category] then
                for key, value in pairs(settings) do
                    RATE_LIMIT_CONFIG[category][key] = value
                end
            end
        end
    end
end

function rate_limiter.get_config()
    return RATE_LIMIT_CONFIG
end

-- Stats function for monitoring
function rate_limiter.get_stats()
    local stats = {
        total_entries = 0,
        auth_entries = 0,
        api_entries = 0,
        global_entries = 0
    }
    
    for key, _ in pairs(rate_limit_store) do
        stats.total_entries = stats.total_entries + 1
        
        if key:match("^rate_limit:username:") or key:match("^rate_limit:ip:") then
            stats.auth_entries = stats.auth_entries + 1
        elseif key:match("^rate_limit:api_ip:") then
            stats.api_entries = stats.api_entries + 1
        elseif key:match("^rate_limit:global_ip:") then
            stats.global_entries = stats.global_entries + 1
        end
    end
    
    return stats
end

return rate_limiter
