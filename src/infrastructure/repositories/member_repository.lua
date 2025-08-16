-- src/infrastructure/repositories/member_repository.lua
-- Member repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")
local fun = require("src.utils.functional")
local DataProcessor = require("src.infrastructure.utils.data_processor")

-- Private helper function to calculate age from date of birth
-- @param date_of_birth string in YYYY-MM-DD format
-- @return number|nil age in years, or nil if invalid/missing
local function calculate_age_from_birth_date(date_of_birth)
  if not date_of_birth or date_of_birth == "" then
    return nil
  end
  
  -- Parse year, month, day from date_of_birth (expecting YYYY-MM-DD format)
  local birth_year, birth_month, birth_day = date_of_birth:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
  if not birth_year or not birth_month or not birth_day then
    return nil
  end
  
  -- Convert to numbers
  birth_year = tonumber(birth_year)
  birth_month = tonumber(birth_month)
  birth_day = tonumber(birth_day)
  
  -- Validate date components
  if not birth_year or not birth_month or not birth_day or
     birth_month < 1 or birth_month > 12 or
     birth_day < 1 or birth_day > 31 then
    return nil
  end
  
  -- Get current date using os.date("*t") for precise date components
  local current_date = os.date("*t")
  local current_year = current_date.year
  local current_month = current_date.month
  local current_day = current_date.day
  
  -- Calculate age
  local age = current_year - birth_year
  
  -- Subtract 1 if birthday hasn't occurred yet this year
  if current_month < birth_month or 
     (current_month == birth_month and current_day < birth_day) then
    age = age - 1
  end
  
  -- Return nil for negative ages (future birth dates)
  return age >= 0 and age or nil
end

-- Private helper function to validate and normalize sort field
-- @param sort_by string|nil the sort field to validate
-- @return string|nil validated and normalized sort field, or nil if invalid
local function validate_sort_field(sort_by)
  if not sort_by or type(sort_by) ~= "string" then
    return nil
  end
  
  -- Normalize: trim whitespace and convert to lowercase
  local normalized = sort_by:match("^%s*(.-)%s*$"):lower()
  
  if normalized == "" then
    return nil
  end
  
  -- Check against allowlist
  if ALLOWED_MEMBER_SORT_FIELDS[normalized] then
    return normalized
  end
  
  -- Log warning for invalid sort field (you can replace this with actual logging)
  -- For now, we'll just silently ignore invalid fields
  return nil
end

-- Allowed fields for member filtering conditions (using functional approach)
local ALLOWED_MEMBER_FILTER_FIELDS = {}
local allowed_fields = {
  "first_name", "last_name", "email", "phone", "address", 
  "date_of_birth", "membership_date", "is_active"
}
for _, field in ipairs(allowed_fields) do
  ALLOWED_MEMBER_FILTER_FIELDS[field] = true
end

-- Allowed fields for member sorting (includes base fields and member-specific fields)
local ALLOWED_MEMBER_SORT_FIELDS = {}
local allowed_sort_fields = {
  -- Base repository fields
  "id", "created_at", "updated_at",
  -- Member-specific fields
  "first_name", "last_name", "email", "phone", "address", 
  "date_of_birth", "membership_date", "is_active",
  -- Computed fields (available in enhanced members)
  "full_name", "age", "membership_years"
}
for _, field in ipairs(allowed_sort_fields) do
  ALLOWED_MEMBER_SORT_FIELDS[field] = true
end

local MemberRepository = {}
MemberRepository.__index = MemberRepository

-- Create a new MemberRepository instance
function MemberRepository.new()
  local schema = {
    first_name = {
      type = "string",
      required = true,
      max_length = 100
    },
    last_name = {
      type = "string",
      required = true,
      max_length = 100
    },
    email = {
      type = "string",
      required = true,
      max_length = 255
    },
    phone = {
      type = "string",
      required = false,
      max_length = 20
    },
    address = {
      type = "string",
      required = false
    },
    date_of_birth = {
      type = "string",  -- SQLite stores dates as strings
      required = false
    },
    membership_date = {
      type = "string",
      required = false
    },
    is_active = {
      type = "number",
      required = false
    }
  }
  
  local base_repo = BaseRepository.new("members", schema)
  local instance = {
    base = base_repo
  }
  setmetatable(instance, MemberRepository)
  return instance
end

-- Delegate to base repository methods
function MemberRepository:find_all(options)
  return self.base:find_all(options)
end

function MemberRepository:find_one(conditions)
  return self.base:find_one(conditions)
end

function MemberRepository:find_by_id(id)
  return self.base:find_by_id(id)
end

function MemberRepository:update_by_id(id, data)
  return self.base:update_by_id(id, data)
end

function MemberRepository:delete_by_id(id)
  return self.base:delete_by_id(id)
end

function MemberRepository:count(conditions)
  return self.base:count(conditions)
end

function MemberRepository:exists(conditions)
  return self.base:exists(conditions)
end

function MemberRepository:paginate(options)
  return self.base:paginate(options)
end

-- Custom create method with default values
function MemberRepository:create(data)
  -- Set default values
  if data.is_active == nil then
    data.is_active = 1  -- Default to active
  end
  
  if data.membership_date == nil then
    data.membership_date = os.date("!%Y-%m-%d")  -- Default to today
  end
  
  return self.base:create(data)
end

-- Custom update method (delegates to base)
function MemberRepository:update(conditions, data)
  return self.base:update(conditions, data)
end

-- Find member by email
function MemberRepository:find_by_email(email)
  return self:find_one({email = email})
end

-- Find active members
function MemberRepository:find_active_members(options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.is_active = 1
  return self:find_all(options)
end

-- Search members by name or email
function MemberRepository:search(query, options)
  options = options or {}
  
  -- Normalize query to prevent nil concatenation
  local q = query or ""
  local pattern = "%" .. q .. "%"
  
  -- Create a custom query for OR conditions (searching name OR email)
  local search_query = [[
    SELECT * FROM members 
    WHERE (first_name LIKE ? OR last_name LIKE ? OR email LIKE ?)
  ]]
  
  -- Add additional conditions if provided
  local params = {pattern, pattern, pattern}
  
  if options.conditions then
    local where_parts = {}
    for field, value in pairs(options.conditions) do
      if not ALLOWED_MEMBER_FILTER_FIELDS[field] then
        return nil, "Invalid condition field: " .. field
      end
      table.insert(where_parts, field .. " = ?")
      table.insert(params, value)
    end
    
    if #where_parts > 0 then
      search_query = search_query .. " AND " .. table.concat(where_parts, " AND ")
    end
  end
  
  -- Add ordering with validation
  if options.order_by then
    local allowed_order_fields = {
      ["first_name"] = true,
      ["last_name"] = true,
      ["email"] = true,
      ["phone"] = true,
      ["address"] = true,
      ["date_of_birth"] = true,
      ["membership_date"] = true,
      ["is_active"] = true
    }
    
    if not allowed_order_fields[options.order_by] then
      return nil, "Invalid order field: " .. options.order_by
    end
    
    local direction = "ASC"
    if options.order_direction then
      local upper_dir = string.upper(options.order_direction)
      if upper_dir == "ASC" or upper_dir == "DESC" then
        direction = upper_dir
      end
    end
    search_query = search_query .. " ORDER BY " .. options.order_by .. " " .. direction
  end
  
  -- Add pagination
  if options.limit then
    search_query = search_query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset then
      search_query = search_query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return self.base:execute_query(search_query, params)
end

-- Count search results for members by name or email (for pagination)
function MemberRepository:count_search(query, options)
  options = options or {}
  
  -- Normalize query to prevent nil concatenation
  local q = query or ""
  local pattern = "%" .. q .. "%"
  
  -- Create a custom count query for OR conditions (searching name OR email)
  local count_query = [[
    SELECT COUNT(*) as count FROM members 
    WHERE (first_name LIKE ? OR last_name LIKE ? OR email LIKE ?)
  ]]
  
  -- Add additional conditions if provided
  local params = {pattern, pattern, pattern}
  
  if options.conditions then
    local where_parts = {}
    for field, value in pairs(options.conditions) do
      if ALLOWED_MEMBER_FILTER_FIELDS[field] then
        table.insert(where_parts, field .. " = ?")
        table.insert(params, value)
      end
    end
    
    if #where_parts > 0 then
      count_query = count_query .. " AND " .. table.concat(where_parts, " AND ")
    end
  end
  
  local result, err = self.base:execute_query_one(count_query, params)
  if not result then
    return nil, err
  end
  
  return tonumber(result.count)
end

-- Get members by birth month (for birthday reminders)
function MemberRepository:find_by_birth_month(month, options)
  options = options or {}
  
  -- Define allowed column names mapping to safe SQL expressions
  local allowed = {
    ["first_name"] = "first_name",
    ["last_name"] = "last_name", 
    ["date_of_birth"] = "date_of_birth",
    ["birth_month"] = "strftime('%m',date_of_birth)"
  }
  
  local query = "SELECT * FROM members WHERE strftime('%m', date_of_birth) = ?"
  local params = {string.format("%02d", month)}
  
  -- Add additional conditions (only for allowed columns)
  if options.conditions then
    for field, value in pairs(options.conditions) do
      if allowed[field] then
        query = query .. " AND " .. allowed[field] .. " = ?"
        table.insert(params, value)
      end
    end
  end
  
  -- Add ordering with validation
  if options.order_by and allowed[options.order_by] then
    local direction = "ASC"
    if options.order_direction then
      local lower_dir = string.lower(options.order_direction)
      if lower_dir == "asc" or lower_dir == "desc" then
        direction = string.upper(lower_dir)
      end
    end
    query = query .. " ORDER BY " .. allowed[options.order_by] .. " " .. direction
  else
    -- Default order by birth date (safe expression)
    query = query .. " ORDER BY strftime('%d', date_of_birth)"
  end
  
  return self.base:execute_query(query, params)
end

-- Get membership statistics
function MemberRepository:get_stats()
  local total_members, total_err = self:count()
  if not total_members then
    return nil, total_err
  end
  
  local active_members, active_err = self:count({is_active = 1})
  if not active_members then
    return nil, active_err
  end
  
  -- Get new members this month using proper date range
  local current_date = os.date("!%Y-%m-%d")
  local year, month = current_date:match("(%d%d%d%d)-(%d%d)")
  local month_start = year .. "-" .. month .. "-01"
  
  -- Calculate month end (first day of next month minus 1 day)
  local next_month = tonumber(month) + 1
  local next_year = tonumber(year)
  if next_month > 12 then
    next_month = 1
    next_year = next_year + 1
  end
  local next_month_start = string.format("%04d-%02d-01", next_year, next_month)
  
  local new_this_month_query = [[
    SELECT COUNT(*) as count FROM members 
    WHERE membership_date >= ? AND membership_date < ?
  ]]
  local new_result, new_err = self.base:execute_query_one(new_this_month_query, {month_start, next_month_start})
  if not new_result then
    return nil, new_err
  end
  
  -- Get birthdays this month
  local current_month_num = tonumber(os.date("!%m"))
  local birthday_query = "SELECT COUNT(*) as count FROM members WHERE strftime('%m', date_of_birth) = ?"
  local birthday_result, birthday_err = self.base:execute_query_one(birthday_query, {string.format("%02d", current_month_num)})
  if not birthday_result then
    return nil, birthday_err
  end
  
  return {
    total_members = total_members,
    active_members = active_members,
    inactive_members = total_members - active_members,
    new_this_month = tonumber(new_result.count),
    birthdays_this_month = tonumber(birthday_result.count)
  }, nil
end

-- Activate/deactivate member
function MemberRepository:set_active_status(member_id, is_active)
  return self:update_by_id(member_id, {is_active = is_active and 1 or 0})
end

-- Get full name (computed field)
function MemberRepository:get_full_name(member)
  if not member then return nil end
  return (member.first_name or "") .. " " .. (member.last_name or "")
end

-- Advanced member operations using functional programming
function MemberRepository:get_enhanced_members(options)
  options = options or {}
  
  -- Get base members
  local members, err = self:find_all(options)
  if not members then
    return nil, err
  end
  
  -- Define transformations using functional approach
  local transformations = {}
  
  -- Add computed fields
  table.insert(transformations, function(member)
    return DataProcessor.add_computed_fields({member}, {
      full_name = function(m) return self:get_full_name(m) end,
      age = function(m) 
        return calculate_age_from_birth_date(m.date_of_birth)
      end,
      membership_years = function(m)
        if m.membership_date then
          local membership_year = m.membership_date:match("(%d%d%d%d)")
          if membership_year then
            return tonumber(os.date("%Y")) - tonumber(membership_year)
          end
        end
        return nil
      end
    })[1]
  end)
  
  -- Apply transformations
  return DataProcessor.process_results(members, transformations), nil
end

-- Get member analytics using functional programming
function MemberRepository:get_member_analytics()
  local members, err = self:find_all()
  if not members then
    return nil, err
  end
  
  -- Group members by various criteria
  local analytics = {}
  
  -- Group by membership year
  analytics.by_membership_year = DataProcessor.group_results(members, function(member)
    if member.membership_date then
      return member.membership_date:match("(%d%d%d%d)") or "unknown"
    end
    return "unknown"
  end)
  
  -- Group by age ranges
  analytics.by_age_range = DataProcessor.group_results(members, function(member)
    local age = calculate_age_from_birth_date(member.date_of_birth)
    if age then
      if age < 18 then return "under_18"
      elseif age < 30 then return "18_29"
      elseif age < 50 then return "30_49"
      elseif age < 65 then return "50_64"
      else return "65_plus"
      end
    end
    return "unknown"
  end)
  
  -- Get active/inactive counts
  local active_members, inactive_members = fun.partition_table(function(member)
    return member.is_active == 1
  end, members)
  
  analytics.status_breakdown = {
    active = #active_members,
    inactive = #inactive_members,
    total = #members
  }
  
  -- Get members with complete information
  analytics.data_completeness = {
    with_phone = fun.count_where(function(m) return m.phone and m.phone ~= "" end, members),
    with_address = fun.count_where(function(m) return m.address and m.address ~= "" end, members),
    with_birth_date = fun.count_where(function(m) return m.date_of_birth and m.date_of_birth ~= "" end, members),
    total = #members
  }
  
  return analytics, nil
end

-- Filter members by advanced criteria using functional programming
function MemberRepository:filter_members_advanced(filter_options)
  local members, err = self:find_all()
  if not members then
    return nil, err
  end
  
  local filters = {}
  
  -- Add age filter
  if filter_options.min_age or filter_options.max_age then
    table.insert(filters, function(member)
      if not member.date_of_birth then return false end
      local birth_year = member.date_of_birth:match("(%d%d%d%d)")
      if not birth_year then return false end
      
      local age = tonumber(os.date("%Y")) - tonumber(birth_year)
      
      if filter_options.min_age and age < filter_options.min_age then
        return false
      end
      if filter_options.max_age and age > filter_options.max_age then
        return false
      end
      
      return true
    end)
  end
  
  -- Add membership duration filter
  if filter_options.min_membership_years then
    table.insert(filters, function(member)
      if not member.membership_date then return false end
      local membership_year = member.membership_date:match("(%d%d%d%d)")
      if not membership_year then return false end
      
      local years = tonumber(os.date("%Y")) - tonumber(membership_year)
      return years >= filter_options.min_membership_years
    end)
  end
  
  -- Add birthday this month filter
  if filter_options.birthday_this_month then
    table.insert(filters, function(member)
      if not member.date_of_birth then return false end
      local birth_month = member.date_of_birth:match("%d%d%d%d-(%d%d)")
      if not birth_month then return false end
      
      return tonumber(birth_month) == tonumber(os.date("%m"))
    end)
  end
  
  -- Apply all filters
  local filtered_members = DataProcessor.apply_filters(members, filters)
  
  -- Apply sorting if specified and valid
  if filter_options.sort_by then
    local validated_sort_field = validate_sort_field(filter_options.sort_by)
    if validated_sort_field then
      local sort_criteria = {{
        field = validated_sort_field,
        direction = filter_options.sort_direction or "asc"
      }}
      filtered_members = DataProcessor.sort_results(filtered_members, sort_criteria)
    else
      -- Fallback to safe default sorting when invalid sort_by is provided
      -- This prevents silent failures and ensures consistent ordering
      local sort_criteria = {{
        field = "last_name",  -- Safe default: sort by last name
        direction = "asc"
      }}
      filtered_members = DataProcessor.sort_results(filtered_members, sort_criteria)
    end
  end
  
  -- Apply pagination if specified
  if filter_options.page and filter_options.per_page then
    return DataProcessor.paginate_results(filtered_members, filter_options.page, filter_options.per_page)
  end
  
  return filtered_members, nil
end

-- Static function to calculate age from date of birth
function MemberRepository.calculate_age(date_of_birth)
  if not date_of_birth or type(date_of_birth) ~= "string" then
    return nil
  end
  
  -- Extract year, month, and day from date string (YYYY-MM-DD format)
  local birth_year, birth_month, birth_day = date_of_birth:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
  
  if not birth_year or not birth_month or not birth_day then
    return nil
  end
  
  birth_year = tonumber(birth_year)
  birth_month = tonumber(birth_month)
  birth_day = tonumber(birth_day)
  
  if not birth_year or not birth_month or not birth_day then
    return nil
  end
  
  -- Get current date
  local current_year = tonumber(os.date("%Y"))
  local current_month = tonumber(os.date("%m"))
  local current_day = tonumber(os.date("%d"))
  
  -- Calculate age
  local age = current_year - birth_year
  
  -- Subtract 1 if birthday hasn't occurred yet this year
  if current_month < birth_month or 
     (current_month == birth_month and current_day < birth_day) then
    age = age - 1
  end
  
  -- Return nil for negative ages (future birth dates)
  return age >= 0 and age or nil
end

return MemberRepository
