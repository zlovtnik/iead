-- src/tests/test_validation.lua
-- Tests for validation utilities

local test_runner = require("src.tests.test_runner")
local validation = require("src.utils.validation")

local tests = {}

function tests.test_is_valid_email()
  test_runner.assert_true(validation.is_valid_email("test@example.com"), "Valid email should pass")
  test_runner.assert_true(validation.is_valid_email("user.name+tag@domain.co.uk"), "Complex valid email should pass")
  test_runner.assert_false(validation.is_valid_email("invalid-email"), "Invalid email should fail")
  test_runner.assert_false(validation.is_valid_email("@example.com"), "Email without username should fail")
  test_runner.assert_false(validation.is_valid_email("test@"), "Email without domain should fail")
  test_runner.assert_false(validation.is_valid_email(nil), "Nil email should fail")
end

function tests.test_is_valid_phone()
  test_runner.assert_true(validation.is_valid_phone("1234567890"), "10 digit phone should pass")
  test_runner.assert_true(validation.is_valid_phone("(123) 456-7890"), "Formatted phone should pass")
  test_runner.assert_true(validation.is_valid_phone("123-456-7890"), "Dashed phone should pass")
  test_runner.assert_false(validation.is_valid_phone("123456789"), "9 digit phone should fail")
  test_runner.assert_false(validation.is_valid_phone("12345678901"), "11 digit phone should fail")
  test_runner.assert_true(validation.is_valid_phone(nil), "Nil phone should pass (optional)")
end

function tests.test_is_valid_date()
  test_runner.assert_true(validation.is_valid_date("2024-01-15"), "Valid date should pass")
  test_runner.assert_true(validation.is_valid_date("2024-02-29"), "Leap year date should pass")
  test_runner.assert_false(validation.is_valid_date("2023-02-29"), "Non-leap year Feb 29 should fail")
  test_runner.assert_false(validation.is_valid_date("2024-13-01"), "Invalid month should fail")
  test_runner.assert_false(validation.is_valid_date("2024-01-32"), "Invalid day should fail")
  test_runner.assert_false(validation.is_valid_date("24-01-15"), "Wrong year format should fail")
  test_runner.assert_false(validation.is_valid_date("invalid"), "Non-date string should fail")
end

function tests.test_is_valid_datetime()
  test_runner.assert_true(validation.is_valid_datetime("2024-01-15 14:30:00"), "Valid datetime should pass")
  test_runner.assert_true(validation.is_valid_datetime("2024-12-31 23:59:59"), "End of year datetime should pass")
  test_runner.assert_false(validation.is_valid_datetime("2024-01-15 25:00:00"), "Invalid hour should fail")
  test_runner.assert_false(validation.is_valid_datetime("2024-01-15 14:60:00"), "Invalid minute should fail")
  test_runner.assert_false(validation.is_valid_datetime("2024-01-15 14:30:60"), "Invalid second should fail")
  test_runner.assert_false(validation.is_valid_datetime("2024-01-15"), "Date without time should fail")
end

function tests.test_is_positive_number()
  test_runner.assert_true(validation.is_positive_number("123"), "Positive number string should pass")
  test_runner.assert_true(validation.is_positive_number(123), "Positive number should pass")
  test_runner.assert_true(validation.is_positive_number("123.45"), "Positive decimal should pass")
  test_runner.assert_false(validation.is_positive_number("0"), "Zero should fail")
  test_runner.assert_false(validation.is_positive_number("-123"), "Negative number should fail")
  test_runner.assert_false(validation.is_positive_number("abc"), "Non-number should fail")
end

function tests.test_is_positive_integer()
  -- Valid positive integers
  test_runner.assert_true(validation.is_positive_integer("123"), "Positive integer string should pass")
  test_runner.assert_true(validation.is_positive_integer(123), "Positive integer number should pass")
  test_runner.assert_true(validation.is_positive_integer("1"), "Single digit string should pass")
  test_runner.assert_true(validation.is_positive_integer(1), "Single digit number should pass")
  
  -- Invalid: floats and decimals
  test_runner.assert_false(validation.is_positive_integer("123.45"), "Decimal string should fail")
  test_runner.assert_false(validation.is_positive_integer(123.45), "Decimal number should fail")
  test_runner.assert_false(validation.is_positive_integer("123.0"), "Decimal with zero fraction should fail")
  test_runner.assert_false(validation.is_positive_integer(123.0), "Number with zero fraction should fail")
  
  -- Invalid: scientific notation
  test_runner.assert_false(validation.is_positive_integer("1e2"), "Scientific notation should fail")
  test_runner.assert_false(validation.is_positive_integer("1E2"), "Uppercase scientific notation should fail")
  test_runner.assert_false(validation.is_positive_integer("1.23e2"), "Decimal scientific notation should fail")
  
  -- Invalid: zero and negatives
  test_runner.assert_false(validation.is_positive_integer("0"), "Zero string should fail")
  test_runner.assert_false(validation.is_positive_integer(0), "Zero number should fail")
  test_runner.assert_false(validation.is_positive_integer("-123"), "Negative string should fail")
  test_runner.assert_false(validation.is_positive_integer(-123), "Negative number should fail")
  
  -- Invalid: non-numeric
  test_runner.assert_false(validation.is_positive_integer("abc"), "Non-numeric string should fail")
  test_runner.assert_false(validation.is_positive_integer(""), "Empty string should fail")
  test_runner.assert_false(validation.is_positive_integer(nil), "Nil should fail")
  
  -- Invalid: strings with extra characters
  test_runner.assert_false(validation.is_positive_integer("123abc"), "String with trailing characters should fail")
  test_runner.assert_false(validation.is_positive_integer("abc123"), "String with leading characters should fail")
  test_runner.assert_false(validation.is_positive_integer(" 123 "), "String with whitespace should fail")
  test_runner.assert_false(validation.is_positive_integer("+123"), "String with plus sign should fail")
end

function tests.test_is_valid_attendance_status()
  test_runner.assert_true(validation.is_valid_attendance_status("present"), "Present status should pass")
  test_runner.assert_true(validation.is_valid_attendance_status("absent"), "Absent status should pass")
  test_runner.assert_true(validation.is_valid_attendance_status("excused"), "Excused status should pass")
  test_runner.assert_true(validation.is_valid_attendance_status("PRESENT"), "Uppercase status should pass")
  test_runner.assert_false(validation.is_valid_attendance_status("late"), "Invalid status should fail")
  test_runner.assert_false(validation.is_valid_attendance_status(""), "Empty status should fail")
end

function tests.test_validate_member_data()
  local valid_data = {
    name = "John Doe",
    email = "john@example.com",
    phone = "1234567890",
    salary = 50000
  }
  
  local is_valid, errors = validation.validate_member_data(valid_data)
  test_runner.assert_true(is_valid, "Valid member data should pass")
  test_runner.assert_equal(#errors, 0, "Should have no errors")
  
  local invalid_data = {
    name = "",
    email = "invalid-email",
    phone = "123",
    salary = -1000
  }
  
  local is_valid2, errors2 = validation.validate_member_data(invalid_data)
  test_runner.assert_false(is_valid2, "Invalid member data should fail")
  test_runner.assert_true(#errors2 > 0, "Should have errors")
end

function tests.test_validate_event_data()
  local valid_data = {
    title = "Sunday Service",
    start_date = "2024-01-07 10:00:00",
    end_date = "2024-01-07 12:00:00",
    location = "Main Sanctuary"
  }
  
  local is_valid, errors = validation.validate_event_data(valid_data)
  test_runner.assert_true(is_valid, "Valid event data should pass")
  test_runner.assert_equal(#errors, 0, "Should have no errors")
  
  local invalid_data = {
    title = "",
    start_date = "invalid-date"
  }
  
  local is_valid2, errors2 = validation.validate_event_data(invalid_data)
  test_runner.assert_false(is_valid2, "Invalid event data should fail")
  test_runner.assert_true(#errors2 > 0, "Should have errors")
end

function tests.test_sanitize_string()
  test_runner.assert_equal(validation.sanitize_string("test"), "test", "Normal string should be unchanged")
  test_runner.assert_equal(validation.sanitize_string("O'Connor"), "O''Connor", "Single quote should be escaped")
  test_runner.assert_equal(validation.sanitize_string("It's a 'test'"), "It''s a ''test''", "Multiple quotes should be escaped")
  test_runner.assert_equal(validation.sanitize_string(nil), "", "Nil should return empty string")
end

return tests
