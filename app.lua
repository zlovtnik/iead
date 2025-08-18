#!/usr/bin/env lua
-- app.lua
-- Main application entry point for Church Management System

-- Add local LuaRocks paths
local home = os.getenv("HOME")
if home then
    package.path = home .. "/.luarocks/share/lua/5.4/?.lua;" .. home .. "/.luarocks/share/lua/5.4/?/init.lua;" .. package.path
    package.cpath = home .. "/.luarocks/lib/lua/5.4/?.so;" .. package.cpath
end

local socket = require("socket")
local http_utils = require("src.utils.http")
local json_utils = require("src.utils.json")
local router = require("src.routes.router")
local schema = require("src.db.schema")

-- Get environment variables
local env = os.getenv("APP_ENV") or "development"
local port = tonumber(os.getenv("PORT")) or 8080
local host = os.getenv("HOST") or "127.0.0.1"
local db_path = os.getenv("DB_PATH") or "church_management.db"

-- Load config with environment variable overrides
local db_config = require("src.config.database")
db_config.host = host
db_config.port = port
db_config.db_file = db_path
db_config.environment = env

-- Print environment information
print("Starting Church Management System")
print("Environment: " .. env)
print("Host: " .. host)
print("Port: " .. port)
print("Database path: " .. db_path)

-- Initialize database schema
schema.init()

-- Main server function
local function start_server(host, port)
  local server = assert(socket.bind(host, port))
  print(string.format("Server running at http://%s:%d/", host, port))
  
  -- Main loop
  while true do
    local client = server:accept()
    client:settimeout(60)
    
    local request = http_utils.parse_request(client)
    local path, query_params = http_utils.parse_query_params(request.path)
    local form_params = http_utils.parse_form_data(request.body)
    
    -- Combine params
    local params = {}
    for k, v in pairs(query_params) do params[k] = v end
    for k, v in pairs(form_params) do params[k] = v end
    
    -- Route the request
    local handled = router.match(path, request.method, client, params)
    
    -- Close the connection
    client:close()
  end
end

-- Start the server
start_server(db_config.host, db_config.port)
