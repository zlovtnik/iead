-- src/controllers/event_controller_with_service.lua
-- Event controller using service layer and repository pattern

local EventService = require("src.application.services.event_service")
local json_utils = require("src.utils.json")
local log = require("src.utils.log")

local EventController = {}

-- Helper function to send error response
local function send_error_response(client, status, message, code)
  json_utils.send_json_response(client, status, {
    error = "Error",
    message = message,
    code = code or "UNKNOWN_ERROR",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  })
end

-- Helper function to validate event ID
local function validate_event_id(event_id, client)
  local id = tonumber(event_id)
  if not id or id <= 0 then
    send_error_response(client, 400, "Invalid event ID", "INVALID_EVENT_ID")
    return nil
  end
  return id
end

-- List events with optional filtering and search
-- GET /events
function EventController.index(client, params)
  -- Parse pagination parameters
  local page = tonumber(params.page) or 1
  local per_page = math.min(tonumber(params.per_page) or 10, 100)
  
  -- Parse filters
  local filters = {}
  if params.status then
    filters.is_active = params.status == "active" and 1 or 0
  end
  if params.location then
    filters.location = params.location
  end
  
  -- Handle search
  local search_query = params.search
  local events, err
  
  if search_query and search_query ~= "" then
    events, err = EventService.search_events(search_query, filters, params.current_user)
  else
    -- Use repository directly for listing with pagination
    local EventRepository = require("src.infrastructure.repositories.event_repository")
    local event_repo = EventRepository.new()
    
    local options = {
      page = page,
      per_page = per_page,
      conditions = filters,
      order_by = params.sort_by or "start_date",
      order_direction = params.sort_order or "ASC"
    }
    
    -- Non-admin users should only see active events
    if not params.current_user or params.current_user.role ~= "Admin" then
      options.conditions = options.conditions or {}
      options.conditions.is_active = 1
    end
    
    local result, repo_err = event_repo:paginate(options)
    if result then
      json_utils.send_json_response(client, 200, {
        events = result.records,
        pagination = {
          current_page = result.current_page,
          per_page = result.per_page,
          total_count = result.total_count,
          total_pages = result.total_pages,
          has_next = result.has_next,
          has_prev = result.has_prev
        }
      })
      return
    else
      err = repo_err
    end
  end
  
  if not events then
    send_error_response(client, 500, err, "EVENTS_FETCH_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 200, {
    events = events
  })
end

-- Get a specific event with attendance statistics
-- GET /events/:id
function EventController.show(client, params, event_id)
  local id = validate_event_id(event_id, client)
  if not id then return end
  
  local event_with_stats, err = EventService.get_event_with_stats(id)
  if not event_with_stats then
    if err and err:find("not found") then
      send_error_response(client, 404, err, "EVENT_NOT_FOUND")
    else
      send_error_response(client, 500, err, "EVENT_FETCH_FAILED")
    end
    return
  end
  
  json_utils.send_json_response(client, 200, event_with_stats)
end

-- Create a new event
-- POST /events
function EventController.create(client, params)
  -- Validate required fields
  if not params.title or params.title == "" then
    send_error_response(client, 400, "Event title is required", "MISSING_TITLE")
    return
  end
  
  if not params.start_date then
    send_error_response(client, 400, "Event start date is required", "MISSING_START_DATE")
    return
  end
  
  -- Prepare event data
  local event_data = {
    title = params.title,
    description = params.description,
    start_date = params.start_date,
    end_date = params.end_date,
    location = params.location,
    max_attendees = tonumber(params.max_attendees)
  }
  
  local event, err = EventService.create_event(event_data, params.current_user)
  if not event then
    send_error_response(client, 400, err, "EVENT_CREATION_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 201, {
    event = event,
    message = "Event created successfully"
  })
end

-- Update an event
-- PUT /events/:id
function EventController.update(client, params, event_id)
  local id = validate_event_id(event_id, client)
  if not id then return end
  
  -- Prepare update data (only include provided fields)
  local update_data = {}
  if params.title then
    update_data.title = params.title
  end
  if params.description then
    update_data.description = params.description
  end
  if params.start_date then
    update_data.start_date = params.start_date
  end
  if params.end_date then
    update_data.end_date = params.end_date
  end
  if params.location then
    update_data.location = params.location
  end
  if params.max_attendees then
    update_data.max_attendees = tonumber(params.max_attendees)
  end
  
  if not next(update_data) then
    send_error_response(client, 400, "No valid fields to update", "NO_CHANGES")
    return
  end
  
  local updated_event, err = EventService.update_event(id, update_data, params.current_user)
  if not updated_event then
    if err and err:find("not found") then
      send_error_response(client, 404, err, "EVENT_NOT_FOUND")
    else
      send_error_response(client, 400, err, "EVENT_UPDATE_FAILED")
    end
    return
  end
  
  json_utils.send_json_response(client, 200, {
    event = updated_event,
    message = "Event updated successfully"
  })
end

-- Cancel an event
-- DELETE /events/:id
function EventController.delete(client, params, event_id)
  local id = validate_event_id(event_id, client)
  if not id then return end
  
  local result, err = EventService.cancel_event(id, params.current_user)
  if not result then
    if err and err:find("not found") then
      send_error_response(client, 404, err, "EVENT_NOT_FOUND")
    else
      send_error_response(client, 400, err, "EVENT_CANCELLATION_FAILED")
    end
    return
  end
  
  json_utils.send_json_response(client, 200, {
    message = "Event cancelled successfully",
    affected_attendees = result.affected_attendees
  })
end

-- Register attendance for an event
-- POST /events/:id/attendance
function EventController.register_attendance(client, params, event_id)
  local id = validate_event_id(event_id, client)
  if not id then return end
  
  if not params.member_id then
    send_error_response(client, 400, "Member ID is required", "MISSING_MEMBER_ID")
    return
  end
  
  local member_id = tonumber(params.member_id)
  if not member_id or member_id <= 0 then
    send_error_response(client, 400, "Invalid member ID", "INVALID_MEMBER_ID")
    return
  end
  
  local status = params.status or "Present"
  local valid_statuses = {Present = true, Absent = true, Excused = true}
  if not valid_statuses[status] then
    send_error_response(client, 400, "Invalid status. Must be Present, Absent, or Excused", "INVALID_STATUS")
    return
  end
  
  local attendance, err = EventService.register_attendance(
    id, 
    member_id, 
    status, 
    params.notes, 
    params.current_user
  )
  
  if not attendance then
    send_error_response(client, 400, err, "ATTENDANCE_REGISTRATION_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 201, {
    attendance = attendance,
    message = "Attendance registered successfully"
  })
end

-- Bulk register attendance for multiple members
-- POST /events/:id/bulk-attendance
function EventController.bulk_register_attendance(client, params, event_id)
  local id = validate_event_id(event_id, client)
  if not id then return end
  
  if not params.member_ids or type(params.member_ids) ~= "table" or #params.member_ids == 0 then
    send_error_response(client, 400, "Member IDs array is required", "MISSING_MEMBER_IDS")
    return
  end
  
  -- Validate all member IDs
  local member_ids = {}
  for _, member_id in ipairs(params.member_ids) do
    local id_num = tonumber(member_id)
    if not id_num or id_num <= 0 then
      send_error_response(client, 400, "Invalid member ID: " .. tostring(member_id), "INVALID_MEMBER_ID")
      return
    end
    table.insert(member_ids, id_num)
  end
  
  local status = params.status or "Present"
  local valid_statuses = {Present = true, Absent = true, Excused = true}
  if not valid_statuses[status] then
    send_error_response(client, 400, "Invalid status. Must be Present, Absent, or Excused", "INVALID_STATUS")
    return
  end
  
  local attendance_records, err = EventService.bulk_register_attendance(
    id, 
    member_ids, 
    status, 
    params.notes, 
    params.current_user
  )
  
  if not attendance_records then
    send_error_response(client, 400, err, "BULK_ATTENDANCE_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 201, {
    attendance_records = attendance_records,
    count = #attendance_records,
    message = "Bulk attendance registered successfully"
  })
end

-- Get upcoming events with statistics
-- GET /events/upcoming
function EventController.upcoming_events(client, params)
  local limit = math.min(tonumber(params.limit) or 10, 50)
  
  local options = {
    limit = limit,
    conditions = {}
  }
  
  -- Non-admin users should only see active events
  if not params.current_user or params.current_user.role ~= "Admin" then
    options.conditions.is_active = 1
  end
  
  local events, err = EventService.get_upcoming_events_with_stats(options)
  if not events then
    send_error_response(client, 500, err, "UPCOMING_EVENTS_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 200, {
    events = events
  })
end

-- Generate event report
-- GET /events/report
function EventController.generate_report(client, params)
  local start_date = params.start_date
  local end_date = params.end_date
  
  if not start_date or not end_date then
    send_error_response(client, 400, "Start date and end date are required", "MISSING_DATE_RANGE")
    return
  end
  
  -- Validate date format (basic check)
  if not start_date:match("^%d%d%d%d%-%d%d%-%d%d$") or not end_date:match("^%d%d%d%d%-%d%d%-%d%d$") then
    send_error_response(client, 400, "Invalid date format. Use YYYY-MM-DD", "INVALID_DATE_FORMAT")
    return
  end
  
  if start_date > end_date then
    send_error_response(client, 400, "Start date must be before end date", "INVALID_DATE_RANGE")
    return
  end
  
  local report, err = EventService.generate_event_report(start_date, end_date)
  if not report then
    send_error_response(client, 500, err, "REPORT_GENERATION_FAILED")
    return
  end
  
  json_utils.send_json_response(client, 200, {
    report = report
  })
end

return EventController
