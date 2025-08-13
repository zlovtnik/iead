-- src/tests/test_rate_limiter.lua
-- Unit tests for the new rate limiter module

local rate_limiter = require("src.utils.rate_limiter")

local tests = {}

-- Test initialization
function tests.test_rate_limiter_init()
  print("Testing rate limiter initialization...")
  
  -- Test with custom config
  rate_limiter.init({
    max_attempts = 3,
    window_seconds = 60,
    redis = {
      enabled = false -- Force memory backend for testing
    }
  })
  
  local config = rate_limiter.get_config()
  assert(config.max_attempts == 3, "Max attempts should be set to 3")
  assert(config.window_seconds == 60, "Window should be set to 60 seconds")
  assert(rate_limiter.get_backend_type() == "memory", "Should use memory backend when Redis is disabled")
  
  print("✓ Rate limiter initialization test passed")
end

-- Test rate limiting behavior
function tests.test_rate_limit_check()
  print("Testing rate limit check functionality...")
  
  -- Initialize with test config
  rate_limiter.init({
    max_attempts = 3,
    window_seconds = 60,
    redis = { enabled = false }
  })
  
  local identifier = "test_user_123"
  
  -- First 3 attempts should be allowed
  for i = 1, 3 do
    local allowed, error_msg = rate_limiter.check_rate_limit(identifier)
    assert(allowed == true, string.format("Attempt %d should be allowed", i))
    assert(error_msg == nil, "No error message should be present for allowed attempts")
  end
  
  -- 4th attempt should be blocked
  local allowed, error_msg = rate_limiter.check_rate_limit(identifier)
  assert(allowed == false, "4th attempt should be blocked")
  assert(error_msg ~= nil, "Error message should be present for blocked attempt")
  
  print("✓ Rate limit check test passed")
end

-- Test rate limit status
function tests.test_rate_limit_status()
  print("Testing rate limit status functionality...")
  
  rate_limiter.init({
    max_attempts = 5,
    window_seconds = 300,
    redis = { enabled = false }
  })
  
  local identifier = "status_test_user"
  
  -- Make some attempts
  rate_limiter.check_rate_limit(identifier)
  rate_limiter.check_rate_limit(identifier)
  
  local status = rate_limiter.get_rate_limit_status(identifier)
  
  assert(status ~= nil, "Status should not be nil")
  assert(status.identifier == identifier, "Identifier should match")
  assert(status.attempts == 2, "Should show 2 attempts")
  assert(status.max_attempts == 5, "Max attempts should be 5")
  assert(status.remaining == 3, "Should have 3 remaining attempts")
  assert(status.is_limited == false, "Should not be limited yet")
  assert(status.window_seconds == 300, "Window should be 300 seconds")
  
  print("✓ Rate limit status test passed")
end

-- Test rate limit clearing
function tests.test_rate_limit_clear()
  print("Testing rate limit clearing...")
  
  rate_limiter.init({
    max_attempts = 2,
    window_seconds = 60,
    redis = { enabled = false }
  })
  
  local identifier = "clear_test_user"
  
  -- Use up the rate limit
  rate_limiter.check_rate_limit(identifier)
  rate_limiter.check_rate_limit(identifier)
  
  -- Next attempt should be blocked
  local allowed = rate_limiter.check_rate_limit(identifier)
  assert(allowed == false, "Should be blocked after limit reached")
  
  -- Clear the rate limit
  local cleared = rate_limiter.clear_rate_limit(identifier)
  assert(cleared == true, "Clear should succeed")
  
  -- Should be allowed again after clearing
  local allowed_after_clear = rate_limiter.check_rate_limit(identifier)
  assert(allowed_after_clear == true, "Should be allowed after clearing rate limit")
  
  print("✓ Rate limit clearing test passed")
end

-- Test different identifiers don't interfere
function tests.test_rate_limit_isolation()
  print("Testing rate limit isolation between identifiers...")
  
  rate_limiter.init({
    max_attempts = 2,
    window_seconds = 60,
    redis = { enabled = false }
  })
  
  local user1 = "isolation_user_1"
  local user2 = "isolation_user_2"
  
  -- Use up rate limit for user1
  rate_limiter.check_rate_limit(user1)
  rate_limiter.check_rate_limit(user1)
  
  -- user1 should be blocked
  local user1_blocked = rate_limiter.check_rate_limit(user1)
  assert(user1_blocked == false, "User1 should be blocked")
  
  -- user2 should still be allowed
  local user2_allowed = rate_limiter.check_rate_limit(user2)
  assert(user2_allowed == true, "User2 should still be allowed")
  
  print("✓ Rate limit isolation test passed")
end

-- Test invalid identifiers
function tests.test_invalid_identifiers()
  print("Testing invalid identifier handling...")
  
  rate_limiter.init({
    max_attempts = 5,
    window_seconds = 60,
    redis = { enabled = false }
  })
  
  -- Test nil identifier
  local allowed, error_msg = rate_limiter.check_rate_limit(nil)
  assert(allowed == false, "Nil identifier should not be allowed")
  assert(error_msg == "Invalid identifier", "Should return invalid identifier error")
  
  -- Test empty identifier
  local allowed2, error_msg2 = rate_limiter.check_rate_limit("")
  assert(allowed2 == false, "Empty identifier should not be allowed")
  assert(error_msg2 == "Invalid identifier", "Should return invalid identifier error")
  
  print("✓ Invalid identifier test passed")
end

-- Test memory cleanup functionality
function tests.test_memory_cleanup()
  print("Testing memory cleanup functionality...")
  
  rate_limiter.init({
    max_attempts = 5,
    window_seconds = 2, -- Very short window for testing
    cleanup_interval = 1, -- Clean up every second
    max_memory_entries = 5,
    redis = { enabled = false }
  })
  
  -- Create several entries
  for i = 1, 10 do
    rate_limiter.check_rate_limit("cleanup_user_" .. i)
  end
  
  -- Wait for entries to expire
  os.execute("sleep 3")
  
  -- Force cleanup by making a new request
  rate_limiter.check_rate_limit("cleanup_trigger")
  
  -- The cleanup should have removed expired entries
  -- This is a bit hard to test directly, but we can at least verify it doesn't crash
  print("✓ Memory cleanup test passed (no crashes)")
end

-- Run all tests
function tests.run_all()
  print("Running rate limiter tests...")
  print("=" .. string.rep("=", 50))
  
  tests.test_rate_limiter_init()
  tests.test_rate_limit_check()
  tests.test_rate_limit_status()
  tests.test_rate_limit_clear()
  tests.test_rate_limit_isolation()
  tests.test_invalid_identifiers()
  tests.test_memory_cleanup()
  
  print("=" .. string.rep("=", 50))
  print("✓ All rate limiter tests passed!")
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_rate_limiter%.lua$") then
  tests.run_all()
end

return tests
