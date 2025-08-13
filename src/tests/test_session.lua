-- src/tests/test_session.lua
-- Unit tests for Session model

-- Test configuration
local test_db_file = "test_session.db"

-- Override database configuration for testing
package.loaded["src.config.database"] = {
  db_file = test_db_file
}

-- Load modules after configuration override
local Session = require("src.models.session")
local User = require("src.models.user")
local security = require("src.utils.security")

-- Test utilities
local function setup_test_db()
  -- Remove existing test database
  os.remove(test_db_file)
  
  -- Initialize database tables
  User.init_db()
  Session.init_db()
end

local function cleanup_test_db()
  os.remove(test_db_file)
end

local function create_test_user()
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "TestPass123",
    role = "Member"
  }
  local user, err = User.create(user_data)
  if not user then
    error("Failed to create test user: " .. (err or "Unknown error"))
  end
  return user
end

-- Test results tracking
local tests_run = 0
local tests_passed = 0

local function assert_equal(actual, expected, message)
  tests_run = tests_run + 1
  if actual == expected then
    tests_passed = tests_passed + 1
    print("✓ " .. (message or "Test passed"))
  else
    print("✗ " .. (message or "Test failed") .. 
          " - Expected: " .. tostring(expected) .. 
          ", Got: " .. tostring(actual))
  end
end

local function assert_not_nil(value, message)
  tests_run = tests_run + 1
  if value ~= nil then
    tests_passed = tests_passed + 1
    print("✓ " .. (message or "Test passed"))
  else
    print("✗ " .. (message or "Test failed") .. " - Expected non-nil value")
  end
end

local function assert_nil(value, message)
  tests_run = tests_run + 1
  if value == nil then
    tests_passed = tests_passed + 1
    print("✓ " .. (message or "Test passed"))
  else
    print("✗ " .. (message or "Test failed") .. " - Expected nil value, got: " .. tostring(value))
  end
end

local function assert_true(value, message)
  tests_run = tests_run + 1
  if value == true then
    tests_passed = tests_passed + 1
    print("✓ " .. (message or "Test passed"))
  else
    print("✗ " .. (message or "Test failed") .. " - Expected true, got: " .. tostring(value))
  end
end

local function assert_false(value, message)
  tests_run = tests_run + 1
  if value == false then
    tests_passed = tests_passed + 1
    print("✓ " .. (message or "Test passed"))
  else
    print("✗ " .. (message or "Test failed") .. " - Expected false, got: " .. tostring(value))
  end
end

-- Test Session.init_db
local function test_init_db()
  print("\n--- Testing Session.init_db ---")
  
  setup_test_db()
  
  -- Test should not throw error
  local success = pcall(Session.init_db)
  assert_true(success, "Session.init_db should execute without error")
  
  cleanup_test_db()
end

-- Test Session.create
local function test_create_session()
  print("\n--- Testing Session.create ---")
  
  setup_test_db()
  local user = create_test_user()
  
  -- Test successful session creation
  local session, err = Session.create(user.id)
  assert_not_nil(session, "Should create session successfully")
  assert_nil(err, "Should not return error on successful creation")
  assert_not_nil(session.token, "Session should have token")
  assert_not_nil(session.expires_at, "Session should have expiration time")
  assert_equal(tonumber(session.user_id), tonumber(user.id), "Session should be linked to correct user")
  
  -- Test session creation with custom duration
  local custom_session, custom_err = Session.create(user.id, 3600) -- 1 hour
  assert_not_nil(custom_session, "Should create session with custom duration")
  assert_nil(custom_err, "Should not return error with custom duration")
  
  -- Test session creation without user_id
  local no_user_session, no_user_err = Session.create(nil)
  assert_nil(no_user_session, "Should not create session without user_id")
  assert_not_nil(no_user_err, "Should return error without user_id")
  
  -- Test session creation with invalid user_id
  local invalid_session, invalid_err = Session.create(99999)
  assert_nil(invalid_session, "Should not create session with invalid user_id")
  assert_not_nil(invalid_err, "Should return error with invalid user_id")
  
  cleanup_test_db()
end

-- Test Session.find_by_token
local function test_find_by_token()
  print("\n--- Testing Session.find_by_token ---")
  
  setup_test_db()
  local user = create_test_user()
  local session = Session.create(user.id)
  
  -- Test finding valid session
  local found_session, err = Session.find_by_token(session.token)
  assert_not_nil(found_session, "Should find session by valid token")
  assert_nil(err, "Should not return error for valid token")
  assert_equal(found_session.token, session.token, "Should return correct session")
  assert_equal(found_session.username, user.username, "Should include user info")
  
  -- Test finding with invalid token
  local invalid_session, invalid_err = Session.find_by_token("invalid_token")
  assert_nil(invalid_session, "Should not find session with invalid token")
  assert_not_nil(invalid_err, "Should return error for invalid token")
  
  -- Test finding with nil token
  local nil_session, nil_err = Session.find_by_token(nil)
  assert_nil(nil_session, "Should not find session with nil token")
  assert_not_nil(nil_err, "Should return error for nil token")
  
  -- Test finding with empty token
  local empty_session, empty_err = Session.find_by_token("")
  assert_nil(empty_session, "Should not find session with empty token")
  assert_not_nil(empty_err, "Should return error for empty token")
  
  cleanup_test_db()
end

-- Test Session.refresh
local function test_refresh_session()
  print("\n--- Testing Session.refresh ---")
  
  setup_test_db()
  local user = create_test_user()
  local session = Session.create(user.id)
  local original_expires_at = session.expires_at
  
  -- Wait a moment to ensure timestamp difference
  os.execute("sleep 1")
  
  -- Test refreshing valid session
  local refreshed_session, err = Session.refresh(session.token)
  assert_not_nil(refreshed_session, "Should refresh session successfully")
  assert_nil(err, "Should not return error on successful refresh")
  assert_true(refreshed_session.expires_at > original_expires_at, "Should extend expiration time")
  
  -- Test refreshing with custom duration
  local custom_refreshed, custom_err = Session.refresh(session.token, 7200) -- 2 hours
  assert_not_nil(custom_refreshed, "Should refresh with custom duration")
  assert_nil(custom_err, "Should not return error with custom duration")
  
  -- Test refreshing invalid token
  local invalid_refresh, invalid_err = Session.refresh("invalid_token")
  assert_nil(invalid_refresh, "Should not refresh invalid token")
  assert_not_nil(invalid_err, "Should return error for invalid token")
  
  -- Test refreshing nil token
  local nil_refresh, nil_err = Session.refresh(nil)
  assert_nil(nil_refresh, "Should not refresh nil token")
  assert_not_nil(nil_err, "Should return error for nil token")
  
  cleanup_test_db()
end

-- Test Session.invalidate
local function test_invalidate_session()
  print("\n--- Testing Session.invalidate ---")
  
  setup_test_db()
  local user = create_test_user()
  local session = Session.create(user.id)
  
  -- Test invalidating valid session
  local success, err = Session.invalidate(session.token)
  assert_true(success, "Should invalidate session successfully")
  assert_nil(err, "Should not return error on successful invalidation")
  
  -- Verify session is actually invalidated
  local found_session, find_err = Session.find_by_token(session.token)
  assert_nil(found_session, "Should not find invalidated session")
  assert_not_nil(find_err, "Should return error when finding invalidated session")
  
  -- Test invalidating already invalidated session
  local already_invalid, already_err = Session.invalidate(session.token)
  assert_false(already_invalid, "Should return false for already invalidated session")
  assert_not_nil(already_err, "Should return error for already invalidated session")
  
  -- Test invalidating with nil token
  local nil_invalid, nil_err = Session.invalidate(nil)
  assert_false(nil_invalid, "Should return false for nil token")
  assert_not_nil(nil_err, "Should return error for nil token")
  
  cleanup_test_db()
end

-- Test Session.cleanup_expired
local function test_cleanup_expired()
  print("\n--- Testing Session.cleanup_expired ---")
  
  setup_test_db()
  local user = create_test_user()
  
  -- Create a valid session first
  local session1 = Session.create(user.id, 3600) -- 1 hour
  
  -- Manually insert an expired session into database to test cleanup
  local conn, env = Session.get_connection()
  local expired_token = security.generate_secure_token()
  local expired_time = os.date("!%Y-%m-%d %H:%M:%S", os.time() - 3600) -- 1 hour ago UTC
  conn:execute(string.format(
    "INSERT INTO sessions (user_id, token, expires_at) VALUES (%d, '%s', '%s')",
    tonumber(user.id), expired_token, expired_time
  ))
  conn:close()
  env:close()
  
  -- Test cleanup
  local cleaned_count = Session.cleanup_expired()
  assert_true(cleaned_count >= 1, "Should clean at least 1 expired session")
  
  -- Verify expired session is removed
  local expired_session, expired_err = Session.find_by_token(expired_token)
  assert_nil(expired_session, "Expired session should be removed")
  
  -- Verify valid session still exists
  local valid_session, valid_err = Session.find_by_token(session1.token)
  assert_not_nil(valid_session, "Valid session should still exist")
  
  cleanup_test_db()
end

-- Test Session.invalidate_user_sessions
local function test_invalidate_user_sessions()
  print("\n--- Testing Session.invalidate_user_sessions ---")
  
  setup_test_db()
  local user1 = create_test_user()
  
  -- Create another user
  local user2_data = {
    username = "testuser2",
    email = "test2@example.com",
    password = "TestPass123",
    role = "Member"
  }
  local user2 = User.create(user2_data)
  
  -- Create multiple sessions for user1
  local session1 = Session.create(user1.id)
  local session2 = Session.create(user1.id)
  local session3 = Session.create(user2.id) -- Different user
  
  -- Test invalidating all sessions for user1
  local invalidated_count, err = Session.invalidate_user_sessions(user1.id)
  assert_equal(invalidated_count, 2, "Should invalidate 2 sessions for user1")
  assert_nil(err, "Should not return error")
  
  -- Verify user1 sessions are invalidated
  local found1, err1 = Session.find_by_token(session1.token)
  local found2, err2 = Session.find_by_token(session2.token)
  assert_nil(found1, "User1 session1 should be invalidated")
  assert_nil(found2, "User1 session2 should be invalidated")
  
  -- Verify user2 session still exists
  local found3, err3 = Session.find_by_token(session3.token)
  assert_not_nil(found3, "User2 session should still exist")
  
  -- Test with nil user_id
  local nil_count, nil_err = Session.invalidate_user_sessions(nil)
  assert_equal(nil_count, 0, "Should return 0 for nil user_id")
  assert_not_nil(nil_err, "Should return error for nil user_id")
  
  cleanup_test_db()
end

-- Test Session.find_by_user_id
local function test_find_by_user_id()
  print("\n--- Testing Session.find_by_user_id ---")
  
  setup_test_db()
  local user = create_test_user()
  
  -- Create multiple sessions for user
  local session1 = Session.create(user.id)
  local session2 = Session.create(user.id)
  
  -- Test finding sessions by user_id
  local user_sessions = Session.find_by_user_id(user.id)
  assert_equal(#user_sessions, 2, "Should find 2 sessions for user")
  
  -- Test with non-existent user
  local no_sessions = Session.find_by_user_id(99999)
  assert_equal(#no_sessions, 0, "Should return empty array for non-existent user")
  
  -- Test with nil user_id
  local nil_sessions = Session.find_by_user_id(nil)
  assert_equal(#nil_sessions, 0, "Should return empty array for nil user_id")
  
  cleanup_test_db()
end

-- Test Session.get_statistics
local function test_get_statistics()
  print("\n--- Testing Session.get_statistics ---")
  
  setup_test_db()
  local user = create_test_user()
  
  -- Create an active session
  local active_session = Session.create(user.id, 3600) -- Active
  
  -- Manually insert an expired session into database
  local conn, env = Session.get_connection()
  local expired_token = security.generate_secure_token()
  local expired_time = os.date("!%Y-%m-%d %H:%M:%S", os.time() - 3600) -- 1 hour ago UTC
  conn:execute(string.format(
    "INSERT INTO sessions (user_id, token, expires_at) VALUES (%d, '%s', '%s')",
    tonumber(user.id), expired_token, expired_time
  ))
  conn:close()
  env:close()
  
  -- Test getting statistics
  local stats = Session.get_statistics()
  assert_not_nil(stats, "Should return statistics object")
  assert_not_nil(stats.total, "Should include total count")
  assert_not_nil(stats.active, "Should include active count")
  assert_not_nil(stats.expired, "Should include expired count")
  assert_true(stats.total >= 2, "Should have at least 2 total sessions")
  assert_true(stats.active >= 1, "Should have at least 1 active session")
  assert_true(stats.expired >= 1, "Should have at least 1 expired session")
  
  cleanup_test_db()
end

-- Test Session.is_valid
local function test_is_valid()
  print("\n--- Testing Session.is_valid ---")
  
  setup_test_db()
  local user = create_test_user()
  local session = Session.create(user.id)
  
  -- Test with valid token
  local is_valid = Session.is_valid(session.token)
  assert_true(is_valid, "Should return true for valid token")
  
  -- Test with invalid token
  local is_invalid = Session.is_valid("invalid_token")
  assert_false(is_invalid, "Should return false for invalid token")
  
  -- Test with nil token
  local is_nil = Session.is_valid(nil)
  assert_false(is_nil, "Should return false for nil token")
  
  cleanup_test_db()
end

-- Test session expiration handling
local function test_session_expiration()
  print("\n--- Testing Session Expiration ---")
  
  setup_test_db()
  local user = create_test_user()
  
  -- Create expired session (negative duration means it expires immediately)
  local expired_session = Session.create(user.id, -1)
  
  -- Try to find expired session
  local found_session, err = Session.find_by_token(expired_session.token)
  assert_nil(found_session, "Should not find expired session")
  assert_not_nil(err, "Should return error for expired session")
  assert_true(err:find("expired") ~= nil, "Error should mention expiration")
  
  cleanup_test_db()
end

-- Test session with deactivated user
local function test_session_with_deactivated_user()
  print("\n--- Testing Session with Deactivated User ---")
  
  setup_test_db()
  local user = create_test_user()
  local session = Session.create(user.id)
  
  -- Deactivate user
  User.deactivate(user.id)
  
  -- Try to find session for deactivated user
  local found_session, err = Session.find_by_token(session.token)
  assert_nil(found_session, "Should not find session for deactivated user")
  assert_not_nil(err, "Should return error for deactivated user")
  assert_true(err:find("deactivated") ~= nil, "Error should mention deactivation")
  
  cleanup_test_db()
end

-- Run all tests
local function run_all_tests()
  print("=== Running Session Model Tests ===")
  
  test_init_db()
  test_create_session()
  test_find_by_token()
  test_refresh_session()
  test_invalidate_session()
  test_cleanup_expired()
  test_invalidate_user_sessions()
  test_find_by_user_id()
  test_get_statistics()
  test_is_valid()
  test_session_expiration()
  test_session_with_deactivated_user()
  
  print("\n=== Test Results ===")
  print(string.format("Tests run: %d", tests_run))
  print(string.format("Tests passed: %d", tests_passed))
  print(string.format("Tests failed: %d", tests_run - tests_passed))
  print(string.format("Success rate: %.1f%%", (tests_passed / tests_run) * 100))
  
  if tests_passed == tests_run then
    print("✓ All tests passed!")
    return true
  else
    print("✗ Some tests failed!")
    return false
  end
end

-- Export test functions for external use
return {
  run_all_tests = run_all_tests,
  setup_test_db = setup_test_db,
  cleanup_test_db = cleanup_test_db
}