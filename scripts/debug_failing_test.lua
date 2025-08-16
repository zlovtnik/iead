#!/usr/bin/env luajit

-- Run just the failing test to debug it

local test_runner = require("src.tests.test_runner")
local security = require("src.utils.security")

print("🔬 Running the failing test: test_generate_secure_password_policy_compliance")
print("==============================================================================")

function test_generate_secure_password_policy_compliance()
  local password = security.generate_secure_password(20)
  print("Generated password: " .. password)
  
  -- Test that generated password meets policy requirements
  local valid, err = security.validate_password_strength(password)
  print("Password validation result: " .. tostring(valid) .. (err and " (" .. err .. ")" or ""))
  
  test_runner.assert_true(valid, "Generated password should meet policy requirements")
  test_runner.assert_nil(err, "Generated password should have no validation errors")
  
  -- Test that password contains required character types
  local has_lower = password:match("%l")
  local has_upper = password:match("%u") 
  local has_digit = password:match("%d")
  
  print("Character type analysis:")
  print("  Has lowercase: " .. tostring(has_lower ~= nil))
  print("  Has uppercase: " .. tostring(has_upper ~= nil))
  print("  Has digits: " .. tostring(has_digit ~= nil))
  
  test_runner.assert_true(password:match("%l") ~= nil, "Password should contain lowercase letters")
  test_runner.assert_true(password:match("%u") ~= nil, "Password should contain uppercase letters")
  test_runner.assert_true(password:match("%d") ~= nil, "Password should contain digits")
end

-- Run the test
local success, error_msg = pcall(test_generate_secure_password_policy_compliance)

if success then
    print("✅ Test passed!")
else
    print("❌ Test failed: " .. error_msg)
end
