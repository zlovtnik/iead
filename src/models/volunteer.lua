-- src/models/volunteer.lua
-- Volunteer model for Church Management System

local luasql = require("luasql.sqlite3")
local db_config = require("src.config.database")

local Volunteer = {}

-- Initialize database and create table if it doesn't exist
function Volunteer.init_db()
  local env = luasql.sqlite3()
  local conn = env:connect(db_config.db_file)
  
  -- Create volunteers table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS volunteers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      event_id INTEGER,
      start_date DATE NOT NULL,
      end_date DATE,
      status TEXT NOT NULL, -- active, inactive, pending
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL
    )
  ]]
  
  conn:close()
  env:close()
  
  print("Volunteers table initialized")
end

-- Get database connection
function Volunteer.get_connection()
  local env = luasql.sqlite3()
  return env:connect(db_config.db_file), env
end

-- Find all volunteers
function Volunteer.find_all()
  local conn, env = Volunteer.get_connection()
  local cursor = conn:execute([[
    SELECT v.*, m.name as member_name, e.title as event_title
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
    LEFT JOIN events e ON v.event_id = e.id
    ORDER BY v.role, m.name
  ]])
  
  local volunteers = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(volunteers, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return volunteers
end

-- Find volunteer by ID
function Volunteer.find_by_id(id)
  local conn, env = Volunteer.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT v.*, m.name as member_name, e.title as event_title
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
    LEFT JOIN events e ON v.event_id = e.id
    WHERE v.id = %d
  ]], id))
  
  local volunteer = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  return volunteer
end

-- Find volunteers by member
function Volunteer.find_by_member(member_id)
  local conn, env = Volunteer.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT v.*, m.name as member_name, e.title as event_title
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
    LEFT JOIN events e ON v.event_id = e.id
    WHERE v.member_id = %d
    ORDER BY v.start_date DESC
  ]], member_id))
  
  local volunteers = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(volunteers, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return volunteers
end

-- Find volunteers by event
function Volunteer.find_by_event(event_id)
  local conn, env = Volunteer.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT v.*, m.name as member_name, e.title as event_title
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
    LEFT JOIN events e ON v.event_id = e.id
    WHERE v.event_id = %d
    ORDER BY v.role, m.name
  ]], event_id))
  
  local volunteers = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(volunteers, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return volunteers
end

-- Create new volunteer
function Volunteer.create(data)
  if not data.member_id or not data.role or not data.start_date or not data.status then
    return nil, "Missing required fields"
  end
  
  local conn, env = Volunteer.get_connection()
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO volunteers (member_id, role, event_id, start_date, end_date, status, notes) VALUES (%d, '%s', %s, '%s', %s, '%s', '%s')",
      tonumber(data.member_id),
      data.role:gsub("'", "''"),
      data.event_id and tonumber(data.event_id) or "NULL",
      data.start_date:gsub("'", "''"),
      data.end_date and ("'" .. data.end_date:gsub("'", "''") .. "'") or "NULL",
      data.status:gsub("'", "''"),
      (data.notes or ""):gsub("'", "''")
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create volunteer record: " .. (err or "Unknown error")
  end
  
  -- Get the inserted record
  local cursor = conn:execute("SELECT * FROM volunteers WHERE rowid = last_insert_rowid()")
  local volunteer = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return volunteer
end

-- Update volunteer
function Volunteer.update(id, data)
  if not data.role or not data.status then
    return nil, "Missing required fields"
  end
  
  local conn, env = Volunteer.get_connection()
  
  -- Check if volunteer exists
  local cursor = conn:execute(string.format("SELECT id FROM volunteers WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Volunteer record not found"
  end
  
  -- Update volunteer
  conn:execute(string.format(
    "UPDATE volunteers SET role = '%s', event_id = %s, start_date = '%s', end_date = %s, status = '%s', notes = '%s' WHERE id = %d",
    data.role:gsub("'", "''"),
    data.event_id and tonumber(data.event_id) or "NULL",
    data.start_date:gsub("'", "''"),
    data.end_date and ("'" .. data.end_date:gsub("'", "''") .. "'") or "NULL",
    data.status:gsub("'", "''"),
    (data.notes or ""):gsub("'", "''"),
    id
  ))
  
  -- Get updated volunteer
  cursor = conn:execute(string.format("SELECT * FROM volunteers WHERE id = %d", id))
  local volunteer = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return volunteer
end

-- Delete volunteer
function Volunteer.delete(id)
  local conn, env = Volunteer.get_connection()
  
  -- Check if volunteer exists
  local cursor = conn:execute(string.format("SELECT id FROM volunteers WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Volunteer record not found"
  end
  
  -- Delete volunteer
  conn:execute(string.format("DELETE FROM volunteers WHERE id = %d", id))
  conn:close()
  env:close()
  
  return true
end

return Volunteer
