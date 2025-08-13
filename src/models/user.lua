-- src/models/user.lua
-- User model for authentication system

local luasql = require("luasql.sqlite3")
local db_config = require("src.config.database")
local security = require("src.utils.security")
local validation = require("src.utils.validation")
local User = {}

-- Initialize database and create users table if it doesn't exist
function User.init_db()
  local env = luasql.sqlite3()
  local conn = env:connect(db_config.db_file)
  
  -- Create users table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('Admin', 'Pastor', 'Member')),
      member_id INTEGER,
      is_active BOOLEAN DEFAULT 1,
      failed_login_attempts INTEGER DEFAULT 0,
      last_login TIMESTAMP,
      password_reset_required BOOLEAN DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (member_id) REFERENCES members(id)
    )
  ]]
  
  -- Create indexes for performance optimization
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)
  ]]
  
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)
  ]]
  
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_users_member_id ON users(member_id)
  ]]
  
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)
  ]]
  
  conn:execute[[
    CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active)
  ]]
  
  conn:close()
  env:close()
  
  print("Users table initialized")
end

-- Get database connection
function User.get_connection()
  local env = luasql.sqlite3()
  return env:connect(db_config.db_file), env
end

-- Create new user with hashed password
function User.create(data)
  -- Validate required fields
  if not data.username or not data.email or not data.password or not data.role then
    return nil, "Missing required fields: username, email, password, role"
  end
  
  -- Validate username format
  local username_valid, username_err = security.validate_username_format(data.username)
  if not username_valid then
    return nil, username_err
  end
  
  -- Validate email format
  if not security.validate_email_format(data.email) then
    return nil, "Invalid email format"
  end
  
  -- Validate password strength
  local password_valid, password_err = security.validate_password_strength(data.password)
  if not password_valid then
    return nil, password_err
  end
  
  -- Validate role
  local valid_roles = {Admin = true, Pastor = true, Member = true}
  if not valid_roles[data.role] then
    return nil, "Invalid role. Must be Admin, Pastor, or Member"
  end
  
  -- Hash password
  local password_hash = security.hash_password(data.password)
  
  local conn, env = User.get_connection()
  
  -- Check if username already exists
  local cursor = conn:execute(string.format("SELECT id FROM users WHERE username = '%s'", 
    security.sanitize_input(data.username)))
  local existing_user = cursor:fetch()
  cursor:close()
  
  if existing_user then
    conn:close()
    env:close()
    return nil, "Username already exists"
  end
  
  -- Check if email already exists
  cursor = conn:execute(string.format("SELECT id FROM users WHERE email = '%s'", 
    security.sanitize_input(data.email)))
  local existing_email = cursor:fetch()
  cursor:close()
  
  if existing_email then
    conn:close()
    env:close()
    return nil, "Email already exists"
  end
  
  -- Validate member_id if provided
  if data.member_id then
    cursor = conn:execute(string.format("SELECT id FROM members WHERE id = %d", tonumber(data.member_id)))
    local member_exists = cursor:fetch()
    cursor:close()
    
    if not member_exists then
      conn:close()
      env:close()
      return nil, "Invalid member_id: member does not exist"
    end
  end
  
  -- Insert new user
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO users (username, email, password_hash, role, member_id, is_active, password_reset_required) VALUES ('%s', '%s', '%s', '%s', %s, %d, %d)",
      security.sanitize_input(data.username),
      security.sanitize_input(data.email),
      password_hash:gsub("'", "''"),
      data.role,
      data.member_id and tonumber(data.member_id) or "NULL",
      data.is_active ~= false and 1 or 0,
      data.password_reset_required and 1 or 0
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create user: " .. (err or "Unknown error")
  end
  
  -- Get the inserted user
  cursor = conn:execute("SELECT * FROM users WHERE rowid = last_insert_rowid()")
  local user = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  -- Convert boolean fields using normalize_boolean
  if user then
    user.is_active = validation.normalize_boolean(user.is_active)
    user.password_reset_required = validation.normalize_boolean(user.password_reset_required)
    -- Remove password hash from returned user
    user.password_hash = nil
  end
  
  return user
end

-- Authenticate user with username and password
function User.authenticate(username, password)
  if not username or not password then
    return nil, "Username and password are required"
  end
  
  local conn, env = User.get_connection()
  
  -- Find user by username
  local cursor = conn:execute(string.format("SELECT * FROM users WHERE username = '%s'", 
    security.sanitize_input(username)))
  local user = cursor:fetch({}, "a")
  cursor:close()
  
  if not user then
    conn:close()
    env:close()
    return nil, "Invalid username or password"
  end
  
  -- Check if user is active using normalized boolean check
  if not validation.normalize_boolean(user.is_active) then
    conn:close()
    env:close()
    return nil, "Account is deactivated"
  end
  
  -- Verify password
  if not security.verify_password(password, user.password_hash) then
    -- Increment failed login attempts
    User.increment_failed_attempts(tonumber(user.id))
    conn:close()
    env:close()
    return nil, "Invalid username or password"
  end
  
  -- Reset failed login attempts and update last login
  User.reset_failed_attempts(tonumber(user.id))
  conn:execute(string.format("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = %d", tonumber(user.id)))
  
  conn:close()
  env:close()
  
  -- Convert boolean fields and remove password hash
  user.is_active = (user.is_active == "1" or user.is_active == 1)
  user.password_reset_required = (user.password_reset_required == "1" or user.password_reset_required == 1)
  user.password_hash = nil
  
  return user
end

-- Find user by username
function User.find_by_username(username)
  if not username then
    return nil
  end
  
  local conn, env = User.get_connection()
  local cursor = conn:execute(string.format("SELECT * FROM users WHERE username = '%s'", 
    security.sanitize_input(username)))
  local user = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  if user then
    user.is_active = (user.is_active == "1" or user.is_active == 1)
    user.password_reset_required = (user.password_reset_required == "1" or user.password_reset_required == 1)
    user.password_hash = nil  -- Don't expose password hash
  end
  
  return user
end

-- Find user by email
function User.find_by_email(email)
  if not email then
    return nil
  end
  
  local conn, env = User.get_connection()
  local cursor = conn:execute(string.format("SELECT * FROM users WHERE email = '%s'", 
    security.sanitize_input(email)))
  local user = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  if user then
    user.is_active = (user.is_active == "1" or user.is_active == 1)
    user.password_reset_required = (user.password_reset_required == "1" or user.password_reset_required == 1)
    user.password_hash = nil  -- Don't expose password hash
  end
  
  return user
end

-- Find user by ID
function User.find_by_id(id)
  if not id then
    return nil
  end
  
  local conn, env = User.get_connection()
  local cursor = conn:execute(string.format("SELECT * FROM users WHERE id = %d", tonumber(id)))
  local user = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  if user then
    user.is_active = (user.is_active == "1" or user.is_active == 1)
    user.password_reset_required = (user.password_reset_required == "1" or user.password_reset_required == 1)
    user.password_hash = nil  -- Don't expose password hash
  end
  
  return user
end

-- Update user password
function User.update_password(user_id, new_password)
  if not user_id or not new_password then
    return nil, "User ID and new password are required"
  end
  
  -- Validate password strength
  local password_valid, password_err = security.validate_password_strength(new_password)
  if not password_valid then
    return nil, password_err
  end
  
  local conn, env = User.get_connection()
  
  -- Check if user exists
  local cursor = conn:execute(string.format("SELECT id FROM users WHERE id = %d", tonumber(user_id)))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "User not found"
  end
  
  -- Hash new password
  local password_hash = security.hash_password(new_password)
  
  -- Update password and reset password_reset_required flag
  conn:execute(string.format(
    "UPDATE users SET password_hash = '%s', password_reset_required = 0 WHERE id = %d",
    password_hash:gsub("'", "''"),
    tonumber(user_id)
  ))
  
  conn:close()
  env:close()
  
  return true
end

-- Increment failed login attempts
function User.increment_failed_attempts(user_id)
  if not user_id then
    return false
  end
  
  local conn, env = User.get_connection()
  
  -- Increment failed attempts
  conn:execute(string.format(
    "UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE id = %d",
    tonumber(user_id)
  ))
  
  -- Check if user should be deactivated (after 5 failed attempts)
  local cursor = conn:execute(string.format(
    "SELECT failed_login_attempts FROM users WHERE id = %d", tonumber(user_id)))
  local result = cursor:fetch({}, "a")
  cursor:close()
  
  if result and tonumber(result.failed_login_attempts) >= 5 then
    conn:execute(string.format("UPDATE users SET is_active = 0 WHERE id = %d", tonumber(user_id)))
  end
  
  conn:close()
  env:close()
  
  return true
end

-- Reset failed login attempts
function User.reset_failed_attempts(user_id)
  if not user_id then
    return false
  end
  
  local conn, env = User.get_connection()
  
  conn:execute(string.format(
    "UPDATE users SET failed_login_attempts = 0 WHERE id = %d",
    tonumber(user_id)
  ))
  
  conn:close()
  env:close()
  
  return true
end

-- Deactivate user account
function User.deactivate(user_id)
  if not user_id then
    return nil, "User ID is required"
  end
  
  local conn, env = User.get_connection()
  
  -- Check if user exists
  local cursor = conn:execute(string.format("SELECT id FROM users WHERE id = %d", tonumber(user_id)))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "User not found"
  end
  
  -- Deactivate user
  conn:execute(string.format("UPDATE users SET is_active = 0 WHERE id = %d", tonumber(user_id)))
  
  conn:close()
  env:close()
  
  return true
end

-- Activate user account
function User.activate(user_id)
  if not user_id then
    return nil, "User ID is required"
  end
  
  local conn, env = User.get_connection()
  
  -- Check if user exists
  local cursor = conn:execute(string.format("SELECT id FROM users WHERE id = %d", tonumber(user_id)))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "User not found"
  end
  
  -- Activate user and reset failed attempts
  conn:execute(string.format(
    "UPDATE users SET is_active = 1, failed_login_attempts = 0 WHERE id = %d", 
    tonumber(user_id)
  ))
  
  conn:close()
  env:close()
  
  return true
end

-- Find all users (for admin operations)
function User.find_all()
  local conn, env = User.get_connection()
  local cursor = conn:execute("SELECT * FROM users ORDER BY id")
  
  local users = {}
  local row = cursor:fetch({}, "a")
  while row do
    -- Convert boolean fields and remove password hash
    row.is_active = (row.is_active == "1" or row.is_active == 1)
    row.password_reset_required = (row.password_reset_required == "1" or row.password_reset_required == 1)
    row.password_hash = nil
    table.insert(users, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return users
end

-- Update user (for admin operations)
function User.update(user_id, data)
  if not user_id then
    return nil, "User ID is required"
  end
  
  local conn, env = User.get_connection()
  
  -- Check if user exists
  local cursor = conn:execute(string.format("SELECT id FROM users WHERE id = %d", tonumber(user_id)))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "User not found"
  end
  
  -- Build update query dynamically
  local updates = {}
  
  if data.username then
    local username_valid, username_err = security.validate_username_format(data.username)
    if not username_valid then
      conn:close()
      env:close()
      return nil, username_err
    end
    
    -- Check if username already exists for another user
    cursor = conn:execute(string.format(
      "SELECT id FROM users WHERE username = '%s' AND id != %d", 
      security.sanitize_input(data.username), tonumber(user_id)))
    local existing_user = cursor:fetch()
    cursor:close()
    
    if existing_user then
      conn:close()
      env:close()
      return nil, "Username already exists"
    end
    
    table.insert(updates, string.format("username = '%s'", security.sanitize_input(data.username)))
  end
  
  if data.email then
    if not security.validate_email_format(data.email) then
      conn:close()
      env:close()
      return nil, "Invalid email format"
    end
    
    -- Check if email already exists for another user
    cursor = conn:execute(string.format(
      "SELECT id FROM users WHERE email = '%s' AND id != %d", 
      security.sanitize_input(data.email), tonumber(user_id)))
    local existing_email = cursor:fetch()
    cursor:close()
    
    if existing_email then
      conn:close()
      env:close()
      return nil, "Email already exists"
    end
    
    table.insert(updates, string.format("email = '%s'", security.sanitize_input(data.email)))
  end
  
  if data.role then
    local valid_roles = {Admin = true, Pastor = true, Member = true}
    if not valid_roles[data.role] then
      conn:close()
      env:close()
      return nil, "Invalid role. Must be Admin, Pastor, or Member"
    end
    table.insert(updates, string.format("role = '%s'", data.role))
  end
  
  if data.member_id ~= nil then
    if data.member_id then
      cursor = conn:execute(string.format("SELECT id FROM members WHERE id = %d", tonumber(data.member_id)))
      local member_exists = cursor:fetch()
      cursor:close()
      
      if not member_exists then
        conn:close()
        env:close()
        return nil, "Invalid member_id: member does not exist"
      end
      table.insert(updates, string.format("member_id = %d", tonumber(data.member_id)))
    else
      table.insert(updates, "member_id = NULL")
    end
  end
  
  if data.is_active ~= nil then
    table.insert(updates, string.format("is_active = %d", data.is_active and 1 or 0))
  end
  
  if data.password_reset_required ~= nil then
    table.insert(updates, string.format("password_reset_required = %d", data.password_reset_required and 1 or 0))
  end
  
  if #updates == 0 then
    conn:close()
    env:close()
    return nil, "No valid fields to update"
  end
  
  -- Execute update
  conn:execute(string.format("UPDATE users SET %s WHERE id = %d", 
    table.concat(updates, ", "), tonumber(user_id)))
  
  -- Get updated user
  cursor = conn:execute(string.format("SELECT * FROM users WHERE id = %d", tonumber(user_id)))
  local user = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  if user then
    user.is_active = (user.is_active == "1" or user.is_active == 1)
    user.password_reset_required = (user.password_reset_required == "1" or user.password_reset_required == 1)
    user.password_hash = nil
  end
  
  return user
end

-- Delete user (soft delete by deactivation)
function User.delete(user_id)
  return User.deactivate(user_id)
end

return User