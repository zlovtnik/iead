-- src/controllers/member_controller.lua
-- Member controller for Church Management System

local Member = require("src.models.member")
local json_utils = require("src.utils.json")

local MemberController = {}

-- List all members
function MemberController.index(client, params)
  local members = Member.find_all()
  json_utils.send_json_response(client, 200, members)
end

-- Get member by ID
function MemberController.show(client, params, id)
  id = tonumber(id)
  local member = Member.find_by_id(id)
  
  if not member then
    json_utils.send_json_response(client, 404, { error = "Member not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, member)
end

-- Create new member
function MemberController.create(client, params)
  if not params.name or not params.email then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local member, err = Member.create(params)
  
  if not member then
    json_utils.send_json_response(client, 400, { error = err or "Failed to create member" })
    return
  end
  
  json_utils.send_json_response(client, 201, member)
end

-- Update member
function MemberController.update(client, params, id)
  id = tonumber(id)
  
  if not params.name or not params.email then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local member, err = Member.update(id, params)
  
  if not member then
    json_utils.send_json_response(client, 404, { error = err or "Member not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, member)
end

-- Delete member
function MemberController.delete(client, params, id)
  id = tonumber(id)
  local success, err = Member.delete(id)
  
  if not success then
    json_utils.send_json_response(client, 404, { error = err or "Member not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, { message = "Member deleted" })
end

return MemberController
