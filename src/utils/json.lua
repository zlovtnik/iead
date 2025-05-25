-- src/utils/json.lua
-- JSON utilities for Church Management System

local cjson = require("cjson")
local json = {}

-- Send JSON response
function json.send_json_response(client, status, data)
  local body = cjson.encode(data)
  json.send_response(client, status, {
    ["Content-Type"] = "application/json",
    ["Content-Length"] = #body
  }, body)
end

-- Send HTTP response
function json.send_response(client, status, headers, body)
  local response = string.format("HTTP/1.1 %d %s\r\n", status, status == 200 and "OK" or "Error")
  
  -- Add headers
  for name, value in pairs(headers) do
    response = response .. string.format("%s: %s\r\n", name, value)
  end
  
  -- Add body
  response = response .. "\r\n" .. (body or "")
  
  client:send(response)
end

return json
