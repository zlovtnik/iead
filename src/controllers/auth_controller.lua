-- src/controllers/auth_controller.lua
-- Authentication controller for login/logout operations

local User = require("src.models.user")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")
local security = require("src.utils.security")
local auth = require("src.middleware.auth")
local log = require("src.utils.log")

local AuthController = {}

-- Login endpoint - authenticate user and create session
-- POST /auth/login
function AuthController.login(client, params)
  -- Validate required fields
  if not params.username or not params.password then
    json_utils.send_json_response(client, 400, {
      error = "Missing required fields",
      code = "MISSING_CREDENTIALS",
      message = "Username and password are required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Apply rate limiting
  local rate_limit_identifier = params.username
  if not auth.rate_limit_check(rate_limit_identifier) then
    json_utils.send_json_response(client, 429, {
      error = "Rate limit exceeded",
      code = "RATE_LIMIT_EXCEEDED",
      message = "Too many login attempts. Please try again in 15 minutes",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Authenticate user
  local user, auth_error = User.authenticate(params.username, params.password)
  
  if not user then
    json_utils.send_json_response(client, 401, {
      error = "Authentication failed",
      code = "INVALID_CREDENTIALS",
      message = auth_error or "Invalid username or password",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Create session
  local session_duration = params.remember_me and (7 * 24 * 60 * 60) or nil -- 7 days if remember_me
  local session, session_error = Session.create(user.id, session_duration)
  
  if not session then
    json_utils.send_json_response(client, 500, {
      error = "Session creation failed",
      code = "SESSION_ERROR",
      message = session_error or "Failed to create session",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Clear rate limiting on successful login
  auth.clear_rate_limit(rate_limit_identifier)
  
  -- Return success response with token and user info
  json_utils.send_json_response(client, 200, {
    message = "Login successful",
    token = session.token,
    expires_at = session.expires_at,
    user = {
      id = user.id,
      username = user.username,
      email = user.email,
      role = user.role,
      member_id = user.member_id,
      password_reset_required = user.password_reset_required
    }
  })
end

-- Logout endpoint - invalidate session
-- POST /auth/logout
function AuthController.logout(client, params)
  -- Extract token from request
  local token = auth.extract_token(client)
  
  if not token then
    json_utils.send_json_response(client, 400, {
      error = "Missing token",
      code = "MISSING_TOKEN",
      message = "Authentication token is required for logout",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Invalidate session
  local success, error_msg = Session.invalidate(token)
  
  if not success then
    json_utils.send_json_response(client, 400, {
      error = "Logout failed",
      code = "LOGOUT_ERROR",
      message = error_msg or "Failed to logout",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  json_utils.send_json_response(client, 200, {
    message = "Logout successful"
  })
end

-- Token refresh endpoint - extend session expiration
-- POST /auth/refresh
function AuthController.refresh_token(client, params)
  -- Extract token from request
  local token = auth.extract_token(client)
  
  if not token then
    json_utils.send_json_response(client, 400, {
      error = "Missing token",
      code = "MISSING_TOKEN",
      message = "Authentication token is required for refresh",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Refresh session
  local session_duration = params.remember_me and (7 * 24 * 60 * 60) or nil -- 7 days if remember_me
  local updated_session, refresh_error = Session.refresh(token, session_duration)
  
  if not updated_session then
    local error_code = "REFRESH_ERROR"
    local message = refresh_error or "Failed to refresh token"
    
    if refresh_error == "Invalid token" then
      error_code = "INVALID_TOKEN"
      message = "Invalid or expired authentication token"
    end
    
    json_utils.send_json_response(client, 401, {
      error = "Token refresh failed",
      code = error_code,
      message = message,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  json_utils.send_json_response(client, 200, {
    message = "Token refreshed successfully",
    token = updated_session.token,
    expires_at = updated_session.expires_at
  })
end

-- Get current user info endpoint
-- GET /auth/me
function AuthController.get_current_user(client, params)
  -- Authenticate request first
  if not auth.authenticate_request(client, params) then
    return -- Error already sent by authenticate_request
  end
  
  local user = params.current_user
  
  json_utils.send_json_response(client, 200, {
    user = {
      id = user.id,
      username = user.username,
      email = user.email,
      role = user.role,
      member_id = user.member_id,
      is_active = user.is_active
    }
  })
end

-- Change password endpoint
-- PUT /auth/password
function AuthController.change_password(client, params)
  -- Authenticate request first
  if not auth.authenticate_request(client, params) then
    return -- Error already sent by authenticate_request
  end
  
  local user = params.current_user
  
  -- Validate required fields
  if not params.current_password or not params.new_password then
    json_utils.send_json_response(client, 400, {
      error = "Missing required fields",
      code = "MISSING_FIELDS",
      message = "Current password and new password are required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Verify current password
  local current_user_data, auth_error = User.authenticate(user.username, params.current_password)
  
  if not current_user_data then
    json_utils.send_json_response(client, 401, {
      error = "Authentication failed",
      code = "INVALID_CURRENT_PASSWORD",
      message = "Current password is incorrect",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Validate new password strength
  local password_valid, password_error = security.validate_password_strength(params.new_password)
  if not password_valid then
    json_utils.send_json_response(client, 400, {
      error = "Invalid password",
      code = "WEAK_PASSWORD",
      message = password_error,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Check if new password is different from current password
  if params.new_password == params.current_password then
    json_utils.send_json_response(client, 400, {
      error = "Invalid password",
      code = "SAME_PASSWORD",
      message = "New password must be different from current password",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Update password
  local success, update_error = User.update_password(user.id, params.new_password)
  
  if not success then
    json_utils.send_json_response(client, 500, {
      error = "Password update failed",
      code = "UPDATE_ERROR",
      message = update_error or "Failed to update password",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Optionally invalidate all other sessions for security
  if params.invalidate_other_sessions then
    local invalidated_count, sess_err = Session.invalidate_user_sessions(user.id)
    if sess_err then
      log.error("Failed to invalidate sessions for user:", user.id, sess_err)
      json_utils.send_json_response(client, 500, { error = "Failed to invalidate user sessions" })
      return
    end
    -- Re-create current session
    local new_session, session_error = Session.create(user.id)
    if new_session then
      json_utils.send_json_response(client, 200, {
        message = "Password changed successfully. All other sessions have been invalidated.",
        new_token = new_session.token,
        expires_at = new_session.expires_at,
        invalidated_sessions = invalidated_count
      })
      return
    end
  end
  
  json_utils.send_json_response(client, 200, {
    message = "Password changed successfully"
  })
end

return AuthController