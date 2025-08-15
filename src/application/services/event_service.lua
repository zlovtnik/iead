-- src/application/services/event_service.lua
-- Event service layer using repository pattern

local EventRepository = require("src.infrastructure.repositories.event_repository")
local AttendanceRepository = require("src.infrastructure.repositories.attendance_repository")
local MemberRepository = require("src.infrastructure.repositories.member_repository")
local log = require("src.utils.log")

local EventService = {}

-- Create a new event with validation
function EventService.create_event(event_data, current_user)
  local event_repo = EventRepository.new()
  
  -- Business logic validation
  if not event_data.title or event_data.title == "" then
    return nil, "Event title is required"
  end
  
  if not event_data.start_date then
    return nil, "Event start date is required"
  end
  
  -- Validate date format and ensure it's not in the past
  local start_date = event_data.start_date
  local today = os.date("!%Y-%m-%d")
  if start_date < today then
    return nil, "Event start date cannot be in the past"
  end
  
  -- If end_date is provided, ensure it's after start_date
  if event_data.end_date and event_data.end_date < start_date then
    return nil, "Event end date must be after start date"
  end
  
  -- Create the event
  local event, err = event_repo:create(event_data)
  if not event then
    return nil, err
  end
  
  log.info("Event created", {
    event_id = event.id,
    title = event.title,
    created_by = current_user and current_user.id
  })
  
  return event, nil
end

-- Update an event with business logic
function EventService.update_event(event_id, update_data, current_user)
  local event_repo = EventRepository.new()
  
  -- Check if event exists
  local existing_event, err = event_repo:find_by_id(event_id)
  if not existing_event then
    return nil, err or "Event not found"
  end
  
  -- Business logic validation
  if update_data.start_date then
    local today = os.date("!%Y-%m-%d")
    if update_data.start_date < today then
      return nil, "Event start date cannot be in the past"
    end
  end
  
  if update_data.end_date and update_data.start_date then
    if update_data.end_date < update_data.start_date then
      return nil, "Event end date must be after start date"
    end
  elseif update_data.end_date and not update_data.start_date then
    if update_data.end_date < existing_event.start_date then
      return nil, "Event end date must be after start date"
    end
  end
  
  -- Update the event
  local updated_event, update_err = event_repo:update_by_id(event_id, update_data)
  if not updated_event then
    return nil, update_err
  end
  
  log.info("Event updated", {
    event_id = event_id,
    updated_fields = update_data,
    updated_by = current_user and current_user.id
  })
  
  return updated_event, nil
end

-- Cancel an event (soft delete with attendance implications)
function EventService.cancel_event(event_id, current_user)
  local event_repo = EventRepository.new()
  local attendance_repo = AttendanceRepository.new()
  
  -- Check if event exists
  local event, err = event_repo:find_by_id(event_id)
  if not event then
    return nil, err or "Event not found"
  end
  
  -- Check if event has already started
  local today = os.date("!%Y-%m-%d")
  if event.start_date <= today then
    return nil, "Cannot cancel an event that has already started"
  end
  
  -- Get attendance count to notify about cancellation
  local attendance_stats, stats_err = attendance_repo:get_event_stats(event_id)
  if stats_err then
    log.warn("Could not get attendance stats for cancelled event", {
      event_id = event_id,
      error = stats_err
    })
  end
  
  -- Deactivate the event
  local success, cancel_err = event_repo:set_active_status(event_id, false)
  if not success then
    return nil, cancel_err
  end
  
  log.info("Event cancelled", {
    event_id = event_id,
    title = event.title,
    affected_attendees = attendance_stats and attendance_stats.total_attendees or 0,
    cancelled_by = current_user and current_user.id
  })
  
  return {
    event = event,
    affected_attendees = attendance_stats and attendance_stats.total_attendees or 0
  }, nil
end

-- Register attendance for an event
function EventService.register_attendance(event_id, member_id, status, notes, current_user)
  local event_repo = EventRepository.new()
  local attendance_repo = AttendanceRepository.new()
  local member_repo = MemberRepository.new()
  
  -- Validate event exists and is active
  local event, event_err = event_repo:find_by_id(event_id)
  if not event then
    return nil, event_err or "Event not found"
  end
  
  if event.is_active ~= 1 then
    return nil, "Event is not active"
  end
  
  -- Validate member exists and is active
  local member, member_err = member_repo:find_by_id(member_id)
  if not member then
    return nil, member_err or "Member not found"
  end
  
  if member.is_active ~= 1 then
    return nil, "Member is not active"
  end
  
  -- Check event capacity if specified
  if event.max_attendees and event.max_attendees > 0 then
    local has_capacity, capacity_err = event_repo:has_capacity(event_id)
    if not has_capacity then
      if capacity_err then
        return nil, capacity_err
      else
        return nil, "Event has reached maximum capacity"
      end
    end
  end
  
  -- Create or update attendance record
  local attendance, attendance_err = attendance_repo:find_or_create(
    event_id, 
    member_id, 
    status or "Present", 
    notes or ""
  )
  
  if not attendance then
    return nil, attendance_err
  end
  
  log.info("Attendance registered", {
    event_id = event_id,
    member_id = member_id,
    status = status,
    registered_by = current_user and current_user.id
  })
  
  return attendance, nil
end

-- Bulk register attendance for multiple members
function EventService.bulk_register_attendance(event_id, member_ids, status, notes, current_user)
  local event_repo = EventRepository.new()
  local attendance_repo = AttendanceRepository.new()
  
  -- Validate event exists and is active
  local event, event_err = event_repo:find_by_id(event_id)
  if not event then
    return nil, event_err or "Event not found"
  end
  
  if event.is_active ~= 1 then
    return nil, "Event is not active"
  end
  
  -- Check capacity if specified
  if event.max_attendees and event.max_attendees > 0 then
    local has_capacity, capacity_err = event_repo:has_capacity(event_id)
    if not has_capacity then
      if capacity_err then
        return nil, capacity_err
      else
        return nil, "Event has reached maximum capacity"
      end
    end
  end
  
  -- Bulk create attendance records
  local attendance_records, attendance_err = attendance_repo:bulk_create_attendance(
    event_id, 
    member_ids, 
    status or "Present", 
    notes or ""
  )
  
  if not attendance_records then
    return nil, attendance_err
  end
  
  log.info("Bulk attendance registered", {
    event_id = event_id,
    member_count = #member_ids,
    status = status,
    registered_by = current_user and current_user.id
  })
  
  return attendance_records, nil
end

-- Get event with full details including attendance statistics
function EventService.get_event_with_stats(event_id)
  local event_repo = EventRepository.new()
  local attendance_repo = AttendanceRepository.new()
  
  -- Get event details
  local event, event_err = event_repo:find_by_id(event_id)
  if not event then
    return nil, event_err or "Event not found"
  end
  
  -- Get attendance statistics
  local attendance_stats, stats_err = attendance_repo:get_event_stats(event_id)
  if stats_err then
    log.warn("Could not get attendance stats", {
      event_id = event_id,
      error = stats_err
    })
    attendance_stats = {
      total_attendees = 0,
      present_count = 0,
      absent_count = 0,
      attendance_rate = 0
    }
  end
  
  -- Combine event data with statistics
  return {
    event = event,
    attendance_stats = attendance_stats
  }, nil
end

-- Get upcoming events with statistics
function EventService.get_upcoming_events_with_stats(options)
  local event_repo = EventRepository.new()
  
  local events_with_stats, err = event_repo:find_events_with_attendance_stats(options)
  if not events_with_stats then
    return nil, err
  end
  
  return events_with_stats, nil
end

-- Search events with business logic
function EventService.search_events(query, filters, current_user)
  local event_repo = EventRepository.new()
  
  -- Apply user-based filtering if needed
  local search_options = {
    conditions = filters,
    order_by = "start_date",
    order_direction = "ASC"
  }
  
  -- Non-admin users should only see active events
  if not current_user or current_user.role ~= "Admin" then
    search_options.conditions = search_options.conditions or {}
    search_options.conditions.is_active = 1
  end
  
  local events, err = event_repo:search(query, search_options)
  if not events then
    return nil, err
  end
  
  return events, nil
end

-- Generate event report
function EventService.generate_event_report(start_date, end_date)
  local event_repo = EventRepository.new()
  local attendance_repo = AttendanceRepository.new()
  
  -- Get events in date range
  local events, events_err = event_repo:find_events_in_date_range(start_date, end_date)
  if not events then
    return nil, events_err
  end
  
  -- Get overall attendance statistics
  local overall_stats, stats_err = attendance_repo:get_overall_stats(start_date, end_date)
  if not overall_stats then
    return nil, stats_err
  end
  
  -- Calculate additional metrics
  local total_events = #events
  local active_events = 0
  for _, event in ipairs(events) do
    if event.is_active == 1 then
      active_events = active_events + 1
    end
  end
  
  return {
    date_range = {
      start_date = start_date,
      end_date = end_date
    },
    event_summary = {
      total_events = total_events,
      active_events = active_events,
      cancelled_events = total_events - active_events
    },
    attendance_summary = overall_stats,
    events = events
  }, nil
end

return EventService
