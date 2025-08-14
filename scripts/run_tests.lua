#!/usr/bin/env lua
-- run_tests.lua
-- Main test runner for Church Management System

local test_runner = require("src.tests.test_runner")

-- Test suites
local test_member = require("src.tests.test_member")
local test_event = require("src.tests.test_event")
local test_attendance = require("src.tests.test_attendance")
local test_donation = require("src.tests.test_donation")
local test_tithe = require("src.tests.test_tithe")
local test_volunteer = require("src.tests.test_volunteer")
local test_http_utils = require("src.tests.test_http_utils")
local test_validation = require("src.tests.test_validation")
local test_datetime = require("src.tests.test_datetime")
local test_controllers = require("src.tests.test_controllers")

-- Setup test environment
print("Setting up test environment...")
local cleanup = test_runner.setup_test_db()

-- Run all test suites
test_runner.run_suite("Member Model Tests", test_member)
test_runner.run_suite("Event Model Tests", test_event)
test_runner.run_suite("Attendance Model Tests", test_attendance)
test_runner.run_suite("Donation Model Tests", test_donation)
test_runner.run_suite("Tithe Model Tests", test_tithe)
test_runner.run_suite("Volunteer Model Tests", test_volunteer)
test_runner.run_suite("HTTP Utils Tests", test_http_utils)
test_runner.run_suite("Validation Tests", test_validation)
test_runner.run_suite("DateTime Tests", test_datetime)
test_runner.run_suite("Controller Tests", test_controllers)

-- Print final results
test_runner.print_results()

-- Cleanup
print("\nCleaning up test environment...")
cleanup()

-- Exit with appropriate code
if test_runner.stats and test_runner.stats.failed > 0 then
  os.exit(1)
else
  os.exit(0)
end
