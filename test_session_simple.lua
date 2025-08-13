-- Simple test runner for Session model
local test_db_file = "test_session_simple.db"

-- Override database configuration for testing
package.loaded["src.config.database"] = {
  db_file = test_db_file
}

-- Remove existing test database
os.remove(test_db_file)

-- Load modules
local User = require("src.models.user")
local Session = require("src.models.session")

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

print("User created successfully: " .. user.username)

print("Creating session...")
local session, session_err = Session.create(user.id)
if not session then
  print("Failed to create session: " .. (session_err or "Unknown error"))
  os.remove(test_db_file)
  return
end

print("Session created successfully: " .. session.token)

print("Finding session by token...")
local found_session, find_err = Session.find_by_token(session.token)
if not found_session then
  print("Failed to find session: " .. (find_err or "Unknown error"))
  os.remove(test_db_file)
  return
end

print("Session found successfully: " .. found_session.username)

print("Testing session refresh...")
local refreshed_session, refresh_err = Session.refresh(session.token)
if not refreshed_session then
  print("Failed to refresh session: " .. (refresh_err or "Unknown error"))
  os.remove(test_db_file)
  return
end

print("Session refreshed successfully")

print("Testing session invalidation...")
local invalidated, invalidate_err = Session.invalidate(session.token)
if not invalidated then
  print("Failed to invalidate session: " .. (invalidate_err or "Unknown error"))
  os.remove(test_db_file)
  return
end

print("Session invalidated successfully")

print("Verifying session is invalidated...")
local invalid_session, invalid_err = Session.find_by_token(session.token)
if invalid_session then
  print("ERROR: Session should be invalidated but was found")
  os.remove(test_db_file)
  return
end

print("Session properly invalidated: " .. (invalid_err or "No error message"))

print("Testing cleanup...")
local cleaned_count = Session.cleanup_expired()
print("Cleaned " .. cleaned_count .. " expired sessions")

print("All basic tests passed!")

-- Cleanup
os.remove(test_db_file)
print("Test database cleaned up")