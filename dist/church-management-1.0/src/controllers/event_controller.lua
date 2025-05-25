-- src/controllers/event_controller.lua
-- Event controller for Church Management System

local Event = require("src.models.event")
local json_utils = require("src.utils.json")

local EventController = {}

-- List all events
function EventController.index(client, params)
  local events = Event.find_all()
  json_utils.send_json_response(client, 200, events)
end

-- Get event by ID
function EventController.show(client, params, id)
  id = tonumber(id)
  local event = Event.find_by_id(id)
  
  if not event then
    json_utils.send_json_response(client, 404, { error = "Event not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, event)
end

-- Create new event
function EventController.create(client, params)
  if not params.title or not params.start_date then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local event, err = Event.create(params)
  
  if not event then
    json_utils.send_json_response(client, 400, { error = err or "Failed to create event" })
    return
  end
  
  json_utils.send_json_response(client, 201, event)
end

-- Update event
function EventController.update(client, params, id)
  id = tonumber(id)
  
  if not params.title or not params.start_date then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local event, err = Event.update(id, params)
  
  if not event then
    json_utils.send_json_response(client, 404, { error = err or "Event not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, event)
end

-- Delete event
function EventController.delete(client, params, id)
  id = tonumber(id)
  local success, err = Event.delete(id)
  
  if not success then
    json_utils.send_json_response(client, 404, { error = err or "Event not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, { message = "Event deleted" })
end

return EventController
