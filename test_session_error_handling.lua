-- Test our error handling for Session.invalidate_user_sessions
local log = require("src.utils.log")

-- Mock Session model with error scenarios
local MockSession = {}

function MockSession.invalidate_user_sessions(user_id)
  if not user_id then
    return 0, "User ID is required"
  end
  if user_id == 999 then
    return nil, "Database connection failed"
  end
  return 3, nil -- Success case: invalidated 3 sessions
end

-- Test the error handling logic similar to what's in the controllers
local function test_session_invalidation_error_handling()
  print("Testing Session.invalidate_user_sessions error handling...")
  
  -- Test case 1: Success
  local invalidated_count, sess_err = MockSession.invalidate_user_sessions(123)
  if sess_err then
    log.error("Failed to invalidate sessions for user:", 123, sess_err)
    print("ERROR: Session invalidation should have succeeded")
    return false
  else
    print("SUCCESS: Session invalidation worked, invalidated", invalidated_count, "sessions")
  end
  
  -- Test case 2: Error handling
  local invalidated_count2, sess_err2 = MockSession.invalidate_user_sessions(999)
  if sess_err2 then
    log.error("Failed to invalidate sessions for user:", 999, sess_err2)
    print("SUCCESS: Error properly caught and logged:", sess_err2)
  else
    print("ERROR: Should have failed for user 999")
    return false
  end
  
  -- Test case 3: Nil user ID
  local invalidated_count3, sess_err3 = MockSession.invalidate_user_sessions(nil)
  if sess_err3 then
    log.error("Failed to invalidate sessions for user:", nil, sess_err3)
    print("SUCCESS: Nil user ID error properly caught:", sess_err3)
  else
    print("ERROR: Should have failed for nil user ID")
    return false
  end
  
  return true
end

-- Run the test
if test_session_invalidation_error_handling() then
  print("\n✅ All error handling tests passed!")
else
  print("\n❌ Some tests failed!")
end
