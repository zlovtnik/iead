-- src/utils/validation.lua
-- Validation utilities for Church Management System

local validation = {}

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
  
  local valid_statuses = {
    present = true,
    absent = true,
    excused = true
  }
  
  return valid_statuses[status:lower()] ~= nil
end

-- Validate payment method
function validation.is_valid_payment_method(method)
  if not method or type(method) ~= "string" then
    return true -- Payment method is optional
  end
  
  local valid_methods = {
    cash = true,
    check = true,
    card = true,
    online = true,
    bank_transfer = true
  }
  
  return valid_methods[method:lower()] ~= nil
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
    table.insert(errors, "Valid status (present, absent, excused) is required")
  end
  
  return #errors == 0, errors
end

-- Validate donation data
function validation.validate_donation_data(data)
  local errors = {}
  
  if not data.amount or not validation.is_positive_number(data.amount) then
    table.insert(errors, "Valid positive amount is required")
  end
  
  if not data.donation_date or not validation.is_valid_date(data.donation_date) then
    table.insert(errors, "Valid donation date is required")
  end
  
  if data.member_id and not validation.is_positive_number(data.member_id) then
    table.insert(errors, "Member ID must be a positive number")
  end
  
  if data.payment_method and not validation.is_valid_payment_method(data.payment_method) then
    table.insert(errors, "Invalid payment method")
  end
  
  return #errors == 0, errors
end

return validation
