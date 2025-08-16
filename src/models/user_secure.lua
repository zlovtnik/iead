-- src/models/user_secure.lua
-- Secure User model using parameterized queries and proper validation

local db = require("src.infrastructure.db.connection")
local security = require("src.utils.security")
local validator = require("src.application.validators.input_validator")
local log = require("src.utils.log")

local User = {}

-- Initialize database and create users table if it doesn't exist
function User.init_db()
  local queries = {
    {[[
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
    ]], {}},
    
    {[[CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)]], {}},
    {[[CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)]], {}},
    {[[CREATE INDEX IF NOT EXISTS idx_users_member_id ON users(member_id)]], {}},
    {[[CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)]], {}},
    {[[CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active)]], {}}
  }
  
  local success, err = db.transaction(queries)
  if not success then
    log.error("Failed to initialize users table", {error = err})
    return false, err
  end
  
  return true
end

-- Validate user data
-- @param data table User data to validate
-- @param is_update boolean Whether this is an update operation
-- @return table sanitized data, table errors
function User.validate_user_data(data, is_update)
  local schema = {
    username = {
      required = not is_update,
      pattern = "^[%w_%-%.]+$",
      min_length = 3,
      max_length = 50
    },
    email = {
      required = not is_update,
      pattern = "^[%w._%+-]+@[%w.-]+%.%w+$",
      min_length = 5,
      max_length = 254
    },
    password = is_update and {} or {
      required = true,
      min_length = 8,
      max_length = 128,
      require_uppercase = true,
      require_lowercase = true,
      require_digit = true
    },
    role = {
      required = not is_update,
      allowed_values = {"Admin", "Pastor", "Member"}
    },
    member_id = {
      pattern = "^%d+$",
      min_value = 1
    }
  }
  
  return validator.validate_request(data, schema)
end

-- Create new user with secure validation
-- @param data table User data
-- @return table user, string error
function User.create(data)
  -- Validate input data
  local sanitized_data, validation_errors = User.validate_user_data(data, false)
  if validation_errors then
    return nil, "Validation failed: " .. table.concat(validation_errors, ", ")
  end
  
  -- Check if username already exists
  local existing_user, err = db.query_one(
    "SELECT id FROM users WHERE username = ?", 
    {sanitized_data.username}
  )
  if err then
    log.error("Database error checking username", {error = err, username = sanitized_data.username})
    return nil, "Database error occurred"
  end
  if existing_user then
    return nil, "Username already exists"
  end
  
  -- Check if email already exists
  existing_user, err = db.query_one(
    "SELECT id FROM users WHERE email = ?", 
    {sanitized_data.email}
  )
  if err then
    log.error("Database error checking email", {error = err, email = sanitized_data.email})
    return nil, "Database error occurred"
  end
  if existing_user then
    return nil, "Email already exists"
  end
  
  -- Validate member_id if provided
  if sanitized_data.member_id then
    local member_exists, err = db.query_one(
      "SELECT id FROM members WHERE id = ?", 
      {tonumber(sanitized_data.member_id)}
    )
    if err then
      log.error("Database error checking member", {error = err, member_id = sanitized_data.member_id})
      return nil, "Database error occurred"
    end
    if not member_exists then
      return nil, "Invalid member_id: member does not exist"
    end
  end
  
  -- Hash password
  local password_hash = security.hash_password(sanitized_data.password)
  
  -- Insert new user
  local affected_rows, err = db.execute(
    [[INSERT INTO users (username, email, password_hash, role, member_id, is_active, password_reset_required) 
      VALUES (?, ?, ?, ?, ?, ?, ?)]],
    {
      sanitized_data.username,
      sanitized_data.email,
      password_hash,
      sanitized_data.role,
      sanitized_data.member_id and tonumber(sanitized_data.member_id) or nil,
      sanitized_data.is_active ~= false and 1 or 0,
      sanitized_data.password_reset_required and 1 or 0
    }
  )
  
  if not affected_rows or err then
    log.error("Failed to create user", {error = err, username = sanitized_data.username})
    return nil, "Failed to create user: " .. (err or "Unknown error")
  end
  
  -- Get the created user
  local user_id, err = db.last_insert_id()
  if not user_id or err then
    log.error("Failed to get new user ID", {error = err})
    return nil, "Failed to retrieve created user"
  end
  
  -- Fetch and return the created user (without password hash)
  local user, err = User.get_by_id(user_id)
  if not user or err then
    log.error("Failed to fetch created user", {error = err, user_id = user_id})
    return nil, "User created but failed to fetch: " .. (err or "Unknown error")
  end
  
  log.info("User created successfully", {user_id = user_id, username = sanitized_data.username})
  return user, nil
end

-- Authenticate user with secure password verification
-- @param username string Username
-- @param password string Plain text password
-- @return table user, string error
function User.authenticate(username, password)
  if not username or not password then
    return nil, "Username and password are required"
  end
  
  -- Sanitize username input
  username = validator.sanitize_string(username, 50)
  password = validator.sanitize_string(password, 128)
  
  -- Get user by username
  local user, err = db.query_one(
    "SELECT * FROM users WHERE username = ? AND is_active = 1", 
    {username}
  )
  
  if err then
    log.error("Database error during authentication", {error = err, username = username})
    return nil, "Authentication error occurred"
  end
  
  if not user then
    log.warn("Authentication failed - user not found", {username = username})
    return nil, "Invalid username or password"
  end
  
  -- Check password
  if not security.verify_password(password, user.password_hash) then
    log.warn("Authentication failed - invalid password", {username = username, user_id = user.id})
    
    -- Increment failed login attempts
    db.execute(
      "UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE id = ?",
      {user.id}
    )
    
    return nil, "Invalid username or password"
  end
  
  -- Reset failed login attempts and update last login
  db.execute(
    "UPDATE users SET failed_login_attempts = 0, last_login = CURRENT_TIMESTAMP WHERE id = ?",
    {user.id}
  )
  
  -- Convert boolean fields and remove password hash
  user.is_active = user.is_active == 1
  user.password_reset_required = user.password_reset_required == 1
  user.password_hash = nil
  
  log.info("User authenticated successfully", {username = username, user_id = user.id})
  return user, nil
end

-- Get user by ID
-- @param id number User ID
-- @return table user, string error
function User.get_by_id(id)
  if not id or type(id) ~= "number" then
    return nil, "Invalid user ID"
  end
  
  local user, err = db.query_one(
    "SELECT * FROM users WHERE id = ?", 
    {id}
  )
  
  if err then
    log.error("Database error getting user by ID", {error = err, user_id = id})
    return nil, "Database error occurred"
  end
  
  if not user then
    return nil, "User not found"
  end
  
  -- Convert boolean fields and remove password hash
  user.is_active = user.is_active == 1
  user.password_reset_required = user.password_reset_required == 1
  user.password_hash = nil
  
  return user, nil
end

-- Get user by username
-- @param username string Username
-- @return table user, string error
function User.get_by_username(username)
  if not username then
    return nil, "Username is required"
  end
  
  username = validator.sanitize_string(username, 50)
  
  local user, err = db.query_one(
    "SELECT * FROM users WHERE username = ?", 
    {username}
  )
  
  if err then
    log.error("Database error getting user by username", {error = err, username = username})
    return nil, "Database error occurred"
  end
  
  if not user then
    return nil, "User not found"
  end
  
  -- Convert boolean fields and remove password hash
  user.is_active = user.is_active == 1
  user.password_reset_required = user.password_reset_required == 1
  user.password_hash = nil
  
  return user, nil
end

-- Get user by email
-- @param email string Email address
-- @return table user, string error
function User.get_by_email(email)
  if not email then
    return nil, "Email is required"
  end
  
  email = validator.sanitize_string(email, 254)
  
  local user, err = db.query_one(
    "SELECT * FROM users WHERE email = ?", 
    {email}
  )
  
  if err then
    log.error("Database error getting user by email", {error = err, email = email})
    return nil, "Database error occurred"
  end
  
  if not user then
    return nil, "User not found"
  end
  
  -- Convert boolean fields and remove password hash
  user.is_active = user.is_active == 1
  user.password_reset_required = user.password_reset_required == 1
  user.password_hash = nil
  
  return user, nil
end

-- Update user password
-- @param user_id number User ID
-- @param new_password string New password
-- @return boolean success, string error
function User.update_password(user_id, new_password)
  if not user_id or not new_password then
    return false, "User ID and new password are required"
  end
  
  -- Validate password
  local _, validation_errors = validator.validate_field(new_password, {
    min_length = 8,
    max_length = 128,
    require_uppercase = true,
    require_lowercase = true,
    require_digit = true
  }, "password")
  
  if validation_errors then
    return false, validation_errors
  end
  
  -- Check if user exists
  local user_exists, err = db.query_one(
    "SELECT id FROM users WHERE id = ?", 
    {user_id}
  )
  
  if err then
    log.error("Database error checking user for password update", {error = err, user_id = user_id})
    return false, "Database error occurred"
  end
  
  if not user_exists then
    return false, "User not found"
  end
  
  -- Hash new password
  local password_hash = security.hash_password(new_password)
  
  -- Update password
  local affected_rows, err = db.execute(
    "UPDATE users SET password_hash = ?, password_reset_required = 0, failed_login_attempts = 0 WHERE id = ?",
    {password_hash, user_id}
  )
  
  if not affected_rows or err then
    log.error("Failed to update password", {error = err, user_id = user_id})
    return false, "Failed to update password: " .. (err or "Unknown error")
  end
  
  log.info("Password updated successfully", {user_id = user_id})
  return true, nil
end

-- Deactivate user account
-- @param user_id number User ID
-- @return boolean success, string error
function User.deactivate(user_id)
  if not user_id then
    return false, "User ID is required"
  end
  
  local affected_rows, err = db.execute(
    "UPDATE users SET is_active = 0 WHERE id = ?",
    {user_id}
  )
  
  if not affected_rows or err then
    log.error("Failed to deactivate user", {error = err, user_id = user_id})
    return false, "Failed to deactivate user: " .. (err or "Unknown error")
  end
  
  log.info("User deactivated successfully", {user_id = user_id})
  return true, nil
end

-- List all users with pagination
-- @param offset number Number of records to skip
-- @param limit number Maximum number of records to return
-- @return table users, string error
function User.list(offset, limit)
  offset = offset or 0
  limit = limit or 50
  
  -- Ensure reasonable limits
  if limit > 100 then limit = 100 end
  if offset < 0 then offset = 0 end
  
  local users, err = db.query_all(
    [[SELECT id, username, email, role, member_id, is_active, 
             failed_login_attempts, last_login, password_reset_required, created_at 
      FROM users 
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?]],
    {limit, offset}
  )
  
  if err then
    log.error("Database error listing users", {error = err})
    return nil, "Database error occurred"
  end
  
  -- Convert boolean fields for all users
  for _, user in ipairs(users) do
    user.is_active = user.is_active == 1
    user.password_reset_required = user.password_reset_required == 1
  end
  
  return users, nil
end

-- Get user count
-- @return number count, string error
function User.count()
  local result, err = db.query_one("SELECT COUNT(*) as count FROM users", {})
  
  if err then
    log.error("Database error counting users", {error = err})
    return nil, "Database error occurred"
  end
  
  return result.count, nil
end

return User
