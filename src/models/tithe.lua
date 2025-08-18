-- src/models/tithe.lua
-- Tithe model for Church Management System

local luasql = require("luasql.postgres")
local db_config = require("src.config.database")

local Tithe = {}

-- Initialize database and create table if it doesn't exist
function Tithe.init_db()
  local env = luasql.postgres()
  local conn = env:connect(db_config.database, db_config.user, db_config.password, db_config.host, db_config.port)

  -- Create tithes table if it doesn't exist
  conn:execute[[
    CREATE TABLE IF NOT EXISTS tithes (
      id SERIAL PRIMARY KEY,
      member_id INTEGER NOT NULL,
      amount DECIMAL(10,2) NOT NULL,
      tithe_date DATE NOT NULL,
      payment_method TEXT,
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
    )
  ]]

  conn:close()
  env:close()

  print("Tithes table initialized")
end

-- Get database connection
function Tithe.get_connection()
  local env = luasql.postgres()
  return env:connect(db_config.database, db_config.user, db_config.password, db_config.host, db_config.port), env
end

-- Find all tithes
function Tithe.find_all()
  local conn, env = Tithe.get_connection()
  local cursor = conn:execute([[
    SELECT t.*, m.name as member_name, m.salary as member_salary 
    FROM tithes t
    JOIN members m ON t.member_id = m.id
    ORDER BY t.tithe_date DESC
  ]])
  
  local tithes = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(tithes, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return tithes
end

-- Find tithe by ID
function Tithe.find_by_id(id)
  local conn, env = Tithe.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT t.*, m.name as member_name, m.salary as member_salary 
    FROM tithes t
    JOIN members m ON t.member_id = m.id
    WHERE t.id = %d
  ]], id))
  
  local tithe = cursor:fetch({}, "a")
  
  cursor:close()
  conn:close()
  env:close()
  
  return tithe
end

-- Find tithes by member
function Tithe.find_by_member(member_id)
  local conn, env = Tithe.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT t.*, m.name as member_name, m.salary as member_salary 
    FROM tithes t
    JOIN members m ON t.member_id = m.id
    WHERE t.member_id = %d
    ORDER BY t.tithe_date DESC
  ]], member_id))
  
  local tithes = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(tithes, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return tithes
end

-- Calculate tithe amount (10% of salary)
function Tithe.calculate_amount(member_id)
  local conn, env = Tithe.get_connection()
  local cursor = conn:execute(string.format([[
    SELECT salary FROM members WHERE id = %d
  ]], member_id))
  
  local member = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  if not member or not member.salary then
    return nil, "Member not found or salary not set"
  end
  
  return tonumber(member.salary) * 0.1 -- 10% of salary
end

-- Create new tithe
function Tithe.create(data)
  if not data.member_id or not data.tithe_date then
    return nil, "Missing required fields"
  end
  
  -- Calculate tithe amount if not provided
  if not data.amount then
    local amount, err = Tithe.calculate_amount(data.member_id)
    if not amount then
      return nil, err
    end
    data.amount = amount
  end
  
  local conn, env = Tithe.get_connection()
  local success, err = pcall(function()
    conn:execute(string.format(
      "INSERT INTO tithes (member_id, amount, tithe_date, payment_method, is_paid, notes) VALUES (%d, %.2f, '%s', '%s', %d, '%s')",
      tonumber(data.member_id),
      tonumber(data.amount),
      data.tithe_date:gsub("'", "''"),
      (data.payment_method or ""):gsub("'", "''"),
      data.is_paid and 1 or 0,
      (data.notes or ""):gsub("'", "''")
    ))
  end)
  
  if not success then
    conn:close()
    env:close()
    return nil, "Failed to create tithe: " .. (err or "Unknown error")
  end
  
  -- Get the inserted tithe
  local cursor = conn:execute("SELECT * FROM tithes WHERE id = currval('tithes_id_seq')")
  local tithe = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return tithe
end

-- Update tithe
function Tithe.update(id, data)
  if not data.member_id or not data.tithe_date then
    return nil, "Missing required fields"
  end
  
  -- Calculate tithe amount if not provided
  if not data.amount then
    local amount, err = Tithe.calculate_amount(data.member_id)
    if not amount then
      return nil, err
    end
    data.amount = amount
  end
  
  local conn, env = Tithe.get_connection()
  
  -- Check if tithe exists
  local cursor = conn:execute(string.format("SELECT id FROM tithes WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Tithe not found"
  end
  
  -- Update tithe
  conn:execute(string.format(
    "UPDATE tithes SET member_id = %d, amount = %.2f, tithe_date = '%s', payment_method = '%s', notes = '%s' WHERE id = %d",
    tonumber(data.member_id),
    tonumber(data.amount),
    data.tithe_date:gsub("'", "''"),
    (data.payment_method or ""):gsub("'", "''"),
    (data.notes or ""):gsub("'", "''"),
    id
  ))
  
  -- Get updated tithe
  cursor = conn:execute(string.format("SELECT * FROM tithes WHERE id = %d", id))
  local tithe = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return tithe
end

-- Delete tithe
function Tithe.delete(id)
  local conn, env = Tithe.get_connection()
  
  -- Check if tithe exists
  local cursor = conn:execute(string.format("SELECT id FROM tithes WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Tithe not found"
  end
  
  -- Delete tithe
  conn:execute(string.format("DELETE FROM tithes WHERE id = %d", id))
  conn:close()
  env:close()
  
  return true
end

-- Generate tithes for all members with salary
function Tithe.generate_monthly_tithes(month, year)
  local conn, env = Tithe.get_connection()
  
  -- Get all members with salary
  local cursor = conn:execute("SELECT id, salary FROM members WHERE salary IS NOT NULL AND salary > 0")
  
  local members = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(members, row)
    row = cursor:fetch({}, "a")
  end
  cursor:close()
  
  -- Format date as YYYY-MM-01
  local tithe_date = string.format("%04d-%02d-01", year, month)
  
  -- Check if tithes already exist for this month
  local results = {}
  for _, member in ipairs(members) do
    cursor = conn:execute(string.format(
      "SELECT id FROM tithes WHERE member_id = %d AND strftime('%%Y-%%m', tithe_date) = strftime('%%Y-%%m', '%s')",
      member.id, tithe_date
    ))
    
    local exists = cursor:fetch()
    cursor:close()
    
    if not exists then
      -- Create tithe for this member
      local tithe_amount = tonumber(member.salary) * 0.1
      
      local success, err = pcall(function()
        conn:execute(string.format(
          "INSERT INTO tithes (member_id, amount, tithe_date, is_paid) VALUES (%d, %.2f, '%s', 0)",
          member.id, tithe_amount, tithe_date
        ))
      end)
      
      if success then
        table.insert(results, {
          member_id = member.id,
          amount = tithe_amount,
          tithe_date = tithe_date,
          created = true
        })
      end
    end
  end
  
  conn:close()
  env:close()
  
  return results
end

-- Calculate monthly tithe for a member (10% of monthly salary)
function Tithe.calculate_monthly_tithe(member_id)
  local Member = require("src.models.member")
  local member = Member.find_by_id(member_id)
  
  if not member or not member.salary then
    return 0
  end
  
  local monthly_salary = tonumber(member.salary) / 12
  local tithe_amount = monthly_salary * 0.1
  
  return math.floor(tithe_amount * 100) / 100 -- Round to 2 decimal places
end

-- Mark tithe as paid
function Tithe.mark_paid(id, payment_method)
  local conn, env = Tithe.get_connection()
  
  -- Check if tithe exists
  local cursor = conn:execute(string.format("SELECT id FROM tithes WHERE id = %d", id))
  local exists = cursor:fetch()
  cursor:close()
  
  if not exists then
    conn:close()
    env:close()
    return nil, "Tithe not found"
  end
  
  -- Mark as paid
  conn:execute(string.format(
    "UPDATE tithes SET is_paid = 1, payment_method = '%s' WHERE id = %d",
    (payment_method or ""):gsub("'", "''"),
    id
  ))
  
  -- Get updated tithe
  cursor = conn:execute(string.format("SELECT * FROM tithes WHERE id = %d", id))
  local tithe = cursor:fetch({}, "a")
  cursor:close()
  conn:close()
  env:close()
  
  return tithe
end

return Tithe
