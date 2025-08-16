-- src/utils/validation.lua
-- Validation utilities for Church Management System

local fun = require("src.utils.functional")

local validation = {}

-- Normalize boolean values from various formats (string, number, boolean)
-- @param value any The value to normalize
-- @return boolean The normalized boolean value
function validation.normalize_boolean(value)
    -- Handle nil
    if value == nil then
        return false
    end
    
    -- Handle string values
    if type(value) == "string" then
        return value:lower() == "true" or value == "1"
    end
    
    -- Handle numbers (0 = false, non-zero = true)
    if type(value) == "number" then
        return value ~= 0
    end
    
    -- Handle booleans directly
    return value == true
end

-- Validate email format
function validation.is_valid_email(email)
  if not email or type(email) ~= "string" then
    return false
  end
  
  -- Basic email validation pattern
  local pattern = "^[%w%._%+%-]+@[%w%._%+%-]+%.%w+$"
  return email:match(pattern) ~= nil
end

-- Validate phone number
function validation.is_valid_phone(phone)
  if not phone or type(phone) ~= "string" then
    return true -- Phone is optional
  end
  
  -- Remove all non-digits
  local digits = phone:gsub("%D", "")
  
  -- Must be 10 digits
  return #digits == 10
end

-- Validate date format (YYYY-MM-DD)
function validation.is_valid_date(date)
  if not date or type(date) ~= "string" then
    return false
  end
  
  local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not year then
    return false
  end
  
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  
  if month < 1 or month > 12 then
    return false
  end
  
  if day < 1 or day > 31 then
    return false
  end
  
  -- Additional validation for specific months
  if month == 2 then
    -- February
    local is_leap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
    if day > (is_leap and 29 or 28) then
      return false
    end
  elseif month == 4 or month == 6 or month == 9 or month == 11 then
    -- April, June, September, November have 30 days
    if day > 30 then
      return false
    end
  end
  
  return true
end

-- Validate datetime format (YYYY-MM-DD HH:MM:SS)
function validation.is_valid_datetime(datetime)
  if not datetime or type(datetime) ~= "string" then
    return false
  end
  
  local date_part, time_part = datetime:match("^(.+) (.+)$")
  if not date_part or not time_part then
    return false
  end
  
  if not validation.is_valid_date(date_part) then
    return false
  end
  
  local hour, minute, second = time_part:match("^(%d%d):(%d%d):(%d%d)$")
  if not hour then
    return false
  end
  
  hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
  
  if hour < 0 or hour > 23 then
    return false
  end
  
  if minute < 0 or minute > 59 then
    return false
  end
  
  if second < 0 or second > 59 then
    return false
  end
  
  return true
end

-- Validate positive number
function validation.is_positive_number(value)
  local num = tonumber(value)
  return num ~= nil and num > 0
end

-- Validate positive integer only (no floats, no scientific notation)
function validation.is_positive_integer(value)
  -- Handle string input - must match regex for positive integers only
  if type(value) == "string" then
    -- Check if string matches pattern for positive integers (no decimals, no scientific notation)
    if not value:match("^%d+$") then
      return false
    end
    local num = tonumber(value)
    return num ~= nil and num > 0
  end
  
  -- Handle number input - must be positive and equal to its floor (integer)
  if type(value) == "number" then
    return value > 0 and value == math.floor(value)
  end
  
  return false
end

-- Validate non-negative number
function validation.is_non_negative_number(value)
  local num = tonumber(value)
  return num ~= nil and num >= 0
end

-- Validate attendance status
function validation.is_valid_attendance_status(status)
  if not status or type(status) ~= "string" then
    return false
  end
  
  local valid_statuses = {"present", "absent", "excused"}
  return fun.any_match(function(s) return s == status:lower() end, valid_statuses)
end

-- Validate payment method
function validation.is_valid_payment_method(method)
  if not method or type(method) ~= "string" then
    return true -- Payment method is optional
  end
  
  local valid_methods = {"cash", "check", "card", "online", "bank_transfer"}
  return fun.any_match(function(m) return m == method:lower() end, valid_methods)
end

-- Sanitize string for SQL
function validation.sanitize_string(str)
  if not str or type(str) ~= "string" then
    return ""
  end
  
  return str:gsub("'", "''")
end

-- Validate member data
function validation.validate_member_data(data)
  local errors = {}
  
  if not data.name or data.name == "" then
    table.insert(errors, "Name is required")
  end
  
  if not data.email or data.email == "" then
    table.insert(errors, "Email is required")
  elseif not validation.is_valid_email(data.email) then
    table.insert(errors, "Invalid email format")
  end
  
  if data.phone and not validation.is_valid_phone(data.phone) then
    table.insert(errors, "Invalid phone number format")
  end
  
  if data.salary and not validation.is_non_negative_number(data.salary) then
    table.insert(errors, "Salary must be a non-negative number")
  end
  
  return #errors == 0, errors
end

-- Validate event data
function validation.validate_event_data(data)
  local errors = {}
  
  if not data.title or data.title == "" then
    table.insert(errors, "Title is required")
  end
  
  if not data.start_date or data.start_date == "" then
    table.insert(errors, "Start date is required")
  elseif not validation.is_valid_datetime(data.start_date) then
    table.insert(errors, "Invalid start date format")
  end
  
  if data.end_date and data.end_date ~= "" and not validation.is_valid_datetime(data.end_date) then
    table.insert(errors, "Invalid end date format")
  end
  
  return #errors == 0, errors
end

-- Validate attendance data
function validation.validate_attendance_data(data)
  local errors = {}
  
  if not data.event_id or not validation.is_positive_number(data.event_id) then
    table.insert(errors, "Valid event ID is required")
  end
  
  if not data.member_id or not validation.is_positive_number(data.member_id) then
    table.insert(errors, "Valid member ID is required")
  end
  
  if not data.status or not validation.is_valid_attendance_status(data.status) then
-- Validate member data using functional approach
function validation.validate_member_data(data)
  if not data then
    return false, {"Member data is required"}
  end
  
  local validation_rules = {
    {field = "first_name", required = true, validator = validation.is_non_empty_string, message = "First name is required"},
    {field = "last_name", required = true, validator = validation.is_non_empty_string, message = "Last name is required"},
    {field = "email", required = true, validator = validation.is_valid_email, message = "Valid email is required"},
    {field = "phone", required = false, validator = validation.is_valid_phone, message = "Invalid phone format"},
    {field = "date_of_birth", required = false, validator = function(v) return not v or v == "" or validation.is_valid_date(v) end, message = "Invalid date format"},
    {field = "membership_date", required = false, validator = function(v) return not v or v == "" or validation.is_valid_date(v) end, message = "Invalid date format"}
  }
  
  local errors = fun.filter_table(function(rule)
    local value = data[rule.field]
    return not rule.validator(value)
  end, validation_rules)
  
  local error_messages = fun.pluck("message", errors)
  
  return #error_messages == 0, error_messages
end

-- Validate event data using functional approach  
function validation.validate_event_data(data)
  if not data then
    return false, {"Event data is required"}
  end
  
  local validation_rules = {
    {field = "title", validator = validation.is_non_empty_string, message = "Event title is required"},
    {field = "start_date", validator = validation.is_valid_datetime, message = "Valid start date is required"},
    {field = "location", validator = function(v) return not v or validation.is_non_empty_string(v) end, message = "Location must be non-empty if provided"}
  }
  
  local errors = fun.filter_table(function(rule)
    return not rule.validator(data[rule.field])
  end, validation_rules)
  
  return #errors == 0, fun.pluck("message", errors)
end

-- Validate attendance data using functional approach
function validation.validate_attendance_data(data)
  if not data then
    return false, {"Attendance data is required"}
  end
  
  local validation_rules = {
    {field = "member_id", validator = validation.is_positive_number, message = "Valid member ID is required"},
    {field = "event_id", validator = validation.is_positive_number, message = "Valid event ID is required"},
    {field = "status", validator = validation.is_valid_attendance_status, message = "Valid status (present, absent, excused) is required"}
  }
  
  local errors = fun.filter_table(function(rule)
    return not rule.validator(data[rule.field])
  end, validation_rules)
  
  return #errors == 0, fun.pluck("message", errors)
end

-- Validate donation data using functional approach
function validation.validate_donation_data(data)
  if not data then
    return false, {"Donation data is required"}
  end
  
  local validation_rules = {
    {field = "amount", validator = validation.is_positive_number, message = "Valid positive amount is required"},
    {field = "donation_date", validator = validation.is_valid_date, message = "Valid donation date is required"},
    {field = "member_id", validator = function(v) return not v or validation.is_positive_number(v) end, message = "Member ID must be a positive number"},
    {field = "payment_method", validator = function(v) return not v or validation.is_valid_payment_method(v) end, message = "Invalid payment method"}
  }
  
  local errors = fun.filter_table(function(rule)
    return not rule.validator(data[rule.field])
  end, validation_rules)
  
  return #errors == 0, fun.pluck("message", errors)
end

-- Batch validate multiple records using functional approach
-- @param records table Array of records to validate
-- @param validator_func function Validation function to apply
-- @return table Valid records
-- @return table Invalid records with errors
function validation.batch_validate(records, validator_func)
  if not records or #records == 0 then
    return {}, {}
  end
  
  local validation_results = fun.map_table(function(record)
    local is_valid, errors = validator_func(record)
    return {
      record = record,
      is_valid = is_valid,
      errors = errors or {}
    }
  end, records)
  
  local valid_records, invalid_records = fun.partition_table(function(result)
    return result.is_valid
  end, validation_results)
  
  return fun.pluck("record", valid_records), invalid_records
end

-- Sanitize a table of data using functional approach
-- @param data table Data to sanitize
-- @param sanitize_rules table Rules for sanitization
-- @return table Sanitized data
function validation.sanitize_data(data, sanitize_rules)
  if not data or not sanitize_rules then
    return data
  end
  
  local sanitized = {}
  fun.from_pairs(data):each(function(key, value)
    local sanitizer = sanitize_rules[key]
    if sanitizer and type(sanitizer) == "function" then
      sanitized[key] = sanitizer(value)
    else
      sanitized[key] = value
    end
  end)
  
  return sanitized
end

return validation
