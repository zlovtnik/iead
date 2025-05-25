-- src/controllers/report_controller.lua
-- Report controller for Church Management System

local Report = require("src.models.report")
local json_utils = require("src.utils.json")

local ReportController = {}

-- Generate member attendance report
function ReportController.member_attendance(client, params)
  local start_date = params.start_date
  local end_date = params.end_date
  
  local report = Report.member_attendance(start_date, end_date)
  json_utils.send_json_response(client, 200, report)
end

-- Generate event attendance report
function ReportController.event_attendance(client, params)
  local start_date = params.start_date
  local end_date = params.end_date
  
  local report = Report.event_attendance(start_date, end_date)
  json_utils.send_json_response(client, 200, report)
end

-- Generate donation summary report
function ReportController.donation_summary(client, params)
  local start_date = params.start_date
  local end_date = params.end_date
  
  local report = Report.donation_summary(start_date, end_date)
  json_utils.send_json_response(client, 200, report)
end

-- Generate top donors report
function ReportController.top_donors(client, params)
  local start_date = params.start_date
  local end_date = params.end_date
  local limit = params.limit and tonumber(params.limit) or 10
  
  local report = Report.top_donors(start_date, end_date, limit)
  json_utils.send_json_response(client, 200, report)
end

-- Generate volunteer hours report
function ReportController.volunteer_hours(client, params)
  local start_date = params.start_date
  local end_date = params.end_date
  
  local report = Report.volunteer_hours(start_date, end_date)
  json_utils.send_json_response(client, 200, report)
end

return ReportController
