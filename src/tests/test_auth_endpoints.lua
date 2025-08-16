-- src/tests/test_auth_endpoints.lua
-- Tests for authentication middleware applied to existing endpoints

local test_runner = require("src.tests.test_runner")
local router = require("src.routes.router")
local User = require("src.models.user")
local Member = require("src.models.member")
local Session = require("src.models.session")
local json_utils = require("src.utils.json")

local tests = {}

-- Mock client helper
local function create_mock_client(headers)
  return {
    headers = headers or {},
    response_status = nil,
    response_body = nil,
    response_headers = {}
  }
end

-- Mock json response for testing
local original_send_json_response
local function mock_json_response()
  original_send_json_response = json_utils.send_json_response
  json_utils.send_json_response = function(client, status, body, headers)
    client.response_status = status
    client.response_body = body
    client.response_headers = headers or {}
  end
end

local function restore_json_response()
  if original_send_json_response then
    json_utils.send_json_response = original_send_json_response
  end
end

-- Setup test database
local function setup()
  test_runner.clear_test_db()
  Member.init_db()
  User.init_db()
  Session.init_db()
end

local function teardown()
  -- Clean up is handled by clear_test_db()
end

-- Test member endpoints authentication
function tests.test_member_endpoints_authentication()
  setup()
  mock_json_response()
  
  -- Create test users without member_id (simpler test)
  local member_user, err1 = User.create({
    username = "member_test",
    email = "member@test.com",
    password = "TestPass123",
    role = "Member"
  })
  
  test_runner.assert_not_nil(member_user, "Member user should be created: " .. (err1 or ""))
  
  local pastor_user, err2 = User.create({
    username = "pastor_test",
    email = "pastor@test.com",
    password = "TestPass123", 
    role = "Pastor"
  })
  
  test_runner.assert_not_nil(pastor_user, "Pastor user should be created: " .. (err2 or ""))
  
  local member_session = Session.create(member_user.id)
  local pastor_session = Session.create(pastor_user.id)
  
  -- Test /members (should require pastor)
  local member_client = create_mock_client({
    Authorization = "Bearer " .. member_session.token
  })
  
  router.match("/members", "GET", member_client, {})
  test_runner.assert_equal(member_client.response_status, 403, "Member should not access member list")
  
  local pastor_client = create_mock_client({
    Authorization = "Bearer " .. pastor_session.token
  })
  
  router.match("/members", "GET", pastor_client, {})
  test_runner.assert_equal(pastor_client.response_status, 200, "Pastor should access member list")
  
  -- Test /members/{id} access control (member should not access arbitrary member data)
  local member_access_client = create_mock_client({
    Authorization = "Bearer " .. member_session.token
  })
  
  router.match("/members/999", "GET", member_access_client, {})
  test_runner.assert_equal(member_access_client.response_status, 403, "Member should not access other member data")
  
  restore_json_response()
  teardown()
end

-- Test event endpoints authentication
function tests.test_event_endpoints_authentication()
  setup()
  mock_json_response()
  
  local member_user, err1 = User.create({
    username = "member_event_test",
    email = "member_event@test.com",
    password = "TestPass123",
    role = "Member"
  })
  
  test_runner.assert_not_nil(member_user, "Member user should be created: " .. (err1 or ""))
  
  local pastor_user, err2 = User.create({
    username = "pastor_event_test",
    email = "pastor_event@test.com",
    password = "TestPass123",
    role = "Pastor"
  })
  
  test_runner.assert_not_nil(pastor_user, "Pastor user should be created: " .. (err2 or ""))
  
  local member_session = Session.create(member_user.id)
  local pastor_session = Session.create(pastor_user.id)
  
  -- Test GET /events (should allow member)
  local member_client = create_mock_client({
    Authorization = "Bearer " .. member_session.token
  })
  
  router.match("/events", "GET", member_client, {})
  test_runner.assert_equal(member_client.response_status, 200, "Member should view events")
  
  -- Test POST /events (should require pastor) - test authorization, not creation logic
  local member_post_client = create_mock_client({
    Authorization = "Bearer " .. member_session.token
  })
  
  router.match("/events", "POST", member_post_client, {})
  test_runner.assert_equal(member_post_client.response_status, 403, "Member should not create events")
  
  local pastor_post_client = create_mock_client({
    Authorization = "Bearer " .. pastor_session.token
  })
  
  router.match("/events", "POST", pastor_post_client, {})
  -- Should get 400 (bad request) or other error, but NOT 403 (auth should pass)
  test_runner.assert_true(pastor_post_client.response_status ~= 403, "Pastor should pass authentication for events")
  
  restore_json_response()
  teardown()
end

-- Test donation endpoints authentication
function tests.test_donation_endpoints_authentication()
  setup()
  mock_json_response()
  
  local member_user, err1 = User.create({
    username = "member_donation_test",
    email = "member_donation@test.com",
    password = "TestPass123",
    role = "Member"
  })
  
  test_runner.assert_not_nil(member_user, "Member user should be created: " .. (err1 or ""))
  
  local pastor_user, err2 = User.create({
    username = "pastor_donation_test",
    email = "pastor_donation@test.com",
    password = "TestPass123",
    role = "Pastor"
  })
  
  test_runner.assert_not_nil(pastor_user, "Pastor user should be created: " .. (err2 or ""))
  
  local member_session = Session.create(member_user.id)
  local pastor_session = Session.create(pastor_user.id)
  
  -- Test GET /donations (should require pastor)
  local member_client = create_mock_client({
    Authorization = "Bearer " .. member_session.token
  })
  
  router.match("/donations", "GET", member_client, {})
  test_runner.assert_equal(member_client.response_status, 403, "Member should not view all donations")
  
  local pastor_client = create_mock_client({
    Authorization = "Bearer " .. pastor_session.token
  })
  
  router.match("/donations", "GET", pastor_client, {})
  test_runner.assert_equal(pastor_client.response_status, 200, "Pastor should view donations")
  
  restore_json_response()
  teardown()
end

-- Test report endpoints authentication
function tests.test_report_endpoints_authentication()
  setup()
  mock_json_response()
  
  local member_user, err1 = User.create({
    username = "member_report_test",
    email = "member_report@test.com",
    password = "TestPass123",
    role = "Member"
  })
  
  test_runner.assert_not_nil(member_user, "Member user should be created: " .. (err1 or ""))
  
  local pastor_user, err2 = User.create({
    username = "pastor_report_test",
    email = "pastor_report@test.com",
    password = "TestPass123",
    role = "Pastor"
  })
  
  test_runner.assert_not_nil(pastor_user, "Pastor user should be created: " .. (err2 or ""))
  
  local member_session = Session.create(member_user.id)
  local pastor_session = Session.create(pastor_user.id)
  
  -- Test report endpoints (should require pastor)
  local member_client = create_mock_client({
    Authorization = "Bearer " .. member_session.token
  })
  
  router.match("/reports/member-attendance", "GET", member_client, {})
  test_runner.assert_equal(member_client.response_status, 403, "Member should not access reports")
  
  local pastor_client = create_mock_client({
    Authorization = "Bearer " .. pastor_session.token
  })
  
  router.match("/reports/member-attendance", "GET", pastor_client, {})
  test_runner.assert_equal(pastor_client.response_status, 200, "Pastor should access reports")
  
  restore_json_response()
  teardown()
end

-- Test user management endpoints authentication
function tests.test_user_management_authentication()
  setup()
  mock_json_response()
  
  local admin_user, err1 = User.create({
    username = "admin_test",
    email = "admin@test.com",
    password = "TestPass123",
    role = "Admin"
  })
  
  test_runner.assert_not_nil(admin_user, "Admin user should be created: " .. (err1 or ""))
  
  local pastor_user, err2 = User.create({
    username = "pastor_user_test", 
    email = "pastor_user@test.com",
    password = "TestPass123",
    role = "Pastor"
  })
  
  test_runner.assert_not_nil(pastor_user, "Pastor user should be created: " .. (err2 or ""))
  
  local admin_session = Session.create(admin_user.id)
  local pastor_session = Session.create(pastor_user.id)
  
  -- Test GET /users (should require admin)
  local pastor_client = create_mock_client({
    Authorization = "Bearer " .. pastor_session.token
  })
  
  router.match("/users", "GET", pastor_client, {})
  test_runner.assert_equal(pastor_client.response_status, 403, "Pastor should not access user management")
  
  local admin_client = create_mock_client({
    Authorization = "Bearer " .. admin_session.token
  })
  
  router.match("/users", "GET", admin_client, {})
  test_runner.assert_equal(admin_client.response_status, 200, "Admin should access user management")
  
  restore_json_response()
  teardown()
end

-- Test unauthenticated access is denied
function tests.test_unauthenticated_access_denied()
  setup()
  mock_json_response()
  
  local client = create_mock_client()
  
  -- Test various endpoints without authentication
  router.match("/members", "GET", client, {})
  test_runner.assert_equal(client.response_status, 401, "Should require authentication for members")
  
  router.match("/events", "GET", client, {})
  test_runner.assert_equal(client.response_status, 401, "Should require authentication for events")
  
  router.match("/donations", "GET", client, {})
  test_runner.assert_equal(client.response_status, 401, "Should require authentication for donations")
  
  router.match("/reports/member-attendance", "GET", client, {})
  test_runner.assert_equal(client.response_status, 401, "Should require authentication for reports")
  
  restore_json_response()
  teardown()
end

return tests
