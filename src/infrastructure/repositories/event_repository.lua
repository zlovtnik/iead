-- src/infrastructure/repositories/event_repository.lua
-- Event repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")

local EventRepository = {}
EventRepository.__index = EventRepository

-- Create a new EventRepository instance
function EventRepository.new()
  local schema = {
    title = {
      type = "string",
      required = true,
      max_length = 200
    },
    description = {
      type = "string",
      required = false
    },
    start_date = {
      type = "string",
      required = true
    },
    end_date = {
      type = "string",
      required = false
    },
    location = {
      type = "string",
      required = false,
      max_length = 255
    },
    max_attendees = {
      type = "number",
      required = false
    },
    is_active = {
      type = "number",
      required = false
    }
  }
  
  local base_repo = BaseRepository.new("events", schema)
  local instance = {
    base = base_repo
  }
  setmetatable(instance, EventRepository)
  return instance
end

-- Delegate to base repository methods
function EventRepository:find_all(options)
  return self.base:find_all(options)
end

function EventRepository:find_one(conditions)
  return self.base:find_one(conditions)
end

function EventRepository:find_by_id(id)
  return self.base:find_by_id(id)
end

function EventRepository:update_by_id(id, data)
  return self.base:update_by_id(id, data)
end

function EventRepository:delete_by_id(id)
  return self.base:delete_by_id(id)
end

function EventRepository:count(conditions)
  return self.base:count(conditions)
end

function EventRepository:exists(conditions)
  return self.base:exists(conditions)
end

function EventRepository:paginate(options)
  return self.base:paginate(options)
end

-- Custom create method with default values
function EventRepository:create(data)
  -- Set default values
  if data.is_active == nil then
    data.is_active = 1  -- Default to active
  end
  
  return self.base:create(data)
end

-- Custom update method (delegates to base)
function EventRepository:update(conditions, data)
  return self.base:update(conditions, data)
end

-- Find upcoming events
function EventRepository:find_upcoming_events(options)
  options = options or {}
  options.conditions = options.conditions or {}
  
  local today = os.date("!%Y-%m-%d")
  options.conditions.start_date = {operator = ">=", value = today}
  options.conditions.is_active = 1
  
  if not options.order_by then
    options.order_by = "start_date"
    options.order_direction = "ASC"
  end
  
  return self:find_all(options)
end

-- Find past events
function EventRepository:find_past_events(options)
  options = options or {}
  options.conditions = options.conditions or {}
  
  local today = os.date("!%Y-%m-%d")
  options.conditions.start_date = {operator = "<", value = today}
  
  if not options.order_by then
    options.order_by = "start_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find events in date range
function EventRepository:find_events_in_date_range(start_date, end_date, options)
  options = options or {}
  
  -- Define allowed column names for events table
  local allowed_columns = {
    ["id"] = true,
    ["title"] = true,
    ["description"] = true,
    ["start_date"] = true,
    ["end_date"] = true,
    ["location"] = true,
    ["created_at"] = true,
    ["is_active"] = true
  }
  
  local query = [[
    SELECT * FROM events 
    WHERE start_date >= ? AND start_date <= ?
    AND is_active = 1
  ]]
  
  local params = {start_date, end_date}
  
  -- Add additional conditions (only for allowed columns)
  if options.conditions then
    for field, value in pairs(options.conditions) do
      if field ~= "start_date" and field ~= "is_active" and allowed_columns[field] then
        query = query .. " AND " .. field .. " = ?"
        table.insert(params, value)
      end
    end
  end
  
  -- Add ordering with validation
  if options.order_by and allowed_columns[options.order_by] then
    local direction = "ASC"
    if options.order_direction then
      local upper_dir = string.upper(options.order_direction)
      if upper_dir == "ASC" or upper_dir == "DESC" then
        direction = upper_dir
      end
    end
    query = query .. " ORDER BY " .. options.order_by .. " " .. direction
  else
    query = query .. " ORDER BY start_date ASC"
  end
  
  -- Add pagination with validation
  if options.limit and type(options.limit) == "number" and options.limit > 0 then
    query = query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset and type(options.offset) == "number" and options.offset >= 0 then
      query = query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return self.base:execute_query(query, params)
end

-- Find events by month
function EventRepository:find_events_by_month(year, month, options)
  options = options or {}
  
  local start_date = string.format("%04d-%02d-01", year, month)
  local next_month = month == 12 and 1 or month + 1
  local next_year = month == 12 and year + 1 or year
  local end_date = string.format("%04d-%02d-01", next_year, next_month)
  
  return self:find_events_in_date_range(start_date, end_date, options)
end

-- Search events by title or description
function EventRepository:search(query, options)
  options = options or {}
  
  -- Define allowed column names for events table
  local allowed_columns = {
    id = "id",
    title = "title",
    description = "description", 
    start_date = "start_date",
    end_date = "end_date",
    location = "location",
    created_at = "created_at",
    is_active = "is_active"
  }
  
  local search_query = [[
    SELECT * FROM events 
    WHERE (title LIKE ? OR description LIKE ?)
    AND is_active = 1
  ]]
  
  local params = {"%" .. query .. "%", "%" .. query .. "%"}
  
  -- Add additional conditions (only for allowed columns)
  if options.conditions then
    for field, value in pairs(options.conditions) do
      if field ~= "title" and field ~= "description" and field ~= "is_active" then
        local safe_column = allowed_columns[field]
        if safe_column then
          search_query = search_query .. " AND " .. safe_column .. " = ?"
          table.insert(params, value)
        else
          return nil, "Invalid field name for search condition: " .. tostring(field)
        end
      end
    end
  end
  
  -- Add ordering with validation
  if options.order_by and allowed_columns[options.order_by] then
    local direction = "ASC"
    if options.order_direction then
      local upper_dir = string.upper(options.order_direction)
      if upper_dir == "ASC" or upper_dir == "DESC" then
        direction = upper_dir
      end
    end
    search_query = search_query .. " ORDER BY " .. options.order_by .. " " .. direction
  else
    search_query = search_query .. " ORDER BY start_date ASC"
  end
  
  -- Add pagination with validation
  if options.limit and type(options.limit) == "number" and options.limit > 0 then
    search_query = search_query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset and type(options.offset) == "number" and options.offset >= 0 then
      search_query = search_query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return self.base:execute_query(search_query, params)
end

-- Get events with attendance counts
function EventRepository:find_events_with_attendance_stats(options)
  options = options or {}
  
  -- Define allowed column names for events table
  local allowed_columns = {
    ["id"] = true,
    ["title"] = true,
    ["description"] = true,
    ["start_date"] = true,
    ["end_date"] = true,
    ["location"] = true,
    ["created_at"] = true,
    ["is_active"] = true
  }
  
  local query = [[
    SELECT e.*, 
           COUNT(a.id) as total_attendees,
           COUNT(CASE WHEN a.status = 'Present' THEN 1 END) as present_count,
           COUNT(CASE WHEN a.status = 'Absent' THEN 1 END) as absent_count
    FROM events e
    LEFT JOIN attendance a ON e.id = a.event_id
    WHERE e.is_active = 1
  ]]
  
  local params = {}
  
  -- Add additional conditions (only for allowed columns)
  if options.conditions then
    for field, value in pairs(options.conditions) do
      if field ~= "is_active" and allowed_columns[field] then
        query = query .. " AND e." .. field .. " = ?"
        table.insert(params, value)
      end
    end
  end
  
  query = query .. " GROUP BY e.id"
  
  -- Add ordering with validation
  if options.order_by and allowed_columns[options.order_by] then
    local direction = "ASC"
    if options.order_direction then
      local upper_dir = string.upper(options.order_direction)
      if upper_dir == "ASC" or upper_dir == "DESC" then
        direction = upper_dir
      end
    end
    query = query .. " ORDER BY e." .. options.order_by .. " " .. direction
  else
    query = query .. " ORDER BY e.start_date ASC"
  end
  
  -- Add pagination with validation
  if options.limit and type(options.limit) == "number" and options.limit > 0 then
    query = query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset and type(options.offset) == "number" and options.offset >= 0 then
      query = query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return self.base:execute_query(query, params)
end

-- Get event statistics
function EventRepository:get_stats()
  local total_events, total_err = self:count()
  if not total_events then
    return nil, total_err
  end
  
  local active_events, active_err = self:count({is_active = 1})
  if not active_events then
    return nil, active_err
  end
  
  -- Get upcoming events count
  local today = os.date("!%Y-%m-%d")
  local upcoming_count, upcoming_err = self:count({
    start_date = {operator = ">=", value = today},
    is_active = 1
  })
  if not upcoming_count then
    return nil, upcoming_err
  end
  
  -- Get events this month
  local current_month = os.date("!%Y-%m")
  local this_month_query = "SELECT COUNT(*) as count FROM events WHERE start_date LIKE ? AND is_active = 1"
  local this_month_result, month_err = self.base:execute_query_one(this_month_query, {current_month .. "%"})
  if not this_month_result then
    return nil, month_err
  end
  
  return {
    total_events = total_events,
    active_events = active_events,
    inactive_events = total_events - active_events,
    upcoming_events = upcoming_count,
    events_this_month = tonumber(this_month_result.count)
  }, nil
end

-- Activate/deactivate event
function EventRepository:set_active_status(event_id, is_active)
  return self:update_by_id(event_id, {is_active = is_active and 1 or 0})
end

-- Check if event has capacity for more attendees
function EventRepository:has_capacity(event_id)
  local event, err = self:find_by_id(event_id)
  if not event then
    return false, err
  end
  
  if not event.max_attendees or event.max_attendees == 0 then
    return true, nil  -- No capacity limit
  end
  
  -- Count current attendees
  local attendance_query = "SELECT COUNT(*) as count FROM attendance WHERE event_id = ? AND status = 'Present'"
  local result, count_err = self.base:execute_query_one(attendance_query, {event_id})
  if not result then
    return false, count_err
  end
  
  local current_attendees = tonumber(result.count)
  return current_attendees < event.max_attendees, nil
end

return EventRepository
