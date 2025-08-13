-- src/tests/test_auth_controller.lua
-- Tests for AuthController

local test_runner = require("src.tests.test_runner")
local AuthController = require("src.controllers.auth_controller")
local User = require("src.models.user")
local Session = require("src.models.session")
local auth = require("src.middleware.auth")

local tests = {}

-- Mock client object for testing
local function create_mock_client()
  local responses = {}
  return {
    headers = {},
    responses = responses,
    send = function(self, response)
      table.insert(responses, response)
    end
  }
end

-- Helper to extract JSON from response
local function extract_json_from_response(response)
  local cjson = require("cjson")
  local body_start = response:find("\r\n\r\n")
  if body_start then
    local body = response:sub(body_start + 4)
    return cjson.decode(body)
  end
  return nil
end

-- Helper to extract status code from response
local function extract_status_from_response(response)
  local status = response:match("HTTP/1%.1 (%d+)")
  return tonumber(status)
end

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
  User.init_db()
  Session.init_db()
  
  -- Clear rate limiting
  auth.clear_rate_limit("testuser")
end

-- Test login with valid credentials
function tests.test_login_valid_credentials()
  setup()
  
  -- Create a test user
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  User.create(user_data)
  
  local client = create_mock_client()
  local params = {
    username = "testuser",
    password = "SecurePass123"
  }
  
  AuthController.login(client, params)
  
  test_runner.assert_equal(#client.responses, 1, "Should send one response")
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_not_nil(json_response.token, "Should return token")
  test_runner.assert_not_nil(json_response.expires_at, "Should return expiration")
  test_runner.assert_equal(json_response.user.username, "testuser", "Should return user info")
  test_runner.assert_equal(json_response.message, "Login successful", "Should return success message")
end

-- Test login with remember_me option
function tests.test_login_with_remember_me()
  setup()
  
  -- Create a test user
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  User.create(user_data)
  
  local client = create_mock_client()
  local params = {
    username = "testuser",
    password = "SecurePass123",
    remember_me = true
  }
  
  AuthController.login(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_not_nil(json_response.token, "Should return token")
  
  -- Verify session has extended duration (7 days)
  local session = Session.find_by_token(json_response.token)
  test_runner.assert_not_nil(session, "Session should exist")
end

-- Test login with missing credentials
function tests.test_login_missing_credentials()
  setup()
  
  local client = create_mock_client()
  local params = {
    username = "testuser"
    -- Missing password
  }
  
  AuthController.login(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 400, "Should return 400 status")
  test_runner.assert_equal(json_response.code, "MISSING_CREDENTIALS", "Should return correct error code")
  test_runner.assert_not_nil(json_response.timestamp, "Should include timestamp")
end

-- Test login with invalid credentials
function tests.test_login_invalid_credentials()
  setup()
  
  -- Create a test user
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  User.create(user_data)
  
  local client = create_mock_client()
  local params = {
    username = "testuser",
    password = "wrongpassword"
  }
  
  AuthController.login(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 401, "Should return 401 status")
  test_runner.assert_equal(json_response.code, "INVALID_CREDENTIALS", "Should return correct error code")
  test_runner.assert_equal(json_response.error, "Authentication failed", "Should return error message")
end

-- Test login with nonexistent user
function tests.test_login_nonexistent_user()
  setup()
  
  local client = create_mock_client()
  local params = {
    username = "nonexistent",
    password = "password"
  }
  
  AuthController.login(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 401, "Should return 401 status")
  test_runner.assert_equal(json_response.code, "INVALID_CREDENTIALS", "Should return correct error code")
end

-- Test logout with valid token
function tests.test_logout_valid_token()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {}
  
  AuthController.logout(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_equal(json_response.message, "Logout successful", "Should return success message")
  
  -- Verify session is invalidated
  local invalid_session = Session.find_by_token(session.token)
  test_runner.assert_nil(invalid_session, "Session should be invalidated")
end

-- Test logout with missing token
function tests.test_logout_missing_token()
  setup()
  
  local client = create_mock_client()
  local params = {}
  
  AuthController.logout(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 400, "Should return 400 status")
  test_runner.assert_equal(json_response.code, "MISSING_TOKEN", "Should return correct error code")
end

-- Test logout with invalid token
function tests.test_logout_invalid_token()
  setup()
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer invalidtoken"
  local params = {}
  
  AuthController.logout(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 400, "Should return 400 status")
  test_runner.assert_equal(json_response.code, "LOGOUT_ERROR", "Should return correct error code")
end

-- Test token refresh with valid token
function tests.test_refresh_token_valid()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {}
  
  AuthController.refresh_token(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_equal(json_response.message, "Token refreshed successfully", "Should return success message")
  test_runner.assert_equal(json_response.token, session.token, "Should return same token")
  test_runner.assert_not_nil(json_response.expires_at, "Should return new expiration")
end

-- Test token refresh with remember_me
function tests.test_refresh_token_with_remember_me()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {
    remember_me = true
  }
  
  AuthController.refresh_token(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_not_nil(json_response.expires_at, "Should return extended expiration")
end

-- Test token refresh with missing token
function tests.test_refresh_token_missing_token()
  setup()
  
  local client = create_mock_client()
  local params = {}
  
  AuthController.refresh_token(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 400, "Should return 400 status")
  test_runner.assert_equal(json_response.code, "MISSING_TOKEN", "Should return correct error code")
end

-- Test token refresh with invalid token
function tests.test_refresh_token_invalid()
  setup()
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer invalidtoken"
  local params = {}
  
  AuthController.refresh_token(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 401, "Should return 401 status")
  test_runner.assert_equal(json_response.code, "INVALID_TOKEN", "Should return correct error code")
end

-- Test get current user with valid token
function tests.test_get_current_user_valid()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {}
  
  AuthController.get_current_user(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_not_nil(json_response.user, "Should return user object")
  test_runner.assert_equal(json_response.user.username, "testuser", "Should return correct username")
  test_runner.assert_equal(json_response.user.email, "test@example.com", "Should return correct email")
  test_runner.assert_equal(json_response.user.role, "Member", "Should return correct role")
end

-- Test get current user with invalid token
function tests.test_get_current_user_invalid_token()
  setup()
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer invalidtoken"
  local params = {}
  
  AuthController.get_current_user(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 401, "Should return 401 status")
end

-- Test change password with valid data
function tests.test_change_password_valid()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {
    current_password = "SecurePass123",
    new_password = "NewSecurePass456"
  }
  
  AuthController.change_password(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_equal(json_response.message, "Password changed successfully", "Should return success message")
  
  -- Verify new password works
  local auth_user = User.authenticate("testuser", "NewSecurePass456")
  test_runner.assert_not_nil(auth_user, "Should authenticate with new password")
  
  -- Verify old password doesn't work
  local old_auth = User.authenticate("testuser", "SecurePass123")
  test_runner.assert_nil(old_auth, "Should not authenticate with old password")
end

-- Test change password with missing fields
function tests.test_change_password_missing_fields()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {
    current_password = "SecurePass123"
    -- Missing new_password
  }
  
  AuthController.change_password(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 400, "Should return 400 status")
  test_runner.assert_equal(json_response.code, "MISSING_FIELDS", "Should return correct error code")
end

-- Test change password with incorrect current password
function tests.test_change_password_incorrect_current()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {
    current_password = "wrongpassword",
    new_password = "NewSecurePass456"
  }
  
  AuthController.change_password(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 401, "Should return 401 status")
  test_runner.assert_equal(json_response.code, "INVALID_CURRENT_PASSWORD", "Should return correct error code")
end

-- Test change password with weak new password
function tests.test_change_password_weak_new_password()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {
    current_password = "SecurePass123",
    new_password = "weak"
  }
  
  AuthController.change_password(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 400, "Should return 400 status")
  test_runner.assert_equal(json_response.code, "WEAK_PASSWORD", "Should return correct error code")
end

-- Test change password with same password
function tests.test_change_password_same_password()
  setup()
  
  -- Create user and session
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session.token
  local params = {
    current_password = "SecurePass123",
    new_password = "SecurePass123"
  }
  
  AuthController.change_password(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 400, "Should return 400 status")
  test_runner.assert_equal(json_response.code, "SAME_PASSWORD", "Should return correct error code")
end

-- Test change password with invalidate other sessions
function tests.test_change_password_invalidate_other_sessions()
  setup()
  
  -- Create user and multiple sessions
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  local user = User.create(user_data)
  local session1 = Session.create(user.id)
  local session2 = Session.create(user.id)
  
  local client = create_mock_client()
  client.headers["Authorization"] = "Bearer " .. session1.token
  local params = {
    current_password = "SecurePass123",
    new_password = "NewSecurePass456",
    invalidate_other_sessions = true
  }
  
  AuthController.change_password(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  local json_response = extract_json_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 200, "Should return 200 status")
  test_runner.assert_not_nil(json_response.new_token, "Should return new token")
  test_runner.assert_not_nil(json_response.expires_at, "Should return expiration")
  
  -- Verify old sessions are invalidated
  local old_session1 = Session.find_by_token(session1.token)
  local old_session2 = Session.find_by_token(session2.token)
  test_runner.assert_nil(old_session1, "Old session 1 should be invalidated")
  test_runner.assert_nil(old_session2, "Old session 2 should be invalidated")
  
  -- Verify new token works
  local new_session = Session.find_by_token(json_response.new_token)
  test_runner.assert_not_nil(new_session, "New session should exist")
end

-- Test change password without authentication
function tests.test_change_password_no_auth()
  setup()
  
  local client = create_mock_client()
  local params = {
    current_password = "password",
    new_password = "newpassword"
  }
  
  AuthController.change_password(client, params)
  
  local status = extract_status_from_response(client.responses[1])
  
  test_runner.assert_equal(status, 401, "Should return 401 status")
end

return tests