-- src/controllers/user_controller_with_repository.lua
-- User controller using repository pattern

local UserRepository = require("src.infrastructure.repositories.user_repository")
local json_utils = require("src.utils.json")
local auth = require("src.middleware.auth")
local log = require("src.utils.log")
local fun = require("src.utils.functional")

local UserController = {}

-- Helper function to validate and convert user_id
local function validate_user_id(user_id, client)
  local id = tonumber(user_id)
  if not id or id <= 0 then
    json_utils.send_json_response(client, 400, {
      error = "Bad Request",
      message = "Invalid user ID",
      code = "INVALID_USER_ID"
    })
    return nil
  end
  return id
end

-- Helper function to send error response
local function send_error_response(client, status, message, code)
  json_utils.send_json_response(client, status, {
    error = "Error",
    message = message,
    code = code or "UNKNOWN_ERROR",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

-- Helper function to parse boolean values consistently
local function parse_boolean(value)
  if value == nil then
    return nil
  end
  
  -- Handle string values
  if type(value) == "string" then
    local lower = string.lower(value)
    if lower == "true" or lower == "1" or lower == "yes" then
      return 1
    elseif lower == "false" or lower == "0" or lower == "no" then
      return 0
    else
      return nil -- unparseable
    end
  end
  
  -- Handle numeric values
  if type(value) == "number" then
    if value == 1 then
      return 1
    elseif value == 0 then
      return 0
    else
      return nil -- unparseable
    end
  end
  
  -- Handle boolean values
  if type(value) == "boolean" then
    return value and 1 or 0
  end
  
  return nil -- unparseable
end

-- Helper function to sanitize data for logging (removes sensitive fields)
local function sanitize_for_logging(data)
  if type(data) ~= "table" then
    return data
  end
  
  -- Define sensitive field patterns that should be masked or omitted
  local sensitive_fields = {
    ["password"] = true,
    ["password_hash"] = true,
    ["ssn"] = true,
    ["token"] = true,
    ["auth_token"] = true,
    ["auth_key"] = true,
    ["auth_secret"] = true,
    ["session_token"] = true,
    ["api_key"] = true,
    ["secret"] = true
  }
  
  -- Use functional approach to filter out sensitive fields
  local sanitized = {}
  for key, value in pairs(data) do
    local lower_key = string.lower(key)
    if not (sensitive_fields[lower_key] or string.match(lower_key, "^auth_")) then
      sanitized[key] = value
    end
    -- Omit sensitive fields entirely from logs
  end
  
  return sanitized
end

-- List all users with pagination and filtering
-- GET /users
function UserController.list_users(client, params)
  local user_repo = UserRepository.new()
  
  -- Parse pagination parameters
  local page = tonumber(params.page) or 1
  local per_page = math.min(tonumber(params.per_page) or 10, 100) -- Max 100 per page
  
  -- Parse filtering parameters
  local conditions = {}
  if params.role then
    conditions.role = params.role
  end
  local parsed_is_active = parse_boolean(params.is_active)
  if parsed_is_active ~= nil then
    conditions.is_active = parsed_is_active
  end
  
  -- Parse search parameter
  local search_query = params.search
  if search_query and search_query ~= "" then
    -- Use search method instead of pagination for search queries
    local search_options = {
      conditions = conditions,
      order_by = params.sort_by or "username",
      order_direction = params.sort_order or "ASC",
      limit = per_page,
      offset = (page - 1) * per_page
    }
    
    local users, err = user_repo:search(search_query, search_options)
    if not users then
      send_error_response(client, 500, err, "SEARCH_FAILED")
      return
    end
    
    -- Count search results using search-aware count method
    local total_count, count_err = user_repo:count_search(search_query, {conditions = conditions})
    if not total_count then
      -- Fallback to result count if search count fails
      total_count = #users
      log.warn("Search count failed, using result count as fallback", {
        search_query = search_query,
        count_error = count_err,
        result_count = total_count
      })
    end
    
    json_utils.send_json_response(client, 200, {
      users = users,
      pagination = {
        current_page = page,
        per_page = per_page,
        total_count = total_count,
        total_pages = math.ceil(total_count / per_page)
      }
    })
    return
  end
  
  -- Regular pagination
  local pagination_options = {
    page = page,
    per_page = per_page,
    conditions = conditions,
    order_by = params.sort_by or "username",
    order_direction = params.sort_order or "ASC"
  }
  
  local result, err = user_repo:paginate(pagination_options)
  if not result then
    send_error_response(client, 500, err, "PAGINATION_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 200, {
    users = result.records,
    pagination = {
      current_page = result.current_page,
      per_page = result.per_page,
      total_count = result.total_count,
      total_pages = result.total_pages,
      has_next = result.has_next,
      has_prev = result.has_prev
    }
  })
end

-- Get a specific user by ID
-- GET /users/:id
function UserController.get_user(client, params, user_id)
  local id = validate_user_id(user_id, client)
  if not id then return end
  
  local user_repo = UserRepository.new()
  local user, err = user_repo:find_by_id(id)
  
  if not user then
    if err then
      send_error_response(client, 500, err, "DATABASE_ERROR")
    else
      send_error_response(client, 404, "User not found", "USER_NOT_FOUND")
    end
    return
  end
  
  -- Remove password from response
  user.password = nil
  
  json_utils.send_json_response(client, 200, {
    user = user
  })
end

-- Create a new user
-- POST /users
function UserController.create_user(client, params)
  local user_repo = UserRepository.new()
  
  -- Validate required fields
  local required_fields = {"username", "email", "password", "role"}
  for _, field in ipairs(required_fields) do
    if not params[field] or params[field] == "" then
      send_error_response(client, 400, field .. " is required", "MISSING_FIELD")
      return
    end
  end
  
  -- Validate role
  local valid_roles = {Admin = true, Pastor = true, Member = true}
  if not valid_roles[params.role] then
    send_error_response(client, 400, "Invalid role. Must be Admin, Pastor, or Member", "INVALID_ROLE")
    return
  end
  
  -- Check if username already exists
  local existing_user, check_err = user_repo:find_by_username(params.username)
  if check_err then
    send_error_response(client, 500, check_err, "DATABASE_ERROR")
    return
  end
  if existing_user then
    send_error_response(client, 409, "Username already exists", "USERNAME_EXISTS")
    return
  end
  
  -- Check if email already exists
  local existing_email, email_err = user_repo:find_by_email(params.email)
  if email_err then
    send_error_response(client, 500, email_err, "DATABASE_ERROR")
    return
  end
  if existing_email then
    send_error_response(client, 409, "Email already exists", "EMAIL_EXISTS")
    return
  end
  
  -- Create user data
  local user_data = {
    username = params.username,
    email = params.email,
    password = params.password,
    role = params.role,
    member_id = tonumber(params.member_id),
    is_active = parse_boolean(params.is_active) or 1
  }
  
  -- Create user
  local user, err = user_repo:create(user_data)
  if not user then
    send_error_response(client, 500, err, "USER_CREATION_FAILED")
    return
  end
  
  -- Remove password from response
  user.password = nil
  
  log.info("User created", {
    user_id = user.id,
    username = user.username,
    role = user.role,
    created_by = params.current_user and params.current_user.id
  })
  
  json_utils.send_json_response(client, 201, {
    user = user,
    message = "User created successfully"
  })
end

-- Update a user
-- PUT /users/:id
function UserController.update_user(client, params, user_id)
  local id = validate_user_id(user_id, client)
  if not id then return end
  
  local user_repo = UserRepository.new()
  
  -- Check if user exists
  local existing_user, err = user_repo:find_by_id(id)
  if not existing_user then
    if err then
      send_error_response(client, 500, err, "DATABASE_ERROR")
    else
      send_error_response(client, 404, "User not found", "USER_NOT_FOUND")
    end
    return
  end
  
  -- Prepare update data (only include changed fields)
  local update_data = {}
  
  if params.username and params.username ~= existing_user.username then
    -- Check if new username already exists
    local username_check, username_err = user_repo:find_by_username(params.username)
    if username_err then
      send_error_response(client, 500, username_err, "DATABASE_ERROR")
      return
    end
    if username_check then
      send_error_response(client, 409, "Username already exists", "USERNAME_EXISTS")
      return
    end
    update_data.username = params.username
  end
  
  if params.email and params.email ~= existing_user.email then
    -- Check if new email already exists
    local email_check, email_err = user_repo:find_by_email(params.email)
    if email_err then
      send_error_response(client, 500, email_err, "DATABASE_ERROR")
      return
    end
    if email_check then
      send_error_response(client, 409, "Email already exists", "EMAIL_EXISTS")
      return
    end
    update_data.email = params.email
  end
  
  if params.password then
    update_data.password = params.password
  end
  
  if params.role then
    local valid_roles = {Admin = true, Pastor = true, Member = true}
    if not valid_roles[params.role] then
      send_error_response(client, 400, "Invalid role", "INVALID_ROLE")
      return
    end
    update_data.role = params.role
  end
  
  if params.member_id then
    update_data.member_id = tonumber(params.member_id)
  end
  
  local parsed_is_active = parse_boolean(params.is_active)
  if parsed_is_active ~= nil then
    update_data.is_active = parsed_is_active
  end
  
  -- Only update if there are changes
  if not next(update_data) then
    send_error_response(client, 400, "No valid fields to update", "NO_CHANGES")
    return
  end
  
  -- Update user
  local updated_user, update_err = user_repo:update_by_id(id, update_data)
  if not updated_user then
    send_error_response(client, 500, update_err, "UPDATE_FAILED")
    return
  end
  
  -- Remove password from response
  updated_user.password = nil
  
  log.info("User updated", {
    user_id = id,
    updated_fields = sanitize_for_logging(update_data),
    updated_by = params.current_user and params.current_user.id
  })
  
  json_utils.send_json_response(client, 200, {
    user = updated_user,
    message = "User updated successfully"
  })
end

-- Deactivate a user (soft delete)
-- DELETE /users/:id
function UserController.deactivate_user(client, params, user_id)
  local id = validate_user_id(user_id, client)
  if not id then return end
  
  local user_repo = UserRepository.new()
  
  -- Check if user exists
  local user, err = user_repo:find_by_id(id)
  if not user then
    if err then
      send_error_response(client, 500, err, "DATABASE_ERROR")
    else
      send_error_response(client, 404, "User not found", "USER_NOT_FOUND")
    end
    return
  end
  
  -- Prevent self-deactivation
  if params.current_user and tonumber(params.current_user.id) == id then
    send_error_response(client, 400, "Cannot deactivate your own account", "SELF_DEACTIVATION")
    return
  end
  
  -- Deactivate user
  local success, deactivate_err = user_repo:set_active_status(id, false)
  if not success then
    send_error_response(client, 500, deactivate_err, "DEACTIVATION_FAILED")
    return
  end
  
  log.info("User deactivated", {
    user_id = id,
    username = user.username,
    deactivated_by = params.current_user and params.current_user.id
  })
  
  json_utils.send_json_response(client, 200, {
    message = "User deactivated successfully"
  })
end

-- Activate a user
-- POST /users/:id/activate
function UserController.activate_user(client, params, user_id)
  local id = validate_user_id(user_id, client)
  if not id then return end
  
  local user_repo = UserRepository.new()
  
  -- Check if user exists
  local user, err = user_repo:find_by_id(id)
  if not user then
    if err then
      send_error_response(client, 500, err, "DATABASE_ERROR")
    else
      send_error_response(client, 404, "User not found", "USER_NOT_FOUND")
    end
    return
  end
  
  -- Activate user
  local success, activate_err = user_repo:set_active_status(id, true)
  if not success then
    send_error_response(client, 500, activate_err, "ACTIVATION_FAILED")
    return
  end
  
  log.info("User activated", {
    user_id = id,
    username = user.username,
    activated_by = params.current_user and params.current_user.id
  })
  
  json_utils.send_json_response(client, 200, {
    message = "User activated successfully"
  })
end

-- Change user role
-- POST /users/:id/change-role
function UserController.change_role(client, params, user_id)
  local id = validate_user_id(user_id, client)
  if not id then return end
  
  if not params.role then
    send_error_response(client, 400, "Role is required", "MISSING_ROLE")
    return
  end
  
  local valid_roles = {Admin = true, Pastor = true, Member = true}
  if not valid_roles[params.role] then
    send_error_response(client, 400, "Invalid role", "INVALID_ROLE")
    return
  end
  
  local user_repo = UserRepository.new()
  
  -- Check if user exists
  local user, err = user_repo:find_by_id(id)
  if not user then
    if err then
      send_error_response(client, 500, err, "DATABASE_ERROR")
    else
      send_error_response(client, 404, "User not found", "USER_NOT_FOUND")
    end
    return
  end
  
  -- Change role
  local updated_user, role_err = user_repo:change_role(id, params.role)
  if not updated_user then
    send_error_response(client, 500, role_err, "ROLE_CHANGE_FAILED")
    return
  end
  
  -- Remove password from response
  updated_user.password = nil
  
  log.info("User role changed", {
    user_id = id,
    old_role = user.role,
    new_role = params.role,
    changed_by = params.current_user and params.current_user.id
  })
  
  json_utils.send_json_response(client, 200, {
    user = updated_user,
    message = "User role changed successfully"
  })
end

-- Get user statistics
-- GET /users/stats
function UserController.get_user_stats(client, params)
  local user_repo = UserRepository.new()
  
  local stats, err = user_repo:get_stats()
  if not stats then
    send_error_response(client, 500, err, "STATS_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 200, {
    stats = stats
  })
end

return UserController
