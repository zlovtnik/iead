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
  
  -- Add CORS headers first
  response = response .. "Access-Control-Allow-Origin: http://localhost:5173\r\n"
  response = response .. "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n"
  response = response .. "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
  response = response .. "Access-Control-Allow-Credentials: true\r\n"

  -- Add custom headers
  for name, value in pairs(headers or {}) do
    response = response .. string.format("%s: %s\r\n", name, value)
  end

  -- Add body
  response = response .. "\r\n" .. (body or "")

  -- Check if client is a socket connection and has send method
  if client and type(client.send) == "function" then
    client:send(response)
  else
    error("Invalid client connection - cannot send response")
  end
end

return json
