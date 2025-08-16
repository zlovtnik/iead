-- src/models/session.lua
-- Session model for token management and authentication

local luasql = require("luasql.sqlite3")
local db_config = require("src.config.database")
local security = require("src.utils.security")
local validation = require("src.utils.validation")

local Session = {}

-- Default session duration in seconds (24 hours)
local DEFAULT_SESSION_DURATION = 24 * 60 * 60

-- Initialize database and create sessions table if it doesn't exist
function Session.init_db()
  local env = luasql.sqlite3()
  local conn = env:connect(db_config.db_file)
  
  -- Create sessions table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      token TEXT UNIQUE NOT NULL,
      expires_at TIMESTAMP NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ]]
  
  -- Create index for performance optimization
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token)
  ]]
  
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id)
  ]]
  
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at)
  ]]
  
  conn:close()
  env:close()
  
  print("Sessions table initialized")
end

-- Get database connection
function Session.get_connection()
  local env = luasql.sqlite3()
  return env:connect(db_config.db_file), env
end

-- Create new session with token
-- @param user_id number The ID of the user to create session for
-- @param options table|number Optional session options or duration in seconds
-- @return table Session object with token and expiration info
-- @return string Error message if creation fails
function Session.create(user_id, options)
  if not user_id then
    return nil, "User ID is required"
  end
  
  -- Handle both old signature (user_id, duration) and new signature (user_id, options)
  local duration = DEFAULT_SESSION_DURATION
  local session_options = {}
  
  if type(options) == "number" then
    -- Old signature: Session.create(user_id, duration)
    duration = options
  elseif type(options) == "table" then
    -- New signature: Session.create(user_id, {duration = ..., ip_address = ..., etc})
    duration = options.duration or DEFAULT_SESSION_DURATION
    session_options = options
  end
  
  local conn, env = Session.get_connection()
  
  -- Verify user exists
  local cursor = conn:execute(string.format("SELECT id FROM users WHERE id = %d", tonumber(user_id)))
  local user_exists = cursor:fetch()
  cursor:close()
  
  if not user_exists then
    conn:close()
    env:close()
    return nil, "User not found"
  end
  
  -- Generate secure token
  local token = security.generate_secure_token()
  
  -- Calculate expiration time using UTC to match SQLite's CURRENT_TIMESTAMP
  local expires_at = os.time() + duration
  local expires_at_str = os.date("!%Y-%m-%d %H:%M:%S", expires_at)
  
  -- Insert new session
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO sessions (user_id, token, expires_at) VALUES (%d, '%s', '%s')",
      tonumber(user_id),
      security.sanitize_input(token),
      expires_at_str
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create session: " .. (err or "Unknown error")
  end
  
  -- Get the created session
  cursor = conn:execute("SELECT * FROM sessions WHERE rowid = last_insert_rowid()")
  local session = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return session
end

-- Find and validate session by token
-- @param token string The session token to validate
-- @return table Session object with user info if valid
-- @return string Error message if validation fails
function Session.find_by_token(token)
  if not token or type(token) ~= 'string' or #token == 0 then
    return nil, "Token is required"
  end
  
  local conn, env = Session.get_connection()
  
  -- Find session with user info, only if not expired
  local cursor = conn:execute(string.format([[
    SELECT s.*, u.username, u.email, u.role, u.member_id, u.is_active 
    FROM sessions s 
    JOIN users u ON s.user_id = u.id 
    WHERE s.token = '%s' AND s.expires_at > CURRENT_TIMESTAMP
  ]], security.sanitize_input(token)))
  
  local session = cursor:fetch({}, "a")
  cursor:close()
  
  if not session then
    -- Check if session exists but is expired
    cursor = conn:execute(string.format("SELECT id FROM sessions WHERE token = '%s'", 
      security.sanitize_input(token)))
    local expired_session = cursor:fetch()
    cursor:close()
    
    if expired_session then
      -- Clean up expired session
      conn:execute(string.format("DELETE FROM sessions WHERE token = '%s'", 
        security.sanitize_input(token)))
      conn:close()
      env:close()
      return nil, "Session expired"
    else
      conn:close()
      env:close()
      return nil, "Invalid token"
    end
  end
  
  -- Check if user is still active using normalized boolean check
  if not validation.normalize_boolean(session.is_active) then
    -- Clean up session for inactive user
    conn:execute(string.format("DELETE FROM sessions WHERE token = '%s'", 
      security.sanitize_input(token)))
    conn:close()
    env:close()
    return nil, "User account is deactivated"
  end
  
  -- Update last accessed time
  conn:execute(string.format(
    "UPDATE sessions SET last_accessed = CURRENT_TIMESTAMP WHERE token = '%s'",
    security.sanitize_input(token)
  ))
  
  conn:close()
  env:close()
  
  -- Convert boolean fields using consistent validation function
  session.is_active = validation.normalize_boolean(session.is_active)
  
  return session
end

-- Refresh session expiration time
-- @param token string The session token to refresh
-- @param duration number Optional new duration in seconds (defaults to 24 hours)
-- @return table Updated session object
-- @return string Error message if refresh fails
function Session.refresh(token, duration)
  if not token or type(token) ~= 'string' or #token == 0 then
    return nil, "Token is required"
  end
  
  duration = duration or DEFAULT_SESSION_DURATION
  
  local conn, env = Session.get_connection()
  
  -- Check if session exists and is valid
  local cursor = conn:execute(string.format("SELECT * FROM sessions WHERE token = '%s'", 
    security.sanitize_input(token)))
  local session = cursor:fetch({}, "a")
  cursor:close()
  
  if not session then
    conn:close()
    env:close()
    return nil, "Invalid token"
  end
  
  -- Calculate new expiration time using UTC to match SQLite's CURRENT_TIMESTAMP
  local expires_at = os.time() + duration
  local expires_at_str = os.date("!%Y-%m-%d %H:%M:%S", expires_at)
  
  -- Update session expiration and last accessed time
  conn:execute(string.format(
    "UPDATE sessions SET expires_at = '%s', last_accessed = CURRENT_TIMESTAMP WHERE token = '%s'",
    expires_at_str,
    security.sanitize_input(token)
  ))
  
  -- Get updated session
  cursor = conn:execute(string.format("SELECT * FROM sessions WHERE token = '%s'", 
    security.sanitize_input(token)))
  local updated_session = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return updated_session
end

-- Invalidate session (logout)
-- @param token string The session token to invalidate
-- @return boolean True if session was invalidated successfully
-- @return string Error message if invalidation fails
function Session.invalidate(token)
  if not token or type(token) ~= 'string' or #token == 0 then
    return false, "Token is required"
  end
  
  local conn, env = Session.get_connection()
  
  -- Check if session exists
  local cursor = conn:execute(string.format("SELECT id FROM sessions WHERE token = '%s'", 
    security.sanitize_input(token)))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return false, "Session not found"
  end
  
  -- Delete session
  conn:execute(string.format("DELETE FROM sessions WHERE token = '%s'", 
    security.sanitize_input(token)))
  
  conn:close()
  env:close()
  
  return true
end

-- Clean up expired sessions
-- @return number Number of expired sessions removed
function Session.cleanup_expired()
  local conn, env = Session.get_connection()
  
  -- Count expired sessions before deletion
  local cursor = conn:execute("SELECT COUNT(*) as count FROM sessions WHERE expires_at < CURRENT_TIMESTAMP")
  local result = cursor:fetch({}, "a")
  local expired_count = tonumber(result.count) or 0
  cursor:close()
  
  -- Delete expired sessions
  conn:execute("DELETE FROM sessions WHERE expires_at < CURRENT_TIMESTAMP")
  
  conn:close()
  env:close()
  
  return expired_count
end

-- Invalidate all sessions for a specific user
-- @param user_id number The ID of the user whose sessions to invalidate
-- @return number Number of sessions invalidated
-- @return string Error message if operation fails
function Session.invalidate_user_sessions(user_id)
  if not user_id then
    return 0, "User ID is required"
  end
  
  local conn, env = Session.get_connection()
  
  -- Count user sessions before deletion
  local cursor = conn:execute(string.format("SELECT COUNT(*) as count FROM sessions WHERE user_id = %d", 
    tonumber(user_id)))
  local result = cursor:fetch({}, "a")
  local session_count = tonumber(result.count) or 0
  cursor:close()
  
  -- Delete all user sessions
  conn:execute(string.format("DELETE FROM sessions WHERE user_id = %d", tonumber(user_id)))
  
  conn:close()
  env:close()
  
  return session_count
end

-- Get all active sessions for a user
-- @param user_id number The ID of the user
-- @return table Array of active session objects
function Session.find_by_user_id(user_id)
  if not user_id then
    return {}
  end
  
  local conn, env = Session.get_connection()
  
  -- Find all non-expired sessions for user
  local cursor = conn:execute(string.format(
    "SELECT * FROM sessions WHERE user_id = %d AND expires_at > CURRENT_TIMESTAMP ORDER BY created_at DESC",
    tonumber(user_id)
  ))
  
  local sessions = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(sessions, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return sessions
end

-- Get session statistics
-- @return table Statistics about sessions (total, active, expired)
function Session.get_statistics()
  local conn, env = Session.get_connection()
  
  -- Count total sessions
  local cursor = conn:execute("SELECT COUNT(*) as count FROM sessions")
  local total_result = cursor:fetch({}, "a")
  local total_sessions = tonumber(total_result.count) or 0
  cursor:close()
  
  -- Count active sessions
  cursor = conn:execute("SELECT COUNT(*) as count FROM sessions WHERE expires_at > CURRENT_TIMESTAMP")
  local active_result = cursor:fetch({}, "a")
  local active_sessions = tonumber(active_result.count) or 0
  cursor:close()
  
  -- Count expired sessions
  cursor = conn:execute("SELECT COUNT(*) as count FROM sessions WHERE expires_at <= CURRENT_TIMESTAMP")
  local expired_result = cursor:fetch({}, "a")
  local expired_sessions = tonumber(expired_result.count) or 0
  cursor:close()
  
  conn:close()
  env:close()
  
  return {
    total = total_sessions,
    active = active_sessions,
    expired = expired_sessions
  }
end

-- Check if a session token is valid (without returning session data)
-- @param token string The session token to check
-- @return boolean True if token is valid and not expired
function Session.is_valid(token)
  local session, err = Session.find_by_token(token)
  return session ~= nil
end

return Session