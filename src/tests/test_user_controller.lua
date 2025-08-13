-- src/tests/test_user_controller.lua
-- Unit tests for user management controller

local UserController = require("src.controllers.user_controller")
local User = require("src.models.user")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")

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

-- Mock JSON response function
local original_send_json_response = json_utils.send_json_response
local function mock_json_response()
  local responses = {}
  json_utils.send_json_response = function(client, status, data)
    table.insert(responses, {status = status, data = data})
    client.last_response = {status = status, data = data}
  end
  return responses
end

-- Restore original JSON response function
local function restore_json_response()
  json_utils.send_json_response = original_send_json_response
end

-- Test helper to create admin user session
local function create_admin_session()
  -- Create admin user
  local admin_user = User.create({
    username = "admin_test",
    email = "admin@test.com",
    password = "AdminPass123",
    role = "Admin"
  })
  
  -- Create session
  local session = Session.create(admin_user.id)
  
  return admin_user, session
end

-- Test helper to create non-admin user session
local function create_member_session()
  -- Create member user
  local member_user = User.create({
    username = "member_test",
    email = "member@test.com",
    password = "MemberPass123",
    role = "Member"
  })
  
  -- Create session
  local session = Session.create(member_user.id)
  
  return member_user, session
end

-- Test helper to create authenticated client
local function create_authenticated_client(session_token)
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session_token
  return client
end

-- Initialize test environment
local function setup_test()
  -- Initialize database
  User.init_db()
  Session.init_db()
  
  -- Clean up any existing test data
  local conn, env = User.get_connection()
  conn:execute("DELETE FROM sessions WHERE 1=1")
  conn:execute("DELETE FROM users WHERE username LIKE '%_test' OR email LIKE '%@test.com'")
  conn:close()
  env:close()
end

-- Clean up test environment
local function teardown_test()
  local conn, env = User.get_connection()
  conn:execute("DELETE FROM sessions WHERE 1=1")
  conn:execute("DELETE FROM users WHERE username LIKE '%_test' OR email LIKE '%@test.com'")
  conn:close()
  env:close()
end

-- Test list_users endpoint
local function test_list_users()
  print("Testing list_users endpoint...")
  setup_test()
  local responses = mock_json_response()
  
  -- Test with admin user
  local admin_user, admin_session = create_admin_session()
  local client = create_authenticated_client(admin_session.token)
  local params = {}
  
  UserController.list_users(client, params)
  
  assert(client.last_response.status == 200, "Should return 200 for admin user")
  assert(client.last_response.data.users, "Should return users array")
  assert(client.last_response.data.total, "Should return total count")
  
  -- Test with non-admin user
  local member_user, member_session = create_member_session()
  client = create_authenticated_client(member_session.token)
  params = {}
  
  UserController.list_users(client, params)
  
  assert(client.last_response.status == 403, "Should return 403 for non-admin user")
  assert(client.last_response.data.code == "INSUFFICIENT_PERMISSIONS", "Should have correct error code")
  
  -- Test without authentication
  client = create_mock_client()
  params = {}
  
  UserController.list_users(client, params)
  
  assert(client.last_response.status == 401, "Should return 401 without authentication")
  
  restore_json_response()
  teardown_test()
  print("✓ list_users tests passed")
end

-- Test create_user endpoint
local function test_create_user()
  print("Testing create_user endpoint...")
  setup_test()
  local responses = mock_json_response()
  
  -- Test successful user creation
  local admin_user, admin_session = create_admin_session()
  local client = create_authenticated_client(admin_session.token)
  local params = {
    username = "new_user_test",
    email = "newuser@test.com",
    password = "NewUserPass123",
    role = "Member"
  }
  
  UserController.create_user(client, params)
  
  assert(client.last_response.status == 201, "Should return 201 for successful creation")
  assert(client.last_response.data.user, "Should return created user")
  assert(client.last_response.data.user.username == "new_user_test", "Should have correct username")
  
  -- Test missing required fields
  client = create_authenticated_client(admin_session.token)
  params = {
    username = "incomplete_user"
    -- Missing email, password, role
  }
  
  UserController.create_user(client, params)
  
  assert(client.last_response.status == 400, "Should return 400 for missing fields")
  assert(client.last_response.data.code == "MISSING_FIELDS", "Should have correct error code")
  
  -- Test duplicate username
  client = create_authenticated_client(admin_session.token)
  params = {
    username = "new_user_test", -- Same as above
    email = "another@test.com",
    password = "AnotherPass123",
    role = "Member"
  }
  
  UserController.create_user(client, params)
  
  assert(client.last_response.status == 400, "Should return 400 for duplicate username")
  assert(client.last_response.data.code == "USERNAME_EXISTS", "Should have correct error code")
  
  -- Test invalid role
  client = create_authenticated_client(admin_session.token)
  params = {
    username = "invalid_role_test",
    email = "invalid@test.com",
    password = "InvalidPass123",
    role = "InvalidRole"
  }
  
  UserController.create_user(client, params)
  
  assert(client.last_response.status == 400, "Should return 400 for invalid role")
  assert(client.last_response.data.code == "INVALID_ROLE", "Should have correct error code")
  
  -- Test non-admin access
  local member_user, member_session = create_member_session()
  client = create_authenticated_client(member_session.token)
  params = {
    username = "unauthorized_test",
    email = "unauthorized@test.com",
    password = "UnauthorizedPass123",
    role = "Member"
  }
  
  UserController.create_user(client, params)
  
  assert(client.last_response.status == 403, "Should return 403 for non-admin user")
  
  restore_json_response()
  teardown_test()
  print("✓ create_user tests passed")
end

-- Test get_user endpoint
local function test_get_user()
  print("Testing get_user endpoint...")
  setup_test()
  local responses = mock_json_response()
  
  -- Create test user
  local test_user = User.create({
    username = "get_test_user",
    email = "gettest@test.com",
    password = "GetTestPass123",
    role = "Member"
  })
  
  -- Test successful user retrieval
  local admin_user, admin_session = create_admin_session()
  local client = create_authenticated_client(admin_session.token)
  local params = {}
  
  UserController.get_user(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 200, "Should return 200 for valid user ID")
  assert(client.last_response.data.user, "Should return user data")
  assert(client.last_response.data.user.id == test_user.id, "Should return correct user")
  
  -- Test invalid user ID
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.get_user(client, params, "invalid")
  
  assert(client.last_response.status == 400, "Should return 400 for invalid user ID")
  assert(client.last_response.data.code == "INVALID_USER_ID", "Should have correct error code")
  
  -- Test non-existent user
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.get_user(client, params, "99999")
  
  assert(client.last_response.status == 404, "Should return 404 for non-existent user")
  assert(client.last_response.data.code == "USER_NOT_FOUND", "Should have correct error code")
  
  -- Test non-admin access
  local member_user, member_session = create_member_session()
  client = create_authenticated_client(member_session.token)
  params = {}
  
  UserController.get_user(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 403, "Should return 403 for non-admin user")
  
  restore_json_response()
  teardown_test()
  print("✓ get_user tests passed")
end

-- Test update_user endpoint
local function test_update_user()
  print("Testing update_user endpoint...")
  setup_test()
  local responses = mock_json_response()
  
  -- Create test user
  local test_user = User.create({
    username = "update_test_user",
    email = "updatetest@test.com",
    password = "UpdateTestPass123",
    role = "Member"
  })
  
  -- Test successful user update
  local admin_user, admin_session = create_admin_session()
  local client = create_authenticated_client(admin_session.token)
  local params = {
    username = "updated_username_test",
    email = "updated@test.com",
    role = "Pastor"
  }
  
  UserController.update_user(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 200, "Should return 200 for successful update")
  assert(client.last_response.data.user, "Should return updated user")
  assert(client.last_response.data.user.username == "updated_username_test", "Should have updated username")
  assert(client.last_response.data.user.role == "Pastor", "Should have updated role")
  
  -- Test admin cannot deactivate themselves
  client = create_authenticated_client(admin_session.token)
  params = {
    is_active = false
  }
  
  UserController.update_user(client, params, tostring(admin_user.id))
  
  assert(client.last_response.status == 400, "Should return 400 when admin tries to deactivate self")
  assert(client.last_response.data.code == "CANNOT_DEACTIVATE_SELF", "Should have correct error code")
  
  -- Test admin cannot change own role
  client = create_authenticated_client(admin_session.token)
  params = {
    role = "Member"
  }
  
  UserController.update_user(client, params, tostring(admin_user.id))
  
  assert(client.last_response.status == 400, "Should return 400 when admin tries to change own role")
  assert(client.last_response.data.code == "CANNOT_CHANGE_OWN_ROLE", "Should have correct error code")
  
  -- Test invalid user ID
  client = create_authenticated_client(admin_session.token)
  params = {
    username = "invalid_update"
  }
  
  UserController.update_user(client, params, "invalid")
  
  assert(client.last_response.status == 400, "Should return 400 for invalid user ID")
  assert(client.last_response.data.code == "INVALID_USER_ID", "Should have correct error code")
  
  -- Test non-existent user
  client = create_authenticated_client(admin_session.token)
  params = {
    username = "nonexistent_update"
  }
  
  UserController.update_user(client, params, "99999")
  
  assert(client.last_response.status == 404, "Should return 404 for non-existent user")
  assert(client.last_response.data.code == "USER_NOT_FOUND", "Should have correct error code")
  
  restore_json_response()
  teardown_test()
  print("✓ update_user tests passed")
end

-- Test deactivate_user endpoint
local function test_deactivate_user()
  print("Testing deactivate_user endpoint...")
  setup_test()
  local responses = mock_json_response()
  
  -- Create test user
  local test_user = User.create({
    username = "deactivate_test_user",
    email = "deactivatetest@test.com",
    password = "DeactivateTestPass123",
    role = "Member"
  })
  
  -- Test successful user deactivation
  local admin_user, admin_session = create_admin_session()
  local client = create_authenticated_client(admin_session.token)
  local params = {}
  
  UserController.deactivate_user(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 200, "Should return 200 for successful deactivation")
  assert(client.last_response.data.message:find("deactivated"), "Should have success message")
  
  -- Test admin cannot deactivate themselves
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.deactivate_user(client, params, tostring(admin_user.id))
  
  assert(client.last_response.status == 400, "Should return 400 when admin tries to deactivate self")
  assert(client.last_response.data.code == "CANNOT_DEACTIVATE_SELF", "Should have correct error code")
  
  -- Test invalid user ID
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.deactivate_user(client, params, "invalid")
  
  assert(client.last_response.status == 400, "Should return 400 for invalid user ID")
  assert(client.last_response.data.code == "INVALID_USER_ID", "Should have correct error code")
  
  -- Test non-existent user
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.deactivate_user(client, params, "99999")
  
  assert(client.last_response.status == 404, "Should return 404 for non-existent user")
  assert(client.last_response.data.code == "USER_NOT_FOUND", "Should have correct error code")
  
  restore_json_response()
  teardown_test()
  print("✓ deactivate_user tests passed")
end

-- Test reset_password endpoint
local function test_reset_password()
  print("Testing reset_password endpoint...")
  setup_test()
  local responses = mock_json_response()
  
  -- Create test user
  local test_user = User.create({
    username = "reset_test_user",
    email = "resettest@test.com",
    password = "ResetTestPass123",
    role = "Member"
  })
  
  -- Test password reset with temporary password generation
  local admin_user, admin_session = create_admin_session()
  local client = create_authenticated_client(admin_session.token)
  local params = {}
  
  UserController.reset_password(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 200, "Should return 200 for successful password reset")
  assert(client.last_response.data.temporary_password, "Should return temporary password")
  assert(client.last_response.data.password_reset_required, "Should require password reset")
  
  -- Test password reset with provided password
  client = create_authenticated_client(admin_session.token)
  params = {
    new_password = "NewResetPass123"
  }
  
  UserController.reset_password(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 200, "Should return 200 for successful password reset with provided password")
  assert(not client.last_response.data.temporary_password, "Should not return temporary password when provided")
  
  -- Test with weak password
  client = create_authenticated_client(admin_session.token)
  params = {
    new_password = "weak"
  }
  
  UserController.reset_password(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 400, "Should return 400 for weak password")
  assert(client.last_response.data.code == "WEAK_PASSWORD", "Should have correct error code")
  
  -- Test invalid user ID
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.reset_password(client, params, "invalid")
  
  assert(client.last_response.status == 400, "Should return 400 for invalid user ID")
  assert(client.last_response.data.code == "INVALID_USER_ID", "Should have correct error code")
  
  -- Test non-existent user
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.reset_password(client, params, "99999")
  
  assert(client.last_response.status == 404, "Should return 404 for non-existent user")
  assert(client.last_response.data.code == "USER_NOT_FOUND", "Should have correct error code")
  
  restore_json_response()
  teardown_test()
  print("✓ reset_password tests passed")
end

-- Test activate_user endpoint
local function test_activate_user()
  print("Testing activate_user endpoint...")
  setup_test()
  local responses = mock_json_response()
  
  -- Create test user and deactivate them
  local test_user = User.create({
    username = "activate_test_user",
    email = "activatetest@test.com",
    password = "ActivateTestPass123",
    role = "Member"
  })
  User.deactivate(test_user.id)
  
  -- Test successful user activation
  local admin_user, admin_session = create_admin_session()
  local client = create_authenticated_client(admin_session.token)
  local params = {}
  
  UserController.activate_user(client, params, tostring(test_user.id))
  
  assert(client.last_response.status == 200, "Should return 200 for successful activation")
  assert(client.last_response.data.message:find("activated"), "Should have success message")
  
  -- Test invalid user ID
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.activate_user(client, params, "invalid")
  
  assert(client.last_response.status == 400, "Should return 400 for invalid user ID")
  assert(client.last_response.data.code == "INVALID_USER_ID", "Should have correct error code")
  
  -- Test non-existent user
  client = create_authenticated_client(admin_session.token)
  params = {}
  
  UserController.activate_user(client, params, "99999")
  
  assert(client.last_response.status == 404, "Should return 404 for non-existent user")
  assert(client.last_response.data.code == "USER_NOT_FOUND", "Should have correct error code")
  
  restore_json_response()
  teardown_test()
  print("✓ activate_user tests passed")
end

-- Run all tests
local function run_all_tests()
  print("Running User Controller tests...")
  print("=" .. string.rep("=", 50))
  
  test_list_users()
  test_create_user()
  test_get_user()
  test_update_user()
  test_deactivate_user()
  test_reset_password()
  test_activate_user()
  
  print("=" .. string.rep("=", 50))
  print("✓ All User Controller tests passed!")
end

-- Export test functions
return {
  run_all_tests = run_all_tests,
  test_list_users = test_list_users,
  test_create_user = test_create_user,
  test_get_user = test_get_user,
  test_update_user = test_update_user,
  test_deactivate_user = test_deactivate_user,
  test_reset_password = test_reset_password,
  test_activate_user = test_activate_user
}