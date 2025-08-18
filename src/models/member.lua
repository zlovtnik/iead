-- src/models/member.lua
-- Member model for Church Management System

local luasql = require("luasql.postgres")
local db_config = require("src.config.database")

local Member = {}

-- Initialize database and create table if it doesn't exist
function Member.init_db()
  local env = luasql.postgres()
  local conn = env:connect(db_config.database, db_config.user, db_config.password, db_config.host, db_config.port)

  -- Create members table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS members (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      phone TEXT,
      salary DECIMAL(10,2),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ]]

  conn:close()
  env:close()

  print("Database initialized: " .. db_config.database)
end

-- Get database connection
function Member.get_connection()
  local env = luasql.postgres()
  return env:connect(db_config.database, db_config.user, db_config.password, db_config.host, db_config.port), env
end

-- Find all members
function Member.find_all()
  local conn, env = Member.get_connection()
  local cursor = conn:execute("SELECT * FROM members ORDER BY id")

  local members = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(members, row)
    row = cursor:fetch({}, "a")
  end

  cursor:close()
  conn:close()
  env:close()

  return members
end

-- Find member by ID
function Member.find_by_id(id)
  local conn, env = Member.get_connection()
  local cursor = conn:execute(string.format("SELECT * FROM members WHERE id = %d", id))
  local member = cursor:fetch({}, "a")

  cursor:close()
  conn:close()
  env:close()

  return member
end

-- Create new member
function Member.create(data)
  if not data.name or not data.email then
    return nil, "Missing required fields"
  end

  local conn, env = Member.get_connection()
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO members (name, email, phone, salary) VALUES ('%s', '%s', '%s', %s)",
      data.name:gsub("'", "''"),
      data.email:gsub("'", "''"),
      (data.phone or ""):gsub("'", "''"),
      data.salary and tonumber(data.salary) or "NULL"
    ))
  end)

  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create member: " .. (err or "Unknown error")
  end

  -- Get the inserted member
  local cursor = conn:execute("SELECT * FROM members WHERE id = currval('members_id_seq')")
  local member = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()

  return member
end

-- Update member
function Member.update(id, data)
  if not data.name or not data.email then
    return nil, "Missing required fields"
  end

  local conn, env = Member.get_connection()

  -- Check if member exists
  local cursor = conn:execute(string.format("SELECT id FROM members WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()

  if not exists then
    conn:close()
    env:close()
    return nil, "Member not found"
  end

  -- Update member
  conn:execute(string.format(
    "UPDATE members SET name = '%s', email = '%s', phone = '%s', salary = %s WHERE id = %d",
    data.name:gsub("'", "''"),
    data.email:gsub("'", "''"),
    (data.phone or ""):gsub("'", "''"),
    data.salary and tonumber(data.salary) or "NULL",
    id
  ))

  -- Get updated member
  cursor = conn:execute(string.format("SELECT * FROM members WHERE id = %d", id))
  local member = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()

  return member
end

-- Delete member
function Member.delete(id)
  local conn, env = Member.get_connection()

  -- Check if member exists
  local cursor = conn:execute(string.format("SELECT id FROM members WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()

  if not exists then
    conn:close()
    env:close()
    return nil, "Member not found"
  end

  -- Delete member
  conn:execute(string.format("DELETE FROM members WHERE id = %d", id))
  conn:close()
  env:close()

  return true
end

return Member
