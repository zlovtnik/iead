#!/usr/bin/env lua
-- Script to create a test user in the main database

local User = require('src.models.user_secure')

print("Creating test user...")

local user_data = {
    username = 'test',
    email = 'test@example.com',
    password = 'TestPassword123!',
    role = 'Member',
    is_active = true
}

print("User data:", user_data.username, user_data.email, user_data.role)

local user, err = User.create(user_data)

if user then
    print("✓ User created successfully!")
    print("  ID:", user.id)
    print("  Username:", user.username)
    print("  Email:", user.email)
    print("  Role:", user.role)
else
    print("✗ Failed to create user:", err)
end
