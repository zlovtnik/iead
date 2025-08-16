#!/usr/bin/env luajit

-- Debug script to investigate the failing test case

local security = require("src.utils.security")

print("🔍 Debug: Investigating password generation policy compliance")
print("==========================================================")

-- Run the same test multiple times to see what's happening
for i = 1, 10 do
    local password = security.generate_secure_password(20)
    
    -- Test character patterns
    local has_lower = password:match("%l") ~= nil
    local has_upper = password:match("%u") ~= nil
    local has_digit = password:match("%d") ~= nil
    
    print(string.format("Password %d: %s", i, password))
    print(string.format("  Lower: %s, Upper: %s, Digit: %s", 
        has_lower and "✅" or "❌",
        has_upper and "✅" or "❌",
        has_digit and "✅" or "❌"))
    
    -- Check validation
    local valid, err = security.validate_password_strength(password)
    print(string.format("  Valid: %s%s", valid and "✅" or "❌", err and " (" .. err .. ")" or ""))
    
    if not has_lower or not has_upper or not has_digit then
        print("  ⚠️  This password would fail the test!")
    end
    print()
end
