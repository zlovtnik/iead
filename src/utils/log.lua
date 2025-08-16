-- src/utils/log.lua
-- Simple logging utility

local log = {}

function log.error(...)
  print("[ERROR]", ...)
end

function log.info(...)
  print("[INFO]", ...)
end

return log
