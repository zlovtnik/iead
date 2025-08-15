-- src/infrastructure/repositories/member_repository.lua
-- Member repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")

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
  
  -- Create a custom query for OR conditions (searching name OR email)
  local search_query = [[
    SELECT * FROM members 
    WHERE (first_name LIKE ? OR last_name LIKE ? OR email LIKE ?)
  ]]
  
  -- Add additional conditions if provided
  local params = {"%" .. query .. "%", "%" .. query .. "%", "%" .. query .. "%"}
  
  if options.conditions then
    local where_parts = {}
    for field, value in pairs(options.conditions) do
      table.insert(where_parts, field .. " = ?")
      table.insert(params, value)
    end
    
    if #where_parts > 0 then
      search_query = search_query .. " AND " .. table.concat(where_parts, " AND ")
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
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

-- Get members by birth month (for birthday reminders)
function MemberRepository:find_by_birth_month(month, options)
  options = options or {}
  
  local query = "SELECT * FROM members WHERE strftime('%m', date_of_birth) = ?"
  local params = {string.format("%02d", month)}
  
  -- Add additional conditions
  if options.conditions then
    for field, value in pairs(options.conditions) do
      query = query .. " AND " .. field .. " = ?"
      table.insert(params, value)
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    query = query .. " ORDER BY " .. options.order_by .. " " .. direction
  else
    -- Default order by birth date
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
  
  -- Get new members this month
  local current_month = os.date("!%Y-%m")
  local new_this_month_query = "SELECT COUNT(*) as count FROM members WHERE membership_date LIKE ?"
  local new_result, new_err = self.base:execute_query_one(new_this_month_query, {current_month .. "%"})
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

return MemberRepository
