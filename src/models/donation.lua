-- src/models/donation.lua
-- Donation model for Church Management System

local luasql = require("luasql.sqlite3")
local db_config = require("src.config.database")

local Donation = {}

-- Initialize database and create table if it doesn't exist
function Donation.init_db()
  local env = luasql.sqlite3()
  local conn = env:connect(db_config.db_file)
  
  -- Create donations table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS donations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER,
      amount DECIMAL(10,2) NOT NULL,
      donation_date DATE NOT NULL,
      payment_method TEXT,
      category TEXT,
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
    )
  ]]
  
  conn:close()
  env:close()
  
  print("Donations table initialized")
end

-- Get database connection
function Donation.get_connection()
  local env = luasql.sqlite3()
  return env:connect(db_config.db_file), env
end

-- Find all donations
function Donation.find_all()
  local conn, env = Donation.get_connection()
  local cursor = conn:execute([[
    SELECT d.*, m.name as member_name 
    FROM donations d
    LEFT JOIN members m ON d.member_id = m.id
    ORDER BY d.donation_date DESC
  ]])
  
  local donations = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(donations, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return donations
end

-- Find donation by ID
function Donation.find_by_id(id)
  local conn, env = Donation.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT d.*, m.name as member_name 
    FROM donations d
    LEFT JOIN members m ON d.member_id = m.id
    WHERE d.id = %d
  ]], id))
  
  local donation = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  return donation
end

-- Find donations by member
function Donation.find_by_member(member_id)
  local conn, env = Donation.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT d.*, m.name as member_name 
    FROM donations d
    LEFT JOIN members m ON d.member_id = m.id
    WHERE d.member_id = %d
    ORDER BY d.donation_date DESC
  ]], member_id))
  
  local donations = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(donations, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return donations
end

-- Create new donation
function Donation.create(data)
  if not data.amount or not data.donation_date then
    return nil, "Missing required fields"
  end
  
  local conn, env = Donation.get_connection()
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO donations (member_id, amount, donation_date, payment_method, category, notes) VALUES (%s, %.2f, '%s', '%s', '%s', '%s')",
      data.member_id and tonumber(data.member_id) or "NULL",
      tonumber(data.amount),
      data.donation_date:gsub("'", "''"),
      (data.payment_method or ""):gsub("'", "''"),
      (data.category or ""):gsub("'", "''"),
      (data.notes or ""):gsub("'", "''")
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create donation: " .. (err or "Unknown error")
  end
  
  -- Get the inserted donation
  local cursor = conn:execute("SELECT * FROM donations WHERE rowid = last_insert_rowid()")
  local donation = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return donation
end

-- Update donation
function Donation.update(id, data)
  if not data.amount or not data.donation_date then
    return nil, "Missing required fields"
  end
  
  local conn, env = Donation.get_connection()
  
  -- Check if donation exists
  local cursor = conn:execute(string.format("SELECT id FROM donations WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Donation not found"
  end
  
  -- Update donation
  conn:execute(string.format(
    "UPDATE donations SET member_id = %s, amount = %.2f, donation_date = '%s', payment_method = '%s', category = '%s', notes = '%s' WHERE id = %d",
    data.member_id and tonumber(data.member_id) or "NULL",
    tonumber(data.amount),
    data.donation_date:gsub("'", "''"),
    (data.payment_method or ""):gsub("'", "''"),
    (data.category or ""):gsub("'", "''"),
    (data.notes or ""):gsub("'", "''"),
    id
  ))
  
  -- Get updated donation
  cursor = conn:execute(string.format("SELECT * FROM donations WHERE id = %d", id))
  local donation = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return donation
end

-- Delete donation
function Donation.delete(id)
  local conn, env = Donation.get_connection()
  
  -- Check if donation exists
  local cursor = conn:execute(string.format("SELECT id FROM donations WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Donation not found"
  end
  
  -- Delete donation
  conn:execute(string.format("DELETE FROM donations WHERE id = %d", id))
  conn:close()
  env:close()
  
  return true
end

-- Calculate total donations by member
function Donation.total_by_member(member_id)
  local conn, env = Donation.get_connection()
  local cursor = conn:execute(string.format(
    "SELECT COALESCE(SUM(amount), 0) as total FROM donations WHERE member_id = %d",
    member_id
  ))
  
  local row = cursor:fetch({}, "a")
  local total = row and row.total or 0
  
  cursor:close()
  conn:close()
  env:close()
  
  return total
end

return Donation
