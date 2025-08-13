-- src/tests/test_datetime.lua
-- Tests for datetime utilities

local test_runner = require("src.tests.test_runner")
local datetime = require("src.utils.datetime")

local tests = {}

function tests.test_now()
  local now = datetime.now()
  test_runner.assert_type(now, "string", "now() should return a string")
  test_runner.assert_true(now:match("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") ~= nil, "Should match datetime format")
end

function tests.test_today()
  local today = datetime.today()
  test_runner.assert_type(today, "string", "today() should return a string")
  test_runner.assert_true(today:match("%d%d%d%d%-%d%d%-%d%d") ~= nil, "Should match date format")
end

function tests.test_format_date()
  local formatted = datetime.format_date("2024-01-15")
  test_runner.assert_type(formatted, "string", "format_date should return a string")
  test_runner.assert_true(#formatted > 0, "Formatted date should not be empty")
end

function tests.test_format_datetime()
  local formatted = datetime.format_datetime("2024-01-15 14:30:00")
  test_runner.assert_type(formatted, "string", "format_datetime should return a string")
  test_runner.assert_true(#formatted > 0, "Formatted datetime should not be empty")
end

function tests.test_add_days()
  local result = datetime.add_days("2024-01-15", 7)
  test_runner.assert_equal(result, "2024-01-22", "Adding 7 days should work correctly")
  
  local result2 = datetime.add_days("2024-01-31", 1)
  test_runner.assert_equal(result2, "2024-02-01", "Adding days across month boundary should work")
end

function tests.test_first_day_of_month()
  local first_day = datetime.first_day_of_month(2024, 1)
  test_runner.assert_equal(first_day, "2024-01-01", "First day of January 2024 should be correct")
  
  local first_day2 = datetime.first_day_of_month(2024, 12)
  test_runner.assert_equal(first_day2, "2024-12-01", "First day of December 2024 should be correct")
end

function tests.test_last_day_of_month()
  local last_day = datetime.last_day_of_month(2024, 1)
  test_runner.assert_equal(last_day, "2024-01-31", "Last day of January 2024 should be correct")
  
  local last_day2 = datetime.last_day_of_month(2024, 2)
  test_runner.assert_equal(last_day2, "2024-02-29", "Last day of February 2024 (leap year) should be correct")
end

function tests.test_start_of_week()
  local start = datetime.start_of_week("2024-01-15") -- Monday
  test_runner.assert_type(start, "string", "start_of_week should return a string")
  test_runner.assert_true(start:match("%d%d%d%d%-%d%d%-%d%d") ~= nil, "Should match date format")
end

function tests.test_end_of_week()
  local end_week = datetime.end_of_week("2024-01-15")
  test_runner.assert_type(end_week, "string", "end_of_week should return a string")
  test_runner.assert_true(end_week:match("%d%d%d%d%-%d%d%-%d%d") ~= nil, "Should match date format")
end

function tests.test_days_between()
  local days = datetime.days_between("2024-01-01", "2024-01-08")
  test_runner.assert_equal(days, 7, "Days between should calculate correctly")
  
  local days2 = datetime.days_between("2024-01-08", "2024-01-01")
  test_runner.assert_equal(days2, 7, "Days between should work in reverse order")
end

function tests.test_is_past()
  local past_result = datetime.is_past("2020-01-01")
  test_runner.assert_true(past_result, "Date in 2020 should be in the past")
  
  local future_result = datetime.is_past("2030-01-01")
  test_runner.assert_false(future_result, "Date in 2030 should not be in the past")
end

function tests.test_is_future()
  local future_result = datetime.is_future("2030-01-01")
  test_runner.assert_true(future_result, "Date in 2030 should be in the future")
  
  local past_result = datetime.is_future("2020-01-01")
  test_runner.assert_false(past_result, "Date in 2020 should not be in the future")
end

function tests.test_get_quarter()
  test_runner.assert_equal(datetime.get_quarter("2024-01-15"), 1, "January should be Q1")
  test_runner.assert_equal(datetime.get_quarter("2024-04-15"), 2, "April should be Q2")
  test_runner.assert_equal(datetime.get_quarter("2024-07-15"), 3, "July should be Q3")
  test_runner.assert_equal(datetime.get_quarter("2024-10-15"), 4, "October should be Q4")
end

function tests.test_calculate_age()
  -- Mock a birth date that would make someone 25 years old
  local birth_year = os.date("%Y") - 25
  local birth_date = birth_year .. "-01-01"
  
  local age = datetime.calculate_age(birth_date)
  test_runner.assert_true(age >= 24 and age <= 26, "Age calculation should be approximately correct")
end

return tests
