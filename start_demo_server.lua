-- start_demo_server.lua
-- Start a demo server with sample data

-- Clean up any existing demo database
os.remove("demo_server_church_management.db")

-- Configure for demo
local db_config = require("src.config.database")
local original_db = db_config.db_file
db_config.db_file = "demo_server_church_management.db"
db_config.host = "127.0.0.1"
db_config.port = 8080

-- Initialize database
local schema = require("src.db.schema")
schema.init()

-- Create sample data
print("Creating sample data...")

local Member = require("src.models.member")
local Event = require("src.models.event")
local Attendance = require("src.models.attendance")
local Donation = require("src.models.donation")

-- Create sample members
local members = {}
local member_names = {
  {"John Doe", "john.doe@example.com"},
  {"Jane Smith", "jane.smith@example.com"},
  {"Bob Johnson", "bob.johnson@example.com"},
  {"Alice Williams", "alice.williams@example.com"},
  {"Charlie Brown", "charlie.brown@example.com"}
}

for i, info in ipairs(member_names) do
  local member = Member.create({
    name = info[1],
    email = info[2],
    phone = string.format("555-01%02d", i),
    salary = math.random(35000, 75000)
  })
  if member then
    table.insert(members, member)
    print("✓ Created member: " .. member.name)
  end
end

-- Create sample events
local events = {}
local event_info = {
  {"Sunday Morning Service", "2024-12-22 10:00:00", "2024-12-22 12:00:00", "Main Sanctuary"},
  {"Bible Study", "2024-12-18 19:00:00", "2024-12-18 20:30:00", "Fellowship Hall"},
  {"Christmas Service", "2024-12-25 10:00:00", "2024-12-25 12:00:00", "Main Sanctuary"},
  {"Youth Group", "2024-12-19 18:00:00", "2024-12-19 20:00:00", "Youth Room"},
  {"Prayer Meeting", "2024-12-20 19:00:00", "2024-12-20 20:00:00", "Prayer Room"}
}

for i, info in ipairs(event_info) do
  local event = Event.create({
    title = info[1],
    description = "Weekly " .. info[1],
    start_date = info[2],
    end_date = info[3],
    location = info[4]
  })
  if event then
    table.insert(events, event)
    print("✓ Created event: " .. event.title)
  end
end

-- Create sample attendance and donations
for _, member in ipairs(members) do
  for _, event in ipairs(events) do
    if math.random() > 0.3 then -- 70% attendance rate
      Attendance.create({
        event_id = tonumber(event.id),
        member_id = tonumber(member.id),
        status = math.random() > 0.1 and "present" or "absent"
      })
    end
  end
  
  -- Create some donations
  if math.random() > 0.4 then -- 60% donation rate
    Donation.create({
      member_id = tonumber(member.id),
      amount = math.random(25, 200),
      donation_date = "2024-12-15",
      payment_method = math.random() > 0.5 and "cash" or "check"
    })
  end
end

print("\n" .. string.rep("=", 60))
print("CHURCH MANAGEMENT SYSTEM - DEMO SERVER")
print(string.rep("=", 60))
print("Sample data created successfully!")
print("")
print("Database: " .. db_config.db_file)
print("Members: " .. #Member.find_all())
print("Events: " .. #Event.find_all())
print("Attendance Records: " .. #Attendance.find_all())
print("Donations: " .. #Donation.find_all())
print("")
print("API Endpoints Available:")
print("  GET    /health                    - Health check")
print("  GET    /                          - Home page")
print("  GET    /members                   - List members")
print("  POST   /members                   - Create member")
print("  GET    /members/{id}              - Get member")
print("  PUT    /members/{id}              - Update member")
print("  DELETE /members/{id}              - Delete member")
print("  GET    /events                    - List events")
print("  POST   /events                    - Create event")
print("  GET    /events/{id}               - Get event")
print("  GET    /attendance                - List attendance")
print("  POST   /attendance                - Record attendance")
print("  GET    /donations                 - List donations")
print("  POST   /donations                 - Record donation")
print("  GET    /tithes                    - List tithes")
print("  POST   /tithes/generate-monthly   - Generate monthly tithes")
print("  GET    /reports/member-attendance - Member attendance report")
print("  GET    /reports/donation-summary  - Donation summary report")
print("")
print("Starting server on http://" .. db_config.host .. ":" .. db_config.port)
print("Press Ctrl+C to stop the server")
print(string.rep("=", 60))

-- Now start the actual server by requiring the main app
-- This will run indefinitely until interrupted
require("app")
