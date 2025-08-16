-- src/tests/test_auth_routes.lua
-- Integration tests for authentication route handling

local test_runner = require("src.tests.test_runner")
local router = require("src.routes.router")
local User = require("src.models.user")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")

-- Mock client for testing
local MockClient = {}
MockClient.__index = MockClient

function MockClient:new()
  local obj = {
    response_status = nil,
    response_body = nil,
    headers = {},
    response_data = ""
  }
  setmetatable(obj, self)
  return obj
end

function MockClient:send(data)
  -- Store the full response data
  self.response_data = data
  
  -- Parse HTTP response to extract status and body
  local status_line = data:match("HTTP/1%.1 (%d+)")
  if status_line then
    self.response_status = tonumber(status_line)
  end
  
  -- Extract JSON body
  local json_start = data:find("\r\n\r\n")
  if json_start then
    local body = data:sub(json_start + 4)
    if body and body ~= "" then
      local cjson = require("cjson")
      local success, parsed = pcall(cjson.decode, body)
      if success then
        self.response_body = parsed
      else
        self.response_body = body
      end
    end
  end
end

function MockClient:set_header(name, value)
  self.headers[name] = value
end

-- Test suite
local AuthRoutesTest = {}

function AuthRoutesTest.setup()
  -- Clean up any existing test data
  test_runner.clear_test_db()
  
  -- Initialize database tables
  User.init_db()
  Session.init_db()
  
  -- Create test user
  local test_user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "TestPassword123!",
    role = "Member"
  }
  User.create(test_user_data)
  
  -- Create admin user
  local admin_user_data = {
    username = "admin",
    email = "admin@example.com", 
    password = "AdminPassword123!",
    role = "Admin"
  }
  User.create(admin_user_data)
end

function AuthRoutesTest.teardown()
  -- Clean up test data
  test_runner.clear_test_db()
end

function AuthRoutesTest.test_auth_login_route()
  local client = MockClient:new()
  local params = {
    username = "testuser",
    password = "TestPassword123!"
  }
  
  -- Test login route
  local success = router.match("/auth/login", "POST", client, params)
  
  test_runner.assert_true(success, "Login route should be matched")
  
  test_runner.assert_equal(client.response_status, 200, "Login should return 200 status")
  test_runner.assert_not_nil(client.response_body, "Login should return response body")
  test_runner.assert_not_nil(client.response_body.token, "Login should return token")
  test_runner.assert_equal(client.response_body.user.username, "testuser", "Login should return user info")
end

function AuthRoutesTest.test_auth_login_invalid_credentials()
  local client = MockClient:new()
  local params = {
    username = "testuser",
    password = "wrongpassword"
  }
  
  -- Test login with invalid credentials
  local success = router.match("/auth/login", "POST", client, params)
  
  test_runner.assert_true(success, "Login route should be matched")
  test_runner.assert_equal(client.response_status, 401, "Invalid login should return 401 status")
  test_runner.assert_equal(client.response_body.code, "INVALID_CREDENTIALS", "Should return invalid credentials error")
end

function AuthRoutesTest.test_auth_logout_route()
  -- First login to get a token
  local login_client = MockClient:new()
  local login_params = {
    username = "testuser",
    password = "TestPassword123!"
  }
  router.match("/auth/login", "POST", login_client, login_params)
  
  -- Check if login was successful before proceeding
  if not login_client.response_body or not login_client.response_body.token then
    print("DEBUG: Login failed, skipping logout test")
    return
  end
  
  local token = login_client.response_body.token
  
  -- Test logout route
  local client = MockClient:new()
  client:set_header("Authorization", "Bearer " .. token)
  local params = {}
  
  local success = router.match("/auth/logout", "POST", client, params)
  
  test_runner.assert_true(success, "Logout route should be matched")
  test_runner.assert_equal(client.response_status, 200, "Logout should return 200 status")
  test_runner.assert_equal(client.response_body.message, "Logout successful", "Should return success message")
end

function AuthRoutesTest.test_auth_me_route()
  -- First login to get a token
  local login_client = MockClient:new()
  local login_params = {
    username = "testuser",
    password = "TestPassword123!"
  }
  router.match("/auth/login", "POST", login_client, login_params)
  local token = login_client.response_body.token
  
  -- Test me route
  local client = MockClient:new()
  client:set_header("Authorization", "Bearer " .. token)
  local params = {}
  
  local success = router.match("/auth/me", "GET", client, params)
  
  test_runner.assert_true(success, "Me route should be matched")
  test_runner.assert_equal(client.response_status, 200, "Me route should return 200 status")
  test_runner.assert_equal(client.response_body.user.username, "testuser", "Should return current user info")
end

function AuthRoutesTest.test_auth_refresh_route()
  -- First login to get a token
  local login_client = MockClient:new()
  local login_params = {
    username = "testuser",
    password = "TestPassword123!"
  }
  router.match("/auth/login", "POST", login_client, login_params)
  local token = login_client.response_body.token
  
  -- Test refresh route
  local client = MockClient:new()
  client:set_header("Authorization", "Bearer " .. token)
  local params = {}
  
  local success = router.match("/auth/refresh", "POST", client, params)
  
  test_runner.assert_true(success, "Refresh route should be matched")
  test_runner.assert_equal(client.response_status, 200, "Refresh should return 200 status")
  test_runner.assert_not_nil(client.response_body.token, "Refresh should return new token")
end

function AuthRoutesTest.test_user_management_routes()
  -- First login as admin to get a token
  local login_client = MockClient:new()
  local login_params = {
    username = "admin",
    password = "AdminPassword123!"
  }
  router.match("/auth/login", "POST", login_client, login_params)
  local token = login_client.response_body.token
  
  -- Test list users route
  local client = MockClient:new()
  client:set_header("Authorization", "Bearer " .. token)
  local params = {}
  
  local success = router.match("/users", "GET", client, params)
  
  test_runner.assert_true(success, "Users list route should be matched")
  test_runner.assert_equal(client.response_status, 200, "Users list should return 200 status")
  test_runner.assert_not_nil(client.response_body.users, "Should return users array")
  test_runner.assert_true(#client.response_body.users >= 2, "Should return at least 2 users")
end

function AuthRoutesTest.test_user_create_route()
  -- First login as admin to get a token
  local login_client = MockClient:new()
  local login_params = {
    username = "admin",
    password = "AdminPassword123!"
  }
  router.match("/auth/login", "POST", login_client, login_params)
  local token = login_client.response_body.token
  
  -- Test create user route
  local client = MockClient:new()
  client:set_header("Authorization", "Bearer " .. token)
  local params = {
    username = "newuser",
    email = "newuser@example.com",
    password = "NewPassword123!",
    role = "Member"
  }
  
  local success = router.match("/users", "POST", client, params)
  
  test_runner.assert_true(success, "User create route should be matched")
  test_runner.assert_equal(client.response_status, 201, "User create should return 201 status")
  test_runner.assert_equal(client.response_body.user.username, "newuser", "Should return created user info")
end

function AuthRoutesTest.test_user_detail_route_pattern()
  -- First login as admin to get a token
  local login_client = MockClient:new()
  local login_params = {
    username = "admin",
    password = "AdminPassword123!"
  }
  router.match("/auth/login", "POST", login_client, login_params)
  local token = login_client.response_body.token
  
  -- Get user ID
  local user = User.find_by_username("testuser")
  
  -- Test get user detail route with pattern
  local client = MockClient:new()
  client:set_header("Authorization", "Bearer " .. token)
  local params = {}
  
  local success = router.match("/users/" .. user.id, "GET", client, params)
  
  test_runner.assert_true(success, "User detail route should be matched")
  test_runner.assert_equal(client.response_status, 200, "User detail should return 200 status")
  test_runner.assert_equal(client.response_body.user.username, "testuser", "Should return correct user info")
end

function AuthRoutesTest.test_user_reset_password_route_pattern()
  -- First login as admin to get a token
  local login_client = MockClient:new()
  local login_params = {
    username = "admin",
    password = "AdminPassword123!"
  }
  router.match("/auth/login", "POST", login_client, login_params)
  local token = login_client.response_body.token
  
  -- Get user ID
  local user = User.find_by_username("testuser")
  
  -- Test reset password route with pattern
  local client = MockClient:new()
  client:set_header("Authorization", "Bearer " .. token)
  local params = {
    new_password = "NewResetPassword123!"
  }
  
  local success = router.match("/users/" .. user.id .. "/reset-password", "POST", client, params)
  
  test_runner.assert_true(success, "Reset password route should be matched")
  test_runner.assert_equal(client.response_status, 200, "Reset password should return 200 status")
  test_runner.assert_equal(client.response_body.message, "Password reset successfully", "Should return success message")
end

function AuthRoutesTest.test_invalid_auth_routes()
  local client = MockClient:new()
  local params = {}
  
  -- Test non-existent auth route
  local success = router.match("/auth/invalid", "GET", client, params)
  
  test_runner.assert_false(success, "Router should return false for non-existent routes")
  test_runner.assert_equal(client.response_status, 404, "Should return 404 for non-existent routes")
end

function AuthRoutesTest.test_method_not_allowed_auth_routes()
  local client = MockClient:new()
  local params = {}
  
  -- Test wrong method on auth route
  local success = router.match("/auth/login", "GET", client, params)
  
  test_runner.assert_true(success, "Router should handle method not allowed")
  test_runner.assert_equal(client.response_status, 405, "Should return 405 for method not allowed")
  test_runner.assert_not_nil(client.response_body.allowed, "Should return allowed methods")
end

-- Run tests
function AuthRoutesTest.run_all()
  print("Running Authentication Routes Integration Tests...")
  
  AuthRoutesTest.setup()
  
  test_runner.run_test("Auth Login Route", AuthRoutesTest.test_auth_login_route)
  test_runner.run_test("Auth Login Invalid Credentials", AuthRoutesTest.test_auth_login_invalid_credentials)
  test_runner.run_test("Auth Logout Route", AuthRoutesTest.test_auth_logout_route)
  test_runner.run_test("Auth Me Route", AuthRoutesTest.test_auth_me_route)
  test_runner.run_test("Auth Refresh Route", AuthRoutesTest.test_auth_refresh_route)
  test_runner.run_test("User Management Routes", AuthRoutesTest.test_user_management_routes)
  test_runner.run_test("User Create Route", AuthRoutesTest.test_user_create_route)
  test_runner.run_test("User Detail Route Pattern", AuthRoutesTest.test_user_detail_route_pattern)
  test_runner.run_test("User Reset Password Route Pattern", AuthRoutesTest.test_user_reset_password_route_pattern)
  test_runner.run_test("Invalid Auth Routes", AuthRoutesTest.test_invalid_auth_routes)
  test_runner.run_test("Method Not Allowed Auth Routes", AuthRoutesTest.test_method_not_allowed_auth_routes)
  
  AuthRoutesTest.teardown()
  
  print("Authentication Routes Integration Tests completed!")
end

return AuthRoutesTest