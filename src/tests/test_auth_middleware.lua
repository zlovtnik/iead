-- src/tests/test_auth_middleware.lua
-- Unit tests for authentication middleware

local auth = require("src.middleware.auth")
local Session = require("src.models.session")
local User = require("src.models.user")
local Member = require("src.models.member")
local json_utils = require("src.utils.json")

-- Test framework setup
local test_runner = require("src.tests.test_runner")
local tests = {}

-- Setup for each test that needs database access
local function setup()
  test_runner.clear_test_db()
  -- Initialize required tables
  Member.init_db()
  User.init_db()
  Session.init_db()
end

-- Mock client object for testing
local function create_mock_client(headers)
  return {
    headers = headers or {},
    response_sent = false,
    response_status = nil,
    response_body = nil,
    send_response = function(self, status, body)
      self.response_sent = true
      self.response_status = status
      self.response_body = body
    end
  }
end

-- Mock json_utils.send_json_response for testing
local original_send_json_response = json_utils.send_json_response
local function mock_json_response()
  json_utils.send_json_response = function(client, status, data)
    client:send_response(status, data)
  end
end

local function restore_json_response()
  json_utils.send_json_response = original_send_json_response
end

-- Test: Extract token from Authorization header
function tests.test_extract_token_success()
  local client = create_mock_client({
    Authorization = "Bearer test_token_123"
  })
  
  local token = auth.extract_token(client)
  assert(token == "test_token_123", "Should extract token from Bearer header")
end

function tests.test_extract_token_case_insensitive()
  local client = create_mock_client({
    authorization = "Bearer test_token_456"
  })
  
  local token = auth.extract_token(client)
  assert(token == "test_token_456", "Should extract token from lowercase authorization header")
end

function tests.test_extract_token_missing_header()
  local client = create_mock_client({})
  
  local token = auth.extract_token(client)
  assert(token == nil, "Should return nil when Authorization header is missing")
end

function tests.test_extract_token_invalid_format()
  local client = create_mock_client({
    Authorization = "Basic dGVzdDp0ZXN0"
  })
  
  local token = auth.extract_token(client)
  assert(token == nil, "Should return nil for non-Bearer authorization")
end

function tests.test_extract_token_no_client()
  local token = auth.extract_token(nil)
  assert(token == nil, "Should return nil when client is nil")
end

-- Test: Rate limiting functionality
function tests.test_rate_limit_check_allows_initial_requests()
  local identifier = "test_user_1"
  
  -- First few requests should be allowed
  for i = 1, 5 do
    local allowed = auth.rate_limit_check(identifier)
    assert(allowed == true, string.format("Request %d should be allowed", i))
  end
end

function tests.test_rate_limit_check_blocks_excess_requests()
  local identifier = "test_user_2"
  
  -- Use up the rate limit
  for i = 1, 5 do
    auth.rate_limit_check(identifier)
  end
  
  -- Next request should be blocked
  local allowed = auth.rate_limit_check(identifier)
  assert(allowed == false, "Request should be blocked after rate limit exceeded")
end

function tests.test_rate_limit_check_different_identifiers()
  local identifier1 = "test_user_3"
  local identifier2 = "test_user_4"
  
  -- Use up rate limit for first identifier
  for i = 1, 5 do
    auth.rate_limit_check(identifier1)
  end
  
  -- Second identifier should still be allowed
  local allowed = auth.rate_limit_check(identifier2)
  assert(allowed == true, "Different identifier should not be affected by rate limit")
end

function tests.test_clear_rate_limit()
  local identifier = "test_user_5"
  
  -- Use up the rate limit
  for i = 1, 5 do
    auth.rate_limit_check(identifier)
  end
  
  -- Clear rate limit
  auth.clear_rate_limit(identifier)
  
  -- Should be allowed again
  local allowed = auth.rate_limit_check(identifier)
  assert(allowed == true, "Should be allowed after clearing rate limit")
end

-- Test: Authentication request validation
function tests.test_authenticate_request_missing_token()
  setup()
  mock_json_response()
  
  local client = create_mock_client({})
  local params = {}
  
  local result = auth.authenticate_request(client, params)
  
  assert(result == false, "Should return false for missing token")
  assert(client.response_sent == true, "Should send error response")
  assert(client.response_status == 401, "Should return 401 status")
  assert(client.response_body.code == "MISSING_TOKEN", "Should return MISSING_TOKEN error code")
  
  restore_json_response()
end

function tests.test_authenticate_request_invalid_token()
  setup()
  mock_json_response()
  
  local client = create_mock_client({
    Authorization = "Bearer invalid_token"
  })
  local params = {}
  
  local result = auth.authenticate_request(client, params)
  
  assert(result == false, "Should return false for invalid token")
  assert(client.response_sent == true, "Should send error response")
  assert(client.response_status == 401, "Should return 401 status")
  assert(client.response_body.code == "INVALID_TOKEN", "Should return INVALID_TOKEN error code")
  
  restore_json_response()
end

-- Test: Role-based access control
function tests.test_require_role_admin()
  mock_json_response()
  
  -- Setup a real authenticated session for testing
  setup()  -- Initialize DB
  
  -- Test with admin user
  local admin_middleware = auth.require_role("Admin")
  
  local admin_user = User.create({
    username = "admin_test",
    email = "admin@test.com", 
    password = "TestPass123",
    role = "Admin"
  })
  local admin_session = Session.create(admin_user.id)
  local admin_client = create_mock_client({ Authorization = "Bearer " .. admin_session.token })
  local admin_params = {}
  
  local result = admin_middleware(admin_client, admin_params)
  assert(result == true, "Admin should have access to admin-required endpoint")
  
  -- Test with pastor user
  local pastor_user = User.create({
    username = "pastor_test",
    email = "pastor@test.com", 
    password = "TestPass123",
    role = "Pastor"
  })
  local pastor_session = Session.create(pastor_user.id)
  local pastor_client = create_mock_client({ Authorization = "Bearer " .. pastor_session.token })
  local pastor_params = {}
  
  result = admin_middleware(pastor_client, pastor_params)
  assert(result == false, "Pastor should not have access to admin-required endpoint")
  assert(pastor_client.response_status == 403, "Should return 403 for insufficient permissions")
  
  restore_json_response()
end

function tests.test_require_role_pastor()
  mock_json_response()
  
  -- Setup a real authenticated session for testing
  setup()  -- Initialize DB
  
  local pastor_middleware = auth.require_role("Pastor")
  
  -- Test with pastor user
  local pastor_user = User.create({
    username = "pastor_test",
    email = "pastor@test.com", 
    password = "TestPass123",
    role = "Pastor"
  })
  local pastor_session = Session.create(pastor_user.id)
  local pastor_client = create_mock_client({ Authorization = "Bearer " .. pastor_session.token })
  local pastor_params = {}
  
  local result = pastor_middleware(pastor_client, pastor_params)
  assert(result == true, "Pastor should have access to pastor-required endpoint")
  
  -- Test with admin user (should also have access due to hierarchy)
  local admin_user = User.create({
    username = "admin_test2",
    email = "admin2@test.com", 
    password = "TestPass123",
    role = "Admin"
  })
  local admin_session = Session.create(admin_user.id)
  local admin_client = create_mock_client({ Authorization = "Bearer " .. admin_session.token })
  local admin_params = {}
  
  result = pastor_middleware(admin_client, admin_params)
  assert(result == true, "Admin should have access to pastor-required endpoint")
  
  -- Test with member user
  local member_user = User.create({
    username = "member_test",
    email = "member@test.com", 
    password = "TestPass123",
    role = "Member"
  })
  local member_session = Session.create(member_user.id)
  local member_client = create_mock_client({ Authorization = "Bearer " .. member_session.token })
  local member_params = {}
  
  result = pastor_middleware(member_client, member_params)
  assert(result == false, "Member should not have access to pastor-required endpoint")
  assert(member_client.response_status == 403, "Should return 403 for insufficient permissions")
  
  restore_json_response()
end

function tests.test_require_role_member()
  mock_json_response()
  
  -- Setup a real authenticated session for testing
  setup()  -- Initialize DB
  
  local member_middleware = auth.require_role("Member")
  
  -- Test with member user
  local member_user = User.create({
    username = "member_test",
    email = "member@test.com", 
    password = "TestPass123",
    role = "Member"
  })
  local member_session = Session.create(member_user.id)
  local member_client = create_mock_client({ Authorization = "Bearer " .. member_session.token })
  local member_params = {}
  
  local result = member_middleware(member_client, member_params)
  assert(result == true, "Member should have access to member-required endpoint")
  
  -- Test with pastor user (should also have access due to hierarchy)
  local pastor_user = User.create({
    username = "pastor_test2",
    email = "pastor2@test.com", 
    password = "TestPass123",
    role = "Pastor"
  })
  local pastor_session = Session.create(pastor_user.id)
  local pastor_client = create_mock_client({ Authorization = "Bearer " .. pastor_session.token })
  local pastor_params = {}
  
  result = member_middleware(pastor_client, pastor_params)
  assert(result == true, "Pastor should have access to member-required endpoint")
  
  -- Test with admin user (should also have access due to hierarchy)
  local admin_user = User.create({
    username = "admin_test3",
    email = "admin3@test.com", 
    password = "TestPass123",
    role = "Admin"
  })
  local admin_session = Session.create(admin_user.id)
  local admin_client = create_mock_client({ Authorization = "Bearer " .. admin_session.token })
  local admin_params = {}
  
  result = member_middleware(admin_client, admin_params)
  assert(result == true, "Admin should have access to member-required endpoint")
  
  restore_json_response()
end

-- Test: Member data access control
function tests.test_can_access_member_data_admin()
  local admin_user = {
    id = 1,
    role = "Admin",
    member_id = nil
  }
  
  local result = auth.can_access_member_data(admin_user, 123)
  assert(result == true, "Admin should be able to access any member data")
end

function tests.test_can_access_member_data_pastor()
  local pastor_user = {
    id = 2,
    role = "Pastor",
    member_id = 456
  }
  
  local result = auth.can_access_member_data(pastor_user, 123)
  assert(result == true, "Pastor should be able to access any member data")
end

function tests.test_can_access_member_data_member_own()
  local member_user = {
    id = 3,
    role = "Member",
    member_id = 123
  }
  
  local result = auth.can_access_member_data(member_user, 123)
  assert(result == true, "Member should be able to access their own data")
end

function tests.test_can_access_member_data_member_other()
  local member_user = {
    id = 3,
    role = "Member",
    member_id = 123
  }
  
  local result = auth.can_access_member_data(member_user, 456)
  assert(result == false, "Member should not be able to access other member's data")
end

function tests.test_can_access_member_data_invalid_params()
  local result = auth.can_access_member_data(nil, 123)
  assert(result == false, "Should return false for nil user")
  
  local user = { id = 1, role = "Member" }
  result = auth.can_access_member_data(user, nil)
  assert(result == false, "Should return false for nil member_id")
end

-- Test: Member access middleware
function tests.test_require_member_access_success()
  mock_json_response()
  
  -- Setup a real authenticated session for testing
  setup()  -- Initialize DB
  
  local member_access_middleware = auth.require_member_access()
  
  -- Create a member first
  local test_member = Member.create({
    name = "Test Member",
    email = "member@test.com",
    phone = "123-456-7890"
  })
  
  local admin_user = User.create({
    username = "admin_member_test",
    email = "admin_member@test.com", 
    password = "TestPass123",
    role = "Admin"
  })
  local admin_session = Session.create(admin_user.id)
  local admin_client = create_mock_client({ Authorization = "Bearer " .. admin_session.token })
  local admin_params = { member_id = tostring(test_member.id) }
  
  local result = member_access_middleware(admin_client, admin_params)
  assert(result == true, "Should allow access for admin user")
  
  restore_json_response()
end

function tests.test_require_member_access_denied()
  mock_json_response()
  
  -- Setup a real authenticated session for testing
  setup()  -- Initialize DB
  
  local member_access_middleware = auth.require_member_access()
  
  -- Create two members
  local member1 = Member.create({
    name = "Test Member 1",
    email = "member1@test.com",
    phone = "123-456-7890"
  })
  
  local member2 = Member.create({
    name = "Test Member 2",
    email = "member2@test.com",
    phone = "123-456-7891"
  })
  
  -- Create a member user associated with member2, but trying to access member1's data
  local member_user = User.create({
    username = "member_test_access",
    email = "member_access@test.com", 
    password = "TestPass123",
    role = "Member",
    member_id = member2.id
  })
  local member_session = Session.create(member_user.id)
  local member_client = create_mock_client({ Authorization = "Bearer " .. member_session.token })
  local member_params = { member_id = tostring(member1.id) }
  
  local result = member_access_middleware(member_client, member_params)
  assert(result == false, "Should deny access for member accessing other's data")
  assert(member_client.response_status == 403, "Should return 403 for access denied")
  
  restore_json_response()
end

function tests.test_require_member_access_url_capture()
  mock_json_response()
  
  -- Setup a real authenticated session for testing
  setup()  -- Initialize DB
  
  local member_access_middleware = auth.require_member_access()
  
  -- Create a member for testing
  local test_member = Member.create({
    name = "Test Member URL",
    email = "member_url@test.com",
    phone = "123-456-7892"
  })
  
  local pastor_user = User.create({
    username = "pastor_url_test",
    email = "pastor_url@test.com", 
    password = "TestPass123",
    role = "Pastor"
  })
  local pastor_session = Session.create(pastor_user.id)
  local pastor_client = create_mock_client({ Authorization = "Bearer " .. pastor_session.token })
  local pastor_params = {}
  
  -- Test with URL capture (member ID from URL pattern)
  local result = member_access_middleware(pastor_client, pastor_params, tostring(test_member.id))
  assert(result == true, "Should allow access using URL capture for member ID")
  
  restore_json_response()
end

-- Test: Rate limiting middleware
function tests.test_rate_limit_middleware()
  mock_json_response()
  
  local rate_limit_middleware = auth.rate_limit(function(client, params)
    return "test_identifier"
  end)
  
  local client = create_mock_client({})
  local params = {}
  
  -- First few requests should pass
  for i = 1, 5 do
    client = create_mock_client({})
    local result = rate_limit_middleware(client, params)
    assert(result == true, string.format("Request %d should pass rate limiting", i))
  end
  
  -- Next request should be blocked
  client = create_mock_client({})
  local result = rate_limit_middleware(client, params)
  assert(result == false, "Request should be blocked by rate limiting")
  assert(client.response_status == 429, "Should return 429 for rate limit exceeded")
  
  restore_json_response()
end

-- Test: Login rate limiting
function tests.test_login_rate_limit()
  mock_json_response()
  
  local login_rate_limit_middleware = auth.login_rate_limit("username")
  
  local params = { username = "test_user" }
  
  -- First few requests should pass
  for i = 1, 5 do
    local client = create_mock_client({})
    local result = login_rate_limit_middleware(client, params)
    assert(result == true, string.format("Login attempt %d should pass rate limiting", i))
  end
  
  -- Next request should be blocked
  local client = create_mock_client({})
  local result = login_rate_limit_middleware(client, params)
  assert(result == false, "Login attempt should be blocked by rate limiting")
  assert(client.response_status == 429, "Should return 429 for rate limit exceeded")
  
  restore_json_response()
end

-- Test: Middleware chaining
function tests.test_middleware_chain_success()
  local middleware1 = function(client, params)
    params.middleware1_called = true
    return true
  end
  
  local middleware2 = function(client, params)
    params.middleware2_called = true
    return true
  end
  
  local chained_middleware = auth.chain({middleware1, middleware2})
  
  local client = create_mock_client({})
  local params = {}
  
  local result = chained_middleware(client, params)
  
  assert(result == true, "Chained middleware should succeed when all middlewares pass")
  assert(params.middleware1_called == true, "First middleware should be called")
  assert(params.middleware2_called == true, "Second middleware should be called")
end

function tests.test_middleware_chain_failure()
  local middleware1 = function(client, params)
    params.middleware1_called = true
    return true
  end
  
  local middleware2 = function(client, params)
    params.middleware2_called = true
    return false -- This middleware fails
  end
  
  local middleware3 = function(client, params)
    params.middleware3_called = true
    return true
  end
  
  local chained_middleware = auth.chain({middleware1, middleware2, middleware3})
  
  local client = create_mock_client({})
  local params = {}
  
  local result = chained_middleware(client, params)
  
  assert(result == false, "Chained middleware should fail when any middleware fails")
  assert(params.middleware1_called == true, "First middleware should be called")
  assert(params.middleware2_called == true, "Second middleware should be called")
  assert(params.middleware3_called == nil, "Third middleware should not be called after failure")
end

-- Test: Protected route wrapper
function tests.test_protect_middleware_success()
  mock_json_response()
  
  local original_handler = function(client, params)
    params.handler_called = true
    return "handler_result"
  end
  
  local auth_middleware = function(client, params)
    params.auth_called = true
    return true
  end
  
  local protected_handler = auth.protect(original_handler, auth_middleware)
  
  local client = create_mock_client({})
  local params = {}
  
  local result = protected_handler(client, params)
  
  assert(params.auth_called == true, "Authentication middleware should be called")
  assert(params.handler_called == true, "Original handler should be called")
  assert(result == "handler_result", "Should return result from original handler")
  
  restore_json_response()
end

function tests.test_protect_middleware_auth_failure()
  mock_json_response()
  
  local original_handler = function(client, params)
    params.handler_called = true
    return "handler_result"
  end
  
  local auth_middleware = function(client, params)
    params.auth_called = true
    return false -- Authentication fails
  end
  
  local protected_handler = auth.protect(original_handler, auth_middleware)
  
  local client = create_mock_client({})
  local params = {}
  
  protected_handler(client, params)
  
  assert(params.auth_called == true, "Authentication middleware should be called")
  assert(params.handler_called == nil, "Original handler should not be called after auth failure")
  
  restore_json_response()
end

-- Test: Permission level checking
function tests.test_has_permission()
  local params_admin = {
    current_user = { role = "Admin" }
  }
  
  local params_pastor = {
    current_user = { role = "Pastor" }
  }
  
  local params_member = {
    current_user = { role = "Member" }
  }
  
  -- Test admin permissions
  assert(auth.has_permission(params_admin, 1) == true, "Admin should have level 1 permission")
  assert(auth.has_permission(params_admin, 2) == true, "Admin should have level 2 permission")
  assert(auth.has_permission(params_admin, 3) == true, "Admin should have level 3 permission")
  
  -- Test pastor permissions
  assert(auth.has_permission(params_pastor, 1) == true, "Pastor should have level 1 permission")
  assert(auth.has_permission(params_pastor, 2) == true, "Pastor should have level 2 permission")
  assert(auth.has_permission(params_pastor, 3) == false, "Pastor should not have level 3 permission")
  
  -- Test member permissions
  assert(auth.has_permission(params_member, 1) == true, "Member should have level 1 permission")
  assert(auth.has_permission(params_member, 2) == false, "Member should not have level 2 permission")
  assert(auth.has_permission(params_member, 3) == false, "Member should not have level 3 permission")
end

function tests.test_get_current_user()
  local params = {
    current_user = {
      id = 1,
      username = "test_user",
      role = "Admin"
    }
  }
  
  local user = auth.get_current_user(params)
  assert(user ~= nil, "Should return user object")
  assert(user.id == 1, "Should return correct user ID")
  assert(user.username == "test_user", "Should return correct username")
  assert(user.role == "Admin", "Should return correct role")
  
  -- Test with no user
  local no_user = auth.get_current_user({})
  assert(no_user == nil, "Should return nil when no current user")
  
  local nil_params = auth.get_current_user(nil)
  assert(nil_params == nil, "Should return nil when params is nil")
end

return tests