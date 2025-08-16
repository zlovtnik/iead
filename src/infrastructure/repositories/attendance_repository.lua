-- src/infrastructure/repositories/attendance_repository.lua
-- Attendance repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")

local AttendanceRepository = {}
AttendanceRepository.__index = AttendanceRepository

-- Create a new AttendanceRepository instance
function AttendanceRepository.new()
  local schema = {
    event_id = {
      type = "number",
      required = true
    },
    member_id = {
      type = "number",
      required = true
    },
    status = {
      type = "string",
      required = true,
      max_length = 20
    },
    notes = {
      type = "string",
      required = false
    }
  }
  
  local base_repo = BaseRepository.new("attendance", schema)
  local instance = {
    base = base_repo
  }
  setmetatable(instance, AttendanceRepository)
  return instance
end

-- Delegate to base repository methods
function AttendanceRepository:find_all(options)
  return self.base:find_all(options)
end

function AttendanceRepository:find_one(conditions)
  return self.base:find_one(conditions)
end

function AttendanceRepository:find_by_id(id)
  return self.base:find_by_id(id)
end

function AttendanceRepository:update_by_id(id, data)
  return self.base:update_by_id(id, data)
end

function AttendanceRepository:delete_by_id(id)
  return self.base:delete_by_id(id)
end

function AttendanceRepository:count(conditions)
  return self.base:count(conditions)
end

function AttendanceRepository:exists(conditions)
  return self.base:exists(conditions)
end

function AttendanceRepository:paginate(options)
  return self.base:paginate(options)
end

-- Custom create method with default values
function AttendanceRepository:create(data)
  -- Set default status if not provided
  if not data.status then
    data.status = "Present"
  end
  
  return self.base:create(data)
end

-- Custom update method (delegates to base)
function AttendanceRepository:update(conditions, data)
  return self.base:update(conditions, data)
end

-- Find attendance by event
function AttendanceRepository:find_by_event(event_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.event_id = event_id
  
  if not options.order_by then
    options.order_by = "id"
    options.order_direction = "ASC"
  end
  
  return self:find_all(options)
end

-- Find attendance by member
function AttendanceRepository:find_by_member(member_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.member_id = member_id
  
  if not options.order_by then
    options.order_by = "id"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find attendance with member and event details
function AttendanceRepository:find_with_details(options)
  options = options or {}
  
  local query = [[
    SELECT a.*, 
           m.first_name, m.last_name, m.email,
           e.title as event_title, e.start_date, e.location
    FROM attendance a
    JOIN members m ON a.member_id = m.id
    JOIN events e ON a.event_id = e.id
  ]]
  
  local params = {}
  
  -- Add WHERE conditions
  if options.conditions then
    local where_parts = {}
    for field, value in pairs(options.conditions) do
      table.insert(where_parts, "a." .. field .. " = ?")
      table.insert(params, value)
    end
    
    if #where_parts > 0 then
      query = query .. " WHERE " .. table.concat(where_parts, " AND ")
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    query = query .. " ORDER BY a." .. options.order_by .. " " .. direction
  else
    query = query .. " ORDER BY e.start_date DESC, m.last_name ASC"
  end
  
  -- Add pagination
  if options.limit then
    query = query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset then
      query = query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return self.base:execute_query(query, params)
end

-- Find attendance by event with member details
function AttendanceRepository:find_by_event_with_members(event_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.event_id = event_id
  
  return self:find_with_details(options)
end

-- Find attendance by member with event details
function AttendanceRepository:find_by_member_with_events(member_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.member_id = member_id
  
  return self:find_with_details(options)
end

-- Get attendance statistics for an event
function AttendanceRepository:get_event_stats(event_id)
  local total_query = "SELECT COUNT(*) as count FROM attendance WHERE event_id = ?"
  local present_query = "SELECT COUNT(*) as count FROM attendance WHERE event_id = ? AND status = 'Present'"
  local absent_query = "SELECT COUNT(*) as count FROM attendance WHERE event_id = ? AND status = 'Absent'"
  
  local total_result, total_err = self.base:execute_query_one(total_query, {event_id})
  if not total_result then
    return nil, total_err
  end
  
  local present_result, present_err = self.base:execute_query_one(present_query, {event_id})
  if not present_result then
    return nil, present_err
  end
  
  local absent_result, absent_err = self.base:execute_query_one(absent_query, {event_id})
  if not absent_result then
    return nil, absent_err
  end
  
  local total_count = tonumber(total_result.count)
  local present_count = tonumber(present_result.count)
  local absent_count = tonumber(absent_result.count)
  
  return {
    total_attendees = total_count,
    present_count = present_count,
    absent_count = absent_count,
    attendance_rate = total_count > 0 and (present_count / total_count * 100) or 0
  }, nil
end

-- Get attendance statistics for a member
function AttendanceRepository:get_member_stats(member_id, start_date, end_date)
  local conditions_sql = "a.member_id = ?"
  local params = {member_id}
  
  if start_date and end_date then
    conditions_sql = conditions_sql .. " AND e.start_date >= ? AND e.start_date <= ?"
    table.insert(params, start_date)
    table.insert(params, end_date)
  end
  
  local total_query = [[
    SELECT COUNT(*) as count 
    FROM attendance a 
    JOIN events e ON a.event_id = e.id 
    WHERE ]] .. conditions_sql
  
  local present_query = [[
    SELECT COUNT(*) as count 
    FROM attendance a 
    JOIN events e ON a.event_id = e.id 
    WHERE ]] .. conditions_sql .. " AND a.status = 'Present'"
  
  local total_result, total_err = self.base:execute_query_one(total_query, params)
  if not total_result then
    return nil, total_err
  end
  
  local present_params = {}
  for _, param in ipairs(params) do
    table.insert(present_params, param)
  end
  
  local present_result, present_err = self.base:execute_query_one(present_query, present_params)
  if not present_result then
    return nil, present_err
  end
  
  local total_count = tonumber(total_result.count)
  local present_count = tonumber(present_result.count)
  local absent_count = total_count - present_count
  
  return {
    total_events = total_count,
    events_attended = present_count,
    events_missed = absent_count,
    attendance_rate = total_count > 0 and (present_count / total_count * 100) or 0
  }, nil
end

-- Mark attendance for multiple members at once
function AttendanceRepository:bulk_create_attendance(event_id, member_ids, status, notes)
  status = status or "Present"
  notes = notes or ""
  
  local attendance_records = {}
  for _, member_id in ipairs(member_ids) do
    table.insert(attendance_records, {
      event_id = event_id,
      member_id = member_id,
      status = status,
      notes = notes
    })
  end
  
  local results = {}
  for _, record in ipairs(attendance_records) do
    local attendance, err = self:create(record)
    if attendance then
      table.insert(results, attendance)
    else
      return nil, "Failed to create attendance for member " .. record.member_id .. ": " .. (err or "unknown error")
    end
  end
  
  return results, nil
end

-- Update attendance status for a specific member and event
function AttendanceRepository:update_member_event_status(member_id, event_id, status, notes)
  local conditions = {
    member_id = member_id,
    event_id = event_id
  }
  
  local update_data = {
    status = status
  }
  
  if notes then
    update_data.notes = notes
  end
  
  return self.base:update(conditions, update_data)
end

-- Find or create attendance record
function AttendanceRepository:find_or_create(event_id, member_id, status, notes)
  -- First try to find existing record
  local existing, err = self:find_one({
    event_id = event_id,
    member_id = member_id
  })
  
  if existing then
    return existing, nil
  end
  
  -- Create new record if not found
  return self:create({
    event_id = event_id,
    member_id = member_id,
    status = status or "Present",
    notes = notes or ""
  })
end

-- Get attendance trends for a member over time
function AttendanceRepository:get_member_attendance_trend(member_id, months_back)
  months_back = months_back or 12
  
  local query = [[
    SELECT 
      strftime('%Y-%m', e.start_date) as month,
      COUNT(*) as total_events,
      COUNT(CASE WHEN a.status = 'Present' THEN 1 END) as attended_events,
      (COUNT(CASE WHEN a.status = 'Present' THEN 1 END) * 100.0 / COUNT(*)) as attendance_rate
    FROM attendance a
    JOIN events e ON a.event_id = e.id
    WHERE a.member_id = ?
    AND e.start_date >= date('now', '-' || ? || ' months')
    GROUP BY strftime('%Y-%m', e.start_date)
    ORDER BY month DESC
  ]]
  
  return self.base:execute_query(query, {member_id, months_back})
end

-- Get overall attendance statistics
function AttendanceRepository:get_overall_stats(start_date, end_date)
  local conditions_sql = ""
  local params = {}
  
  if start_date and end_date then
    conditions_sql = " WHERE e.start_date >= ? AND e.start_date <= ?"
    params = {start_date, end_date}
  end
  
  local stats_query = [[
    SELECT 
      COUNT(DISTINCT a.event_id) as total_events,
      COUNT(DISTINCT a.member_id) as unique_attendees,
      COUNT(*) as total_records,
      COUNT(CASE WHEN a.status = 'Present' THEN 1 END) as total_present,
      COUNT(CASE WHEN a.status = 'Absent' THEN 1 END) as total_absent,
      AVG(CASE WHEN a.status = 'Present' THEN 100.0 ELSE 0.0 END) as average_attendance_rate
    FROM attendance a
    JOIN events e ON a.event_id = e.id
  ]] .. conditions_sql
  
  return self.base:execute_query_one(stats_query, params)
end

return AttendanceRepository
