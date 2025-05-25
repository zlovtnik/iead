-- src/controllers/donation_controller.lua
-- Donation controller for Church Management System

local Donation = require("src.models.donation")
local json_utils = require("src.utils.json")

local DonationController = {}

-- List all donations
function DonationController.index(client, params)
  local donations = Donation.find_all()
  json_utils.send_json_response(client, 200, donations)
end

-- Get donation by ID
function DonationController.show(client, params, id)
  id = tonumber(id)
  local donation = Donation.find_by_id(id)
  
  if not donation then
    json_utils.send_json_response(client, 404, { error = "Donation not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, donation)
end

-- Get donations by member
function DonationController.by_member(client, params, member_id)
  member_id = tonumber(member_id)
  local donations = Donation.find_by_member(member_id)
  json_utils.send_json_response(client, 200, donations)
end

-- Create new donation
function DonationController.create(client, params)
  if not params.amount or not params.donation_date then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local donation, err = Donation.create(params)
  
  if not donation then
    json_utils.send_json_response(client, 400, { error = err or "Failed to create donation" })
    return
  end
  
  json_utils.send_json_response(client, 201, donation)
end

-- Update donation
function DonationController.update(client, params, id)
  id = tonumber(id)
  
  if not params.amount or not params.donation_date then
    json_utils.send_json_response(client, 400, { error = "Missing required fields" })
    return
  end
  
  local donation, err = Donation.update(id, params)
  
  if not donation then
    json_utils.send_json_response(client, 404, { error = err or "Donation not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, donation)
end

-- Delete donation
function DonationController.delete(client, params, id)
  id = tonumber(id)
  local success, err = Donation.delete(id)
  
  if not success then
    json_utils.send_json_response(client, 404, { error = err or "Donation not found" })
    return
  end
  
  json_utils.send_json_response(client, 200, { message = "Donation deleted" })
end

return DonationController
