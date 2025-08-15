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
  
  local base_repo = BaseRepository.new("users", schema)
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
    local hashed_password, hash_err = security.hash_password(data.password)
    if not hashed_password then
      return nil, "Failed to hash password: " .. (hash_err or "unknown error")
    end
    data.password = hashed_password
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
  options.conditions = options.conditions or {}
  
  -- Use LIKE operator for search
  local search_conditions = {
    username = {operator = "LIKE", value = "%" .. query .. "%"}
  }
  
  -- If query looks like an email, also search by email
  if query:match("@") then
    -- This would require OR condition, which our base repository doesn't support yet
    -- For now, we'll search by email if it contains @
    search_conditions = {
      email = {operator = "LIKE", value = "%" .. query .. "%"}
    }
  end
  
  options.conditions = search_conditions
  return self:find_all(options)
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
