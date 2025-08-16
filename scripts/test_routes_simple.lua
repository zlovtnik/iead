-- Simple test to verify authentication routes are registered
local router = require("src.routes.router")

print("Testing authentication routes registration...")

-- Test that routes are registered
local auth_routes = {
  "/auth/login",
  "/auth/logout", 
  "/auth/refresh",
  "/auth/me",
  "/auth/password"
}

local user_routes = {
  "/users"
}

local user_pattern_routes = {
  "^/users/(%d+)$",
  "^/users/(%d+)/activate$",
  "^/users/(%d+)/reset-password$",
  "^/users/(%d+)/change-role$"
}

print("\nChecking exact routes:")
for _, route in ipairs(auth_routes) do
  if router.exact_routes[route] then
    print("✓ " .. route .. " is registered")
  else
    print("✗ " .. route .. " is NOT registered")
  end
end

for _, route in ipairs(user_routes) do
  if router.exact_routes[route] then
    print("✓ " .. route .. " is registered")
  else
    print("✗ " .. route .. " is NOT registered")
  end
end

print("\nChecking pattern routes:")
for _, pattern in ipairs(user_pattern_routes) do
  if router.pattern_routes[pattern] then
    print("✓ " .. pattern .. " is registered")
  else
    print("✗ " .. pattern .. " is NOT registered")
  end
end

print("\nTesting route matching:")

-- Create a simple mock client
local mock_client = {
  response_status = nil,
  response_body = nil,
  headers = {}
}

function mock_client:send(data)
  -- Simple response parsing
  local status = data:match("HTTP/1%.1 (%d+)")
  if status then
    self.response_status = tonumber(status)
  end
end

-- Test login route matching
local success = router.match("/auth/login", "POST", mock_client, {})
print("Login route match: " .. (success and "✓ SUCCESS" or "✗ FAILED"))

-- Test users route matching  
success = router.match("/users", "GET", mock_client, {})
print("Users route match: " .. (success and "✓ SUCCESS" or "✗ FAILED"))

-- Test user detail pattern matching
success = router.match("/users/123", "GET", mock_client, {})
print("User detail pattern match: " .. (success and "✓ SUCCESS" or "✗ FAILED"))

print("\nRoute integration test completed!")