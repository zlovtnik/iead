-- src/models/report.lua
-- Report model for Church Management System

local luasql = require("luasql.postgres")
local db_config = require("src.config.database")

local Report = {}

-- Get database connection
function Report.get_connection()
  local env = luasql.postgres()
  return env:connect(db_config.database, db_config.user, db_config.password, db_config.host, db_config.port), env
end

-- Generate member attendance report
function Report.member_attendance(start_date, end_date)
  local conn, env = Report.get_connection()

  local query = [[
    SELECT m.id, m.name, m.email, 
           COUNT(a.id) as total_events,
           SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
           SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count,
           SUM(CASE WHEN a.status = 'excused' THEN 1 ELSE 0 END) as excused_count
    FROM members m
    LEFT JOIN attendance a ON m.id = a.member_id
    LEFT JOIN events e ON a.event_id = e.id
  ]]

  if start_date and end_date then
    query = query .. string.format(" WHERE e.start_date BETWEEN '%s' AND '%s'", 
                                  start_date:gsub("'", "''"), 
                                  end_date:gsub("'", "''"))
  end

  query = query .. " GROUP BY m.id ORDER BY m.name"

  local cursor = conn:execute(query)

  local report = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(report, row)
    row = cursor:fetch({}, "a")
  end

  cursor:close()
  conn:close()
  env:close()

  return report
end

-- Generate event attendance report
function Report.event_attendance(start_date, end_date)
  local conn, env = Report.get_connection()
  
  local query = [[
    SELECT e.id, e.title, e.start_date, e.location,
           COUNT(a.id) as total_attendees,
           SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
           SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count,
           SUM(CASE WHEN a.status = 'excused' THEN 1 ELSE 0 END) as excused_count
    FROM events e
    LEFT JOIN attendance a ON e.id = a.event_id
  ]]
  
  if start_date and end_date then
    query = query .. string.format(" WHERE e.start_date BETWEEN '%s' AND '%s'", 
                                  start_date:gsub("'", "''"), 
                                  end_date:gsub("'", "''"))
  end
  
  query = query .. " GROUP BY e.id ORDER BY e.start_date DESC"
  
  local cursor = conn:execute(query)
  
  local report = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(report, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return report
end

-- Generate donation summary report
function Report.donation_summary(start_date, end_date)
  local conn, env = Report.get_connection()
  
  local query = [[
    SELECT 
      SUM(amount) as total_amount,
      COUNT(DISTINCT member_id) as donor_count,
      COUNT(*) as donation_count,
      AVG(amount) as average_donation,
      MAX(amount) as largest_donation,
      MIN(amount) as smallest_donation
    FROM donations
  ]]
  
  if start_date and end_date then
    query = query .. string.format(" WHERE donation_date BETWEEN '%s' AND '%s'", 
                                  start_date:gsub("'", "''"), 
                                  end_date:gsub("'", "''"))
  end
  
  local cursor = conn:execute(query)
  local summary = cursor:fetch({}, "a")
  cursor:close()
  
  -- Get donation by category
  query = [[
    SELECT 
      category,
      SUM(amount) as total_amount,
      COUNT(*) as donation_count
    FROM donations
  ]]
  
  if start_date and end_date then
    query = query .. string.format(" WHERE donation_date BETWEEN '%s' AND '%s'", 
                                  start_date:gsub("'", "''"), 
                                  end_date:gsub("'", "''"))
  end
  
  query = query .. " GROUP BY category ORDER BY total_amount DESC"
  
  cursor = conn:execute(query)
  
  local categories = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(categories, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return {
    summary = summary,
    categories = categories
  }
end

-- Generate top donors report
function Report.top_donors(start_date, end_date, limit)
  limit = limit or 10
  
  local conn, env = Report.get_connection()
  
  local query = [[
    SELECT 
      m.id,
      m.name,
      m.email,
      SUM(d.amount) as total_donated,
      COUNT(d.id) as donation_count,
      MAX(d.amount) as largest_donation,
      MIN(d.amount) as smallest_donation,
      AVG(d.amount) as average_donation
    FROM donations d
    JOIN members m ON d.member_id = m.id
  ]]
  
  if start_date and end_date then
    query = query .. string.format(" WHERE d.donation_date BETWEEN '%s' AND '%s'", 
                                  start_date:gsub("'", "''"), 
                                  end_date:gsub("'", "''"))
  end
  
  query = query .. string.format(" GROUP BY m.id ORDER BY total_donated DESC LIMIT %d", limit)
  
  local cursor = conn:execute(query)
  
  local donors = {}
  local row = cursor:fetch({}, "a")
  while row do
    table.insert(donors, row)
    row = cursor:fetch({}, "a")
  end
  
  cursor:close()
  conn:close()
  env:close()
  
  return donors
end

-- Generate volunteer hours report
function Report.volunteer_hours(start_date, end_date)
  local conn, env = Report.get_connection()
  
  local query = [[
    SELECT 
      m.id,
      m.name,
      m.email,
      v.role,
      COUNT(v.id) as assignment_count
    FROM volunteers v
    JOIN members m ON v.member_id = m.id
  ]]
  
  if start_date and end_date then
    query = query .. string.format(" WHERE v.start_date BETWEEN '%s' AND '%s'", 
                                  start_date:gsub("'", "''"), 
                                  end_date:gsub("'", "''"))
  end
  
  query = query .. " GROUP BY m.id, v.role ORDER BY m.name, v.role"
  
  local cursor = conn:execute(query)
  
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

return Report
