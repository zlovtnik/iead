-- src/controllers/auth_controller_secure.lua
-- Secure authentication controller with comprehensive security measures

local User = require("src.models.user_secure")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")
local security = require("src.utils.security")
local validator = require("src.application.validators.input_validator")
local rate_limiter = require("src.application.middlewares.rate_limit_middleware")
local log = require("src.utils.log")

local AuthController = {}

-- Generate request ID for tracking
local function generate_request_id()
  return security.generate_token(16)
end

-- Login endpoint with comprehensive security
-- POST /auth/login
function AuthController.login(client, params)
  local request_id = generate_request_id()
  local client_ip = client.ip or "unknown"
  
  log.info("Login attempt started", {
    request_id = request_id,
    ip = client_ip,
    username = params and params.username or "unknown"
  })
  
  -- Validate input data
  local sanitized_data, validation_errors = validator.validate_request(params, validator.schemas.user_login)
  if validation_errors then
    log.warn("Login validation failed", {
      request_id = request_id,
      ip = client_ip,
      errors = validation_errors
    })
    
    json_utils.send_json_response(client, 400, {
      error = "Validation Error",
      code = "VALIDATION_FAILED",
      message = "Invalid login data provided",
      details = validation_errors,
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Apply rate limiting for both IP and username
  local rate_limit_config = rate_limiter.get_config().auth_endpoints
  local ip_identifier = "login_ip:" .. client_ip
  local username_identifier = "login_username:" .. sanitized_data.username
  
  -- Check IP rate limit
  local ip_allowed, ip_remaining = rate_limiter.check_rate_limit(ip_identifier, rate_limit_config)
  if not ip_allowed then
    log.warn("IP rate limit exceeded", {
      request_id = request_id,
      ip = client_ip,
      username = sanitized_data.username
    })
    
    json_utils.send_json_response(client, 429, {
      error = "Rate Limit Exceeded",
      code = "IP_RATE_LIMIT_EXCEEDED",
      message = "Too many login attempts from this IP. Please try again in " .. 
               math.ceil(rate_limit_config.window_seconds / 60) .. " minutes",
      retry_after = rate_limit_config.window_seconds,
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Check username rate limit
  local username_allowed, username_remaining = rate_limiter.check_rate_limit(username_identifier, rate_limit_config)
  if not username_allowed then
    log.warn("Username rate limit exceeded", {
      request_id = request_id,
      ip = client_ip,
      username = sanitized_data.username
    })
    
    json_utils.send_json_response(client, 429, {
      error = "Rate Limit Exceeded",
      code = "USERNAME_RATE_LIMIT_EXCEEDED",
      message = "Too many login attempts for this username. Please try again in " .. 
               math.ceil(rate_limit_config.window_seconds / 60) .. " minutes",
      retry_after = rate_limit_config.window_seconds,
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Authenticate user
  local user, auth_error = User.authenticate(sanitized_data.username, sanitized_data.password)
  
  if not user then
    -- Record failed authentication attempt
    rate_limiter.record_attempt(ip_identifier, rate_limit_config)
    rate_limiter.record_attempt(username_identifier, rate_limit_config)
    
    log.warn("Authentication failed", {
      request_id = request_id,
      ip = client_ip,
      username = sanitized_data.username,
      error = auth_error
    })
    
    json_utils.send_json_response(client, 401, {
      error = "Authentication Failed",
      code = "INVALID_CREDENTIALS",
      message = "Invalid username or password",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Check if account is active
  if not user.is_active then
    log.warn("Login attempt on inactive account", {
      request_id = request_id,
      ip = client_ip,
      username = sanitized_data.username,
      user_id = user.id
    })
    
    json_utils.send_json_response(client, 403, {
      error = "Account Inactive",
      code = "ACCOUNT_INACTIVE",
      message = "Your account has been deactivated. Please contact an administrator",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Reset rate limits on successful authentication
  rate_limiter.reset_rate_limit(ip_identifier)
  rate_limiter.reset_rate_limit(username_identifier)
  
  -- Create session
  local session, session_error = Session.create(user.id, {
    ip_address = client_ip,
    user_agent = client.headers and client.headers["User-Agent"] or "Unknown",
    request_id = request_id
  })
  
  if not session then
    log.error("Failed to create session", {
      request_id = request_id,
      ip = client_ip,
      user_id = user.id,
      error = session_error
    })
    
    json_utils.send_json_response(client, 500, {
      error = "Session Creation Failed",
      code = "SESSION_ERROR",
      message = "Failed to create user session",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  log.info("User logged in successfully", {
    request_id = request_id,
    ip = client_ip,
    user_id = user.id,
    username = user.username,
    session_id = session.id
  })
  
  -- Return success response
  json_utils.send_json_response(client, 200, {
    message = "Login successful",
    user = {
      id = user.id,
      username = user.username,
      email = user.email,
      role = user.role,
      member_id = user.member_id,
      password_reset_required = user.password_reset_required
    },
    session = {
      token = session.token,
      expires_at = session.expires_at
    },
    request_id = request_id,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

-- Logout endpoint
-- POST /auth/logout
function AuthController.logout(client, params)
  local request_id = generate_request_id()
  local client_ip = client.ip or "unknown"
  
  -- Extract token from Authorization header
  local token = nil
  if client.headers and client.headers["Authorization"] then
    token = client.headers["Authorization"]:match("^Bearer%s+(.+)$")
  end
  
  if not token then
    json_utils.send_json_response(client, 400, {
      error = "Missing Token",
      code = "MISSING_TOKEN",
      message = "Authorization token is required",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Destroy session
  local success, error_msg = Session.destroy(token)
  
  if not success then
    log.warn("Failed to destroy session during logout", {
      request_id = request_id,
      ip = client_ip,
      error = error_msg
    })
    
    json_utils.send_json_response(client, 400, {
      error = "Logout Failed",
      code = "LOGOUT_ERROR",
      message = "Failed to logout: " .. (error_msg or "Unknown error"),
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  log.info("User logged out successfully", {
    request_id = request_id,
    ip = client_ip
  })
  
  json_utils.send_json_response(client, 200, {
    message = "Logout successful",
    request_id = request_id,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

-- Get current user endpoint
-- GET /auth/me
function AuthController.me(client, params)
  local request_id = generate_request_id()
  local client_ip = client.ip or "unknown"
  
  -- Extract token from Authorization header
  local token = nil
  if client.headers and client.headers["Authorization"] then
    token = client.headers["Authorization"]:match("^Bearer%s+(.+)$")
  end
  
  if not token then
    json_utils.send_json_response(client, 401, {
      error = "Unauthorized",
      code = "MISSING_TOKEN",
      message = "Authorization token is required",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Validate session and get user
  local session, session_error = Session.validate(token)
  if not session then
    log.warn("Invalid session token", {
      request_id = request_id,
      ip = client_ip,
      error = session_error
    })
    
    json_utils.send_json_response(client, 401, {
      error = "Unauthorized",
      code = "INVALID_TOKEN",
      message = "Invalid or expired session token",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Get user details
  local user, user_error = User.get_by_id(session.user_id)
  if not user then
    log.error("Failed to get user for valid session", {
      request_id = request_id,
      ip = client_ip,
      user_id = session.user_id,
      error = user_error
    })
    
    json_utils.send_json_response(client, 500, {
      error = "Internal Error",
      code = "USER_FETCH_ERROR",
      message = "Failed to retrieve user information",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Return user information
  json_utils.send_json_response(client, 200, {
    user = {
      id = user.id,
      username = user.username,
      email = user.email,
      role = user.role,
      member_id = user.member_id,
      is_active = user.is_active,
      password_reset_required = user.password_reset_required,
      last_login = user.last_login,
      created_at = user.created_at
    },
    session = {
      expires_at = session.expires_at,
      created_at = session.created_at
    },
    request_id = request_id,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

-- Refresh session endpoint
-- POST /auth/refresh
function AuthController.refresh(client, params)
  local request_id = generate_request_id()
  local client_ip = client.ip or "unknown"
  
  -- Extract token from Authorization header
  local token = nil
  if client.headers and client.headers["Authorization"] then
    token = client.headers["Authorization"]:match("^Bearer%s+(.+)$")
  end
  
  if not token then
    json_utils.send_json_response(client, 401, {
      error = "Unauthorized",
      code = "MISSING_TOKEN",
      message = "Authorization token is required",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Refresh session
  local new_session, refresh_error = Session.refresh(token, {
    ip_address = client_ip,
    user_agent = client.headers and client.headers["User-Agent"] or "Unknown",
    request_id = request_id
  })
  
  if not new_session then
    log.warn("Failed to refresh session", {
      request_id = request_id,
      ip = client_ip,
      error = refresh_error
    })
    
    json_utils.send_json_response(client, 401, {
      error = "Session Refresh Failed",
      code = "REFRESH_ERROR",
      message = "Failed to refresh session: " .. (refresh_error or "Unknown error"),
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  log.info("Session refreshed successfully", {
    request_id = request_id,
    ip = client_ip,
    user_id = new_session.user_id,
    session_id = new_session.id
  })
  
  -- Return new session
  json_utils.send_json_response(client, 200, {
    message = "Session refreshed successfully",
    session = {
      token = new_session.token,
      expires_at = new_session.expires_at
    },
    request_id = request_id,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

-- Change password endpoint
-- POST /auth/change-password
function AuthController.change_password(client, params)
  local request_id = generate_request_id()
  local client_ip = client.ip or "unknown"
  
  -- Extract token from Authorization header
  local token = nil
  if client.headers and client.headers["Authorization"] then
    token = client.headers["Authorization"]:match("^Bearer%s+(.+)$")
  end
  
  if not token then
    json_utils.send_json_response(client, 401, {
      error = "Unauthorized",
      code = "MISSING_TOKEN",
      message = "Authorization token is required",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Validate session
  local session, session_error = Session.validate(token)
  if not session then
    json_utils.send_json_response(client, 401, {
      error = "Unauthorized",
      code = "INVALID_TOKEN",
      message = "Invalid or expired session token",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Validate input
  if not params or not params.current_password or not params.new_password then
    json_utils.send_json_response(client, 400, {
      error = "Missing Fields",
      code = "MISSING_FIELDS",
      message = "Current password and new password are required",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Verify current password by re-authenticating user
  local user, auth_error = User.authenticate(session.username or "", params.current_password)
  if not user or user.id ~= session.user_id then
    log.warn("Invalid current password during password change", {
      request_id = request_id,
      ip = client_ip,
      user_id = session.user_id
    })
    
    json_utils.send_json_response(client, 400, {
      error = "Invalid Password",
      code = "INVALID_CURRENT_PASSWORD",
      message = "Current password is incorrect",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Update password
  local success, update_error = User.update_password(session.user_id, params.new_password)
  if not success then
    log.error("Failed to update password", {
      request_id = request_id,
      ip = client_ip,
      user_id = session.user_id,
      error = update_error
    })
    
    json_utils.send_json_response(client, 400, {
      error = "Password Update Failed",
      code = "PASSWORD_UPDATE_ERROR",
      message = update_error or "Failed to update password",
      request_id = request_id,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  log.info("Password changed successfully", {
    request_id = request_id,
    ip = client_ip,
    user_id = session.user_id
  })
  
  json_utils.send_json_response(client, 200, {
    message = "Password changed successfully",
    request_id = request_id,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

return AuthController
