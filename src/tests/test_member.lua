-- src/tests/test_member.lua
-- Tests for Member model

local test_runner = require("src.tests.test_runner")
local Member = require("src.models.member")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
end

function tests.test_create_member()
  setup()
  
  local member_data = {
    name = "John Doe",
    email = "john@example.com",
    phone = "123-456-7890",
    salary = 50000
  }
  
  local member, err = Member.create(member_data)
  
  test_runner.assert_not_nil(member, "Member should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(member.name, "John Doe", "Name should match")
  test_runner.assert_equal(member.email, "john@example.com", "Email should match")
  test_runner.assert_equal(member.phone, "123-456-7890", "Phone should match")
  test_runner.assert_equal(tonumber(member.salary), 50000, "Salary should match")
end

function tests.test_create_member_missing_required_fields()
  setup()
  
  local member_data = {
    phone = "123-456-7890"
  }
  
  local member, err = Member.create(member_data)
  
  test_runner.assert_nil(member, "Member should not be created")
  test_runner.assert_not_nil(err, "Should have error")
end

function tests.test_find_all_members()
  setup()
  
  -- Create test members
  Member.create({name = "John Doe", email = "john@example.com"})
  Member.create({name = "Jane Smith", email = "jane@example.com"})
  
  local members = Member.find_all()
  
  test_runner.assert_equal(#members, 2, "Should have 2 members")
  test_runner.assert_equal(members[1].name, "John Doe", "First member name should match")
  test_runner.assert_equal(members[2].name, "Jane Smith", "Second member name should match")
end

function tests.test_find_member_by_id()
  setup()
  
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  local found_member = Member.find_by_id(tonumber(member.id))
  
  test_runner.assert_not_nil(found_member, "Member should be found")
  test_runner.assert_equal(found_member.name, "John Doe", "Name should match")
  test_runner.assert_equal(found_member.email, "john@example.com", "Email should match")
end

function tests.test_find_member_by_invalid_id()
  setup()
  
  local member = Member.find_by_id(99999)
  
  test_runner.assert_nil(member, "Member should not be found")
end

function tests.test_update_member()
  setup()
  
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  local id = tonumber(member.id)
  
  local update_data = {
    name = "John Smith",
    email = "johnsmith@example.com",
    phone = "987-654-3210",
    salary = 60000
  }
  
  local updated_member = Member.update(id, update_data)
  
  test_runner.assert_not_nil(updated_member, "Member should be updated")
  test_runner.assert_equal(updated_member.name, "John Smith", "Name should be updated")
  test_runner.assert_equal(updated_member.email, "johnsmith@example.com", "Email should be updated")
  test_runner.assert_equal(updated_member.phone, "987-654-3210", "Phone should be updated")
  test_runner.assert_equal(tonumber(updated_member.salary), 60000, "Salary should be updated")
end

function tests.test_update_nonexistent_member()
  setup()
  
  local update_data = {
    name = "John Smith",
    email = "johnsmith@example.com"
  }
  
  local updated_member, err = Member.update(99999, update_data)
  
  test_runner.assert_nil(updated_member, "Member should not be updated")
  test_runner.assert_not_nil(err, "Should have error")
end

function tests.test_delete_member()
  setup()
  
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  local id = tonumber(member.id)
  
  local result = Member.delete(id)
  
  test_runner.assert_true(result, "Delete should be successful")
  
  local found_member = Member.find_by_id(id)
  test_runner.assert_nil(found_member, "Member should not be found after deletion")
end

function tests.test_delete_nonexistent_member()
  setup()
  
  local result, err = Member.delete(99999)
  
  test_runner.assert_nil(result, "Delete should fail")
  test_runner.assert_not_nil(err, "Should have error")
end

return tests
