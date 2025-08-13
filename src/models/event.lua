-- src/models/event.lua
-- Event model for Church Management System

local luasql = require("luasql.sqlite3")
local db_config = require("src.config.database")

local Event = {}

-- Initialize database and create table if it doesn't exist
function Event.init_db()
  local env = luasql.sqlite3()
  local conn = env:connect(db_config.db_file)
  
  -- Create events table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT,
      start_date DATETIME NOT NULL,
      end_date DATETIME,
      location TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ]]
  
  conn:close()
  env:close()
  
  print("Events table initialized")
end

-- Get database connection
function Event.get_connection()
  local env = luasql.sqlite3()
  return env:connect(db_config.db_file), env
end

-- Find all events
function Event.find_all()
  local conn, env = Event.get_connection()
  local cursor = conn:execute("SELECT * FROM events ORDER BY start_date DESC")
  
  local events = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(events, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return events
end

-- Find event by ID
function Event.find_by_id(id)
  local conn, env = Event.get_connection()
  local cursor = conn:execute(string.format("SELECT * FROM events WHERE id = %d", id))
  local event = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  return event
end

-- Create new event
function Event.create(data)
  if not data.title or not data.start_date then
    return nil, "Missing required fields"
  end
  
  local conn, env = Event.get_connection()
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO events (title, description, start_date, end_date, location) VALUES ('%s', '%s', '%s', '%s', '%s')",
      data.title:gsub("'", "''"),
      (data.description or ""):gsub("'", "''"),
      data.start_date:gsub("'", "''"),
      (data.end_date or ""):gsub("'", "''"),
      (data.location or ""):gsub("'", "''")
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create event: " .. (err or "Unknown error")
  end
  
  -- Get the inserted event
  local cursor = conn:execute("SELECT * FROM events WHERE rowid = last_insert_rowid()")
  local event = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return event
end

-- Update event
function Event.update(id, data)
  if not data.title or not data.start_date then
    return nil, "Missing required fields"
  end
  
  local conn, env = Event.get_connection()
  
  -- Check if event exists
  local cursor = conn:execute(string.format("SELECT id FROM events WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Event not found"
  end
  
  -- Update event
  conn:execute(string.format(
    "UPDATE events SET title = '%s', description = '%s', start_date = '%s', end_date = '%s', location = '%s' WHERE id = %d",
    data.title:gsub("'", "''"),
    (data.description or ""):gsub("'", "''"),
    data.start_date:gsub("'", "''"),
    (data.end_date or ""):gsub("'", "''"),
    (data.location or ""):gsub("'", "''"),
    id
  ))
  
  -- Get updated event
  cursor = conn:execute(string.format("SELECT * FROM events WHERE id = %d", id))
  local event = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return event
end

-- Delete event
function Event.delete(id)
  local conn, env = Event.get_connection()
  
  -- Check if event exists
  local cursor = conn:execute(string.format("SELECT id FROM events WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Event not found"
  end
  
  -- Delete event
  conn:execute(string.format("DELETE FROM events WHERE id = %d", id))
  conn:close()
  env:close()
  
  return true
end

-- Find upcoming events
function Event.find_upcoming()
  local conn, env = Event.get_connection()
  local cursor = conn:execute("SELECT * FROM events WHERE start_date > datetime('now') ORDER BY start_date ASC")
  
  local events = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(events, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return events
end

return Event
