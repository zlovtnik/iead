-- Debug script for User creation
local User = require('src.models.user')
local test_runner = require('src.tests.test_runner')

-- Setup test database
local cleanup = test_runner.setup_test_db()

print("Testing User.create...")

local user_data = {
    username = 'testuser',
    email = 'test@example.com',
    password = 'SecurePass123',
    role = 'Member'
}

print("User data:", user_data.username, user_data.email, user_data.role)

local success, result, err = pcall(User.create, user_data)

print("pcall success:", success)
if success then
    print("User created:", result ~= nil)
    print("Error:", err)
    if result then
        print("User ID:", result.id)
        print("Username:", result.username)
    end
else
    print("Error during creation:", result)
end

-- Cleanup
cleanup()