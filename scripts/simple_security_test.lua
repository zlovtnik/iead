-- scripts/simple_security_test.lua
-- Simple security test that doesn't require full database setup

local function test_password_hashing()
    print("Testing password hashing...")
    
    -- Load the security module
    package.path = package.path .. ";./src/?.lua"
    local security = require("src.utils.security")
    
    local password = "TestPassword123"
    local hash = security.hash_password(password)
    
    -- Verify hash is not plain text
    if hash == password then
        print("❌ FAILED: Password not hashed!")
        return false
    end
    
    -- Verify password verification works
    if not security.verify_password(password, hash) then
        print("❌ FAILED: Password verification failed!")
        return false
    end
    
    -- Verify wrong password fails
    if security.verify_password("WrongPassword", hash) then
        print("❌ FAILED: Wrong password accepted!")
        return false
    end
    
    print("✅ PASSED: Password hashing works correctly")
    return true
end

local function test_input_validation()
    print("Testing input validation...")
    
    local validator = require("src.application.validators.input_validator")
    
    -- Test email validation
    local valid_data, errors = validator.validate_request({
        email = "valid@example.com"
    }, {
        email = {
            required = true,
            pattern = "^[%w._%+-]+@[%w.-]+%.%w+$",
            max_length = 254
        }
    })
    
    if errors then
        print("❌ FAILED: Valid email rejected")
        return false
    end
    
    -- Test invalid email
    valid_data, errors = validator.validate_request({
        email = "invalid-email"
    }, {
        email = {
            required = true,
            pattern = "^[%w._%+-]+@[%w.-]+%.%w+$",
            max_length = 254
        }
    })
    
    if not errors then
        print("❌ FAILED: Invalid email accepted")
        return false
    end
    
    print("✅ PASSED: Input validation works correctly")
    return true
end

local function test_token_generation()
    print("Testing token generation...")
    
    local security = require("src.utils.security")
    
    local token1 = security.generate_token(32)
    local token2 = security.generate_token(32)
    
    -- Tokens should be different
    if token1 == token2 then
        print("❌ FAILED: Tokens are the same!")
        return false
    end
    
    -- Tokens should be the right length
    if #token1 ~= 32 or #token2 ~= 32 then
        print("❌ FAILED: Wrong token length")
        return false
    end
    
    -- Tokens should only contain valid characters
    if not token1:match("^[%w]+$") or not token2:match("^[%w]+$") then
        print("❌ FAILED: Invalid characters in token")
        return false
    end
    
    print("✅ PASSED: Token generation works correctly")
    return true
end

local function test_rate_limiting()
    print("Testing rate limiting...")
    
    local rate_limiter = require("src.application.middlewares.rate_limit_middleware")
    
    local config = {
        max_attempts = 3,
        window_seconds = 60
    }
    
    local identifier = "test_user_" .. os.time()
    
    -- First attempts should be allowed
    for i = 1, config.max_attempts do
        local allowed, remaining = rate_limiter.check_rate_limit(identifier, config)
        if not allowed then
            print("❌ FAILED: Should be allowed")
            return false
        end
    end
    
    -- Next attempt should be rate limited
    local allowed, remaining = rate_limiter.check_rate_limit(identifier, config)
    if allowed then
        print("❌ FAILED: Should be rate limited")
        return false
    end
    
    print("✅ PASSED: Rate limiting works correctly")
    return true
end

local function test_input_sanitization()
    print("Testing input sanitization...")
    
    local validator = require("src.application.validators.input_validator")
    
    local malicious_input = "<script>alert('xss')</script>"
    local sanitized = validator.sanitize_string(malicious_input)
    
    -- Should not contain original script tags
    if sanitized == malicious_input then
        print("❌ FAILED: Input not sanitized")
        return false
    end
    
    -- Test SQL injection attempts
    local sql_injection = "'; DROP TABLE users; --"
    local sanitized_sql = validator.sanitize_string(sql_injection)
    
    -- Should be sanitized
    if sanitized_sql == sql_injection then
        print("❌ FAILED: SQL injection not sanitized")
        return false
    end
    
    print("✅ PASSED: Input sanitization works correctly")
    return true
end

-- Run all tests
print("=== Simple Security Tests ===\n")

local tests = {
    test_password_hashing,
    test_input_validation,
    test_token_generation,
    test_rate_limiting,
    test_input_sanitization
}

local passed = 0
local failed = 0

for _, test in ipairs(tests) do
    local success, result = pcall(test)
    if success and result then
        passed = passed + 1
    else
        failed = failed + 1
        if not success then
            print("❌ Test error: " .. (result or "Unknown error"))
        end
    end
    print("")
end

print("=== Results ===")
print("Passed: " .. passed)
print("Failed: " .. failed)
print("Total:  " .. (passed + failed))

if failed > 0 then
    print("\n❌ SOME TESTS FAILED")
    os.exit(1)
else
    print("\n✅ ALL TESTS PASSED")
    os.exit(0)
end
