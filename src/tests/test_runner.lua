-- src/tests/test_runner.lua
-- Simple test runner for Church Management System

local test_runner = {}

-- Test statistics (accessible from outside)
test_runner.stats = {
  passed = 0,
  failed = 0,
  total = 0,
  failures = {}
}

-- Colors for output
local colors = {
  green = "\27[32m",
  red = "\27[31m",
  yellow = "\27[33m",
  blue = "\27[34m",
  reset = "\27[0m"
}

-- Assert functions
function test_runner.assert_equal(actual, expected, message)
  if actual == expected then
    return true
  else
    error(string.format("%s: expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

function test_runner.assert_not_nil(value, message)
  if value ~= nil then
    return true
  else
    error(message or "Expected value to not be nil")
  end
end

function test_runner.assert_nil(value, message)
  if value == nil then
    return true
  else
    error(string.format("%s: expected nil, got %s", message or "Assertion failed", tostring(value)))
  end
end

function test_runner.assert_true(value, message)
  if value == true then
    return true
  else
    error(message or "Expected true")
  end
end

function test_runner.assert_false(value, message)
  if value == false then
    return true
  else
    error(message or "Expected false")
  end
end

function test_runner.assert_type(value, expected_type, message)
  if type(value) == expected_type then
    return true
  else
    error(string.format("%s: expected %s, got %s", message or "Type assertion failed", expected_type, type(value)))
  end
end

-- Run a single test
function test_runner.run_test(name, test_func)
  test_runner.stats.total = test_runner.stats.total + 1
  
  local success, err = pcall(test_func)
  
  if success then
    test_runner.stats.passed = test_runner.stats.passed + 1
    print(colors.green .. "✓ " .. name .. colors.reset)
  else
    test_runner.stats.failed = test_runner.stats.failed + 1
    table.insert(test_runner.stats.failures, {name = name, error = err})
    print(colors.red .. "✗ " .. name .. colors.reset)
    print(colors.red .. "  " .. err .. colors.reset)
  end
end

-- Run a test suite
function test_runner.run_suite(suite_name, tests)
  print(colors.blue .. "\n=== " .. suite_name .. " ===" .. colors.reset)
  
  for name, test_func in pairs(tests) do
    test_runner.run_test(name, test_func)
  end
end

-- Print final results
function test_runner.print_results()
  print(colors.blue .. "\n=== Test Results ===" .. colors.reset)
  print(string.format("Total: %d", test_runner.stats.total))
  print(colors.green .. string.format("Passed: %d", test_runner.stats.passed) .. colors.reset)
  
  if test_runner.stats.failed > 0 then
    print(colors.red .. string.format("Failed: %d", test_runner.stats.failed) .. colors.reset)
    print(colors.yellow .. "\nFailures:" .. colors.reset)
    for _, failure in ipairs(test_runner.stats.failures) do
      print(colors.red .. "- " .. failure.name .. ": " .. failure.error .. colors.reset)
    end
  end
  
  print(string.format("\nSuccess rate: %.1f%%", (test_runner.stats.passed / test_runner.stats.total) * 100))
end

-- Setup test database
function test_runner.setup_test_db()
  local db_config = require("src.config.database")
  local original_db = db_config.db_file
  
  -- Use test database
  db_config.db_file = "test_church_management.db"
  
  -- Initialize schema
  local schema = require("src.db.schema")
  schema.init()
  
  return function()
    -- Cleanup function
    db_config.db_file = original_db
    os.remove("test_church_management.db")
  end
end

-- Clear test database
function test_runner.clear_test_db()
  local luasql = require("luasql.sqlite3")
  local db_config = require("src.config.database")
  
  local env = luasql.sqlite3()
  local conn = env:connect(db_config.db_file)
  
  -- Clear all tables (order matters due to foreign key constraints)
  conn:execute("DELETE FROM attendance")
  conn:execute("DELETE FROM donations")
  conn:execute("DELETE FROM volunteers")
  conn:execute("DELETE FROM tithes")
  conn:execute("DELETE FROM users")  -- Clear users before members due to foreign key
  conn:execute("DELETE FROM events")
  conn:execute("DELETE FROM members")
  
  conn:close()
  env:close()
end

return test_runner
