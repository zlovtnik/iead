-- src/controllers/tithe_controller.lua
-- Tithe controller for Church Management System

local Tithe = require("src.models.tithe")
local Member = require("src.models.member")
local json_utils = require("src.utils.json")

local TitheController = {}

-- List all tithes
function TitheController.index(client, params)
  local tithes = Tithe.find_all()
  json_utils.send_json_response(client, 200, tithes)
end

-- Get tithe by ID
function TitheController.show(client, params, id)
  id = tonumber(id)
  local tithe = Tithe.find_by_id(id)
  
  if not tithe then
    json_utils.send_json_response(client, 404, { error = "Tithe not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, tithe)
end

-- Get tithes by member
function TitheController.by_member(client, params, member_id)
  member_id = tonumber(member_id)
  local tithes = Tithe.find_by_member(member_id)
  json_utils.send_json_response(client, 200, tithes)
end

-- Create new tithe
function TitheController.create(client, params)
  if not params.member_id or not params.tithe_date then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local tithe, err = Tithe.create(params)
  
  if not tithe then
    json_utils.send_json_response(client, 400, { error = err or "Failed to create tithe" })
    return
  end
  
  json_utils.send_json_response(client, 201, tithe)
end

-- Update tithe
function TitheController.update(client, params, id)
  id = tonumber(id)
  
  if not params.member_id or not params.tithe_date then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local tithe, err = Tithe.update(id, params)
  
  if not tithe then
    json_utils.send_json_response(client, 404, { error = err or "Tithe not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, tithe)
end

-- Delete tithe
function TitheController.delete(client, params, id)
  id = tonumber(id)
  local success, err = Tithe.delete(id)
  
  if not success then
    json_utils.send_json_response(client, 404, { error = err or "Tithe not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, { message = "Tithe deleted" })
end

-- Mark tithe as paid
function TitheController.mark_paid(client, params, id)
  id = tonumber(id)
  
  local tithe = Tithe.find_by_id(id)
  if not tithe then
    json_utils.send_json_response(client, 404, { error = "Tithe not found" })
    return
  end
  
  local updated_tithe, err = Tithe.update(id, {
    member_id = tithe.member_id,
    amount = tithe.amount,
    tithe_date = tithe.tithe_date,
    payment_method = params.payment_method or tithe.payment_method,
    is_paid = true,
    notes = params.notes or tithe.notes
  })
  
  if not updated_tithe then
    json_utils.send_json_response(client, 400, { error = err or "Failed to update tithe" })
    return
  end
  
  json_utils.send_json_response(client, 200, updated_tithe)
end

-- Generate monthly tithes for all members with salary
function TitheController.generate_monthly(client, params)
  if not params.month or not params.year then
    json_utils.send_json_response(client, 400, { error = "Missing month and year" })
    return
  end
  
  local month = tonumber(params.month)
  local year = tonumber(params.year)
  
  if not month or month < 1 or month > 12 or not year then
    json_utils.send_json_response(client, 400, { error = "Invalid month or year" })
    return
  end
  
  local results = Tithe.generate_monthly_tithes(month, year)
  json_utils.send_json_response(client, 200, {
    message = string.format("Generated tithes for %d members", #results),
    tithes = results
  })
end

-- Calculate tithe amount for a member
function TitheController.calculate(client, params, member_id)
  member_id = tonumber(member_id)
  
  local amount, err = Tithe.calculate_amount(member_id)
  
  if not amount then
    json_utils.send_json_response(client, 400, { error = err or "Failed to calculate tithe" })
    return
  end
  
  json_utils.send_json_response(client, 200, { amount = amount })
end

return TitheController
