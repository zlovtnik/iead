-- src/tests/test_user.lua
-- Tests for User model

local test_runner = require("src.tests.test_runner")
local User = require("src.models.user")
local Member = require("src.models.member")

local tests = {}

-- Setup for each test
local function setup()
  test_runner.clear_test_db()
  -- Initialize User table
  User.init_db()
end

-- Test user creation with valid data
function tests.test_create_user_valid_data()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local user, err = User.create(user_data)
  
  test_runner.assert_not_nil(user, "User should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(user.username, "testuser", "Username should match")
  test_runner.assert_equal(user.email, "test@example.com", "Email should match")
  test_runner.assert_equal(user.role, "Member", "Role should match")
  test_runner.assert_true(user.is_active, "User should be active by default")
  test_runner.assert_false(user.password_reset_required, "Password reset should not be required by default")
  test_runner.assert_nil(user.password_hash, "Password hash should not be exposed")
end

-- Test user creation with member_id
function tests.test_create_user_with_member_id()
  setup()
  
  -- Create a member first
  local member = Member.create({name = "John Doe", email = "john@example.com"})
  
  local user_data = {
    username = "johndoe",
    email = "john@example.com",
    password = "SecurePass123",
    role = "Member",
    member_id = tonumber(member.id)
  }
  
  local user, err = User.create(user_data)
  
  test_runner.assert_not_nil(user, "User should be created")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(tonumber(user.member_id), tonumber(member.id), "Member ID should match")
end

-- Test user creation with missing required fields
function tests.test_create_user_missing_fields()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com"
    -- Missing password and role
  }
  
  local user, err = User.create(user_data)
  
  test_runner.assert_nil(user, "User should not be created")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Missing required fields") ~= nil, "Error should mention missing fields")
end

-- Test user creation with invalid username
function tests.test_create_user_invalid_username()
  setup()
  
  local user_data = {
    username = "ab", -- Too short
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local user, err = User.create(user_data)
  
  test_runner.assert_nil(user, "User should not be created")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "at least 3 characters") ~= nil, "Error should mention username length")
end

-- Test user creation with invalid email
function tests.test_create_user_invalid_email()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "invalid-email",
    password = "SecurePass123",
    role = "Member"
  }
  
  local user, err = User.create(user_data)
  
  test_runner.assert_nil(user, "User should not be created")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Invalid email format") ~= nil, "Error should mention invalid email")
end

-- Test user creation with weak password
function tests.test_create_user_weak_password()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "weak", -- Too short and no uppercase/digits
    role = "Member"
  }
  
  local user, err = User.create(user_data)
  
  test_runner.assert_nil(user, "User should not be created")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "at least 8 characters") ~= nil, "Error should mention password length")
end

-- Test user creation with invalid role
function tests.test_create_user_invalid_role()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "InvalidRole"
  }
  
  local user, err = User.create(user_data)
  
  test_runner.assert_nil(user, "User should not be created")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Invalid role") ~= nil, "Error should mention invalid role")
end

-- Test user creation with duplicate username
function tests.test_create_user_duplicate_username()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test1@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  User.create(user_data)
  
  -- Try to create another user with same username
  user_data.email = "test2@example.com"
  local user, err = User.create(user_data)
  
  test_runner.assert_nil(user, "User should not be created")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Username already exists") ~= nil, "Error should mention duplicate username")
end

-- Test user creation with duplicate email
function tests.test_create_user_duplicate_email()
  setup()
  
  local user_data = {
    username = "testuser1",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  User.create(user_data)
  
  -- Try to create another user with same email
  user_data.username = "testuser2"
  local user, err = User.create(user_data)
  
  test_runner.assert_nil(user, "User should not be created")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Email already exists") ~= nil, "Error should mention duplicate email")
end

-- Test user authentication with valid credentials
function tests.test_authenticate_valid_credentials()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  User.create(user_data)
  
  local user, err = User.authenticate("testuser", "SecurePass123")
  
  test_runner.assert_not_nil(user, "User should be authenticated")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(user.username, "testuser", "Username should match")
  test_runner.assert_nil(user.password_hash, "Password hash should not be exposed")
end

-- Test user authentication with invalid username
function tests.test_authenticate_invalid_username()
  setup()
  
  local user, err = User.authenticate("nonexistent", "password")
  
  test_runner.assert_nil(user, "User should not be authenticated")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Invalid username or password") ~= nil, "Error should be generic")
end

-- Test user authentication with invalid password
function tests.test_authenticate_invalid_password()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  User.create(user_data)
  
  local user, err = User.authenticate("testuser", "wrongpassword")
  
  test_runner.assert_nil(user, "User should not be authenticated")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Invalid username or password") ~= nil, "Error should be generic")
end

-- Test user authentication with deactivated account
function tests.test_authenticate_deactivated_account()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  User.deactivate(tonumber(created_user.id))
  
  local user, err = User.authenticate("testuser", "SecurePass123")
  
  test_runner.assert_nil(user, "User should not be authenticated")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Account is deactivated") ~= nil, "Error should mention deactivation")
end

-- Test finding user by username
function tests.test_find_by_username()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  User.create(user_data)
  
  local user = User.find_by_username("testuser")
  
  test_runner.assert_not_nil(user, "User should be found")
  test_runner.assert_equal(user.username, "testuser", "Username should match")
  test_runner.assert_nil(user.password_hash, "Password hash should not be exposed")
end

-- Test finding user by email
function tests.test_find_by_email()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  User.create(user_data)
  
  local user = User.find_by_email("test@example.com")
  
  test_runner.assert_not_nil(user, "User should be found")
  test_runner.assert_equal(user.email, "test@example.com", "Email should match")
  test_runner.assert_nil(user.password_hash, "Password hash should not be exposed")
end

-- Test finding user by ID
function tests.test_find_by_id()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  local user = User.find_by_id(tonumber(created_user.id))
  
  test_runner.assert_not_nil(user, "User should be found")
  test_runner.assert_equal(user.id, created_user.id, "ID should match")
  test_runner.assert_nil(user.password_hash, "Password hash should not be exposed")
end

-- Test updating user password
function tests.test_update_password()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  local result, err = User.update_password(tonumber(created_user.id), "NewSecurePass456")
  
  test_runner.assert_true(result, "Password should be updated")
  test_runner.assert_nil(err, "Should not have error")
  
  -- Test authentication with new password
  local user = User.authenticate("testuser", "NewSecurePass456")
  test_runner.assert_not_nil(user, "Should authenticate with new password")
  
  -- Test that old password no longer works
  local old_auth = User.authenticate("testuser", "SecurePass123")
  test_runner.assert_nil(old_auth, "Should not authenticate with old password")
end

-- Test updating password with weak password
function tests.test_update_password_weak()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  local result, err = User.update_password(tonumber(created_user.id), "weak")
  
  test_runner.assert_nil(result, "Password should not be updated")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "at least 8 characters") ~= nil, "Error should mention password length")
end

-- Test failed login attempt tracking
function tests.test_failed_login_attempts()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  local user_id = tonumber(created_user.id)
  
  -- Increment failed attempts
  User.increment_failed_attempts(user_id)
  User.increment_failed_attempts(user_id)
  
  -- Reset failed attempts
  local result = User.reset_failed_attempts(user_id)
  test_runner.assert_true(result, "Failed attempts should be reset")
end

-- Test account deactivation after multiple failed attempts
function tests.test_account_deactivation_after_failed_attempts()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  local user_id = tonumber(created_user.id)
  
  -- Simulate 5 failed login attempts
  for i = 1, 5 do
    User.increment_failed_attempts(user_id)
  end
  
  -- Try to authenticate - should fail due to deactivation
  local user, err = User.authenticate("testuser", "SecurePass123")
  test_runner.assert_nil(user, "User should not be authenticated")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Account is deactivated") ~= nil, "Account should be deactivated")
end

-- Test user deactivation
function tests.test_deactivate_user()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  local result, err = User.deactivate(tonumber(created_user.id))
  
  test_runner.assert_true(result, "User should be deactivated")
  test_runner.assert_nil(err, "Should not have error")
  
  -- Verify user cannot authenticate
  local user = User.authenticate("testuser", "SecurePass123")
  test_runner.assert_nil(user, "Deactivated user should not authenticate")
end

-- Test user activation
function tests.test_activate_user()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  User.deactivate(tonumber(created_user.id))
  
  local result, err = User.activate(tonumber(created_user.id))
  
  test_runner.assert_true(result, "User should be activated")
  test_runner.assert_nil(err, "Should not have error")
  
  -- Verify user can authenticate again
  local user = User.authenticate("testuser", "SecurePass123")
  test_runner.assert_not_nil(user, "Activated user should authenticate")
end

-- Test finding all users
function tests.test_find_all_users()
  setup()
  
  -- Create multiple users
  User.create({username = "user1", email = "user1@example.com", password = "SecurePass123", role = "Member"})
  User.create({username = "user2", email = "user2@example.com", password = "SecurePass123", role = "Pastor"})
  User.create({username = "user3", email = "user3@example.com", password = "SecurePass123", role = "Admin"})
  
  local users = User.find_all()
  
  test_runner.assert_equal(#users, 3, "Should have 3 users")
  test_runner.assert_nil(users[1].password_hash, "Password hash should not be exposed")
end

-- Test updating user
function tests.test_update_user()
  setup()
  
  local user_data = {
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  }
  
  local created_user = User.create(user_data)
  
  local update_data = {
    username = "updateduser",
    email = "updated@example.com",
    role = "Pastor"
  }
  
  local updated_user, err = User.update(tonumber(created_user.id), update_data)
  
  test_runner.assert_not_nil(updated_user, "User should be updated")
  test_runner.assert_nil(err, "Should not have error")
  test_runner.assert_equal(updated_user.username, "updateduser", "Username should be updated")
  test_runner.assert_equal(updated_user.email, "updated@example.com", "Email should be updated")
  test_runner.assert_equal(updated_user.role, "Pastor", "Role should be updated")
end

-- Test updating user with duplicate username
function tests.test_update_user_duplicate_username()
  setup()
  
  -- Create two users
  User.create({username = "user1", email = "user1@example.com", password = "SecurePass123", role = "Member"})
  local user2 = User.create({username = "user2", email = "user2@example.com", password = "SecurePass123", role = "Member"})
  
  -- Try to update user2 with user1's username
  local updated_user, err = User.update(tonumber(user2.id), {username = "user1"})
  
  test_runner.assert_nil(updated_user, "User should not be updated")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "Username already exists") ~= nil, "Error should mention duplicate username")
end

-- Test updating nonexistent user
function tests.test_update_nonexistent_user()
  setup()
  
  local updated_user, err = User.update(99999, {username = "newuser"})
  
  test_runner.assert_nil(updated_user, "User should not be updated")
  test_runner.assert_not_nil(err, "Should have error")
  test_runner.assert_true(string.find(err, "User not found") ~= nil, "Error should mention user not found")
end

return tests