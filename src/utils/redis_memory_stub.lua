-- redis_memory_stub.lua
-- Simple in-memory Redis client stub for fallback
local redis = {}
local store = {}

function redis:set(key, value)
  store[key] = value
  return true
end

function redis:get(key)
  return store[key]
end

function redis:del(key)
  if key == nil then
    return nil, "key is nil"
  end
  local existed = store[key] ~= nil
  store[key] = nil
  return existed
end

function redis:exists(key)
  return store[key] ~= nil
end

function redis:flushall()
  store = {}
  return true
end

return redis
