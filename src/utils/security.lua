-- Security utilities for authentication system
-- Provides password hashing, token generation, and security validation

local bcrypt = require('bcrypt')
local random = require('resty.random')

local security = {}

-- Password hashing configuration
local BCRYPT_ROUNDS = 12

-- Token configuration
local TOKEN_LENGTH = 32

-- Password policy configuration
local MIN_PASSWORD_LENGTH = 8
local REQUIRE_UPPERCASE = true
local REQUIRE_LOWERCASE = true
local REQUIRE_DIGIT = true
local REQUIRE_SPECIAL = false

-- Hash a password using bcrypt
-- @param password string The plain text password to hash
-- @return string The bcrypt hash of the password
function security.hash_password(password)
    if not password or type(password) ~= 'string' or #password == 0 then
        error("Password must be a non-empty string")
    end
    
    return bcrypt.digest(password, BCRYPT_ROUNDS)
end

-- Verify a password against its hash
-- @param password string The plain text password to verify
-- @param hash string The bcrypt hash to verify against
-- @return boolean True if password matches hash, false otherwise
function security.verify_password(password, hash)
    if not password or type(password) ~= 'string' then
        return false
    end
    
    if not hash or type(hash) ~= 'string' then
        return false
    end
    
    return bcrypt.verify(password, hash)
end

-- Generate a cryptographically secure random token
-- @return string Base64 encoded random token
function security.generate_secure_token()
    local bytes = random.bytes(TOKEN_LENGTH)
    if not bytes then
        error("Failed to generate secure random bytes")
    end
    
    -- Convert bytes to base64 for safe HTTP transmission
    local base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = {}
    
    for i = 1, #bytes, 3 do
        local b1, b2, b3 = string.byte(bytes, i, i + 2)
        b2 = b2 or 0
        b3 = b3 or 0
        
        local bitmap = (b1 << 16) | (b2 << 8) | b3
        
        result[#result + 1] = base64_chars:sub((bitmap >> 18) + 1, (bitmap >> 18) + 1)
        result[#result + 1] = base64_chars:sub(((bitmap >> 12) & 63) + 1, ((bitmap >> 12) & 63) + 1)
        result[#result + 1] = i + 1 <= #bytes and base64_chars:sub(((bitmap >> 6) & 63) + 1, ((bitmap >> 6) & 63) + 1) or "="
        result[#result + 1] = i + 2 <= #bytes and base64_chars:sub((bitmap & 63) + 1, (bitmap & 63) + 1) or "="
    end
    
    return table.concat(result)
end

-- Validate password strength according to policy
-- @param password string The password to validate
-- @return boolean True if password meets policy requirements
-- @return string Error message if validation fails
function security.validate_password_strength(password)
    if not password or type(password) ~= 'string' then
        return false, "Password must be a string"
    end
    
    if #password < MIN_PASSWORD_LENGTH then
        return false, string.format("Password must be at least %d characters long", MIN_PASSWORD_LENGTH)
    end
    
    if REQUIRE_UPPERCASE and not password:match("%u") then
        return false, "Password must contain at least one uppercase letter"
    end
    
    if REQUIRE_LOWERCASE and not password:match("%l") then
        return false, "Password must contain at least one lowercase letter"
    end
    
    if REQUIRE_DIGIT and not password:match("%d") then
        return false, "Password must contain at least one digit"
    end
    
    if REQUIRE_SPECIAL and not password:match("[%W_]") then
        return false, "Password must contain at least one special character"
    end
    
    return true, nil
end

-- Sanitize input to prevent SQL injection and XSS
-- @param input string The input to sanitize
-- @return string Sanitized input
function security.sanitize_input(input)
    if not input or type(input) ~= 'string' then
        return ""
    end
    
    -- Remove or escape potentially dangerous characters
    local sanitized = input:gsub("'", "''")  -- Escape single quotes for SQL
    sanitized = sanitized:gsub("<", "&lt;")   -- Escape HTML tags
    sanitized = sanitized:gsub(">", "&gt;")
    sanitized = sanitized:gsub("&", "&amp;")
    sanitized = sanitized:gsub('"', "&quot;")
    
    -- Trim whitespace
    sanitized = sanitized:match("^%s*(.-)%s*$")
    
    return sanitized
end

-- Generate a secure session token with timestamp
-- @return string Session token
-- @return number Timestamp when token was generated
function security.generate_session_token()
    local token = security.generate_secure_token()
    local timestamp = os.time()
    return token, timestamp
end

-- Validate email format
-- @param email string Email address to validate
-- @return boolean True if email format is valid
function security.validate_email_format(email)
    if not email or type(email) ~= 'string' then
        return false
    end
    
    -- Basic email validation pattern
    local pattern = "^[%w%._%+%-]+@[%w%.%-]+%.%w+$"
    return email:match(pattern) ~= nil
end

-- Validate username format
-- @param username string Username to validate
-- @return boolean True if username format is valid
-- @return string Error message if validation fails
function security.validate_username_format(username)
    if not username or type(username) ~= 'string' then
        return false, "Username must be a string"
    end
    
    if #username < 3 then
        return false, "Username must be at least 3 characters long"
    end
    
    if #username > 50 then
        return false, "Username must be no more than 50 characters long"
    end
    
    -- Allow alphanumeric characters, underscores, and hyphens
    if not username:match("^[%w_%-]+$") then
        return false, "Username can only contain letters, numbers, underscores, and hyphens"
    end
    
    return true, nil
end

return security