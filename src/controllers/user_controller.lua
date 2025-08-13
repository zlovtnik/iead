-- src/controllers/user_controller.lua
-- User management controller for admin operations

local User = require("src.models.user")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")
local security = require("src.utils.security")
local auth = require("src.middleware.auth")

local UserController = {}

-- List all users endpoint (Admin only)
function UserController.list_users(client, params)
  if not auth.require_admin()(client, params) then
    return
  end
  
  local users = User.find_all()
  json_utils.send_json_response(client, 200, {
    users = users,
    total = #users
  })
end

-- Get user details endpoint (Admin only)
function UserController.get_user(client, params, user_id)
  if not auth.require_admin()(client, params) then
    return
  end
  
  if not user_id then
    json_utils.send_json_response(client, 400, {
      error = "Missing user ID",
      code = "MISSING_USER_ID",
      message = "User ID is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  local user = User.find_by_id(tonumber(user_id))
  
  if not user then
    json_utils.send_json_response(client, 404, {
      error = "User not found",
      code = "USER_NOT_FOUND",
      message = "User with the specified ID does not exist",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  json_utils.send_json_response(client, 200, {
    user = user
  })
end

-- Create new user endpoint (Admin only)
function UserController.create_user(client, params)
  if not auth.require_admin()(client, params) then
    return
  end
  
  if not params.username or not params.email or not params.password or not params.role then
    json_utils.send_json_response(client, 400, {
      error = "Missing required fields",
      code = "MISSING_FIELDS",
      message = "Username, email, password, and role are required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  local user_data = {
    username = params.username,
    email = params.email,
    password = params.password,
    role = params.role,
    member_id = params.member_id,
    is_active = params.is_active,
    password_reset_required = params.password_reset_required
  }
  
  local user, error_msg = User.create(user_data)
  
  if not user then
    local error_code = "USER_CREATION_FAILED"
    local status_code = 400
    
    if error_msg:find("Username already exists") then
      error_code = "USERNAME_EXISTS"
    elseif error_msg:find("Email already exists") then
      error_code = "EMAIL_EXISTS"
    elseif error_msg:find("Invalid email format") then
      error_code = "INVALID_EMAIL"
    elseif error_msg:find("Invalid role") then
      error_code = "INVALID_ROLE"
    elseif error_msg:find("password") then
      error_code = "WEAK_PASSWORD"
    elseif error_msg:find("member does not exist") then
      error_code = "INVALID_MEMBER_ID"
    else
      status_code = 500
    end
    
    json_utils.send_json_response(client, status_code, {
      error = "User creation failed",
      code = error_code,
      message = error_msg,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  json_utils.send_json_response(client, 201, {
    message = "User created successfully",
    user = user
  })
end

-- Update user endpoint (Admin only)
function UserController.update_user(client, params, user_id)
  if not auth.require_admin()(client, params) then
    return
  end
  
  if not user_id then
    json_utils.send_json_response(client, 400, {
      error = "Missing user ID",
      code = "MISSING_USER_ID",
      message = "User ID is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Extract update data from params
  local update_data = {}
  if params.username then update_data.username = params.username end
  if params.email then update_data.email = params.email end
  if params.role then update_data.role = params.role end
  if params.member_id ~= nil then update_data.member_id = params.member_id end
  if params.is_active ~= nil then update_data.is_active = params.is_active end
  if params.password_reset_required ~= nil then update_data.password_reset_required = params.password_reset_required end
  
  local user, error_msg = User.update(tonumber(user_id), update_data)
  
  if not user then
    local error_code = "USER_UPDATE_FAILED"
    local status_code = 400
    
    if error_msg:find("User not found") then
      error_code = "USER_NOT_FOUND"
      status_code = 404
    elseif error_msg:find("Username already exists") then
      error_code = "USERNAME_EXISTS"
    elseif error_msg:find("Email already exists") then
      error_code = "EMAIL_EXISTS"
    elseif error_msg:find("Invalid email format") then
      error_code = "INVALID_EMAIL"
    elseif error_msg:find("Invalid role") then
      error_code = "INVALID_ROLE"
    elseif error_msg:find("member does not exist") then
      error_code = "INVALID_MEMBER_ID"
    elseif error_msg:find("No valid fields") then
      error_code = "NO_FIELDS_TO_UPDATE"
    else
      status_code = 500
    end
    
    json_utils.send_json_response(client, status_code, {
      error = "User update failed",
      code = error_code,
      message = error_msg,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  json_utils.send_json_response(client, 200, {
    message = "User updated successfully",
    user = user
  })
end

-- Deactivate user endpoint (Admin only)
function UserController.deactivate_user(client, params, user_id)
  if not auth.require_admin()(client, params) then
    return
  end
  
  if not user_id then
    json_utils.send_json_response(client, 400, {
      error = "Missing user ID",
      code = "MISSING_USER_ID",
      message = "User ID is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Prevent admin from deactivating themselves
  local current_user = auth.get_current_user(params)
  if current_user and tonumber(current_user.id) == tonumber(user_id) then
    json_utils.send_json_response(client, 400, {
      error = "Cannot deactivate own account",
      code = "CANNOT_DEACTIVATE_SELF",
      message = "You cannot deactivate your own account",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  local success, error_msg = User.deactivate(tonumber(user_id))
  
  if not success then
    local error_code = "USER_DEACTIVATION_FAILED"
    local status_code = 400
    
    if error_msg:find("User not found") then
      error_code = "USER_NOT_FOUND"
      status_code = 404
    else
      status_code = 500
    end
    
    json_utils.send_json_response(client, status_code, {
      error = "User deactivation failed",
      code = error_code,
      message = error_msg,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Invalidate all sessions for the deactivated user
  Session.invalidate_user_sessions(tonumber(user_id))
  
  json_utils.send_json_response(client, 200, {
    message = "User deactivated successfully"
  })
end

-- Activate user endpoint (Admin only)
function UserController.activate_user(client, params, user_id)
  if not auth.require_admin()(client, params) then
    return
  end
  
  if not user_id then
    json_utils.send_json_response(client, 400, {
      error = "Missing user ID",
      code = "MISSING_USER_ID",
      message = "User ID is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  local success, error_msg = User.activate(tonumber(user_id))
  
  if not success then
    local error_code = "USER_ACTIVATION_FAILED"
    local status_code = 400
    
    if error_msg:find("User not found") then
      error_code = "USER_NOT_FOUND"
      status_code = 404
    else
      status_code = 500
    end
    
    json_utils.send_json_response(client, status_code, {
      error = "User activation failed",
      code = error_code,
      message = error_msg,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  json_utils.send_json_response(client, 200, {
    message = "User activated successfully"
  })
end

-- Reset user password endpoint (Admin only)
function UserController.reset_password(client, params, user_id)
  if not auth.require_admin()(client, params) then
    return
  end
  
  if not user_id then
    json_utils.send_json_response(client, 400, {
      error = "Missing user ID",
      code = "MISSING_USER_ID",
      message = "User ID is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  if not params.new_password then
    json_utils.send_json_response(client, 400, {
      error = "Missing new password",
      code = "MISSING_PASSWORD",
      message = "New password is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  local success, error_msg = User.update_password(tonumber(user_id), params.new_password)
  
  if not success then
    local error_code = "PASSWORD_RESET_FAILED"
    local status_code = 400
    
    if error_msg:find("User not found") then
      error_code = "USER_NOT_FOUND"
      status_code = 404
    elseif error_msg:find("password") then
      error_code = "WEAK_PASSWORD"
    else
      status_code = 500
    end
    
    json_utils.send_json_response(client, status_code, {
      error = "Password reset failed",
      code = error_code,
      message = error_msg,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Optionally set password_reset_required flag
  if params.require_password_change then
    User.update(tonumber(user_id), { password_reset_required = true })
  end
  
  -- Invalidate all sessions for the user to force re-login
  Session.invalidate_user_sessions(tonumber(user_id))
  
  json_utils.send_json_response(client, 200, {
    message = "Password reset successfully"
  })
end

-- Change user role endpoint (Admin only)
function UserController.change_role(client, params, user_id)
  if not auth.require_admin()(client, params) then
    return
  end
  
  if not user_id then
    json_utils.send_json_response(client, 400, {
      error = "Missing user ID",
      code = "MISSING_USER_ID",
      message = "User ID is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  if not params.role then
    json_utils.send_json_response(client, 400, {
      error = "Missing role",
      code = "MISSING_ROLE",
      message = "Role is required",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Prevent admin from changing their own role
  local current_user = auth.get_current_user(params)
  if current_user and tonumber(current_user.id) == tonumber(user_id) then
    json_utils.send_json_response(client, 400, {
      error = "Cannot change own role",
      code = "CANNOT_CHANGE_OWN_ROLE",
      message = "You cannot change your own role",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  local user, error_msg = User.update(tonumber(user_id), { role = params.role })
  
  if not user then
    local error_code = "ROLE_CHANGE_FAILED"
    local status_code = 400
    
    if error_msg:find("User not found") then
      error_code = "USER_NOT_FOUND"
      status_code = 404
    elseif error_msg:find("Invalid role") then
      error_code = "INVALID_ROLE"
    else
      status_code = 500
    end
    
    json_utils.send_json_response(client, status_code, {
      error = "Role change failed",
      code = error_code,
      message = error_msg,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return
  end
  
  -- Invalidate all sessions for the user to force re-login with new role
  Session.invalidate_user_sessions(tonumber(user_id))
  
  json_utils.send_json_response(client, 200, {
    message = "User role changed successfully",
    user = user
  })
end

return UserController