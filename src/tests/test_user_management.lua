-- src/tests/test_user_management.lua
-- Unit tests for user management controller operations

local UserController = require("src.controllers.user_controller")
local User = require("src.models.user")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")
local auth = require("src.middleware.auth")

-- Mock client object for testing
local function create_mock_client()
  local responses = {}
  return {
    headers = {},
    responses = responses,
    send = function(self, data)
      table.insert(responses, data)
    end
  }
end

-- Mock params with admin user
local function create_admin_params()
  return {
    current_user = {
      id = 1,
      username = "admin",
      email = "admin@test.com",
      role = "Admin",
      is_active = true
    },
    session_token = "valid_admin_token"
  }
end

-- Mock params with non-admin user
local function create_member_params()
  return {
    current_user = {
      id = 2,
      username = "member",
      email = "member@test.com",
      role = "Member",
      member_id = 1,
      is_active = true
    },
    session_token = "valid_member_token"
  }
end

-- Test helper to capture JSON responses
local function capture_json_response(client, expected_status)
  local response_data = nil
  local original_send = json_utils.send_json_response
  
  json_utils.send_json_response = function(c, status, data)
    if c == client then
      response_data = {status = status, data = data}
    end
  end
  
  return function()
    json_utils.send_json_response = original_send
    return response_data
  end
end

-- Test helper to mock auth middleware
local function mock_auth_require_admin(should_pass)
  local original_require_admin = auth.require_admin
  
  auth.require_admin = function()
    return function(client, params)
      return should_pass
    end
  end
  
  return function()
    auth.require_admin = original_require_admin
  end
end

-- Test helper to mock User model methods
local function mock_user_methods(mocks)
  local originals = {}
  
  for method, mock_func in pairs(mocks) do
    originals[method] = User[method]
    User[method] = mock_func
  end
  
  return function()
    for method, original_func in pairs(originals) do
      User[method] = original_func
    end
  end
end

-- Test helper to mock Session model methods
local function mock_session_methods(mocks)
  local originals = {}
  
  for method, mock_func in pairs(mocks) do
    originals[method] = Session[method]
    Session[method] = mock_func
  end
  
  return function()
    for method, original_func in pairs(originals) do
      Session[method] = original_func
    end
  end
end

-- Test suite
local tests = {}

-- Test list_users endpoint
function tests.test_list_users_success()
  local client = create_mock_client()
  local params = create_admin_params()
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    find_all = function()
      return {
        {id = 1, username = "admin", email = "admin@test.com", role = "Admin"},
        {id = 2, username = "user1", email = "user1@test.com", role = "Member"}
      }
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.list_users(client, params)
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 200, "Expected status 200")
  assert(response.data.total == 2, "Expected 2 users")
  assert(#response.data.users == 2, "Expected 2 users in array")
  print("✓ list_users success test passed")
end

function tests.test_list_users_unauthorized()
  local client = create_mock_client()
  local params = create_member_params()
  
  local cleanup_auth = mock_auth_require_admin(false)
  local cleanup_response = capture_json_response(client)
  
  UserController.list_users(client, params)
  
  local response = cleanup_response()
  cleanup_auth()
  
  -- Should not have response since auth middleware handles the error
  assert(response == nil, "Expected no response when unauthorized")
  print("✓ list_users unauthorized test passed")
end

-- Test get_user endpoint
function tests.test_get_user_success()
  local client = create_mock_client()
  local params = create_admin_params()
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    find_by_id = function(id)
      if id == 2 then
        return {id = 2, username = "user1", email = "user1@test.com", role = "Member"}
      end
      return nil
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.get_user(client, params, "2")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 200, "Expected status 200")
  assert(response.data.user.id == 2, "Expected user ID 2")
  print("✓ get_user success test passed")
end

function tests.test_get_user_not_found()
  local client = create_mock_client()
  local params = create_admin_params()
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    find_by_id = function(id)
      return nil
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.get_user(client, params, "999")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 404, "Expected status 404")
  assert(response.data.code == "USER_NOT_FOUND", "Expected USER_NOT_FOUND error code")
  print("✓ get_user not found test passed")
end

function tests.test_get_user_missing_id()
  local client = create_mock_client()
  local params = create_admin_params()
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_response = capture_json_response(client)
  
  UserController.get_user(client, params, nil)
  
  local response = cleanup_response()
  cleanup_auth()
  
  assert(response.status == 400, "Expected status 400")
  assert(response.data.code == "MISSING_USER_ID", "Expected MISSING_USER_ID error code")
  print("✓ get_user missing ID test passed")
end

-- Test create_user endpoint
function tests.test_create_user_success()
  local client = create_mock_client()
  local params = create_admin_params()
  params.username = "newuser"
  params.email = "newuser@test.com"
  params.password = "SecurePass123!"
  params.role = "Member"
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    create = function(data)
      return {
        id = 3,
        username = data.username,
        email = data.email,
        role = data.role,
        is_active = true
      }
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.create_user(client, params)
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 201, "Expected status 201")
  assert(response.data.user.username == "newuser", "Expected correct username")
  print("✓ create_user success test passed")
end

function tests.test_create_user_missing_fields()
  local client = create_mock_client()
  local params = create_admin_params()
  -- Missing required fields
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_response = capture_json_response(client)
  
  UserController.create_user(client, params)
  
  local response = cleanup_response()
  cleanup_auth()
  
  assert(response.status == 400, "Expected status 400")
  assert(response.data.code == "MISSING_FIELDS", "Expected MISSING_FIELDS error code")
  print("✓ create_user missing fields test passed")
end

function tests.test_create_user_username_exists()
  local client = create_mock_client()
  local params = create_admin_params()
  params.username = "existing"
  params.email = "new@test.com"
  params.password = "SecurePass123!"
  params.role = "Member"
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    create = function(data)
      return nil, "Username already exists"
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.create_user(client, params)
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 400, "Expected status 400")
  assert(response.data.code == "USERNAME_EXISTS", "Expected USERNAME_EXISTS error code")
  print("✓ create_user username exists test passed")
end

-- Test update_user endpoint
function tests.test_update_user_success()
  local client = create_mock_client()
  local params = create_admin_params()
  params.username = "updated_user"
  params.email = "updated@test.com"
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    update = function(id, data)
      return {
        id = id,
        username = data.username,
        email = data.email,
        role = "Member",
        is_active = true
      }
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.update_user(client, params, "2")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 200, "Expected status 200")
  assert(response.data.user.username == "updated_user", "Expected updated username")
  print("✓ update_user success test passed")
end

function tests.test_update_user_not_found()
  local client = create_mock_client()
  local params = create_admin_params()
  params.username = "updated_user"
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    update = function(id, data)
      return nil, "User not found"
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.update_user(client, params, "999")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 404, "Expected status 404")
  assert(response.data.code == "USER_NOT_FOUND", "Expected USER_NOT_FOUND error code")
  print("✓ update_user not found test passed")
end

-- Test deactivate_user endpoint
function tests.test_deactivate_user_success()
  local client = create_mock_client()
  local params = create_admin_params()
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    deactivate = function(id)
      return true
    end
  })
  local cleanup_session = mock_session_methods({
    invalidate_user_sessions = function(user_id)
      return true
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.deactivate_user(client, params, "2")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  cleanup_session()
  
  assert(response.status == 200, "Expected status 200")
  assert(response.data.message:find("deactivated"), "Expected deactivation message")
  print("✓ deactivate_user success test passed")
end

function tests.test_deactivate_user_self()
  local client = create_mock_client()
  local params = create_admin_params()
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_response = capture_json_response(client)
  
  -- Try to deactivate own account (user ID 1)
  UserController.deactivate_user(client, params, "1")
  
  local response = cleanup_response()
  cleanup_auth()
  
  assert(response.status == 400, "Expected status 400")
  assert(response.data.code == "CANNOT_DEACTIVATE_SELF", "Expected CANNOT_DEACTIVATE_SELF error code")
  print("✓ deactivate_user self test passed")
end

-- Test activate_user endpoint
function tests.test_activate_user_success()
  local client = create_mock_client()
  local params = create_admin_params()
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    activate = function(id)
      return true
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.activate_user(client, params, "2")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  
  assert(response.status == 200, "Expected status 200")
  assert(response.data.message:find("activated"), "Expected activation message")
  print("✓ activate_user success test passed")
end

-- Test reset_password endpoint
function tests.test_reset_password_success()
  local client = create_mock_client()
  local params = create_admin_params()
  params.new_password = "NewSecurePass123!"
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    update_password = function(id, password)
      return true
    end
  })
  local cleanup_session = mock_session_methods({
    invalidate_user_sessions = function(user_id)
      return true
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.reset_password(client, params, "2")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  cleanup_session()
  
  assert(response.status == 200, "Expected status 200")
  assert(response.data.message:find("reset"), "Expected password reset message")
  print("✓ reset_password success test passed")
end

function tests.test_reset_password_missing_password()
  local client = create_mock_client()
  local params = create_admin_params()
  -- Missing new_password
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_response = capture_json_response(client)
  
  UserController.reset_password(client, params, "2")
  
  local response = cleanup_response()
  cleanup_auth()
  
  assert(response.status == 400, "Expected status 400")
  assert(response.data.code == "MISSING_PASSWORD", "Expected MISSING_PASSWORD error code")
  print("✓ reset_password missing password test passed")
end

-- Test change_role endpoint
function tests.test_change_role_success()
  local client = create_mock_client()
  local params = create_admin_params()
  params.role = "Pastor"
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_user = mock_user_methods({
    update = function(id, data)
      return {
        id = id,
        username = "user1",
        email = "user1@test.com",
        role = data.role,
        is_active = true
      }
    end
  })
  local cleanup_session = mock_session_methods({
    invalidate_user_sessions = function(user_id)
      return true
    end
  })
  
  local cleanup_response = capture_json_response(client)
  
  UserController.change_role(client, params, "2")
  
  local response = cleanup_response()
  cleanup_auth()
  cleanup_user()
  cleanup_session()
  
  assert(response.status == 200, "Expected status 200")
  assert(response.data.user.role == "Pastor", "Expected role to be Pastor")
  print("✓ change_role success test passed")
end

function tests.test_change_role_self()
  local client = create_mock_client()
  local params = create_admin_params()
  params.role = "Pastor"
  
  local cleanup_auth = mock_auth_require_admin(true)
  local cleanup_response = capture_json_response(client)
  
  -- Try to change own role (user ID 1)
  UserController.change_role(client, params, "1")
  
  local response = cleanup_response()
  cleanup_auth()
  
  assert(response.status == 400, "Expected status 400")
  assert(response.data.code == "CANNOT_CHANGE_OWN_ROLE", "Expected CANNOT_CHANGE_OWN_ROLE error code")
  print("✓ change_role self test passed")
end

-- Run all tests
local function run_tests()
  print("Running User Management Controller Tests...")
  print("=" .. string.rep("=", 50))
  
  local passed = 0
  local failed = 0
  
  for test_name, test_func in pairs(tests) do
    local success, error_msg = pcall(test_func)
    if success then
      passed = passed + 1
    else
      failed = failed + 1
      print("✗ " .. test_name .. " FAILED: " .. tostring(error_msg))
    end
  end
  
  print("=" .. string.rep("=", 50))
  print(string.format("Tests completed: %d passed, %d failed", passed, failed))
  
  if failed > 0 then
    os.exit(1)
  end
end

-- Export for external test runner
if not package.loaded["src.tests.test_runner"] then
  run_tests()
end

return {
  name = "User Management Controller Tests",
  tests = tests,
  run = run_tests
}