-- src/tests/test_attendance.lua
-- Tests for Attendance model

local test_runner = require("src.tests.test_runner")
local Attendance = require("src.models.attendance")
local Member = require("src.models.member")
local Event = require("src.models.event")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
  
  -- Create test member and event
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  local event = Event.create({
    title = "Sunday Service",
    start_date = "2024-01-07 10:00:00"
  })
  
  return tonumber(member.id), tonumber(event.id)
end

function tests.test_create_attendance()
  local member_id, event_id = setup()
  
  local attendance_data = {
    event_id = event_id,
    member_id = member_id,
    status = "present",
    notes = "On time"
  }
  
  local attendance, err = Attendance.create(attendance_data)
  
  test_runner.assert_not_nil(attendance, "Attendance should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(tonumber(attendance.event_id), event_id, "Event ID should match")
  test_runner.assert_equal(tonumber(attendance.member_id), member_id, "Member ID should match")
  test_runner.assert_equal(attendance.status, "present", "Status should match")
end

function tests.test_create_attendance_missing_required_fields()
  local member_id, event_id = setup()
  
  local attendance_data = {
    notes = "Some notes"
  }
  
  local attendance, err = Attendance.create(attendance_data)
  
  test_runner.assert_nil(attendance, "Attendance should not be created")
  test_runner.assert_not_nil(err, "Should have error")
end

function tests.test_find_all_attendance()
  local member_id, event_id = setup()
  
  -- Create test attendance records
  Attendance.create({
    event_id = event_id,
    member_id = member_id,
    status = "present"
  })
  
  local attendances = Attendance.find_all()
  
  test_runner.assert_equal(#attendances, 1, "Should have 1 attendance record")
  test_runner.assert_equal(attendances[1].status, "present", "Status should match")
end

function tests.test_find_by_event()
  local member_id, event_id = setup()
  
  Attendance.create({
    event_id = event_id,
    member_id = member_id,
    status = "present"
  })
  
  local attendances = Attendance.find_by_event(event_id)
  
  test_runner.assert_equal(#attendances, 1, "Should have 1 attendance record")
  test_runner.assert_equal(tonumber(attendances[1].event_id), event_id, "Event ID should match")
end

function tests.test_find_by_member()
  local member_id, event_id = setup()
  
  Attendance.create({
    event_id = event_id,
    member_id = member_id,
    status = "present"
  })
  
  local attendances = Attendance.find_by_member(member_id)
  
  test_runner.assert_equal(#attendances, 1, "Should have 1 attendance record")
  test_runner.assert_equal(tonumber(attendances[1].member_id), member_id, "Member ID should match")
end

function tests.test_update_attendance()
  local member_id, event_id = setup()
  
  local attendance = Attendance.create({
    event_id = event_id,
    member_id = member_id,
    status = "present"
  })
  local id = tonumber(attendance.id)
  
  local update_data = {
    event_id = event_id,
    member_id = member_id,
    status = "absent",
    notes = "Was sick"
  }
  
  local updated_attendance = Attendance.update(id, update_data)
  
  test_runner.assert_not_nil(updated_attendance, "Attendance should be updated")
  test_runner.assert_equal(updated_attendance.status, "absent", "Status should be updated")
  test_runner.assert_equal(updated_attendance.notes, "Was sick", "Notes should be updated")
end

function tests.test_delete_attendance()
  local member_id, event_id = setup()
  
  local attendance = Attendance.create({
    event_id = event_id,
    member_id = member_id,
    status = "present"
  })
  local id = tonumber(attendance.id)
  
  local result = Attendance.delete(id)
  
  test_runner.assert_true(result, "Delete should be successful")
  
  local found_attendance = Attendance.find_by_id(id)
  test_runner.assert_nil(found_attendance, "Attendance should not be found after deletion")
end

return tests
