-- src/utils/datetime.lua
-- Date and time utilities for Church Management System

local datetime = {}

-- Get current timestamp in SQLite format
function datetime.now()
  return os.date("%Y-%m-%d %H:%M:%S")
end

-- Get current date in SQLite format
function datetime.today()
  return os.date("%Y-%m-%d")
end

-- Format timestamp for display
function datetime.format_datetime(datetime_str, format)
  if not datetime_str then
    return ""
  end
  
  format = format or "%B %d, %Y at %I:%M %p"
  
  -- Parse SQLite datetime format
  local year, month, day, hour, min, sec = datetime_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  
  if not year then
    return datetime_str
  end
  
  local time = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })
  
  return os.date(format, time)
end

-- Format date for display
function datetime.format_date(date_str, format)
  if not date_str then
    return ""
  end
  
  format = format or "%B %d, %Y"
  
  -- Parse SQLite date format
  local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
  
  if not year then
    return date_str
  end
  
  local time = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = 12
  })
  
  return os.date(format, time)
end

-- Add days to a date
function datetime.add_days(date_str, days)
  if not date_str or not days then
    return date_str
  end
  
  local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
  
  if not year then
    return date_str
  end
  
  local time = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = 12
  })
  
  time = time + (days * 24 * 60 * 60)
  
  return os.date("%Y-%m-%d", time)
end

-- Get first day of month
function datetime.first_day_of_month(year, month)
  if not year or not month then
    local now = os.date("*t")
    year = year or now.year
    month = month or now.month
  end
  
  return string.format("%04d-%02d-01", year, month)
end

-- Get last day of month
function datetime.last_day_of_month(year, month)
  if not year or not month then
    local now = os.date("*t")
    year = year or now.year
    month = month or now.month
  end
  
  -- Get first day of next month, then subtract one day
  local next_month = month + 1
  local next_year = year
  
  if next_month > 12 then
    next_month = 1
    next_year = year + 1
  end
  
  local first_of_next = os.time({
    year = next_year,
    month = next_month,
    day = 1,
    hour = 12
  })
  
  local last_of_current = first_of_next - (24 * 60 * 60)
  
  return os.date("%Y-%m-%d", last_of_current)
end

-- Get start of week (Sunday)
function datetime.start_of_week(date_str)
  if not date_str then
    date_str = datetime.today()
  end
  
  local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
  
  if not year then
    return date_str
  end
  
  local time = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = 12
  })
  
  local wday = os.date("*t", time).wday
  
  -- wday: 1=Sunday, 2=Monday, etc.
  local days_to_subtract = wday - 1
  
  time = time - (days_to_subtract * 24 * 60 * 60)
  
  return os.date("%Y-%m-%d", time)
end

-- Get end of week (Saturday)
function datetime.end_of_week(date_str)
  local start = datetime.start_of_week(date_str)
  return datetime.add_days(start, 6)
end

-- Calculate age from birth date
function datetime.calculate_age(birth_date)
  if not birth_date then
    return nil
  end
  
  local birth_year, birth_month, birth_day = birth_date:match("(%d+)-(%d+)-(%d+)")
  
  if not birth_year then
    return nil
  end
  
  local now = os.date("*t")
  local age = now.year - tonumber(birth_year)
  
  -- Adjust if birthday hasn't occurred this year
  if now.month < tonumber(birth_month) or 
     (now.month == tonumber(birth_month) and now.day < tonumber(birth_day)) then
    age = age - 1
  end
  
  return age
end

-- Get days between two dates
function datetime.days_between(date1, date2)
  if not date1 or not date2 then
    return nil
  end
  
  local function parse_date(date_str)
    local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
    if not year then
      return nil
    end
    return os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = 12
    })
  end
  
  local time1 = parse_date(date1)
  local time2 = parse_date(date2)
  
  if not time1 or not time2 then
    return nil
  end
  
  local diff = math.abs(time2 - time1)
  return math.floor(diff / (24 * 60 * 60))
end

-- Check if date is in the past
function datetime.is_past(date_str)
  if not date_str then
    return false
  end
  
  local today = datetime.today()
  return date_str < today
end

-- Check if date is in the future
function datetime.is_future(date_str)
  if not date_str then
    return false
  end
  
  local today = datetime.today()
  return date_str > today
end

-- Get quarter from date
function datetime.get_quarter(date_str)
  if not date_str then
    return nil
  end
  
  local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
  
  if not month then
    return nil
  end
  
  month = tonumber(month)
  
  if month >= 1 and month <= 3 then
    return 1
  elseif month >= 4 and month <= 6 then
    return 2
  elseif month >= 7 and month <= 9 then
    return 3
  else
    return 4
  end
end

return datetime
