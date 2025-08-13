-- src/middleware/auth.lua
-- Authentication middleware for request validation and authorization

local Session = require("src.models.session")
local User = require("src.models.user")
local json_utils = require("src.utils.json")
local security = require("src.utils.security")

local auth = {}

-- Rate limiting storage (in-memory for simplicity)
-- In production, this should use Redis or similar persistent storage
local rate_limit_store = {}

-- Rate limiting configuration
local RATE_LIMIT_MAX_ATTEMPTS = 5
local RATE_LIMIT_WINDOW = 15 * 60 -- 15 minutes in seconds

-- Role hierarchy for permission checking
local ROLE_HIERARCHY = {
  Admin = 3,
  Pastor = 2,
  Member = 1
}

-- Permission levels required for different operations
local PERMISSION_LEVELS = {
  READ_OWN = 1,    -- Member can read their own data
  READ_ALL = 2,    -- Pastor can read all church data
  WRITE_ALL = 2,   -- Pastor can write all church data
  ADMIN = 3        -- Admin can manage users and system
}

-- Extract token from Authorization header
-- @param client table The client connection object
-- @return string|nil The extracted token or nil if not found
function auth.extract_token(client)
  if not client or not client.headers then
    return nil
  end
  
  local auth_header = client.headers["Authorization"] or client.headers["authorization"]
  if not auth_header then
    return nil
  end
  
  -- Extract Bearer token
  local token = auth_header:match("^Bearer%s+(.+)$")
  return token
end

-- Check rate limiting for authentication attempts
-- @param identifier string The identifier to check (username, IP, etc.)
-- @return boolean True if request is allowed, false if rate limited
function auth.rate_limit_check(identifier)
  if not identifier then
    return false
  end
  
  local current_time = os.time()
  local key = "auth_attempts:" .. identifier
  
  -- Clean up old entries
  if rate_limit_store[key] then
    local attempts = rate_limit_store[key]
    local filtered_attempts = {}
    
    for _, attempt_time in ipairs(attempts) do
      if current_time - attempt_time < RATE_LIMIT_WINDOW then
        table.insert(filtered_attempts, attempt_time)
      end
    end
    
    rate_limit_store[key] = filtered_attempts
  else
    rate_limit_store[key] = {}
  end
  
  -- Check if rate limit exceeded
  if #rate_limit_store[key] >= RATE_LIMIT_MAX_ATTEMPTS then
    return false
  end
  
  -- Record this attempt
  table.insert(rate_limit_store[key], current_time)
  
  return true
end

-- Clear rate limiting for successful authentication
-- @param identifier string The identifier to clear
function auth.clear_rate_limit(identifier)
  if identifier then
    local key = "auth_attempts:" .. identifier
    rate_limit_store[key] = nil
  end
end

-- Send authentication error response
-- @param client table The client connection object
-- @param status number HTTP status code
-- @param error_code string Error code for client identification
-- @param message string Human-readable error message
local function send_auth_error(client, status, error_code, message)
  json_utils.send_json_response(client, status, {
    error = message,
    code = error_code,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

-- Authenticate request and extract user context
-- @param client table The client connection object
-- @param params table Request parameters (will be modified to include user context)
-- @return boolean True if authentication successful, false otherwise
function auth.authenticate_request(client, params)
  params = params or {}
  
  -- Extract token from request
  local token = auth.extract_token(client)
  if not token then
    send_auth_error(client, 401, "MISSING_TOKEN", "Authentication token is required")
    return false
  end
  
  -- Validate session token
  local session, err = Session.find_by_token(token)
  if not session then
    local error_code = "INVALID_TOKEN"
    local message = "Invalid or expired authentication token"
    
    if err == "Session expired" then
      error_code = "TOKEN_EXPIRED"
      message = "Authentication token has expired"
    elseif err == "User account is deactivated" then
      error_code = "ACCOUNT_DEACTIVATED"
      message = "User account is deactivated"
    end
    
    send_auth_error(client, 401, error_code, message)
    return false
  end
  
  -- Add user context to params
  params.current_user = {
    id = tonumber(session.user_id),
    username = session.username,
    email = session.email,
    role = session.role,
    member_id = session.member_id and tonumber(session.member_id) or nil,
    is_active = session.is_active
  }
  
  params.session_token = token
  
  return true
end

-- Check if user has required role level
-- @param user_role string The user's role
-- @param required_level number The required permission level
-- @return boolean True if user has sufficient permissions
local function has_permission_level(user_role, required_level)
  local user_level = ROLE_HIERARCHY[user_role] or 0
  return user_level >= required_level
end

-- Require specific role for access
-- @param required_role string The required role ('Admin', 'Pastor', 'Member')
-- @return function Middleware function that checks role
function auth.require_role(required_role)
  return function(client, params)
    -- First authenticate the request
    if not auth.authenticate_request(client, params) then
      return false
    end
    
    local user = params.current_user
    if not user then
      send_auth_error(client, 401, "AUTHENTICATION_REQUIRED", "Authentication is required")
      return false
    end
    
    -- Check role hierarchy
    local required_level = ROLE_HIERARCHY[required_role] or 0
    if not has_permission_level(user.role, required_level) then
      send_auth_error(client, 403, "INSUFFICIENT_PERMISSIONS", 
        string.format("Access denied. %s role required", required_role))
      return false
    end
    
    return true
  end
end

-- Require admin role for access
-- @return function Middleware function that checks for admin role
function auth.require_admin()
  return auth.require_role("Admin")
end

-- Require pastor or admin role for access
-- @return function Middleware function that checks for pastor or admin role
function auth.require_pastor()
  return auth.require_role("Pastor")
end

-- Require member, pastor, or admin role for access (any authenticated user)
-- @return function Middleware function that checks for any valid role
function auth.require_member()
  return auth.require_role("Member")
end

-- Check if user can access specific member data
-- @param user table The current user object
-- @param member_id number The member ID being accessed
-- @return boolean True if user can access the member data
function auth.can_access_member_data(user, member_id)
  if not user or not member_id then
    return false
  end
  
  -- Admin and Pastor can access all member data
  if user.role == "Admin" or user.role == "Pastor" then
    return true
  end
  
  -- Member can only access their own data
  if user.role == "Member" and user.member_id then
    return tonumber(user.member_id) == tonumber(member_id)
  end
  
  return false
end

-- Middleware for member-specific data access
-- @param member_id_param string The parameter name containing member ID (default: "member_id")
-- @return function Middleware function that checks member data access
function auth.require_member_access(member_id_param)
  member_id_param = member_id_param or "member_id"
  
  return function(client, params, ...)
    -- First authenticate the request
    if not auth.authenticate_request(client, params) then
      return false
    end
    
    local user = params.current_user
    if not user then
      send_auth_error(client, 401, "AUTHENTICATION_REQUIRED", "Authentication is required")
      return false
    end
    
    -- Extract member ID from params or URL captures
    local member_id = params[member_id_param]
    if not member_id and ... then
      -- Try to get from URL captures (first capture group)
      local captures = {...}
      member_id = captures[1]
    end
    
    if not member_id then
      send_auth_error(client, 400, "MISSING_MEMBER_ID", "Member ID is required")
      return false
    end
    
    -- Check access permissions
    if not auth.can_access_member_data(user, member_id) then
      send_auth_error(client, 403, "ACCESS_DENIED", 
        "You can only access your own member data")
      return false
    end
    
    return true
  end
end

-- Rate limiting middleware for authentication endpoints
-- @param identifier_func function Function to extract identifier from client/params
-- @return function Middleware function that applies rate limiting
function auth.rate_limit(identifier_func)
  return function(client, params)
    local identifier = "unknown"
    
    if identifier_func then
      identifier = identifier_func(client, params) or "unknown"
    else
      -- Default to using client IP or connection info
      identifier = tostring(client):gsub("table: ", "")
    end
    
    if not auth.rate_limit_check(identifier) then
      send_auth_error(client, 429, "RATE_LIMIT_EXCEEDED", 
        string.format("Too many authentication attempts. Please try again in %d minutes", 
          math.ceil(RATE_LIMIT_WINDOW / 60)))
      return false
    end
    
    return true
  end
end

-- Middleware to apply authentication to existing routes
-- @param handler function The original route handler
-- @param auth_middleware function The authentication middleware to apply
-- @return function Wrapped handler with authentication
function auth.protect(handler, auth_middleware)
  return function(client, params, ...)
    -- Apply authentication middleware
    if auth_middleware and not auth_middleware(client, params, ...) then
      return -- Authentication failed, error already sent
    end
    
    -- Call original handler
    return handler(client, params, ...)
  end
end

-- Middleware chain executor
-- @param middlewares table Array of middleware functions
-- @return function Combined middleware function
function auth.chain(middlewares)
  return function(client, params, ...)
    for _, middleware in ipairs(middlewares) do
      if not middleware(client, params, ...) then
        return false
      end
    end
    return true
  end
end

-- Helper to create authentication middleware for login endpoints
-- @param username_param string Parameter name for username (default: "username")
-- @return function Rate limiting middleware for login attempts
function auth.login_rate_limit(username_param)
  username_param = username_param or "username"
  
  return auth.rate_limit(function(client, params)
    return params[username_param] or "unknown"
  end)
end

-- Clear rate limiting on successful authentication
-- @param identifier string The identifier to clear
function auth.clear_login_rate_limit(identifier)
  auth.clear_rate_limit(identifier)
end

-- Get current user from authenticated request
-- @param params table Request parameters with user context
-- @return table|nil Current user object or nil if not authenticated
function auth.get_current_user(params)
  return params and params.current_user or nil
end

-- Check if current user has specific permission level
-- @param params table Request parameters with user context
-- @param permission_level number Required permission level
-- @return boolean True if user has required permission level
function auth.has_permission(params, permission_level)
  local user = auth.get_current_user(params)
  if not user then
    return false
  end
  
  return has_permission_level(user.role, permission_level)
end

-- Middleware for different permission levels
auth.require_read_own = function()
  return function(client, params, ...)
    if not auth.authenticate_request(client, params) then
      return false
    end
    
    if not auth.has_permission(params, PERMISSION_LEVELS.READ_OWN) then
      send_auth_error(client, 403, "INSUFFICIENT_PERMISSIONS", "Insufficient permissions")
      return false
    end
    
    return true
  end
end

auth.require_read_all = function()
  return function(client, params, ...)
    if not auth.authenticate_request(client, params) then
      return false
    end
    
    if not auth.has_permission(params, PERMISSION_LEVELS.READ_ALL) then
      send_auth_error(client, 403, "INSUFFICIENT_PERMISSIONS", "Pastor or Admin role required")
      return false
    end
    
    return true
  end
end

auth.require_write_all = function()
  return function(client, params, ...)
    if not auth.authenticate_request(client, params) then
      return false
    end
    
    if not auth.has_permission(params, PERMISSION_LEVELS.WRITE_ALL) then
      send_auth_error(client, 403, "INSUFFICIENT_PERMISSIONS", "Pastor or Admin role required")
      return false
    end
    
    return true
  end
end

return auth