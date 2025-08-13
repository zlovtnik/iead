-- src/tests/test_tithe.lua
-- Tests for Tithe model

local test_runner = require("src.tests.test_runner")
local Tithe = require("src.models.tithe")
local Member = require("src.models.member")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
  
  -- Create test member with salary
  local member = Member.create({
    name = "John Doe", 
    email = "john@example.com",
    salary = 50000
  })
  return tonumber(member.id)
end

function tests.test_create_tithe()
  local member_id = setup()
  
  local tithe_data = {
    member_id = member_id,
    amount = 416.67, -- 10% of monthly salary (50000/12)
    tithe_date = "2024-01-01",
    payment_method = "cash",
    is_paid = true,
    notes = "January tithe"
  }
  
  local tithe, err = Tithe.create(tithe_data)
  
  test_runner.assert_not_nil(tithe, "Tithe should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(tonumber(tithe.member_id), member_id, "Member ID should match")
  test_runner.assert_equal(tonumber(tithe.amount), 416.67, "Amount should match")
  test_runner.assert_equal(tithe.payment_method, "cash", "Payment method should match")
end

function tests.test_create_tithe_missing_required_fields()
  local member_id = setup()
  
  local tithe_data = {
    notes = "Some notes"
  }
  
  local tithe, err = Tithe.create(tithe_data)
  
  test_runner.assert_nil(tithe, "Tithe should not be created")
  test_runner.assert_not_nil(err, "Should have error")
end

function tests.test_find_all_tithes()
  local member_id = setup()
  
  -- Create test tithes
  Tithe.create({
    member_id = member_id,
    amount = 416.67,
    tithe_date = "2024-01-01"
  })
  Tithe.create({
    member_id = member_id,
    amount = 416.67,
    tithe_date = "2024-02-01"
  })
  
  local tithes = Tithe.find_all()
  
  test_runner.assert_equal(#tithes, 2, "Should have 2 tithes")
end

function tests.test_find_by_member()
  local member_id = setup()
  
  Tithe.create({
    member_id = member_id,
    amount = 416.67,
    tithe_date = "2024-01-01"
  })
  
  local tithes = Tithe.find_by_member(member_id)
  
  test_runner.assert_equal(#tithes, 1, "Should have 1 tithe")
  test_runner.assert_equal(tonumber(tithes[1].member_id), member_id, "Member ID should match")
end

function tests.test_calculate_monthly_tithe()
  local member_id = setup()
  
  local amount = Tithe.calculate_monthly_tithe(member_id)
  
  -- Expected: 50000 / 12 * 0.1 = 416.67 (rounded)
  test_runner.assert_equal(math.floor(tonumber(amount) * 100), 41666, "Monthly tithe should be correct")
end

function tests.test_mark_paid()
  local member_id = setup()
  
  local tithe = Tithe.create({
    member_id = member_id,
    amount = 416.67,
    tithe_date = "2024-01-01",
    is_paid = false
  })
  local id = tonumber(tithe.id)
  
  local updated_tithe = Tithe.mark_paid(id, "cash")
  
  test_runner.assert_not_nil(updated_tithe, "Tithe should be marked as paid")
  test_runner.assert_equal(tonumber(updated_tithe.is_paid), 1, "Should be marked as paid")
  test_runner.assert_equal(updated_tithe.payment_method, "cash", "Payment method should be set")
end

function tests.test_generate_monthly_tithes()
  local member_id = setup()
  
  local generated = Tithe.generate_monthly_tithes(1, 2024)
  
  test_runner.assert_equal(#generated, 1, "Should generate 1 tithe")
  test_runner.assert_equal(tonumber(generated[1].member_id), member_id, "Member ID should match")
  test_runner.assert_equal(generated[1].tithe_date, "2024-01-01", "Date should be correct")
end

function tests.test_update_tithe()
  local member_id = setup()
  
  local tithe = Tithe.create({
    member_id = member_id,
    amount = 416.67,
    tithe_date = "2024-01-01"
  })
  local id = tonumber(tithe.id)
  
  local update_data = {
    member_id = member_id,
    amount = 500.00,
    tithe_date = "2024-01-01",
    payment_method = "check",
    is_paid = true
  }
  
  local updated_tithe = Tithe.update(id, update_data)
  
  test_runner.assert_not_nil(updated_tithe, "Tithe should be updated")
  test_runner.assert_equal(tonumber(updated_tithe.amount), 500.00, "Amount should be updated")
  test_runner.assert_equal(updated_tithe.payment_method, "check", "Payment method should be updated")
end

function tests.test_delete_tithe()
  local member_id = setup()
  
  local tithe = Tithe.create({
    member_id = member_id,
    amount = 416.67,
    tithe_date = "2024-01-01"
  })
  local id = tonumber(tithe.id)
  
  local result = Tithe.delete(id)
  
  test_runner.assert_true(result, "Delete should be successful")
  
  local found_tithe = Tithe.find_by_id(id)
  test_runner.assert_nil(found_tithe, "Tithe should not be found after deletion")
end

return tests
