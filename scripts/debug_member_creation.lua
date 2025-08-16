#!/usr/bin/env lua

-- Debug member creation issue

local test_runner = require("src.tests.test_runner")
local Member = require("src.models.member")

print("🔍 Debugging Member Creation")
print("============================")

-- Setup
test_runner.clear_test_db()
Member.init_db()

-- Try creating a member
local member, err = Member.create({
  name = "Test Member",
  email = "test@example.com",
  phone = "123-456-7890"
})

print("Member creation result:")
print("  Member: " .. tostring(member))
print("  Error: " .. tostring(err))

if member then
  print("  Member ID: " .. tostring(member.id))
  print("  Member Name: " .. tostring(member.name))
  print("  Member Email: " .. tostring(member.email))
else
  print("❌ Member creation failed!")
  print("   Error message: " .. (err or "Unknown error"))
end
