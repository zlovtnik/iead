-- src/application/validators/input_validator.lua
-- Input validation middleware for request sanitization and validation

local json_utils = require("src.utils.json")
local log = require("src.utils.log")

local validator = {}

-- Validation rules for different data types
local VALIDATION_RULES = {
    email = {
        pattern = "^[%w._%+-]+@[%w.-]+%.%w+$",
        max_length = 254,
        min_length = 5
    },
    username = {
        pattern = "^[%w_%-%.]+$",
        max_length = 50,
        min_length = 3
    },
    password = {
        min_length = 8,
        max_length = 128,
        require_uppercase = true,
        require_lowercase = true,
        require_digit = true,
        require_special = false
    },
    name = {
        pattern = "^[%w%s%-'%.]+$",
        max_length = 100,
        min_length = 1
    },
    phone = {
        pattern = "^%+?[%d%s%-%.%(%)]+$",
        max_length = 20,
        min_length = 10
    },
    role = {
        allowed_values = {"Admin", "Pastor", "Member"}
    },
    id = {
        pattern = "^%d+$",
        min_value = 1
    },
    amount = {
        pattern = "^%d+%.?%d*$",
        min_value = 0
    },
    date = {
        pattern = "^%d%d%d%d%-%d%d%-%d%d$"
    },
    datetime = {
        pattern = "^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$"
    }
}

-- Sanitize input string to prevent injection attacks
-- @param input string The input string to sanitize
-- @param max_length number Optional maximum length
-- @return string The sanitized input
function validator.sanitize_string(input, max_length)
    if not input or type(input) ~= "string" then
        return ""
    end
    
    -- Remove null bytes and control characters (except tab, newline, carriage return)
    local sanitized = input:gsub("[\000-\008\011\012\014-\031\127]", "")
    
    -- HTML encode dangerous characters to prevent XSS
    sanitized = sanitized:gsub("&", "&amp;")  -- Must be first to avoid double-encoding
    sanitized = sanitized:gsub("<", "&lt;")
    sanitized = sanitized:gsub(">", "&gt;")
    sanitized = sanitized:gsub('"', "&quot;")
    sanitized = sanitized:gsub("'", "&#x27;")
    
    -- Remove or replace SQL injection patterns
    sanitized = sanitized:gsub("%-%-", "")  -- Remove SQL comments
    sanitized = sanitized:gsub("/[%*].*[%*]/", "")  -- Remove /* */ comments
    sanitized = sanitized:gsub("%s*[Dd][Rr][Oo][Pp]%s+[Tt][Aa][Bb][Ll][Ee]", "")  -- Remove DROP TABLE
    sanitized = sanitized:gsub("%s*[Dd][Ee][Ll][Ee][Tt][Ee]%s+[Ff][Rr][Oo][Mm]", "")  -- Remove DELETE FROM
    sanitized = sanitized:gsub("%;", "")  -- Remove semicolons that could terminate statements
    
    -- Trim whitespace
    sanitized = sanitized:match("^%s*(.-)%s*$") or ""
    
    -- Apply length limit
    if max_length and #sanitized > max_length then
        sanitized = sanitized:sub(1, max_length)
    end
    
    return sanitized
end

-- Validate individual field based on rules
-- @param value any The value to validate
-- @param rules table The validation rules to apply
-- @param field_name string The name of the field (for error messages)
-- @return valid boolean, error string
function validator.validate_field(value, rules, field_name)
    if not rules then
        return true, nil
    end
    
    -- Check required
    if rules.required and (value == nil or value == "") then
        return false, field_name .. " is required"
    end
    
    -- If value is nil/empty and not required, it's valid
    if value == nil or value == "" then
        return true, nil
    end
    
    -- Convert to string for validation
    local str_value = tostring(value)
    
    -- Check length constraints
    if rules.min_length and #str_value < rules.min_length then
        return false, field_name .. " must be at least " .. rules.min_length .. " characters"
    end
    
    if rules.max_length and #str_value > rules.max_length then
        return false, field_name .. " must be no more than " .. rules.max_length .. " characters"
    end
    
    -- Check pattern
    if rules.pattern and not str_value:match(rules.pattern) then
        return false, field_name .. " format is invalid"
    end
    
    -- Check allowed values
    if rules.allowed_values then
        local found = false
        for _, allowed in ipairs(rules.allowed_values) do
            if str_value == allowed then
                found = true
                break
            end
        end
        if not found then
            return false, field_name .. " must be one of: " .. table.concat(rules.allowed_values, ", ")
        end
    end
    
    -- Check numeric constraints
    local num_value = tonumber(str_value)
    if rules.min_value and (not num_value or num_value < rules.min_value) then
        return false, field_name .. " must be at least " .. rules.min_value
    end
    
    if rules.max_value and (not num_value or num_value > rules.max_value) then
        return false, field_name .. " must be no more than " .. rules.max_value
    end
    
    -- Password complexity checks
    if rules.require_uppercase and not str_value:match("[A-Z]") then
        return false, field_name .. " must contain at least one uppercase letter"
    end
    
    if rules.require_lowercase and not str_value:match("[a-z]") then
        return false, field_name .. " must contain at least one lowercase letter"
    end
    
    if rules.require_digit and not str_value:match("%d") then
        return false, field_name .. " must contain at least one digit"
    end
    
    if rules.require_special and not str_value:match("[^%w%s]") then
        return false, field_name .. " must contain at least one special character"
    end
    
    return true, nil
end

-- Validate and sanitize request data
-- @param data table The request data to validate
-- @param schema table The validation schema
-- @return sanitized_data table, errors table
function validator.validate_request(data, schema)
    if not data or type(data) ~= "table" then
        return nil, {general = "Invalid request data"}
    end
    
    if not schema or type(schema) ~= "table" then
        return data, nil
    end
    
    local sanitized = {}
    local errors = {}
    
    -- Validate each field in schema
    for field_name, field_rules in pairs(schema) do
        local value = data[field_name]
        
        -- Sanitize string values
        if type(value) == "string" then
            value = validator.sanitize_string(value, field_rules.max_length)
        end
        
        -- Validate field
        local valid, error_msg = validator.validate_field(value, field_rules, field_name)
        if not valid then
            errors[field_name] = error_msg
        else
            sanitized[field_name] = value
        end
    end
    
    -- Check for unexpected fields (optional strict mode)
    if schema._strict then
        for field_name, _ in pairs(data) do
            if not schema[field_name] and field_name ~= "_strict" then
                errors[field_name] = "Unexpected field: " .. field_name
            end
        end
    end
    
    -- Return results
    if next(errors) then
        return nil, errors
    else
        return sanitized, nil
    end
end

-- Common validation schemas
validator.schemas = {
    user_create = {
        username = {
            required = true,
            pattern = VALIDATION_RULES.username.pattern,
            min_length = VALIDATION_RULES.username.min_length,
            max_length = VALIDATION_RULES.username.max_length
        },
        email = {
            required = true,
            pattern = VALIDATION_RULES.email.pattern,
            min_length = VALIDATION_RULES.email.min_length,
            max_length = VALIDATION_RULES.email.max_length
        },
        password = {
            required = true,
            min_length = VALIDATION_RULES.password.min_length,
            max_length = VALIDATION_RULES.password.max_length,
            require_uppercase = VALIDATION_RULES.password.require_uppercase,
            require_lowercase = VALIDATION_RULES.password.require_lowercase,
            require_digit = VALIDATION_RULES.password.require_digit,
            require_special = VALIDATION_RULES.password.require_special
        },
        role = {
            required = true,
            allowed_values = VALIDATION_RULES.role.allowed_values
        },
        member_id = {
            pattern = VALIDATION_RULES.id.pattern,
            min_value = VALIDATION_RULES.id.min_value
        }
    },
    
    user_login = {
        username = {
            required = true,
            max_length = VALIDATION_RULES.username.max_length
        },
        password = {
            required = true,
            max_length = VALIDATION_RULES.password.max_length
        }
    },
    
    member_create = {
        name = {
            required = true,
            pattern = VALIDATION_RULES.name.pattern,
            max_length = VALIDATION_RULES.name.max_length,
            min_length = VALIDATION_RULES.name.min_length
        },
        email = {
            pattern = VALIDATION_RULES.email.pattern,
            max_length = VALIDATION_RULES.email.max_length
        },
        phone = {
            pattern = VALIDATION_RULES.phone.pattern,
            max_length = VALIDATION_RULES.phone.max_length
        },
        date_of_birth = {
            pattern = VALIDATION_RULES.date.pattern
        }
    },
    
    donation_create = {
        member_id = {
            required = true,
            pattern = VALIDATION_RULES.id.pattern,
            min_value = VALIDATION_RULES.id.min_value
        },
        amount = {
            required = true,
            pattern = VALIDATION_RULES.amount.pattern,
            min_value = VALIDATION_RULES.amount.min_value
        },
        donation_date = {
            pattern = VALIDATION_RULES.date.pattern
        },
        category = {
            max_length = 50
        }
    },
    
    event_create = {
        name = {
            required = true,
            pattern = VALIDATION_RULES.name.pattern,
            max_length = 100,
            min_length = 1
        },
        start_date = {
            required = true,
            pattern = VALIDATION_RULES.datetime.pattern
        },
        end_date = {
            pattern = VALIDATION_RULES.datetime.pattern
        },
        description = {
            max_length = 1000
        }
    }
}

-- Middleware function to validate request body
-- @param schema table The validation schema to use
-- @return function The middleware function
function validator.validate_middleware(schema)
    return function(client, params, next)
        if not params then
            json_utils.send_json_response(client, 400, {
                error = "Bad Request",
                code = "MISSING_DATA",
                message = "Request body is required",
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            })
            return
        end
        
        local sanitized_data, errors = validator.validate_request(params, schema)
        
        if errors then
            json_utils.send_json_response(client, 400, {
                error = "Validation Error",
                code = "VALIDATION_FAILED",
                message = "Request validation failed",
                details = errors,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            })
            return
        end
        
        -- Replace params with sanitized data
        for k, v in pairs(sanitized_data) do
            params[k] = v
        end
        
        -- Continue to next middleware/handler
        if next then
            next()
        end
    end
end

return validator
