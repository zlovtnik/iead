-- src/controllers/attendance_controller.lua
-- Attendance controller for Church Management System

local Attendance = require("src.models.attendance")
local json_utils = require("src.utils.json")

local AttendanceController = {}

-- List all attendance records
function AttendanceController.index(client, params)
  local records = Attendance.find_all()
  json_utils.send_json_response(client, 200, records)
end

-- Get attendance by ID
function AttendanceController.show(client, params, id)
  id = tonumber(id)
  local record = Attendance.find_by_id(id)
  
  if not record then
    json_utils.send_json_response(client, 404, { error = "Attendance record not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, record)
end

-- Get attendance by event
function AttendanceController.by_event(client, params, event_id)
  event_id = tonumber(event_id)
  local records = Attendance.find_by_event(event_id)
  json_utils.send_json_response(client, 200, records)
end

-- Get attendance by member
function AttendanceController.by_member(client, params, member_id)
  member_id = tonumber(member_id)
  local records = Attendance.find_by_member(member_id)
  json_utils.send_json_response(client, 200, records)
end

-- Create new attendance record
function AttendanceController.create(client, params)
  if not params.event_id or not params.member_id or not params.status then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local record, err = Attendance.create(params)
  
  if not record then
    json_utils.send_json_response(client, 400, { error = err or "Failed to create attendance record" })
    return
  end
  
  json_utils.send_json_response(client, 201, record)
end

-- Update attendance record
function AttendanceController.update(client, params, id)
  id = tonumber(id)
  
  if not params.status then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local record, err = Attendance.update(id, params)
  
  if not record then
    json_utils.send_json_response(client, 404, { error = err or "Attendance record not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, record)
end

-- Delete attendance record
function AttendanceController.delete(client, params, id)
  id = tonumber(id)
  local success, err = Attendance.delete(id)
  
  if not success then
    json_utils.send_json_response(client, 404, { error = err or "Attendance record not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, { message = "Attendance record deleted" })
end

return AttendanceController
