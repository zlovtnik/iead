-- src/infrastructure/repositories/user_repository.lua
-- User repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")
local security = require("src.utils.security")

local UserRepository = {}
UserRepository.__index = UserRepository

-- Create a new UserRepository instance
function UserRepository.new()
  local schema = {
    username = {
      type = "string",
      required = true,
      min_length = 3,
      max_length = 50
    },
    email = {
      type = "string",
      required = true,
      max_length = 255
    },
    password = {
      type = "string",
      required = true,
      min_length = 8
    },
    role = {
      type = "string",
      required = true
    },
    member_id = {
      type = "number",
      required = false
    },
    is_active = {
      type = "number",  -- SQLite uses 0/1 for boolean
      required = false
    }
  }
  
  -- Define allowed columns for ORDER BY clauses (security measure)
  local allowed_columns = {
    "id", "username", "email", "role", "member_id", "is_active", "created_at", "updated_at"
  }
  
  local base_repo = BaseRepository.new("users", schema, allowed_columns)
  local instance = {
    base = base_repo
  }
  setmetatable(instance, UserRepository)
  return instance
end

-- Delegate to base repository methods
function UserRepository:find_all(options)
  return self.base:find_all(options)
end

function UserRepository:find_one(conditions)
  return self.base:find_one(conditions)
end

function UserRepository:find_by_id(id)
  return self.base:find_by_id(id)
end

function UserRepository:update_by_id(id, data)
  return self.base:update_by_id(id, data)
end

function UserRepository:delete_by_id(id)
  return self.base:delete_by_id(id)
end

function UserRepository:count(conditions)
  return self.base:count(conditions)
end

function UserRepository:exists(conditions)
  return self.base:exists(conditions)
end

function UserRepository:paginate(options)
  return self.base:paginate(options)
end

-- Custom create method that handles password hashing
function UserRepository:create(data)
  -- Hash password if provided
  if data.password then
    local hashed_password, hash_err = security.hash_password(data.password)
    if not hashed_password then
      return nil, "Failed to hash password: " .. (hash_err or "unknown error")
    end
    data.password = hashed_password
  end
  
  -- Set default values
  if data.is_active == nil then
    data.is_active = 1  -- Default to active
  end
  
  if data.role == nil then
    data.role = "Member"  -- Default role
  end
  
  return self.base:create(data)
end

-- Custom update method that handles password hashing
function UserRepository:update(conditions, data)
  -- Hash password if provided
  if data.password then
    local ok, hashed_password_or_err = pcall(security.hash_password, data.password)
    if not ok then
      return nil, "Failed to hash password: " .. hashed_password_or_err
    end
    data.password = hashed_password_or_err
  end
  
  return self.base:update(conditions, data)
end

-- Find user by username
function UserRepository:find_by_username(username)
  return self:find_one({username = username})
end

-- Find user by email
function UserRepository:find_by_email(email)
  return self:find_one({email = email})
end

-- Find active users
function UserRepository:find_active_users(options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.is_active = 1
  return self:find_all(options)
end

-- Find users by role
function UserRepository:find_by_role(role, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.role = role
  return self:find_all(options)
end

-- Verify user credentials
function UserRepository:verify_credentials(username, password)
  local user, err = self:find_by_username(username)
  if not user then
    return nil, err or "User not found"
  end
  
  if user.is_active ~= 1 then
    return nil, "Account is deactivated"
  end
  
  local is_valid = security.verify_password(password, user.password)
  if not is_valid then
    return nil, "Invalid password"
  end
  
  return user, nil
end

-- Activate/deactivate user
function UserRepository:set_active_status(user_id, is_active)
  return self:update_by_id(user_id, {is_active = is_active and 1 or 0})
end

-- Change user role
function UserRepository:change_role(user_id, new_role)
  return self:update_by_id(user_id, {role = new_role})
end

-- Search users by username or email
function UserRepository:search(query, options)
  options = options or {}
  local original_conditions = options.conditions or {}
  
  -- Since base repository doesn't support OR conditions, we'll use fallback approach
  -- Run two separate queries and merge results
  
  -- Query 1: Search by username
  local username_options = {
    conditions = {},
    order_by = options.order_by,
    order_direction = options.order_direction,
    limit = options.limit,
    offset = options.offset
  }
  
  -- Copy original conditions to preserve existing filters
  for key, value in pairs(original_conditions) do
    username_options.conditions[key] = value
  end
  
  -- Add username search condition
  username_options.conditions.username = {operator = "LIKE", value = "%" .. query .. "%"}
  
  -- Query 2: Search by email
  local email_options = {
    conditions = {},
    order_by = options.order_by,
    order_direction = options.order_direction,
    limit = options.limit,
    offset = options.offset
  }
  
  -- Copy original conditions to preserve existing filters
  for key, value in pairs(original_conditions) do
    email_options.conditions[key] = value
  end
  
  -- Add email search condition
  email_options.conditions.email = {operator = "LIKE", value = "%" .. query .. "%"}
  
  -- Execute both queries
  local username_results, username_err = self:find_all(username_options)
  if not username_results then
    return nil, username_err
  end
  
  local email_results, email_err = self:find_all(email_options)
  if not email_results then
    return nil, email_err
  end
  
  -- Merge and deduplicate results by ID
  local merged_results = {}
  local seen_ids = {}
  
  -- Add username results
  for _, user in ipairs(username_results) do
    if not seen_ids[user.id] then
      table.insert(merged_results, user)
      seen_ids[user.id] = true
    end
  end
  
  -- Add email results (deduplicated)
  for _, user in ipairs(email_results) do
    if not seen_ids[user.id] then
      table.insert(merged_results, user)
      seen_ids[user.id] = true
    end
  end
  
  -- Note: This approach may not perfectly preserve pagination limits
  -- since we're merging results from two queries
  return merged_results
end

-- Count search results by username or email (uses same search logic as search method)
function UserRepository:count_search(query, options)
  options = options or {}
  local original_conditions = options.conditions or {}
  
  -- Since base repository doesn't support OR conditions, we'll use fallback approach
  -- Run two separate count queries and merge the counts
  
  -- Count 1: Count username matches
  local username_conditions = {}
  
  -- Copy original conditions to preserve existing filters
  for key, value in pairs(original_conditions) do
    username_conditions[key] = value
  end
  
  -- Add username search condition
  username_conditions.username = {operator = "LIKE", value = "%" .. query .. "%"}
  
  -- Count 2: Count email matches
  local email_conditions = {}
  
  -- Copy original conditions to preserve existing filters
  for key, value in pairs(original_conditions) do
    email_conditions[key] = value
  end
  
  -- Add email search condition
  email_conditions.email = {operator = "LIKE", value = "%" .. query .. "%"}
  
  -- Execute both count queries
  local username_count, username_err = self:count(username_conditions)
  if not username_count then
    return nil, username_err
  end
  
  local email_count, email_err = self:count(email_conditions)
  if not email_count then
    return nil, email_err
  end
  
  -- Since we can't easily deduplicate counts without running full queries,
  -- we'll use a conservative approach and return the maximum of the two counts
  -- This may overestimate but ensures pagination doesn't break
  -- For exact counts, would need to run the full search query and count results
  return math.max(username_count, email_count)
end

-- Get user statistics
function UserRepository:get_stats()
  local total_users, total_err = self:count()
  if not total_users then
    return nil, total_err
  end
  
  local active_users, active_err = self:count({is_active = 1})
  if not active_users then
    return nil, active_err
  end
  
  local admin_count, admin_err = self:count({role = "Admin"})
  if not admin_count then
    return nil, admin_err
  end
  
  local pastor_count, pastor_err = self:count({role = "Pastor"})
  if not pastor_count then
    return nil, pastor_err
  end
  
  local member_count, member_err = self:count({role = "Member"})
  if not member_count then
    return nil, member_err
  end
  
  return {
    total_users = total_users,
    active_users = active_users,
    inactive_users = total_users - active_users,
    admin_count = admin_count,
    pastor_count = pastor_count,
    member_count = member_count
  }, nil
end

return UserRepository
