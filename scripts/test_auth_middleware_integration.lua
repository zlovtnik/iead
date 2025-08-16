#!/usr/bin/env luajit

-- Test runner for authentication endpoints

local test_runner = require("src.tests.test_runner")
local tests = require("src.tests.test_auth_endpoints")

print("🔐 Testing Authentication Middleware Applied to Endpoints")
print("========================================================")

-- Initialize stats
test_runner.stats = {passed = 0, failed = 0, total = 0, failures = {}}

-- Run all tests
for name, test_func in pairs(tests) do
  if name:match("^test_") then
    test_runner.stats.total = test_runner.stats.total + 1
    local success, error_msg = pcall(test_func)
    
    if success then
      test_runner.stats.passed = test_runner.stats.passed + 1
      print("✓ " .. name)
    else
      test_runner.stats.failed = test_runner.stats.failed + 1
      table.insert(test_runner.stats.failures, name .. ": " .. error_msg)
      print("✗ " .. name .. ": " .. error_msg)
    end
  end
end

print()
print("Authentication Endpoint Tests Summary:")
print("Total: " .. test_runner.stats.total)
print("Passed: " .. test_runner.stats.passed)
print("Failed: " .. test_runner.stats.failed)

if test_runner.stats.failed > 0 then
  print()
  print("Failures:")
  for _, failure in ipairs(test_runner.stats.failures) do
    print("- " .. failure)
  end
else
  print()
  print("✅ All authentication middleware tests passed!")
  print("🛡️  Endpoints are properly protected with role-based access control")
end
