#!/usr/bin/env lua
-- Script to create a test user in the main database

local User = require('src.models.user_secure')

print("Creating test user...")

-- Prefer env-driven config to avoid committing secrets & to minimize collisions
local suffix = tostring(os.time())
local username = os.getenv('TEST_USER_USERNAME') or ('test_' .. suffix)
local email = os.getenv('TEST_USER_EMAIL') or ('test+' .. suffix .. '@example.com')
local password = os.getenv('TEST_USER_PASSWORD')
if not password or password == '' then
    io.stderr:write("TEST_USER_PASSWORD must be set via environment variable\n")
    os.exit(2)
end
local role = os.getenv('TEST_USER_ROLE') or 'Member'
local is_active = ((os.getenv('TEST_USER_ACTIVE') or 'true'):lower() ~= 'false')

local user_data = {
    username = username,
    email    = email,
    password = password,
    role     = role,
    is_active= is_active
}

print(("User data: username=%s, role=%s"):format(
    user_data.username,
    user_data.role
))
if user then
    print("✓ User created successfully!")
    print("  ID:", user.id)
    print("  Username:", user.username)
    print("  Role:", user.role)
    os.exit(0)
else
    io.stderr:write("✗ Failed to create user: " .. tostring(err) .. "\n")
    os.exit(1)
end
else
    print("✗ Failed to create user:", err)
end
