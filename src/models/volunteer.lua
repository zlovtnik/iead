-- src/models/volunteer.lua
-- Volunteer model for Church Management System

local luasql = require("luasql.postgres")
local db_config = require("src.config.database")

local Volunteer = {}

-- Initialize database and create table if it doesn't exist
function Volunteer.init_db()
  local env = luasql.postgres()
  local conn = env:connect(db_config.database, db_config.user, db_config.password, db_config.host, db_config.port)

  -- Create volunteers table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS volunteers (
      id SERIAL PRIMARY KEY,
      member_id INTEGER NOT NULL,
      event_id INTEGER,
      role TEXT NOT NULL,
      hours INTEGER DEFAULT 0,
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
    )
  ]]

  conn:close()
  env:close()

  print("Volunteers table initialized")
end

-- Get database connection
function Volunteer.get_connection()
  local env = luasql.postgres()
  return env:connect(db_config.database, db_config.user, db_config.password, db_config.host, db_config.port), env
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
    ORDER BY v.created_at DESC
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
  if not data.member_id or not data.role then
    return nil, "Missing required fields"
  end
  
  local conn, env = Volunteer.get_connection()
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO volunteers (member_id, event_id, role, hours, notes) VALUES (%d, %s, '%s', %d, '%s')",
      tonumber(data.member_id),
      data.event_id and tonumber(data.event_id) or "NULL",
      data.role:gsub("'", "''"),
      tonumber(data.hours) or 0,
      (data.notes or ""):gsub("'", "''")
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create volunteer record: " .. (err or "Unknown error")
  end
  
  -- Get the inserted record
  local cursor = conn:execute("SELECT * FROM volunteers WHERE id = currval('volunteers_id_seq')")
  local volunteer = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return volunteer
end

-- Update volunteer
function Volunteer.update(id, data)
  if not data.role then
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
    "UPDATE volunteers SET member_id = %d, event_id = %s, role = '%s', hours = %d, notes = '%s' WHERE id = %d",
    tonumber(data.member_id),
    data.event_id and tonumber(data.event_id) or "NULL",
    data.role:gsub("'", "''"),
    tonumber(data.hours) or 0,
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

-- Calculate total hours by member
function Volunteer.total_hours_by_member(member_id)
  local conn, env = Volunteer.get_connection()
  local cursor = conn:execute(string.format(
    "SELECT COALESCE(SUM(hours), 0) as total FROM volunteers WHERE member_id = %d",
    member_id
  ))
  
  local row = cursor:fetch({}, "a")
  local total = row and row.total or 0
  
  cursor:close()
  conn:close()
  env:close()
  
  return total
end

return Volunteer
