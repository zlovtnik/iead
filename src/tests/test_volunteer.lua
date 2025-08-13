-- src/tests/test_volunteer.lua
-- Tests for Volunteer model

local test_runner = require("src.tests.test_runner")
local Volunteer = require("src.models.volunteer")
local Member = require("src.models.member")
local Event = require("src.models.event")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
  
  -- Create test member and event
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  local event = Event.create({
    title = "Church Cleanup",
    start_date = "2024-01-07 09:00:00"
  })
  
  return tonumber(member.id), tonumber(event.id)
end

function tests.test_create_volunteer()
  local member_id, event_id = setup()
  
  local volunteer_data = {
    event_id = event_id,
    member_id = member_id,
    role = "Setup Coordinator",
    hours = 4,
    notes = "Helped with table setup"
  }
  
  local volunteer, err = Volunteer.create(volunteer_data)
  
  test_runner.assert_not_nil(volunteer, "Volunteer should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(tonumber(volunteer.event_id), event_id, "Event ID should match")
  test_runner.assert_equal(tonumber(volunteer.member_id), member_id, "Member ID should match")
  test_runner.assert_equal(volunteer.role, "Setup Coordinator", "Role should match")
end

function tests.test_create_volunteer_missing_required_fields()
  local member_id, event_id = setup()
  
  local volunteer_data = {
    notes = "Some notes"
  }
  
  local volunteer, err = Volunteer.create(volunteer_data)
  
  test_runner.assert_nil(volunteer, "Volunteer should not be created")
  test_runner.assert_not_nil(err, "Should have error")
end

function tests.test_find_all_volunteers()
  local member_id, event_id = setup()
  
  -- Create test volunteer records
  Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Setup",
    hours = 2
  })
  Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Cleanup",
    hours = 3
  })
  
  local volunteers = Volunteer.find_all()
  
  test_runner.assert_equal(#volunteers, 2, "Should have 2 volunteer records")
end

function tests.test_find_by_event()
  local member_id, event_id = setup()
  
  Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Setup",
    hours = 2
  })
  
  local volunteers = Volunteer.find_by_event(event_id)
  
  test_runner.assert_equal(#volunteers, 1, "Should have 1 volunteer record")
  test_runner.assert_equal(tonumber(volunteers[1].event_id), event_id, "Event ID should match")
end

function tests.test_find_by_member()
  local member_id, event_id = setup()
  
  Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Setup",
    hours = 2
  })
  
  local volunteers = Volunteer.find_by_member(member_id)
  
  test_runner.assert_equal(#volunteers, 1, "Should have 1 volunteer record")
  test_runner.assert_equal(tonumber(volunteers[1].member_id), member_id, "Member ID should match")
end

function tests.test_update_volunteer()
  local member_id, event_id = setup()
  
  local volunteer = Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Setup",
    hours = 2
  })
  local id = tonumber(volunteer.id)
  
  local update_data = {
    event_id = event_id,
    member_id = member_id,
    role = "Setup Coordinator",
    hours = 4,
    notes = "Led the setup team"
  }
  
  local updated_volunteer = Volunteer.update(id, update_data)
  
  test_runner.assert_not_nil(updated_volunteer, "Volunteer should be updated")
  test_runner.assert_equal(updated_volunteer.role, "Setup Coordinator", "Role should be updated")
  test_runner.assert_equal(tonumber(updated_volunteer.hours), 4, "Hours should be updated")
end

function tests.test_delete_volunteer()
  local member_id, event_id = setup()
  
  local volunteer = Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Setup",
    hours = 2
  })
  local id = tonumber(volunteer.id)
  
  local result = Volunteer.delete(id)
  
  test_runner.assert_true(result, "Delete should be successful")
  
  local found_volunteer = Volunteer.find_by_id(id)
  test_runner.assert_nil(found_volunteer, "Volunteer should not be found after deletion")
end

function tests.test_total_hours_by_member()
  local member_id, event_id = setup()
  
  -- Create multiple volunteer records
  Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Setup",
    hours = 2
  })
  Volunteer.create({
    event_id = event_id,
    member_id = member_id,
    role = "Cleanup",
    hours = 3
  })
  
  local total_hours = Volunteer.total_hours_by_member(member_id)
  
  test_runner.assert_equal(tonumber(total_hours), 5, "Total hours should be sum of volunteer hours")
end

return tests
