-- src/utils/log.lua
-- Simple logging utility

local log = {}

function log.error(...)
  print("[ERROR]", ...)
end

function log.warn(...)
  print("[WARN]", ...)
end

function log.info(...)
  print("[INFO]", ...)
end

function log.debug(...)
  print("[DEBUG]", ...)
end

return log
