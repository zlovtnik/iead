-- src/tests/test_auth_integration.lua
-- Integration tests for authentication middleware with routes

local auth = require("src.middleware.auth")
local User = require("src.models.user")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")
local test_runner = require("src.tests.test_runner")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
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

-- Test: Complete authentication flow with valid session
function tests.test_complete_auth_flow_valid_session()
  setup()
  mock_json_response()
  
  -- Create a test user
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Pastor"
  }
  local user = User.create(user_data)
  assert(user ~= nil, "User should be created")
  
  -- Create a session for the user
  local session = Session.create(user.id)
  assert(session ~= nil, "Session should be created")
  
  -- Create a protected route handler
  local protected_handler = function(client, params)
    params.handler_called = true
    json_utils.send_json_response(client, 200, {
      message = "Access granted",
      user = params.current_user
    })
  end
  
  -- Apply authentication middleware
  local auth_protected_handler = auth.protect(protected_handler, auth.require_pastor())
  
  -- Test with valid token
  local client = create_mock_client({
    Authorization = "Bearer " .. session.token
  })
  local params = {}
  
  auth_protected_handler(client, params)
  
  assert(params.handler_called == true, "Handler should be called with valid authentication")
  assert(client.response_status == 200, "Should return 200 for successful access")
  assert(client.response_body.message == "Access granted", "Should return success message")
  assert(client.response_body.user.username == "testuser", "Should include user info")
  
  restore_json_response()
end

-- Test: Authentication failure with invalid token
function tests.test_complete_auth_flow_invalid_token()
  setup()
  mock_json_response()
  
  -- Create a protected route handler
  local protected_handler = function(client, params)
    params.handler_called = true
    json_utils.send_json_response(client, 200, { message = "Access granted" })
  end
  
  -- Apply authentication middleware
  local auth_protected_handler = auth.protect(protected_handler, auth.require_member())
  
  -- Test with invalid token
  local client = create_mock_client({
    Authorization = "Bearer invalid_token_123"
  })
  local params = {}
  
  auth_protected_handler(client, params)
  
  assert(params.handler_called == nil, "Handler should not be called with invalid token")
  assert(client.response_status == 401, "Should return 401 for invalid token")
  assert(client.response_body.code == "INVALID_TOKEN", "Should return INVALID_TOKEN error")
  
  restore_json_response()
end

-- Test: Role-based access control
function tests.test_role_based_access_control()
  setup()
  mock_json_response()
  
  -- Create users with different roles
  local admin_user = User.create({
    username = "admin",
    email = "admin@example.com",
    password = "SecurePass123",
    role = "Admin"
  })
  
  local member_user = User.create({
    username = "member",
    email = "member@example.com",
    password = "SecurePass123",
    role = "Member"
  })
  
  -- Create sessions
  local admin_session = Session.create(admin_user.id)
  local member_session = Session.create(member_user.id)
  
  -- Create admin-only route
  local admin_handler = function(client, params)
    json_utils.send_json_response(client, 200, { message = "Admin access granted" })
  end
  
  local admin_protected_handler = auth.protect(admin_handler, auth.require_admin())
  
  -- Test admin access with admin token
  local admin_client = create_mock_client({
    Authorization = "Bearer " .. admin_session.token
  })
  
  admin_protected_handler(admin_client, {})
  assert(admin_client.response_status == 200, "Admin should have access to admin endpoint")
  
  -- Test member access with member token (should fail)
  local member_client = create_mock_client({
    Authorization = "Bearer " .. member_session.token
  })
  
  admin_protected_handler(member_client, {})
  assert(member_client.response_status == 403, "Member should not have access to admin endpoint")
  assert(member_client.response_body.code == "INSUFFICIENT_PERMISSIONS", "Should return insufficient permissions error")
  
  restore_json_response()
end

-- Test: Member data access control
function tests.test_member_data_access_control()
  setup()
  mock_json_response()
  
  -- First create actual members in the members table
  local Member = require("src.models.member")
  Member.init_db()
  
  local member_record1 = Member.create({
    name = "John Doe",
    email = "john@example.com"
  })
  
  local member_record2 = Member.create({
    name = "Jane Smith", 
    email = "jane@example.com"
  })
  
  -- Create test users linked to members
  local member1 = User.create({
    username = "member1",
    email = "member1@example.com",
    password = "SecurePass123",
    role = "Member",
    member_id = member_record1.id
  })
  
  local member2 = User.create({
    username = "member2",
    email = "member2@example.com",
    password = "SecurePass123",
    role = "Member",
    member_id = member_record2.id
  })
  
  local pastor = User.create({
    username = "pastor",
    email = "pastor@example.com",
    password = "SecurePass123",
    role = "Pastor"
  })
  
  -- Verify users were created successfully
  assert(member1 ~= nil, "Member1 should be created successfully")
  assert(member2 ~= nil, "Member2 should be created successfully")
  assert(pastor ~= nil, "Pastor should be created successfully")
  
  -- Create sessions
  local member1_session = Session.create(member1.id)
  local member2_session = Session.create(member2.id)
  local pastor_session = Session.create(pastor.id)
  
  -- Create member data access handler
  local member_data_handler = function(client, params, member_id)
    json_utils.send_json_response(client, 200, {
      message = "Member data access granted",
      member_id = member_id,
      user = params.current_user
    })
  end
  
  local protected_member_handler = auth.protect(member_data_handler, auth.require_member_access())
  
  -- Test member1 accessing their own data
  local member1_client = create_mock_client({
    Authorization = "Bearer " .. member1_session.token
  })
  
  protected_member_handler(member1_client, {}, tostring(member_record1.id))
  assert(member1_client.response_status == 200, "Member should be able to access their own data")
  
  -- Test member1 accessing member2's data (should fail)
  member1_client = create_mock_client({
    Authorization = "Bearer " .. member1_session.token
  })
  
  protected_member_handler(member1_client, {}, tostring(member_record2.id))
  assert(member1_client.response_status == 403, "Member should not be able to access other member's data")
  
  -- Test pastor accessing any member data (should succeed)
  local pastor_client = create_mock_client({
    Authorization = "Bearer " .. pastor_session.token
  })
  
  protected_member_handler(pastor_client, {}, tostring(member_record1.id))
  assert(pastor_client.response_status == 200, "Pastor should be able to access any member data")
  
  restore_json_response()
end

-- Test: Rate limiting on authentication endpoints
function tests.test_rate_limiting_integration()
  setup()
  mock_json_response()
  
  -- Create a login-like handler with rate limiting
  local login_handler = function(client, params)
    json_utils.send_json_response(client, 200, { message = "Login attempt processed" })
  end
  
  local rate_limited_handler = auth.protect(login_handler, auth.login_rate_limit("username"))
  
  local params = { username = "testuser" }
  
  -- First 5 attempts should succeed
  for i = 1, 5 do
    local client = create_mock_client({})
    rate_limited_handler(client, params)
    assert(client.response_status == 200, string.format("Login attempt %d should succeed", i))
  end
  
  -- 6th attempt should be rate limited
  local client = create_mock_client({})
  rate_limited_handler(client, params)
  assert(client.response_status == 429, "6th login attempt should be rate limited")
  assert(client.response_body.code == "RATE_LIMIT_EXCEEDED", "Should return rate limit exceeded error")
  
  restore_json_response()
end

-- Test: Middleware chaining
function tests.test_middleware_chaining()
  setup()
  mock_json_response()
  
  -- Create a user and session
  local user = User.create({
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Pastor"
  })
  local session = Session.create(user.id)
  
  -- Create a handler that requires both authentication and specific role
  local protected_handler = function(client, params)
    json_utils.send_json_response(client, 200, {
      message = "Access granted with chained middleware",
      user = params.current_user
    })
  end
  
  -- Chain multiple middleware functions
  local chained_middleware = auth.chain({
    auth.require_pastor(),
    function(client, params)
      params.custom_check = true
      return true
    end
  })
  
  local fully_protected_handler = auth.protect(protected_handler, chained_middleware)
  
  -- Test with valid pastor token
  local client = create_mock_client({
    Authorization = "Bearer " .. session.token
  })
  local params = {}
  
  fully_protected_handler(client, params)
  
  assert(client.response_status == 200, "Should succeed with chained middleware")
  assert(params.custom_check == true, "Custom middleware should be executed")
  assert(params.current_user.role == "Pastor", "Should have user context from auth middleware")
  
  restore_json_response()
end

return tests