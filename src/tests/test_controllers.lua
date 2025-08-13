-- src/tests/test_controllers.lua
-- Integration tests for controllers

local test_runner = require("src.tests.test_runner")
local Member = require("src.models.member")
local Event = require("src.models.event")
local MemberController = require("src.controllers.member_controller")
local EventController = require("src.controllers.event_controller")

local tests = {}

-- Mock client for testing
local MockClient = {}
function MockClient:new()
  local client = {
    responses = {},
    status_code = nil,
    response_data = nil
  }
  
  function client.send(self, data)
    table.insert(self.responses, data)
    -- Parse status code from HTTP response
    local status = data:match("HTTP/1%.1 (%d+)")
    if status then
      self.status_code = tonumber(status)
    end
    -- Try to extract JSON data
    local json_start = data:find("\r\n\r\n")
    if json_start then
      local json_data = data:sub(json_start + 4)
      if json_data and #json_data > 0 then
        local success, decoded = pcall(require("cjson").decode, json_data)
        if success then
          self.response_data = decoded
        end
      end
    end
  end
  
  setmetatable(client, {__index = MockClient})
  return client
end

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
end

function tests.test_member_controller_index()
  setup()
  
  -- Create test members
  Member.create({name = "John Doe", email = "john@example.com"})
  Member.create({name = "Jane Smith", email = "jane@example.com"})
  
  local client = MockClient:new()
  MemberController.index(client, {})
  
  test_runner.assert_equal(client.status_code, 200, "Should return 200 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_equal(#client.response_data, 2, "Should return 2 members")
end

function tests.test_member_controller_show_existing()
  setup()
  
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  
  local client = MockClient:new()
  MemberController.show(client, {}, member.id)
  
  test_runner.assert_equal(client.status_code, 200, "Should return 200 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_equal(client.response_data.name, "John Doe", "Should return correct member")
end

function tests.test_member_controller_show_not_found()
  setup()
  
  local client = MockClient:new()
  MemberController.show(client, {}, "99999")
  
  test_runner.assert_equal(client.status_code, 404, "Should return 404 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_not_nil(client.response_data.error, "Should have error message")
end

function tests.test_member_controller_create_valid()
  setup()
  
  local params = {
    name = "New Member",
    email = "new@example.com",
    phone = "1234567890",
    salary = "50000"
  }
  
  local client = MockClient:new()
  MemberController.create(client, params)
  
  test_runner.assert_equal(client.status_code, 201, "Should return 201 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_equal(client.response_data.name, "New Member", "Should return created member")
end

function tests.test_member_controller_create_invalid()
  setup()
  
  local params = {
    phone = "1234567890"
    -- Missing required name and email
  }
  
  local client = MockClient:new()
  MemberController.create(client, params)
  
  test_runner.assert_equal(client.status_code, 400, "Should return 400 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_not_nil(client.response_data.error, "Should have error message")
end

function tests.test_event_controller_index()
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
  
  local client = MockClient:new()
  EventController.index(client, {})
  
  test_runner.assert_equal(client.status_code, 200, "Should return 200 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_equal(#client.response_data, 2, "Should return 2 events")
end

function tests.test_event_controller_create_valid()
  setup()
  
  local params = {
    title = "New Event",
    description = "Test event",
    start_date = "2024-06-01 10:00:00",
    location = "Main Hall"
  }
  
  local client = MockClient:new()
  EventController.create(client, params)
  
  test_runner.assert_equal(client.status_code, 201, "Should return 201 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_equal(client.response_data.title, "New Event", "Should return created event")
end

function tests.test_event_controller_update()
  setup()
  
  local event = Event.create({
    title = "Original Title",
    start_date = "2024-01-07 10:00:00"
  })
  
  local params = {
    title = "Updated Title",
    start_date = "2024-01-07 11:00:00",
    description = "Updated description"
  }
  
  local client = MockClient:new()
  EventController.update(client, params, event.id)
  
  test_runner.assert_equal(client.status_code, 200, "Should return 200 status")
  test_runner.assert_not_nil(client.response_data, "Should have response data")
  test_runner.assert_equal(client.response_data.title, "Updated Title", "Should return updated event")
end

function tests.test_event_controller_delete()
  setup()
  
  local event = Event.create({
    title = "To Delete",
    start_date = "2024-01-07 10:00:00"
  })
  
  local client = MockClient:new()
  EventController.delete(client, {}, event.id)
  
  test_runner.assert_equal(client.status_code, 200, "Should return 200 status")
  
  -- Verify deletion
  local found_event = Event.find_by_id(tonumber(event.id))
  test_runner.assert_nil(found_event, "Event should be deleted")
end

return tests
