-- src/application/middlewares/auth_middleware.lua
-- Enhanced authentication middleware with comprehensive security

local Session = require("src.models.session")
local User = require("src.models.user_secure")
local json_utils = require("src.utils.json")
local rate_limiter = require("src.application.middlewares.rate_limit_middleware")
local log = require("src.utils.log")

local auth = {}

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

-- Extract client IP address
-- @param client table The client connection
-- @return string The client IP address
local function get_client_ip(client)
  if not client then
    return "unknown"
  end
  
  -- Check for forwarded IP headers (from reverse proxy)
  if client.headers then
    local forwarded_ip = client.headers["X-Forwarded-For"] or 
                        client.headers["x-forwarded-for"] or
                        client.headers["X-Real-IP"] or
                        client.headers["x-real-ip"]
    
    if forwarded_ip then
      -- Take first IP if comma-separated list
      return forwarded_ip:match("^([^,]+)") or forwarded_ip
    end
  end
  
  -- Fallback to direct connection IP
  return client.ip or "unknown"
end

-- Extract token from Authorization header
-- @param client table The client connection object
-- @return string|nil The extracted token or nil if not found
function auth.extract_token(client)
  if not client or not client.headers then
    log.info("No client or headers found")
    return nil
  end
  
  local auth_header = client.headers["Authorization"] or client.headers["authorization"]
  if not auth_header then
    log.info("No Authorization header found")
    return nil
  end
  
  log.info("Auth header found", {header = auth_header})
  
  -- Extract Bearer token
  local token = auth_header:match("^Bearer%s+(.+)$")
  
  log.info("Token extraction result", {token = token or "nil"})
  
  return token
end

-- Validate user session and extract user information
-- @param token string Session token
-- @return table user, table session, string error
function auth.validate_session(token)
  if not token then
    return nil, nil, "Missing authentication token"
  end
  
  -- Find and validate session
  local session, session_error = Session.find_by_token(token)
  if not session then
    return nil, nil, session_error or "Invalid session"
  end
  
    -- The find_by_token already includes user info, so extract it
  local validation = require("src.utils.validation")
  
  local user = {
    id = session.user_id,
    username = session.username,
    email = session.email,
    role = session.role,
    member_id = session.member_id,
    is_active = validation.normalize_boolean(session.is_active)
  }
  
  -- Debug logging
  log.info("Session validation debug", {
    user_id = session.user_id,
    username = session.username,
    is_active_raw = session.is_active,
    is_active_type = type(session.is_active),
    is_active_computed = user.is_active
  })
  
  -- Check if user is active
  if not user.is_active then
    return nil, nil, "User account is inactive"
  end
  
  return user, session, nil
end

-- Check if user has required permission level
-- @param user table User object
-- @param required_level number Required permission level
-- @return boolean true if authorized, false otherwise
function auth.has_permission(user, required_level)
  if not user or not user.role then
    return false
  end
  
  local user_level = ROLE_HIERARCHY[user.role] or 0
  return user_level >= required_level
end

-- Check if user can access specific resource
-- @param user table User object
-- @param resource_owner_id number ID of resource owner
-- @param required_level number Required permission level
-- @return boolean true if authorized, false otherwise
function auth.can_access_resource(user, resource_owner_id, required_level)
  if not user then
    return false
  end
  
  -- Admins and Pastors can access all resources
  if auth.has_permission(user, PERMISSION_LEVELS.READ_ALL) then
    return true
  end
  
  -- Members can only access their own resources
  if resource_owner_id and user.member_id == tonumber(resource_owner_id) then
    return true
  end
  
  return false
end

-- Authentication middleware - requires valid session
-- @param required_role string Optional minimum required role
-- @return function The middleware function
function auth.require_auth(required_role)
  return function(client, params, next)
    local client_ip = get_client_ip(client)
    local request_id = params and params.request_id or "unknown"
    
    -- Apply global rate limiting
    rate_limiter.global_rate_limit_middleware(client, params, function()
      -- Extract token
      local token = auth.extract_token(client)
      if not token then
        log.warn("Missing authentication token", {
          ip = client_ip,
          request_id = request_id
        })
        
        json_utils.send_json_response(client, 401, {
          error = "Unauthorized",
          code = "MISSING_TOKEN",
          message = "Authentication token is required",
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
        return
      end
      
      -- Validate session
      local user, session, auth_error = auth.validate_session(token)
      if not user then
        log.warn("Authentication failed", {
          ip = client_ip,
          request_id = request_id,
          error = auth_error
        })
        
        json_utils.send_json_response(client, 401, {
          error = "Unauthorized",
          code = "INVALID_TOKEN",
          message = auth_error or "Invalid authentication token",
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
        return
      end
      
      -- Check role requirement if specified
      if required_role then
        local required_level = ROLE_HIERARCHY[required_role] or 0
        if not auth.has_permission(user, required_level) then
          log.warn("Insufficient permissions", {
            ip = client_ip,
            request_id = request_id,
            user_id = user.id,
            user_role = user.role,
            required_role = required_role
          })
          
          json_utils.send_json_response(client, 403, {
            error = "Forbidden",
            code = "INSUFFICIENT_PERMISSIONS",
            message = "Insufficient permissions for this operation",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
          })
          return
        end
      end
      
      -- Add user and session to request context
      params = params or {}
      params.current_user = user
      params.current_session = session
      
      log.debug("Authentication successful", {
        ip = client_ip,
        request_id = request_id,
        user_id = user.id,
        username = user.username,
        role = user.role
      })
      
      -- Continue to next middleware/handler
      if next then
        next()
      end
    end)
  end
end

-- Authorization middleware for resource access
-- @param permission_level number Required permission level
-- @param resource_id_param string Parameter name containing resource owner ID
-- @return function The middleware function
function auth.require_permission(permission_level, resource_id_param)
  return function(client, params, next)
    local client_ip = get_client_ip(client)
    local request_id = params and params.request_id or "unknown"
    
    -- Check if user is authenticated (should be set by require_auth middleware)
    local user = params and params.current_user
    if not user then
      log.error("Authorization middleware called without authentication", {
        ip = client_ip,
        request_id = request_id
      })
      
      json_utils.send_json_response(client, 500, {
        error = "Internal Error",
        code = "MIDDLEWARE_ERROR",
        message = "Authentication required before authorization",
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
      })
      return
    end
    
    -- Check permission level
    if not auth.has_permission(user, permission_level) then
      -- If user doesn't have global permission, check resource-specific access
      local resource_id = nil
      if resource_id_param and params then
        resource_id = params[resource_id_param]
      end
      
      if not resource_id or not auth.can_access_resource(user, resource_id, permission_level) then
        log.warn("Authorization failed", {
          ip = client_ip,
          request_id = request_id,
          user_id = user.id,
          user_role = user.role,
          required_permission = permission_level,
          resource_id = resource_id
        })
        
        json_utils.send_json_response(client, 403, {
          error = "Forbidden",
          code = "INSUFFICIENT_PERMISSIONS",
          message = "You don't have permission to access this resource",
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
        return
      end
    end
    
    log.debug("Authorization successful", {
      ip = client_ip,
      request_id = request_id,
      user_id = user.id,
      permission_level = permission_level
    })
    
    -- Continue to next middleware/handler
    if next then
      next()
    end
  end
end

-- Optional authentication middleware - sets user if token is valid
-- @return function The middleware function
function auth.optional_auth()
  return function(client, params, next)
    local token = auth.extract_token(client)
    
    if token then
      local user, session, _ = auth.validate_session(token)
      if user then
        params = params or {}
        params.current_user = user
        params.current_session = session
      end
    end
    
    -- Always continue to next middleware/handler
    if next then
      next()
    end
  end
end

-- Admin only middleware
function auth.require_admin()
  return auth.require_auth("Admin")
end

-- Pastor or Admin middleware
function auth.require_pastor()
  return auth.require_auth("Pastor")
end

-- Member or higher middleware (any authenticated user)
function auth.require_member()
  return auth.require_auth("Member")
end

-- Resource owner or admin access
-- @param resource_id_param string Parameter name containing resource owner ID
-- @return function The middleware function
function auth.require_owner_or_admin(resource_id_param)
  return auth.require_permission(PERMISSION_LEVELS.READ_OWN, resource_id_param)
end

-- Admin write access
function auth.require_admin_write()
  return auth.require_permission(PERMISSION_LEVELS.ADMIN)
end

-- Pastor write access
function auth.require_pastor_write()
  return auth.require_permission(PERMISSION_LEVELS.WRITE_ALL)
end

-- CSRF protection middleware
-- @return function The middleware function
function auth.csrf_protection()
  return function(client, params, next)
    local client_ip = get_client_ip(client)
    local request_id = params and params.request_id or "unknown"
    
    -- Check for state-changing HTTP methods
    local method = client.method or "GET"
    if method == "POST" or method == "PUT" or method == "DELETE" or method == "PATCH" then
      -- Verify CSRF token in headers
      local csrf_token = client.headers and (
        client.headers["X-CSRF-Token"] or 
        client.headers["x-csrf-token"]
      )
      
      if not csrf_token then
        log.warn("Missing CSRF token", {
          ip = client_ip,
          request_id = request_id,
          method = method
        })
        
        json_utils.send_json_response(client, 403, {
          error = "Forbidden",
          code = "MISSING_CSRF_TOKEN",
          message = "CSRF token is required for this operation",
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
        return
      end
      
      -- Validate CSRF token against session
      local user = params and params.current_user
      local session = params and params.current_session
      
      if session and not Session.validate_csrf_token(session.token, csrf_token) then
        log.warn("Invalid CSRF token", {
          ip = client_ip,
          request_id = request_id,
          user_id = user and user.id,
          method = method
        })
        
        json_utils.send_json_response(client, 403, {
          error = "Forbidden",
          code = "INVALID_CSRF_TOKEN",
          message = "Invalid CSRF token",
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
        return
      end
    end
    
    -- Continue to next middleware/handler
    if next then
      next()
    end
  end
end

-- Export permission levels for use in controllers
auth.PERMISSION_LEVELS = PERMISSION_LEVELS
auth.ROLE_HIERARCHY = ROLE_HIERARCHY

return auth
