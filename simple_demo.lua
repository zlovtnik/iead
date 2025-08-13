-- simple_demo.lua
-- Simple demonstration of the Church Management System functionality

local Member = require("src.models.member")
local Event = require("src.models.event")
local Attendance = require("src.models.attendance")
local Donation = require("src.models.donation")
local Tithe = require("src.models.tithe")

-- Clean up any existing demo database
os.remove("demo_church_management.db")

-- Configure for demo
local db_config = require("src.config.database")
db_config.db_file = "demo_church_management.db"

-- Initialize database
local schema = require("src.db.schema")
schema.init()

print("Church Management System - Simple Demo")
print("=" .. string.rep("=", 45))

-- Create a member
print("\n1. Creating a member...")
local member, err = Member.create({
  name = "John Doe",
  email = "john.doe@example.com",
  phone = "555-0123",
  salary = 50000
})

if member then
  print("✓ Member created: " .. member.name .. " (ID: " .. member.id .. ")")
else
  print("✗ Error creating member: " .. (err or "unknown"))
  return
end

-- Create an event
print("\n2. Creating an event...")
local event, err = Event.create({
  title = "Sunday Morning Service",
  description = "Weekly Sunday service",
  start_date = "2024-01-07 10:00:00",
  end_date = "2024-01-07 12:00:00",
  location = "Main Sanctuary"
})

if event then
  print("✓ Event created: " .. event.title .. " (ID: " .. event.id .. ")")
else
  print("✗ Error creating event: " .. (err or "unknown"))
  return
end

-- Record attendance
print("\n3. Recording attendance...")
local attendance, err = Attendance.create({
  event_id = tonumber(event.id),
  member_id = tonumber(member.id),
  status = "present",
  notes = "Arrived on time"
})

if attendance then
  print("✓ Attendance recorded for " .. member.name .. " at " .. event.title)
else
  print("✗ Error recording attendance: " .. (err or "unknown"))
  return
end

-- Record a donation
print("\n4. Recording a donation...")
local donation, err = Donation.create({
  member_id = tonumber(member.id),
  amount = 100.50,
  donation_date = "2024-01-07",
  payment_method = "cash",
  category = "general offering"
})

if donation then
  print("✓ Donation recorded: $" .. donation.amount .. " from " .. member.name)
else
  print("✗ Error recording donation: " .. (err or "unknown"))
  return
end

-- Calculate and record tithe
print("\n5. Calculating monthly tithe...")
local monthly_tithe = Tithe.calculate_monthly_tithe(tonumber(member.id))
print("✓ Monthly tithe calculated: $" .. string.format("%.2f", monthly_tithe))

local tithe, err = Tithe.create({
  member_id = tonumber(member.id),
  amount = monthly_tithe,
  tithe_date = "2024-01-01",
  is_paid = false
})

if tithe then
  print("✓ Tithe record created (ID: " .. tithe.id .. ")")
  
  -- Mark as paid
  local paid_tithe = Tithe.mark_paid(tonumber(tithe.id), "check")
  if paid_tithe then
    print("✓ Tithe marked as paid")
  end
else
  print("✗ Error creating tithe: " .. (err or "unknown"))
end

-- Test queries
print("\n6. Testing queries...")

local all_members = Member.find_all()
print("✓ Total members: " .. #all_members)

local all_events = Event.find_all()
print("✓ Total events: " .. #all_events)

local member_donations = Donation.find_by_member(tonumber(member.id))
print("✓ Donations by " .. member.name .. ": " .. #member_donations)

local total_donations = Donation.total_by_member(tonumber(member.id))
print("✓ Total donations by " .. member.name .. ": $" .. total_donations)

local member_attendance = Attendance.find_by_member(tonumber(member.id))
print("✓ Attendance records for " .. member.name .. ": " .. #member_attendance)

print("\n7. System Statistics:")
print("Members: " .. #Member.find_all())
print("Events: " .. #Event.find_all())
print("Attendance Records: " .. #Attendance.find_all())
print("Donations: " .. #Donation.find_all())
print("Tithes: " .. #Tithe.find_all())

print("\n" .. string.rep("=", 45))
print("✓ Demo completed successfully!")
print("All core functionality is working properly.")
print("Database: " .. db_config.db_file)
print(string.rep("=", 45))
