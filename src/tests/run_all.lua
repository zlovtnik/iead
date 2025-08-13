-- src/tests/run_all.lua
-- Test runner that executes all test suites

local test_runner = require("src.tests.test_runner")

-- Import all test modules
local member_tests = require("src.tests.test_member")
local user_tests = require("src.tests.test_user")
local security_tests = require("src.tests.test_security")

-- Setup test database
local cleanup = test_runner.setup_test_db()

print("Running all tests...")

-- Run all test suites
test_runner.run_suite("Member Model Tests", member_tests)
test_runner.run_suite("User Model Tests", user_tests)
test_runner.run_suite("Security Utils Tests", security_tests)

-- Print final results
test_runner.print_results()

-- Cleanup
cleanup()

print("\nAll tests completed!")