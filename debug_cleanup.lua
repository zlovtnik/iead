-- Debug cleanup test
local test_db_file = "debug_cleanup.db"

-- Override database configuration for testing
package.loaded["src.config.database"] = {
  db_file = test_db_file
}

-- Remove existing test database
os.remove(test_db_file)

-- Load modules
local User = require("src.models.user")
local Session = require("src.models.session")
local security = require("src.utils.security")

print("Initializing database...")
User.init_db()
Session.init_db()

print("Creating test user...")
local user_data = {
  username = "testuser",
  email = "test@example.com",
  password = "TestPass123",
  role = "Member"
}

local user, user_err = User.create(user_data)
if not user then
  print("Failed to create user: " .. (user_err or "Unknown error"))
  os.remove(test_db_file)
  return
end

print("Creating active session...")
local active_session = Session.create(user.id, 3600) -- 1 hour
print("Active session token: " .. active_session.token)
print("Active session expires at: " .. active_session.expires_at)

print("Manually inserting expired session...")
local conn, env = Session.get_connection()
local expired_token = security.generate_secure_token()
local expired_time = os.date("%Y-%m-%d %H:%M:%S", os.time() - 3600) -- 1 hour ago
print("Expired session token: " .. expired_token)
print("Expired session expires at: " .. expired_time)

conn:execute(string.format(
  "INSERT INTO sessions (user_id, token, expires_at) VALUES (%d, '%s', '%s')",
  tonumber(user.id), expired_token, expired_time
))
conn:close()
env:close()

print("Getting statistics before cleanup...")
local stats_before = Session.get_statistics()
print("Total: " .. stats_before.total)
print("Active: " .. stats_before.active)
print("Expired: " .. stats_before.expired)

print("Running cleanup...")
local cleaned_count = Session.cleanup_expired()
print("Cleaned " .. cleaned_count .. " sessions")

print("Getting statistics after cleanup...")
local stats_after = Session.get_statistics()
print("Total: " .. stats_after.total)
print("Active: " .. stats_after.active)
print("Expired: " .. stats_after.expired)

print("Checking if active session still exists...")
local found_active, err = Session.find_by_token(active_session.token)
if found_active then
  print("Active session found: " .. found_active.username)
else
  print("Active session NOT found: " .. (err or "No error"))
end

print("Checking if expired session was removed...")
local found_expired, err2 = Session.find_by_token(expired_token)
if found_expired then
  print("ERROR: Expired session still found!")
else
  print("Expired session properly removed: " .. (err2 or "No error"))
end

-- Cleanup
os.remove(test_db_file)
print("Test database cleaned up")