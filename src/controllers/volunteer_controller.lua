-- src/controllers/volunteer_controller.lua
-- Volunteer controller for Church Management System

local Volunteer = require("src.models.volunteer")
local json_utils = require("src.utils.json")

local VolunteerController = {}

-- List all volunteers
function VolunteerController.index(client, params)
  local volunteers = Volunteer.find_all()
  json_utils.send_json_response(client, 200, volunteers)
end

-- Get volunteer by ID
function VolunteerController.show(client, params, id)
  id = tonumber(id)
  local volunteer = Volunteer.find_by_id(id)
  
  if not volunteer then
    json_utils.send_json_response(client, 404, { error = "Volunteer record not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, volunteer)
end

-- Get volunteers by member
function VolunteerController.by_member(client, params, member_id)
  member_id = tonumber(member_id)
  local volunteers = Volunteer.find_by_member(member_id)
  json_utils.send_json_response(client, 200, volunteers)
end

-- Get volunteers by event
function VolunteerController.by_event(client, params, event_id)
  event_id = tonumber(event_id)
  local volunteers = Volunteer.find_by_event(event_id)
  json_utils.send_json_response(client, 200, volunteers)
end

-- Create new volunteer
function VolunteerController.create(client, params)
  if not params.member_id or not params.role or not params.start_date or not params.status then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local volunteer, err = Volunteer.create(params)
  
  if not volunteer then
    json_utils.send_json_response(client, 400, { error = err or "Failed to create volunteer record" })
    return
  end
  
  json_utils.send_json_response(client, 201, volunteer)
end

-- Update volunteer
function VolunteerController.update(client, params, id)
  id = tonumber(id)
  
  if not params.role or not params.status then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local volunteer, err = Volunteer.update(id, params)
  
  if not volunteer then
    json_utils.send_json_response(client, 404, { error = err or "Volunteer record not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, volunteer)
end

-- Delete volunteer
function VolunteerController.delete(client, params, id)
  id = tonumber(id)
  local success, err = Volunteer.delete(id)
  
  if not success then
    json_utils.send_json_response(client, 404, { error = err or "Volunteer record not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, { message = "Volunteer record deleted" })
end

return VolunteerController
