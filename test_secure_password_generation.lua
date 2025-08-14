#!/usr/bin/env lua

-- Test script to verify secure password generation improvements
-- This script tests the cryptographically secure random number generation

local security = require("src.utils.security")

print("🔐 Testing Secure Password Generation")
print("====================================")

-- Test 1: Basic password generation
print("\n1. Basic Password Generation:")
for i = 1, 5 do
    local password = security.generate_secure_password(12)
    print(string.format("   Password %d: %s (length: %d)", i, password, #password))
    
    -- Validate each password
    local valid, err = security.validate_password_strength(password)
    if valid then
        print("   ✅ Password meets policy requirements")
    else
        print("   ❌ Password validation failed: " .. (err or "unknown error"))
    end
end

-- Test 2: Different lengths
print("\n2. Different Password Lengths:")
local lengths = {8, 12, 16, 20, 32}
for _, length in ipairs(lengths) do
    local password = security.generate_secure_password(length)
    print(string.format("   Length %d: %s", length, password))
    assert(#password == length, "Password length mismatch")
end

-- Test 3: Character set validation
print("\n3. Character Set Validation:")
local password = security.generate_secure_password(20)
print(string.format("   Test password: %s", password))

local has_lower = password:match("%l") ~= nil
local has_upper = password:match("%u") ~= nil
local has_digit = password:match("%d") ~= nil

print(string.format("   Contains lowercase: %s", has_lower and "✅" or "❌"))
print(string.format("   Contains uppercase: %s", has_upper and "✅" or "❌"))
print(string.format("   Contains digits: %s", has_digit and "✅" or "❌"))

-- Test 4: Uniqueness test
print("\n4. Uniqueness Test:")
local passwords = {}
local duplicates = 0
for i = 1, 100 do
    local password = security.generate_secure_password(15)
    if passwords[password] then
        duplicates = duplicates + 1
    else
        passwords[password] = true
    end
end

print(string.format("   Generated 100 passwords, found %d duplicates", duplicates))
if duplicates == 0 then
    print("   ✅ All passwords are unique")
else
    print("   ⚠️  Found duplicate passwords (may indicate weak randomness)")
end

-- Test 5: Token generation
print("\n5. Secure Token Generation:")
for i = 1, 3 do
    local token = security.generate_secure_token()
    print(string.format("   Token %d: %s (length: %d)", i, token, #token))
end

print("\n✅ Secure password generation tests completed!")
