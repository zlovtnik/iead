-- src/db/schema.lua
-- Database schema for Church Management System

local Member = require("src.models.member")
local Event = require("src.models.event")
local Attendance = require("src.models.attendance")
local Donation = require("src.models.donation")
local Volunteer = require("src.models.volunteer")
local Tithe = require("src.models.tithe")

local schema = {}

-- Initialize database schema
function schema.init()
  -- Initialize tables in the correct order (respecting foreign key constraints)
  Member.init_db()
  Event.init_db()
  Attendance.init_db()
  Donation.init_db()
  Volunteer.init_db()
  Tithe.init_db()
  
  print("Database schema initialized")
end

return schema
