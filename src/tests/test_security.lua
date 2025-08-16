-- src/tests/test_security.lua
-- Tests for security utilities

local test_runner = require("src.tests.test_runner")
local security = require("src.utils.security")

local tests = {}

-- Test password hashing functionality
function tests.test_hash_password()
  local password = "testPassword123"
  local hash = security.hash_password(password)
  
  test_runner.assert_not_nil(hash, "Hash should not be nil")
  test_runner.assert_type(hash, "string", "Hash should be a string")
  test_runner.assert_true(#hash > 0, "Hash should not be empty")
  test_runner.assert_true(hash ~= password, "Hash should be different from original password")
  
  -- Test that same password produces different hashes (due to salt)
  local hash2 = security.hash_password(password)
  test_runner.assert_true(hash ~= hash2, "Same password should produce different hashes due to salt")
end

function tests.test_hash_password_invalid_input()
  local success, err = pcall(security.hash_password, nil)
  test_runner.assert_false(success, "Should fail with nil password")
  
  local success2, err2 = pcall(security.hash_password, "")
  test_runner.assert_false(success2, "Should fail with empty password")
  
  local success3, err3 = pcall(security.hash_password, 123)
  test_runner.assert_false(success3, "Should fail with non-string password")
end

-- Test password verification functionality
function tests.test_verify_password()
  local password = "testPassword123"
  local hash = security.hash_password(password)
  
  test_runner.assert_true(security.verify_password(password, hash), "Correct password should verify")
  test_runner.assert_false(security.verify_password("wrongPassword", hash), "Wrong password should not verify")
  test_runner.assert_false(security.verify_password("", hash), "Empty password should not verify")
end

function tests.test_verify_password_invalid_input()
  local hash = security.hash_password("testPassword123")
  
  test_runner.assert_false(security.verify_password(nil, hash), "Nil password should return false")
  test_runner.assert_false(security.verify_password("password", nil), "Nil hash should return false")
  test_runner.assert_false(security.verify_password("password", ""), "Empty hash should return false")
  test_runner.assert_false(security.verify_password("password", "invalid_hash"), "Invalid hash should return false")
end

-- Test secure token generation
function tests.test_generate_secure_token()
  local token = security.generate_secure_token()
  
  test_runner.assert_not_nil(token, "Token should not be nil")
  test_runner.assert_type(token, "string", "Token should be a string")
  test_runner.assert_true(#token > 0, "Token should not be empty")
  
  -- Test that tokens are unique
  local token2 = security.generate_secure_token()
  test_runner.assert_true(token ~= token2, "Generated tokens should be unique")
  
  -- Test token length (base64 encoded 32 bytes should be around 44 characters)
  test_runner.assert_true(#token >= 40, "Token should be sufficiently long")
end

-- Test password strength validation
function tests.test_validate_password_strength()
  -- Test valid passwords
  local valid, err = security.validate_password_strength("Password123")
  test_runner.assert_true(valid, "Valid password should pass")
  test_runner.assert_nil(err, "Valid password should have no error")
  
  -- Test minimum length
  local valid2, err2 = security.validate_password_strength("Pass1")
  test_runner.assert_false(valid2, "Short password should fail")
  test_runner.assert_not_nil(err2, "Short password should have error message")
  
  -- Test uppercase requirement
  local valid3, err3 = security.validate_password_strength("password123")
  test_runner.assert_false(valid3, "Password without uppercase should fail")
  test_runner.assert_not_nil(err3, "Should have error message about uppercase")
  
  -- Test lowercase requirement
  local valid4, err4 = security.validate_password_strength("PASSWORD123")
  test_runner.assert_false(valid4, "Password without lowercase should fail")
  test_runner.assert_not_nil(err4, "Should have error message about lowercase")
  
  -- Test digit requirement
  local valid5, err5 = security.validate_password_strength("Password")
  test_runner.assert_false(valid5, "Password without digit should fail")
  test_runner.assert_not_nil(err5, "Should have error message about digit")
end

function tests.test_validate_password_strength_invalid_input()
  local valid, err = security.validate_password_strength(nil)
  test_runner.assert_false(valid, "Nil password should fail")
  test_runner.assert_not_nil(err, "Should have error message")
  
  local valid2, err2 = security.validate_password_strength(123)
  test_runner.assert_false(valid2, "Non-string password should fail")
  test_runner.assert_not_nil(err2, "Should have error message")
end

-- Test input sanitization
function tests.test_sanitize_input()
  test_runner.assert_equal(security.sanitize_input("normal text"), "normal text", "Normal text should be unchanged")
  test_runner.assert_equal(security.sanitize_input("O'Connor"), "O''Connor", "Single quotes should be escaped")
  test_runner.assert_equal(security.sanitize_input("<script>"), "&lt;script&gt;", "HTML tags should be escaped")
  test_runner.assert_equal(security.sanitize_input("A & B"), "A &amp; B", "Ampersands should be escaped")
  test_runner.assert_equal(security.sanitize_input('"quoted"'), "&quot;quoted&quot;", "Double quotes should be escaped")
  test_runner.assert_equal(security.sanitize_input("  spaced  "), "spaced", "Whitespace should be trimmed")
  test_runner.assert_equal(security.sanitize_input(nil), "", "Nil input should return empty string")
  test_runner.assert_equal(security.sanitize_input(123), "", "Non-string input should return empty string")
end

-- Test session token generation
function tests.test_generate_session_token()
  local token, timestamp = security.generate_session_token()
  
  test_runner.assert_not_nil(token, "Session token should not be nil")
  test_runner.assert_not_nil(timestamp, "Timestamp should not be nil")
  test_runner.assert_type(token, "string", "Token should be a string")
  test_runner.assert_type(timestamp, "number", "Timestamp should be a number")
  test_runner.assert_true(timestamp > 0, "Timestamp should be positive")
  
  -- Test that tokens are unique
  local token2, timestamp2 = security.generate_session_token()
  test_runner.assert_true(token ~= token2, "Session tokens should be unique")
  test_runner.assert_true(timestamp2 >= timestamp, "Second timestamp should be >= first")
end

-- Test email validation
function tests.test_validate_email_format()
  test_runner.assert_true(security.validate_email_format("test@example.com"), "Valid email should pass")
  test_runner.assert_true(security.validate_email_format("user.name+tag@domain.co.uk"), "Complex valid email should pass")
  test_runner.assert_true(security.validate_email_format("user_name@domain-name.com"), "Email with underscores and hyphens should pass")
  
  test_runner.assert_false(security.validate_email_format("invalid-email"), "Invalid email should fail")
  test_runner.assert_false(security.validate_email_format("@example.com"), "Email without username should fail")
  test_runner.assert_false(security.validate_email_format("test@"), "Email without domain should fail")
  test_runner.assert_false(security.validate_email_format("test@domain"), "Email without TLD should fail")
  test_runner.assert_false(security.validate_email_format(nil), "Nil email should fail")
  test_runner.assert_false(security.validate_email_format(""), "Empty email should fail")
end

-- Test username validation
function tests.test_validate_username_format()
  local valid, err = security.validate_username_format("validuser")
  test_runner.assert_true(valid, "Valid username should pass")
  test_runner.assert_nil(err, "Valid username should have no error")
  
  local valid2, err2 = security.validate_username_format("user_name")
  test_runner.assert_true(valid2, "Username with underscore should pass")
  test_runner.assert_nil(err2, "Should have no error")
  
  local valid3, err3 = security.validate_username_format("user-name")
  test_runner.assert_true(valid3, "Username with hyphen should pass")
  test_runner.assert_nil(err3, "Should have no error")
  
  local valid4, err4 = security.validate_username_format("user123")
  test_runner.assert_true(valid4, "Username with numbers should pass")
  test_runner.assert_nil(err4, "Should have no error")
  
  -- Test invalid usernames
  local valid5, err5 = security.validate_username_format("ab")
  test_runner.assert_false(valid5, "Short username should fail")
  test_runner.assert_not_nil(err5, "Should have error message")
  
  local valid6, err6 = security.validate_username_format(string.rep("a", 51))
  test_runner.assert_false(valid6, "Long username should fail")
  test_runner.assert_not_nil(err6, "Should have error message")
  
  local valid7, err7 = security.validate_username_format("user@name")
  test_runner.assert_false(valid7, "Username with special characters should fail")
  test_runner.assert_not_nil(err7, "Should have error message")
  
  local valid8, err8 = security.validate_username_format(nil)
  test_runner.assert_false(valid8, "Nil username should fail")
  test_runner.assert_not_nil(err8, "Should have error message")
end

-- Test multiple password hashing for consistency
function tests.test_password_hashing_consistency()
  local password = "testPassword123"
  local hashes = {}
  
  -- Generate multiple hashes
  for i = 1, 5 do
    hashes[i] = security.hash_password(password)
  end
  
  -- Verify all hashes are different (due to salt)
  for i = 1, 4 do
    for j = i + 1, 5 do
      test_runner.assert_true(hashes[i] ~= hashes[j], "All hashes should be different due to salt")
    end
  end
  
  -- Verify all hashes can verify the original password
  for i = 1, 5 do
    test_runner.assert_true(security.verify_password(password, hashes[i]), "All hashes should verify the original password")
  end
end

-- Test token generation uniqueness
function tests.test_token_uniqueness()
  local tokens = {}
  local num_tokens = 100
  
  -- Generate multiple tokens
  for i = 1, num_tokens do
    tokens[i] = security.generate_secure_token()
  end
  
  -- Check for uniqueness
  for i = 1, num_tokens - 1 do
    for j = i + 1, num_tokens do
      test_runner.assert_true(tokens[i] ~= tokens[j], "All tokens should be unique")
    end
  end
end

-- Test secure password generation
function tests.test_generate_secure_password()
  local password = security.generate_secure_password()
  
  test_runner.assert_not_nil(password, "Password should not be nil")
  test_runner.assert_type(password, "string", "Password should be a string")
  test_runner.assert_true(#password == 12, "Default password length should be 12")
  
  -- Test custom length
  local password_custom = security.generate_secure_password(16)
  test_runner.assert_true(#password_custom == 16, "Custom password length should be respected")
  
  -- Test that passwords are unique
  local password2 = security.generate_secure_password()
  test_runner.assert_true(password ~= password2, "Generated passwords should be unique")
end

function tests.test_generate_secure_password_policy_compliance()
  local password = security.generate_secure_password(20)
  
  -- Test that generated password meets policy requirements
  local valid, err = security.validate_password_strength(password)
  test_runner.assert_true(valid, "Generated password should meet policy requirements")
  test_runner.assert_nil(err, "Generated password should have no validation errors")
  
  -- Test that password contains required character types
  test_runner.assert_true(password:match("%l") ~= nil, "Password should contain lowercase letters")
  test_runner.assert_true(password:match("%u") ~= nil, "Password should contain uppercase letters")
  test_runner.assert_true(password:match("%d") ~= nil, "Password should contain digits")
end

function tests.test_generate_secure_password_uniqueness()
  local passwords = {}
  local num_passwords = 50
  
  -- Generate multiple passwords
  for i = 1, num_passwords do
    passwords[i] = security.generate_secure_password(15)
  end
  
  -- Check for uniqueness
  for i = 1, num_passwords - 1 do
    for j = i + 1, num_passwords do
      test_runner.assert_true(passwords[i] ~= passwords[j], "All generated passwords should be unique")
    end
  end
  
  -- Verify all passwords meet policy
  for i = 1, num_passwords do
    local valid, err = security.validate_password_strength(passwords[i])
    test_runner.assert_true(valid, "All generated passwords should meet policy requirements")
  end
end

function tests.test_generate_secure_password_edge_cases()
  -- Test minimum viable length
  local short_password = security.generate_secure_password(8)
  test_runner.assert_true(#short_password == 8, "Should generate password of requested length")
  
  local valid, err = security.validate_password_strength(short_password)
  test_runner.assert_true(valid, "Short password should still meet policy requirements")
  
  -- Test longer passwords
  local long_password = security.generate_secure_password(50)
  test_runner.assert_true(#long_password == 50, "Should generate long password of requested length")
  
  local valid2, err2 = security.validate_password_strength(long_password)
  test_runner.assert_true(valid2, "Long password should meet policy requirements")
end

return tests