-- src/application/middlewares/request_validator.lua
-- Enhanced request validation middleware with schema support

local ApiResponse = require("src.application.middlewares.api_response")
local ErrorHandler = require("src.application.middlewares.error_handler")
local log = require("src.utils.log")

local RequestValidator = {}

-- Validation rule types
local RULE_TYPES = {
  REQUIRED = "required",
  TYPE = "type",
  LENGTH = "length",
  PATTERN = "pattern",
  RANGE = "range",
  EMAIL = "email",
  DATE = "date",
  ENUM = "enum",
  CUSTOM = "custom"
}

-- Built-in validation patterns
local PATTERNS = {
  email = "^[%w._%+-]+@[%w.-]+%.[%a]+$",
  phone = "^%+?[%d%s%-%(%)%.]+$",
  date = "^%d%d%d%d%-%d%d%-%d%d$",
  datetime = "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d",
  uuid = "^[%w%-]+$",
  slug = "^[%w%-_]+$",
  username = "^[%w_%-%.]+$",
  password = "^.{8,}$"  -- At least 8 characters
}

-- Data type validators
local TYPE_VALIDATORS = {
  string = function(value) return type(value) == "string" end,
  number = function(value) return type(value) == "number" end,
  integer = function(value) return type(value) == "number" and math.floor(value) == value end,
  boolean = function(value) return type(value) == "boolean" end,
  table = function(value) return type(value) == "table" end,
  array = function(value) return type(value) == "table" and #value > 0 end
}

-- Sanitize input value
-- @param value mixed The value to sanitize
-- @param field_type string The expected field type
-- @return mixed The sanitized value
local function sanitize_value(value, field_type)
  if value == nil then return nil end
  
  -- Convert empty strings to nil for optional fields
  if type(value) == "string" and value == "" then
    return nil
  end
  
  -- Type conversions
  if field_type == "number" or field_type == "integer" then
    local num = tonumber(value)
    if num and field_type == "integer" then
      return math.floor(num)
    end
    return num
  elseif field_type == "boolean" then
    if type(value) == "string" then
      local lower = string.lower(value)
      return lower == "true" or lower == "1" or lower == "yes"
    end
    return not not value  -- Convert to boolean
  elseif field_type == "string" then
    return tostring(value)
  end
  
  return value
end

-- Validate a single field
-- @param value mixed The value to validate
-- @param rules table The validation rules
-- @param field_name string The field name (for error messages)
-- @return boolean, string Whether validation passed, error message if failed
local function validate_field(value, rules, field_name)
  -- Check required
  if rules.required and (value == nil or value == "") then
    return false, string.format("%s is required", field_name)
  end
  
  -- If value is nil and not required, skip other validations
  if value == nil then
    return true
  end
  
  -- Sanitize value based on expected type
  if rules.type then
    value = sanitize_value(value, rules.type)
    if value == nil and rules.required then
      return false, string.format("%s must be a valid %s", field_name, rules.type)
    end
  end
  
  -- Type validation
  if rules.type and value ~= nil then
    local type_validator = TYPE_VALIDATORS[rules.type]
    if type_validator and not type_validator(value) then
      return false, string.format("%s must be of type %s", field_name, rules.type)
    end
  end
  
  -- Length validation for strings
  if rules.length and type(value) == "string" then
    local len = string.len(value)
    if rules.length.min and len < rules.length.min then
      return false, string.format("%s must be at least %d characters long", field_name, rules.length.min)
    end
    if rules.length.max and len > rules.length.max then
      return false, string.format("%s must be no more than %d characters long", field_name, rules.length.max)
    end
  end
  
  -- Range validation for numbers
  if rules.range and type(value) == "number" then
    if rules.range.min and value < rules.range.min then
      return false, string.format("%s must be at least %s", field_name, rules.range.min)
    end
    if rules.range.max and value > rules.range.max then
      return false, string.format("%s must be no more than %s", field_name, rules.range.max)
    end
  end
  
  -- Pattern validation
  if rules.pattern and type(value) == "string" then
    local pattern = PATTERNS[rules.pattern] or rules.pattern
    if not string.match(value, pattern) then
      local pattern_name = PATTERNS[rules.pattern] and rules.pattern or "pattern"
      return false, string.format("%s format is invalid", field_name)
    end
  end
  
  -- Enum validation
  if rules.enum and value ~= nil then
    local valid = false
    for _, enum_value in ipairs(rules.enum) do
      if value == enum_value then
        valid = true
        break
      end
    end
    if not valid then
      return false, string.format("%s must be one of: %s", field_name, table.concat(rules.enum, ", "))
    end
  end
  
  -- Custom validation function
  if rules.custom and type(rules.custom) == "function" then
    local success, error_message = rules.custom(value, field_name)
    if not success then
      return false, error_message or string.format("%s is invalid", field_name)
    end
  end
  
  return true
end

-- Validate request data against schema
-- @param data table The request data to validate
-- @param schema table The validation schema
-- @return table, table Sanitized data and validation errors
function RequestValidator.validate(data, schema)
  local sanitized_data = {}
  local errors = {}
  
  if not data then data = {} end
  if not schema then return data, {} end
  
  -- Validate each field in schema
  for field_name, rules in pairs(schema) do
    local value = data[field_name]
    local success, error_message = validate_field(value, rules, field_name)
    
    if success then
      -- Store sanitized value
      sanitized_data[field_name] = sanitize_value(value, rules.type)
    else
      table.insert(errors, {
        field = field_name,
        message = error_message,
        value = value
      })
    end
  end
  
  -- Check for unexpected fields if strict mode is enabled
  if schema._strict then
    for field_name, value in pairs(data) do
      if not schema[field_name] then
        table.insert(errors, {
          field = field_name,
          message = string.format("Unexpected field: %s", field_name),
          value = value
        })
      end
    end
  end
  
  return sanitized_data, errors
end

-- Create validation middleware for a specific schema
-- @param schema table The validation schema
-- @param options table Optional configuration
-- @return function The middleware function
function RequestValidator.create_validator(schema, options)
  options = options or {}
  
  return function(client, params, next)
    local request_id = params and params.request_id or "unknown"
    
    -- Parse request body if needed
    local request_data = params or {}
    if client.body and client.headers and 
       (client.headers["Content-Type"] or ""):find("application/json") then
      local success, parsed_data = pcall(require("cjson").decode, client.body)
      if success and type(parsed_data) == "table" then
        -- Merge parsed body with existing params
        for key, value in pairs(parsed_data) do
          request_data[key] = value
        end
      else
        if params.handle_error then
          params.handle_error({
            message = "Invalid JSON in request body",
            code = "INVALID_JSON",
            status_code = 400
          })
          return
        end
      end
    end
    
    -- Perform validation
    local sanitized_data, validation_errors = RequestValidator.validate(request_data, schema)
    
    if #validation_errors > 0 then
      log.warn("Request validation failed", {
        request_id = request_id,
        errors = validation_errors,
        endpoint = options.endpoint or "unknown"
      })
      
      if params.handle_error then
        params.handle_error({
          validation_errors = validation_errors,
          message = "Request validation failed",
          type = "validation"
        })
      else
        -- Fallback error handling
        local response = ApiResponse.error(
          "VALIDATION_FAILED",
          "The request data is invalid",
          validation_errors,
          { request_id = request_id }
        )
        ApiResponse.send(client, 400, response)
      end
      return
    end
    
    -- Replace params with sanitized data
    for key, value in pairs(sanitized_data) do
      params[key] = value
    end
    
    -- Add validation metadata
    params._validated = true
    params._validation_schema = schema
    

    log.debug("Request validation passed", {
      request_id = request_id,
      fields_validated = table.concat(get_table_keys(schema), ", "),
      endpoint = options.endpoint or "unknown"
    })
    
    -- Continue to next middleware/handler
    if next then
      next()
    end
  end
end

-- Common validation schemas
RequestValidator.schemas = {
  -- User authentication
  login = {
    username = { required = true, type = "string", length = { min = 3, max = 50 } },
    password = { required = true, type = "string", length = { min = 8, max = 128 } },
    remember_me = { type = "boolean" }
  },
  
  -- User registration/creation
  user_create = {
    username = { required = true, type = "string", pattern = "username", length = { min = 3, max = 50 } },
    email = { required = true, type = "string", pattern = "email", length = { max = 255 } },
    password = { required = true, type = "string", pattern = "password", length = { min = 8, max = 128 } },
    role = { required = true, type = "string", enum = { "Admin", "Pastor", "Member" } },
    member_id = { type = "integer", range = { min = 1 } }
  },
  
  -- User update
  user_update = {
    email = { type = "string", pattern = "email", length = { max = 255 } },
    role = { type = "string", enum = { "Admin", "Pastor", "Member" } },
    is_active = { type = "boolean" },
    member_id = { type = "integer", range = { min = 1 } }
  },
  
  -- Password change
  password_change = {
    current_password = { required = true, type = "string" },
    new_password = { required = true, type = "string", pattern = "password", length = { min = 8, max = 128 } },
    confirm_password = { required = true, type = "string" }
  },
  
  -- Member creation
  member_create = {
    first_name = { required = true, type = "string", length = { min = 1, max = 100 } },
    last_name = { required = true, type = "string", length = { min = 1, max = 100 } },
    email = { required = true, type = "string", pattern = "email", length = { max = 255 } },
    phone = { type = "string", pattern = "phone", length = { max = 20 } },
    address = { type = "string", length = { max = 500 } },
    birth_date = { type = "string", pattern = "date" },
    join_date = { type = "string", pattern = "date" },
    status = { type = "string", enum = { "Active", "Inactive", "Visitor" } }
  },
  
  -- Member update
  member_update = {
    first_name = { type = "string", length = { min = 1, max = 100 } },
    last_name = { type = "string", length = { min = 1, max = 100 } },
    email = { type = "string", pattern = "email", length = { max = 255 } },
    phone = { type = "string", pattern = "phone", length = { max = 20 } },
    address = { type = "string", length = { max = 500 } },
    birth_date = { type = "string", pattern = "date" },
    join_date = { type = "string", pattern = "date" },
    status = { type = "string", enum = { "Active", "Inactive", "Visitor" } }
  },
  
  -- Pagination parameters
  pagination = {
    page = { type = "integer", range = { min = 1 } },
    per_page = { type = "integer", range = { min = 1, max = 100 } },
    order_by = { type = "string", length = { max = 50 } },
    order_direction = { type = "string", enum = { "ASC", "DESC", "asc", "desc" } }
  },
  
  -- Search parameters
  search = {
    q = { type = "string", length = { min = 1, max = 200 } },
    search = { type = "string", length = { min = 1, max = 200 } }
  }
}

-- Helper to combine schemas
-- @param ... table Multiple schemas to combine
-- @return table Combined schema
function RequestValidator.combine_schemas(...)
  local combined = {}
  for _, schema in ipairs({...}) do
    for field, rules in pairs(schema) do
      combined[field] = rules
    end
  end
  return combined
end

-- Helper to create optional version of schema
-- @param schema table The schema to make optional
-- @return table Schema with all required fields made optional
function RequestValidator.make_optional(schema)
  local optional_schema = {}
  for field, rules in pairs(schema) do
    local optional_rules = {}
    for key, value in pairs(rules) do
      if key ~= "required" then
        optional_rules[key] = value
      end
    end
    optional_schema[field] = optional_rules
  end
  return optional_schema
end

return RequestValidator
