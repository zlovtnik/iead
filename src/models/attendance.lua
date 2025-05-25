-- src/models/attendance.lua
-- Attendance model for Church Management System

local luasql = require("luasql.sqlite3")
local db_config = require("src.config.database")

local Attendance = {}

-- Initialize database and create table if it doesn't exist
function Attendance.init_db()
  local env = luasql.sqlite3()
  local conn = env:connect(db_config.db_file)
  
  -- Create attendance table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS attendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      member_id INTEGER NOT NULL,
      status TEXT NOT NULL, -- present, absent, excused
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
      FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
      UNIQUE(event_id, member_id)
    )
  ]]
  
  conn:close()
  env:close()
  
  print("Attendance table initialized")
end

-- Get database connection
function Attendance.get_connection()
  local env = luasql.sqlite3()
  return env:connect(db_config.db_file), env
end

-- Find all attendance records
function Attendance.find_all()
  local conn, env = Attendance.get_connection()
  local cursor = conn:execute([[
    SELECT a.*, e.title as event_title, m.name as member_name 
    FROM attendance a
    JOIN events e ON a.event_id = e.id
    JOIN members m ON a.member_id = m.id
    ORDER BY e.start_date DESC
  ]])
  
  local records = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(records, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return records
end

-- Find attendance by ID
function Attendance.find_by_id(id)
  local conn, env = Attendance.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT a.*, e.title as event_title, m.name as member_name 
    FROM attendance a
    JOIN events e ON a.event_id = e.id
    JOIN members m ON a.member_id = m.id
    WHERE a.id = %d
  ]], id))
  
  local record = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  return record
end

-- Find attendance by event
function Attendance.find_by_event(event_id)
  local conn, env = Attendance.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT a.*, e.title as event_title, m.name as member_name 
    FROM attendance a
    JOIN events e ON a.event_id = e.id
    JOIN members m ON a.member_id = m.id
    WHERE a.event_id = %d
    ORDER BY m.name
  ]], event_id))
  
  local records = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(records, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return records
end

-- Find attendance by member
function Attendance.find_by_member(member_id)
  local conn, env = Attendance.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT a.*, e.title as event_title, m.name as member_name 
    FROM attendance a
    JOIN events e ON a.event_id = e.id
    JOIN members m ON a.member_id = m.id
    WHERE a.member_id = %d
    ORDER BY e.start_date DESC
  ]], member_id))
  
  local records = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(records, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return records
end

-- Create new attendance record
function Attendance.create(data)
  if not data.event_id or not data.member_id or not data.status then
    return nil, "Missing required fields"
  end
  
  local conn, env = Attendance.get_connection()
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO attendance (event_id, member_id, status, notes) VALUES (%d, %d, '%s', '%s')",
      tonumber(data.event_id),
      tonumber(data.member_id),
      data.status:gsub("'", "''"),
      (data.notes or ""):gsub("'", "''")
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create attendance record: " .. (err or "Unknown error")
  end
  
  -- Get the inserted record
  local cursor = conn:execute("SELECT * FROM attendance WHERE rowid = last_insert_rowid()")
  local record = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return record
end

-- Update attendance record
function Attendance.update(id, data)
  if not data.status then
    return nil, "Missing required fields"
  end
  
  local conn, env = Attendance.get_connection()
  
  -- Check if record exists
  local cursor = conn:execute(string.format("SELECT id FROM attendance WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Attendance record not found"
  end
  
  -- Update record
  conn:execute(string.format(
    "UPDATE attendance SET status = '%s', notes = '%s' WHERE id = %d",
    data.status:gsub("'", "''"),
    (data.notes or ""):gsub("'", "''"),
    id
  ))
  
  -- Get updated record
  cursor = conn:execute(string.format("SELECT * FROM attendance WHERE id = %d", id))
  local record = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return record
end

-- Delete attendance record
function Attendance.delete(id)
  local conn, env = Attendance.get_connection()
  
  -- Check if record exists
  local cursor = conn:execute(string.format("SELECT id FROM attendance WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Attendance record not found"
  end
  
  -- Delete record
  conn:execute(string.format("DELETE FROM attendance WHERE id = %d", id))
  conn:close()
  env:close()
  
  return true
end

return Attendance
