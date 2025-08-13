-- src/tests/test_donation.lua
-- Tests for Donation model

local test_runner = require("src.tests.test_runner")
local Donation = require("src.models.donation")
local Member = require("src.models.member")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
  
  -- Create test member
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  return tonumber(member.id)
end

function tests.test_create_donation()
  local member_id = setup()
  
  local donation_data = {
    member_id = member_id,
    amount = 100.50,
    donation_date = "2024-01-07",
    payment_method = "cash",
    category = "general",
    notes = "Sunday offering"
  }
  
  local donation, err = Donation.create(donation_data)
  
  test_runner.assert_not_nil(donation, "Donation should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(tonumber(donation.member_id), member_id, "Member ID should match")
  test_runner.assert_equal(tonumber(donation.amount), 100.50, "Amount should match")
  test_runner.assert_equal(donation.payment_method, "cash", "Payment method should match")
end

function tests.test_create_donation_missing_required_fields()
  local member_id = setup()
  
  local donation_data = {
    member_id = member_id,
    notes = "Some notes"
  }
  
  local donation, err = Donation.create(donation_data)
  
  test_runner.assert_nil(donation, "Donation should not be created")
  test_runner.assert_not_nil(err, "Should have error")
end

function tests.test_find_all_donations()
  local member_id = setup()
  
  -- Create test donations
  Donation.create({
    member_id = member_id,
    amount = 100.50,
    donation_date = "2024-01-07"
  })
  Donation.create({
    member_id = member_id,
    amount = 200.75,
    donation_date = "2024-01-14"
  })
  
  local donations = Donation.find_all()
  
  test_runner.assert_equal(#donations, 2, "Should have 2 donations")
end

function tests.test_find_donation_by_id()
  local member_id = setup()
  
  local donation = Donation.create({
    member_id = member_id,
    amount = 100.50,
    donation_date = "2024-01-07"
  })
  local found_donation = Donation.find_by_id(tonumber(donation.id))
  
  test_runner.assert_not_nil(found_donation, "Donation should be found")
  test_runner.assert_equal(tonumber(found_donation.amount), 100.50, "Amount should match")
end

function tests.test_find_by_member()
  local member_id = setup()
  
  Donation.create({
    member_id = member_id,
    amount = 100.50,
    donation_date = "2024-01-07"
  })
  
  local donations = Donation.find_by_member(member_id)
  
  test_runner.assert_equal(#donations, 1, "Should have 1 donation")
  test_runner.assert_equal(tonumber(donations[1].member_id), member_id, "Member ID should match")
end

function tests.test_update_donation()
  local member_id = setup()
  
  local donation = Donation.create({
    member_id = member_id,
    amount = 100.50,
    donation_date = "2024-01-07"
  })
  local id = tonumber(donation.id)
  
  local update_data = {
    member_id = member_id,
    amount = 150.75,
    donation_date = "2024-01-07",
    payment_method = "check",
    category = "building fund"
  }
  
  local updated_donation = Donation.update(id, update_data)
  
  test_runner.assert_not_nil(updated_donation, "Donation should be updated")
  test_runner.assert_equal(tonumber(updated_donation.amount), 150.75, "Amount should be updated")
  test_runner.assert_equal(updated_donation.payment_method, "check", "Payment method should be updated")
end

function tests.test_delete_donation()
  local member_id = setup()
  
  local donation = Donation.create({
    member_id = member_id,
    amount = 100.50,
    donation_date = "2024-01-07"
  })
  local id = tonumber(donation.id)
  
  local result = Donation.delete(id)
  
  test_runner.assert_true(result, "Delete should be successful")
  
  local found_donation = Donation.find_by_id(id)
  test_runner.assert_nil(found_donation, "Donation should not be found after deletion")
end

function tests.test_total_by_member()
  local member_id = setup()
  
  -- Create multiple donations
  Donation.create({
    member_id = member_id,
    amount = 100.50,
    donation_date = "2024-01-07"
  })
  Donation.create({
    member_id = member_id,
    amount = 200.75,
    donation_date = "2024-01-14"
  })
  
  local total = Donation.total_by_member(member_id)
  
  test_runner.assert_equal(tonumber(total), 301.25, "Total should be sum of donations")
end

return tests
