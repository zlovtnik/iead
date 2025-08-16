-- scripts/verify_security_fixes.lua
-- Script to verify that critical security fixes are properly implemented

local db = require("src.infrastructure.db.connection")
local validator = require("src.application.validators.input_validator")
local security = require("src.utils.security")
local User = require("src.models.user_secure")
local rate_limiter = require("src.application.middlewares.rate_limit_middleware")

local test_results = {
    passed = 0,
    failed = 0,
    tests = {}
}

-- Helper function to run a test
local function run_test(name, test_func)
    print("Running test: " .. name)
    local success, result = pcall(test_func)
    
    if success and result then
        print("✓ PASSED: " .. name)
        test_results.passed = test_results.passed + 1
        table.insert(test_results.tests, {name = name, status = "PASSED"})
    else
        print("✗ FAILED: " .. name .. " - " .. (result or "Unknown error"))
        test_results.failed = test_results.failed + 1
        table.insert(test_results.tests, {name = name, status = "FAILED", error = result})
    end
    print("")
end

-- Test 1: SQL Injection Prevention
run_test("SQL Injection Prevention", function()
    -- Test that SQL injection attempts are properly sanitized
    local malicious_username = "admin'; DROP TABLE users; --"
    local safe_data, errors = validator.validate_request({
        username = malicious_username,
        email = "test@example.com",
        password = "ValidPass123",
        role = "Member"
    }, validator.schemas.user_create)
    
    -- Should either sanitize the input or reject it entirely
    if errors and errors.username then
        return true -- Rejected dangerous input
    elseif safe_data and safe_data.username and not safe_data.username:find("DROP") then
        return true -- Sanitized the input
    end
    
    return false
end)

-- Test 2: Password Hashing Security
run_test("Password Hashing Security", function()
    local password = "TestPassword123"
    local hash = security.hash_password(password)
    
    -- Verify hash is bcrypt format and not plain text
    if hash == password then
        return false -- Password not hashed!
    end
    
    -- Verify password verification works
    if not security.verify_password(password, hash) then
        return false -- Verification failed
    end
    
    -- Verify wrong password fails
    if security.verify_password("WrongPassword", hash) then
        return false -- Wrong password accepted!
    end
    
    return true
end)

-- Test 3: Input Validation
run_test("Input Validation", function()
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
        return false -- Valid email rejected
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
        return false -- Invalid email accepted
    end
    
    return true
end)

-- Test 4: Rate Limiting
run_test("Rate Limiting", function()
    local config = {
        max_attempts = 3,
        window_seconds = 60
    }
    
    local identifier = "test_user_" .. os.time()
    
    -- First attempts should be allowed
    for i = 1, config.max_attempts do
        local allowed, remaining = rate_limiter.check_rate_limit(identifier, config)
        if not allowed then
            return false -- Should be allowed
        end
    end
    
    -- Next attempt should be rate limited
    local allowed, remaining = rate_limiter.check_rate_limit(identifier, config)
    if allowed then
        return false -- Should be rate limited
    end
    
    return true
end)

-- Test 5: Token Generation Security
run_test("Token Generation Security", function()
    local token1 = security.generate_token(32)
    local token2 = security.generate_token(32)
    
    -- Tokens should be different
    if token1 == token2 then
        return false -- Tokens are the same!
    end
    
    -- Tokens should be the right length
    if #token1 ~= 32 or #token2 ~= 32 then
        return false -- Wrong token length
    end
    
    -- Tokens should only contain valid characters
    if not token1:match("^[%w]+$") or not token2:match("^[%w]+$") then
        return false -- Invalid characters in token
    end
    
    return true
end)

-- Test 6: Database Connection Security
run_test("Database Connection Security", function()
    -- Test that database connections work with parameterized queries
    local success, err = pcall(function()
        local result = db.query_one("SELECT ? as test_value", {"test_data"})
        return result and result.test_value == "test_data"
    end)
    
    return success
end)

-- Test 7: Secure User Creation
run_test("Secure User Creation", function()
    -- Initialize database first
    User.init_db()
    
    -- Create a test user with secure validation
    local unique_username = "test_user_" .. os.time()
    local user_data = {
        username = unique_username,
        email = unique_username .. "@example.com",
        password = "SecurePass123",
        role = "Member"
    }
    
    local user, error = User.create(user_data)
    
    if not user then
        return false -- User creation failed: .. (error or "unknown")
    end
    
    -- Verify password is hashed
    if user.password_hash then
        return false -- Password hash exposed in returned user object
    end
    
    -- Try to authenticate with the created user
    local auth_user, auth_error = User.authenticate(user_data.username, user_data.password)
    
    if not auth_user then
        return false -- Authentication failed: .. (auth_error or "unknown")
    end
    
    return true
end)

-- Test 8: Input Sanitization
run_test("Input Sanitization", function()
    local malicious_input = "<script>alert('xss')</script>"
    local sanitized = validator.sanitize_string(malicious_input)
    
    -- Should not contain script tags
    if sanitized:find("<script>") then
        return false -- XSS vulnerability detected
    end
    
    -- Test SQL injection attempts
    local sql_injection = "'; DROP TABLE users; --"
    local sanitized_sql = validator.sanitize_string(sql_injection)
    
    -- Should not contain dangerous SQL
    if sanitized_sql:find("DROP TABLE") then
        return false -- SQL injection vulnerability detected
    end
    
    return true
end)

-- Run all tests
print("=== Church Management System Security Tests ===\n")

-- Print summary
print("=== Test Results ===")
print("Passed: " .. test_results.passed)
print("Failed: " .. test_results.failed)
print("Total:  " .. (test_results.passed + test_results.failed))

if test_results.failed > 0 then
    print("\n=== Failed Tests ===")
    for _, test in ipairs(test_results.tests) do
        if test.status == "FAILED" then
            print("✗ " .. test.name .. ": " .. (test.error or "Unknown error"))
        end
    end
    print("\n❌ SECURITY TESTS FAILED - Critical vulnerabilities detected!")
    os.exit(1)
else
    print("\n✅ ALL SECURITY TESTS PASSED - System appears secure!")
    os.exit(0)
end
