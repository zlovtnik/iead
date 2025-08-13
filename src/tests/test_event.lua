-- src/tests/test_event.lua
-- Tests for Event model

local test_runner = require("src.tests.test_runner")
local Event = require("src.models.event")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
end

function tests.test_create_event()
  setup()
  
  local event_data = {
    title = "Sunday Service",
    description = "Weekly Sunday service",
    start_date = "2024-01-07 10:00:00",
    end_date = "2024-01-07 12:00:00",
    location = "Main Sanctuary"
  }
  
  local event, err = Event.create(event_data)
  
  test_runner.assert_not_nil(event, "Event should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(event.title, "Sunday Service", "Title should match")
  test_runner.assert_equal(event.description, "Weekly Sunday service", "Description should match")
  test_runner.assert_equal(event.location, "Main Sanctuary", "Location should match")
end

function tests.test_create_event_missing_required_fields()
  setup()
  
  local event_data = {
    description = "Some event"
  }
  
  local event, err = Event.create(event_data)
  
  test_runner.assert_nil(event, "Event should not be created")
  test_runner.assert_not_nil(err, "Should have error")
end

function tests.test_find_all_events()
  setup()
  
  -- Create test events
  Event.create({
    title = "Sunday Service",
    start_date = "2024-01-07 10:00:00"
  })
  Event.create({
    title = "Bible Study",
    start_date = "2024-01-10 19:00:00"
  })
  
  local events = Event.find_all()
  
  test_runner.assert_equal(#events, 2, "Should have 2 events")
end

function tests.test_find_event_by_id()
  setup()
  
  local event = Event.create({
    title = "Sunday Service",
    start_date = "2024-01-07 10:00:00"
  })
  local found_event = Event.find_by_id(tonumber(event.id))
  
  test_runner.assert_not_nil(found_event, "Event should be found")
  test_runner.assert_equal(found_event.title, "Sunday Service", "Title should match")
end

function tests.test_update_event()
  setup()
  
  local event = Event.create({
    title = "Sunday Service",
    start_date = "2024-01-07 10:00:00"
  })
  local id = tonumber(event.id)
  
  local update_data = {
    title = "Morning Service",
    start_date = "2024-01-07 09:00:00",
    location = "Main Hall"
  }
  
  local updated_event = Event.update(id, update_data)
  
  test_runner.assert_not_nil(updated_event, "Event should be updated")
  test_runner.assert_equal(updated_event.title, "Morning Service", "Title should be updated")
  test_runner.assert_equal(updated_event.location, "Main Hall", "Location should be updated")
end

function tests.test_delete_event()
  setup()
  
  local event = Event.create({
    title = "Sunday Service",
    start_date = "2024-01-07 10:00:00"
  })
  local id = tonumber(event.id)
  
  local result = Event.delete(id)
  
  test_runner.assert_true(result, "Delete should be successful")
  
  local found_event = Event.find_by_id(id)
  test_runner.assert_nil(found_event, "Event should not be found after deletion")
end

function tests.test_find_upcoming_events()
  setup()
  
  -- Create events with different dates
  Event.create({
    title = "Past Event",
    start_date = "2023-01-01 10:00:00"
  })
  Event.create({
    title = "Future Event",
    start_date = "2025-12-31 10:00:00"
  })
  
  local upcoming_events = Event.find_upcoming()
  
  test_runner.assert_equal(#upcoming_events, 1, "Should have 1 upcoming event")
  test_runner.assert_equal(upcoming_events[1].title, "Future Event", "Should be the future event")
end

return tests
