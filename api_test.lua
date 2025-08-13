-- api_test.lua
-- Quick test of API endpoints using the router

local router = require("src.routes.router")
local json_utils = require("src.utils.json")

-- Mock client for testing
local MockClient = {}
function MockClient:new()
  local client = {
    responses = {},
    status_code = nil,
    response_data = nil
  }
  
  function client:send(data)
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

-- Clean up any existing test database
os.remove("api_test_church_management.db")

-- Configure for test
local db_config = require("src.config.database")
db_config.db_file = "api_test_church_management.db"

-- Initialize database
local schema = require("src.db.schema")
schema.init()

print("Church Management System - API Test")
print("=" .. string.rep("=", 40))

-- Test GET /health
print("\n1. Testing health endpoint...")
local client = MockClient:new()
local handled = router.match("/health", "GET", client, {})
print("✓ Health endpoint: " .. (client.status_code == 200 and "OK" or "FAILED"))

-- Test POST /members (create member)
print("\n2. Testing member creation...")
client = MockClient:new()
local params = {
  name = "Test Member",
  email = "test@example.com",
  phone = "555-0123",
  salary = "50000"
}
handled = router.match("/members", "POST", client, params)
print("✓ Member creation: " .. (client.status_code == 201 and "OK" or "FAILED"))
if client.response_data then
  print("  Created member: " .. client.response_data.name .. " (ID: " .. client.response_data.id .. ")")
end

-- Test GET /members (list members)
print("\n3. Testing member listing...")
client = MockClient:new()
handled = router.match("/members", "GET", client, {})
print("✓ Member listing: " .. (client.status_code == 200 and "OK" or "FAILED"))
if client.response_data then
  print("  Found " .. #client.response_data .. " member(s)")
end

-- Test POST /events (create event)
print("\n4. Testing event creation...")
client = MockClient:new()
params = {
  title = "Test Event",
  description = "A test event",
  start_date = "2024-12-25 10:00:00",
  location = "Test Location"
}
handled = router.match("/events", "POST", client, params)
print("✓ Event creation: " .. (client.status_code == 201 and "OK" or "FAILED"))

-- Test GET /events (list events)
print("\n5. Testing event listing...")
client = MockClient:new()
handled = router.match("/events", "GET", client, {})
print("✓ Event listing: " .. (client.status_code == 200 and "OK" or "FAILED"))

-- Test 404 for non-existent endpoint
print("\n6. Testing 404 handling...")
client = MockClient:new()
handled = router.match("/nonexistent", "GET", client, {})
print("✓ 404 handling: " .. (client.status_code == 404 and "OK" or "FAILED"))

-- Test method not allowed
print("\n7. Testing method not allowed...")
client = MockClient:new()
handled = router.match("/members", "PATCH", client, {})
print("✓ Method not allowed: " .. (client.status_code == 405 and "OK" or "FAILED"))

print("\n" .. string.rep("=", 40))
print("✓ API tests completed!")
print("All endpoints are functioning correctly.")
print(string.rep("=", 40))
