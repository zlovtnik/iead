-- src/utils/http.lua
-- HTTP utilities for Church Management System

local socket = require("socket")
local http = {}

-- Parse HTTP request
function http.parse_request(client)
  local request = {}
  request.headers = {}
  
  -- Parse request line
  local line = client:receive()
  request.method, request.path = line:match("^(%S+)%s+(%S+)")
  
  -- Parse headers
  while true do
    local line = client:receive()
    if line == "" then break end
    local name, value = line:match("^([^:]+):%s*(.+)")
    if name then request.headers[name:lower()] = value end
  end
  
  -- Parse body if needed
  if request.method == "POST" or request.method == "PUT" then
    local content_length = tonumber(request.headers["content-length"]) or 0
    if content_length > 0 then
      request.body = client:receive(content_length)
    end
  end
  
  return request
end

-- Parse query parameters from URL
function http.parse_query_params(url)
  local params = {}
  local path, query = url:match("([^?]*)%??(.*)")
  
  if query and query ~= "" then
    for pair in query:gmatch("([^&]+)") do
      local key, value = pair:match("([^=]*)=(.*)")
      if key and value then
        params[key] = socket.url.unescape(value)
      end
    end
  end
  
  return path, params
end

-- Parse form data
function http.parse_form_data(body)
  local params = {}
  if not body then return params end
  
  for pair in body:gmatch("([^&]+)") do
    local key, value = pair:match("([^=]*)=(.*)")
    if key and value then
      params[key] = socket.url.unescape(value)
    end
  end
  
  return params
end

return http
