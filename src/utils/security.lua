-- Security utilities for authentication system
-- Provides password hashing, token generation, and security validation

local bcrypt = require('bcrypt')

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
    
    local success, result = pcall(bcrypt.verify, password, hash)
    return success and result
end

-- Generate a cryptographically secure random number between 1 and max
-- Uses OS CSPRNG (/dev/urandom) with rejection sampling to avoid modulo bias
-- @param max number Maximum value (inclusive)
-- @return number Random number between 1 and max
local function secure_random(max)
    if max <= 1 then return 1 end
    
    -- Try to use OS CSPRNG (/dev/urandom)
    local urandom = io.open("/dev/urandom", "rb")
    if not urandom then
        -- Fallback to math.random (non-cryptographic)
        -- Note: This fallback provides no cryptographic guarantees
        return math.random(1, max)
    end
    
    -- Calculate number of bytes needed
    local nbytes = 1
    local range = 256
    while range < max do
        nbytes = nbytes + 1
        range = range * 256
    end
    
    -- Calculate rejection threshold to avoid modulo bias
    local limit = math.floor(range / max) * max
    
    local result
    repeat
        local bytes = urandom:read(nbytes)
        if not bytes or #bytes < nbytes then
            -- Fallback if read fails
            urandom:close()
            return math.random(1, max)
        end
        
        -- Convert bytes to number
        local val = 0
        for i = 1, #bytes do
            val = val * 256 + bytes:byte(i)
        end
        
        -- Accept value if it's within the unbiased range
        if val < limit then
            result = (val % max) + 1
            break
        end
        -- Otherwise, retry to avoid modulo bias
    until false
    
    urandom:close()
    return result
end

-- Generate a cryptographically secure random token
-- @return string Hex encoded random token
function security.generate_secure_token()
    local chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local result = {}
    
    -- Generate a token that's twice the TOKEN_LENGTH for better entropy
    for i = 1, TOKEN_LENGTH * 2 do
        local rand_index = secure_random(#chars)
        result[#result + 1] = chars:sub(rand_index, rand_index)
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
    -- Order matters: escape ampersands first to avoid double-escaping
    local sanitized = input:gsub("&", "&amp;")
    sanitized = sanitized:gsub("'", "''")  -- Escape single quotes for SQL
    sanitized = sanitized:gsub("<", "&lt;")   -- Escape HTML tags
    sanitized = sanitized:gsub(">", "&gt;")
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

-- Generate a secure temporary password
-- @param length number Optional length of password (default: 12)
-- @return string Generated secure password
function security.generate_secure_password(length)
    length = length or 12
    
    -- Character sets for password generation
    local lowercase = "abcdefghijklmnopqrstuvwxyz"
    local uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local digits = "0123456789"
    local special = "!@#$%^&*"
    
    -- Ensure password meets policy requirements
    local password = {}
    
    -- Add at least one character from each required set
    if REQUIRE_LOWERCASE then
        local idx = secure_random(#lowercase)
        password[#password + 1] = lowercase:sub(idx, idx)
    end
    
    if REQUIRE_UPPERCASE then
        local idx = secure_random(#uppercase)
        password[#password + 1] = uppercase:sub(idx, idx)
    end
    
    if REQUIRE_DIGIT then
        local idx = secure_random(#digits)
        password[#password + 1] = digits:sub(idx, idx)
    end
    
    if REQUIRE_SPECIAL then
        local idx = secure_random(#special)
        password[#password + 1] = special:sub(idx, idx)
    end
    
    -- Fill remaining length with random characters from all sets
    local all_chars = lowercase .. uppercase .. digits
    if REQUIRE_SPECIAL then
        all_chars = all_chars .. special
    end
    
    for i = #password + 1, length do
        local idx = secure_random(#all_chars)
        password[i] = all_chars:sub(idx, idx)
    end
    
    -- Shuffle the password array to randomize character positions
    for i = #password, 2, -1 do
        local j = secure_random(i)
        password[i], password[j] = password[j], password[i]
    end
    
    return table.concat(password)
end

return security