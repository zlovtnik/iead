-- src/infrastructure/repositories/volunteer_repository.lua
-- Volunteer repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")

local VolunteerRepository = {}
VolunteerRepository.__index = VolunteerRepository

-- Create a new VolunteerRepository instance
function VolunteerRepository.new()
  local schema = {
    member_id = {
      type = "number",
      required = true
    },
    event_id = {
      type = "number",
      required = true
    },
    role = {
      type = "string",
      required = true,
      max_length = 100
    },
    hours = {
      type = "number",
      required = false
    },
    notes = {
      type = "string",
      required = false
    },
    status = {
      type = "string",
      required = false,
      max_length = 20
    }
  }
  
  local base_repo = BaseRepository.new("volunteers", schema)
  local instance = {
    base = base_repo
  }
  setmetatable(instance, VolunteerRepository)
  return instance
end

-- Delegate to base repository methods
function VolunteerRepository:find_all(options)
  return self.base:find_all(options)
end

function VolunteerRepository:find_one(conditions)
  return self.base:find_one(conditions)
end

function VolunteerRepository:find_by_id(id)
  return self.base:find_by_id(id)
end

function VolunteerRepository:update_by_id(id, data)
  return self.base:update_by_id(id, data)
end

function VolunteerRepository:delete_by_id(id)
  return self.base:delete_by_id(id)
end

function VolunteerRepository:count(conditions)
  return self.base:count(conditions)
end

function VolunteerRepository:exists(conditions)
  return self.base:exists(conditions)
end

function VolunteerRepository:paginate(options)
  return self.base:paginate(options)
end

-- Custom create method with default values
function VolunteerRepository:create(data)
  -- Set default status if not provided
  if not data.status then
    data.status = "Active"
  end
  
  -- Set default hours if not provided
  if not data.hours then
    data.hours = 0
  end
  
  return self.base:create(data)
end

-- Custom update method (delegates to base)
function VolunteerRepository:update(conditions, data)
  return self.base:update(conditions, data)
end

-- Find volunteers by member
function VolunteerRepository:find_by_member(member_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.member_id = member_id
  
  if not options.order_by then
    options.order_by = "id"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find volunteers by event
function VolunteerRepository:find_by_event(event_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.event_id = event_id
  
  if not options.order_by then
    options.order_by = "role"
    options.order_direction = "ASC"
  end
  
  return self:find_all(options)
end

-- Find volunteers by role
function VolunteerRepository:find_by_role(role, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.role = role
  
  if not options.order_by then
    options.order_by = "id"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find volunteers by status
function VolunteerRepository:find_by_status(status, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.status = status
  
  if not options.order_by then
    options.order_by = "id"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find volunteers with member and event details
function VolunteerRepository:find_with_details(options)
  options = options or {}
  
  local query = [[
    SELECT v.*, 
           m.first_name, m.last_name, m.email, m.phone,
           e.title as event_title, e.start_date, e.end_date, e.location
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
    JOIN events e ON v.event_id = e.id
  ]]
  
  local params = {}
  
  -- Add WHERE conditions
  if options.conditions then
    local where_parts = {}
    for field, value in pairs(options.conditions) do
      table.insert(where_parts, "v." .. field .. " = ?")
      table.insert(params, value)
    end
    
    if #where_parts > 0 then
      query = query .. " WHERE " .. table.concat(where_parts, " AND ")
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    query = query .. " ORDER BY v." .. options.order_by .. " " .. direction
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

-- Find volunteers by event with member details
function VolunteerRepository:find_by_event_with_members(event_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.event_id = event_id
  
  return self:find_with_details(options)
end

-- Find volunteers by member with event details
function VolunteerRepository:find_by_member_with_events(member_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.member_id = member_id
  
  return self:find_with_details(options)
end

-- Get volunteer statistics for an event
function VolunteerRepository:get_event_volunteer_stats(event_id)
  local total_query = "SELECT COUNT(*) as count FROM volunteers WHERE event_id = ?"
  local active_query = "SELECT COUNT(*) as count FROM volunteers WHERE event_id = ? AND status = 'Active'"
  local hours_query = "SELECT SUM(hours) as total_hours FROM volunteers WHERE event_id = ?"
  
  local total_result, total_err = self.base:execute_query_one(total_query, {event_id})
  if not total_result then
    return nil, total_err
  end
  
  local active_result, active_err = self.base:execute_query_one(active_query, {event_id})
  if not active_result then
    return nil, active_err
  end
  
  local hours_result, hours_err = self.base:execute_query_one(hours_query, {event_id})
  if not hours_result then
    return nil, hours_err
  end
  
  local total_volunteers = tonumber(total_result.count)
  local active_volunteers = tonumber(active_result.count)
  local total_hours = tonumber(hours_result.total_hours) or 0
  
  return {
    total_volunteers = total_volunteers,
    active_volunteers = active_volunteers,
    inactive_volunteers = total_volunteers - active_volunteers,
    total_hours = total_hours,
    average_hours = total_volunteers > 0 and (total_hours / total_volunteers) or 0
  }, nil
end

-- Get volunteer statistics for a member
function VolunteerRepository:get_member_volunteer_stats(member_id, start_date, end_date)
  local conditions_sql = "v.member_id = ?"
  local params = {member_id}
  
  if start_date and end_date then
    conditions_sql = conditions_sql .. " AND e.start_date >= ? AND e.start_date <= ?"
    table.insert(params, start_date)
    table.insert(params, end_date)
  end
  
  local stats_query = [[
    SELECT 
      COUNT(*) as total_volunteer_roles,
      COUNT(CASE WHEN v.status = 'Active' THEN 1 END) as active_roles,
      SUM(v.hours) as total_hours,
      COUNT(DISTINCT v.event_id) as events_volunteered,
      COUNT(DISTINCT v.role) as unique_roles
    FROM volunteers v
    JOIN events e ON v.event_id = e.id
    WHERE ]] .. conditions_sql
  
  local result, err = self.base:execute_query_one(stats_query, params)
  if not result then
    return nil, err
  end
  
  return {
    total_volunteer_roles = tonumber(result.total_volunteer_roles),
    active_roles = tonumber(result.active_roles),
    total_hours = tonumber(result.total_hours) or 0,
    events_volunteered = tonumber(result.events_volunteered),
    unique_roles = tonumber(result.unique_roles)
  }, nil
end

-- Get top volunteers by hours for a date range
function VolunteerRepository:get_top_volunteers_by_hours(start_date, end_date, limit)
  limit = limit or 10
  
  local query = [[
    SELECT v.member_id, m.first_name, m.last_name, m.email,
           SUM(v.hours) as total_hours,
           COUNT(v.id) as volunteer_count,
           COUNT(DISTINCT v.event_id) as events_count,
           COUNT(DISTINCT v.role) as roles_count
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
    JOIN events e ON v.event_id = e.id
    WHERE e.start_date >= ? AND e.start_date <= ?
    AND v.status = 'Active'
    GROUP BY v.member_id, m.first_name, m.last_name, m.email
    ORDER BY total_hours DESC
    LIMIT ?
  ]]
  
  return self.base:execute_query(query, {start_date, end_date, limit})
end

-- Get volunteer roles summary
function VolunteerRepository:get_roles_summary(start_date, end_date)
  local conditions_sql = ""
  local params = {}
  
  if start_date and end_date then
    conditions_sql = " WHERE e.start_date >= ? AND e.start_date <= ?"
    params = {start_date, end_date}
  end
  
  local query = [[
    SELECT v.role,
           COUNT(*) as volunteer_count,
           COUNT(DISTINCT v.member_id) as unique_volunteers,
           SUM(v.hours) as total_hours,
           AVG(v.hours) as average_hours
    FROM volunteers v
    JOIN events e ON v.event_id = e.id
  ]] .. conditions_sql .. [[
    GROUP BY v.role
    ORDER BY volunteer_count DESC
  ]]
  
  return self.base:execute_query(query, params)
end

-- Search volunteers with member and event information
function VolunteerRepository:search_with_details(query, options)
  options = options or {}
  
  local search_query = [[
    SELECT v.*, 
           m.first_name, m.last_name, m.email,
           e.title as event_title, e.start_date, e.location
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
    JOIN events e ON v.event_id = e.id
    WHERE (m.first_name LIKE ? OR m.last_name LIKE ? OR m.email LIKE ? 
           OR v.role LIKE ? OR v.notes LIKE ? OR e.title LIKE ?)
  ]]
  
  local search_param = "%" .. query .. "%"
  local params = {search_param, search_param, search_param, search_param, search_param, search_param}
  
  -- Add additional conditions
  if options.conditions then
    for field, value in pairs(options.conditions) do
      search_query = search_query .. " AND v." .. field .. " = ?"
      table.insert(params, value)
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    search_query = search_query .. " ORDER BY v." .. options.order_by .. " " .. direction
  else
    search_query = search_query .. " ORDER BY e.start_date DESC, m.last_name ASC"
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

-- Update volunteer status
function VolunteerRepository:update_status(volunteer_id, status)
  local valid_statuses = {Active = true, Inactive = true, Completed = true}
  if not valid_statuses[status] then
    return nil, "Invalid status. Must be Active, Inactive, or Completed"
  end
  
  return self:update_by_id(volunteer_id, {status = status})
end

-- Update volunteer hours
function VolunteerRepository:update_hours(volunteer_id, hours)
  if not hours or hours < 0 then
    return nil, "Hours must be a non-negative number"
  end
  
  return self:update_by_id(volunteer_id, {hours = hours})
end

-- Check if member is already volunteering for event in same role
function VolunteerRepository:is_duplicate_volunteer(member_id, event_id, role)
  local existing, err = self:find_one({
    member_id = member_id,
    event_id = event_id,
    role = role
  })
  
  if err then
    return false, err
  end
  
  return existing ~= nil, nil
end

-- Get volunteer availability (members not already volunteering for an event)
function VolunteerRepository:get_available_volunteers(event_id)
  local query = [[
    SELECT m.id, m.first_name, m.last_name, m.email, m.phone
    FROM members m
    WHERE m.is_active = 1
    AND m.id NOT IN (
      SELECT v.member_id 
      FROM volunteers v 
      WHERE v.event_id = ? AND v.status = 'Active'
    )
    ORDER BY m.last_name, m.first_name
  ]]
  
  return self.base:execute_query(query, {event_id})
end

-- Get volunteer history for a member
function VolunteerRepository:get_member_volunteer_history(member_id, limit)
  limit = limit or 50
  
  local query = [[
    SELECT v.*, e.title as event_title, e.start_date, e.end_date, e.location
    FROM volunteers v
    JOIN events e ON v.event_id = e.id
    WHERE v.member_id = ?
    ORDER BY e.start_date DESC
    LIMIT ?
  ]]
  
  return self.base:execute_query(query, {member_id, limit})
end

-- Get overall volunteer statistics
function VolunteerRepository:get_overall_stats(start_date, end_date)
  local conditions_sql = ""
  local params = {}
  
  if start_date and end_date then
    conditions_sql = " WHERE e.start_date >= ? AND e.start_date <= ?"
    params = {start_date, end_date}
  end
  
  local stats_query = [[
    SELECT 
      COUNT(*) as total_volunteer_assignments,
      COUNT(DISTINCT v.member_id) as unique_volunteers,
      COUNT(DISTINCT v.event_id) as events_with_volunteers,
      COUNT(DISTINCT v.role) as unique_roles,
      SUM(v.hours) as total_hours,
      AVG(v.hours) as average_hours,
      COUNT(CASE WHEN v.status = 'Active' THEN 1 END) as active_assignments,
      COUNT(CASE WHEN v.status = 'Completed' THEN 1 END) as completed_assignments
    FROM volunteers v
    JOIN events e ON v.event_id = e.id
  ]] .. conditions_sql
  
  return self.base:execute_query_one(stats_query, params)
end

return VolunteerRepository
