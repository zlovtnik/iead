-- src/application/middlewares/error_handler.lua
-- Centralized error handling middleware

local ApiResponse = require("src.application.middlewares.api_response")
local log = require("src.utils.log")

local ErrorHandler = {}

-- Error categories for better handling
local ERROR_CATEGORIES = {
  VALIDATION = "validation",
  AUTHENTICATION = "authentication", 
  AUTHORIZATION = "authorization",
  RESOURCE = "resource",
  BUSINESS_LOGIC = "business_logic",
  INFRASTRUCTURE = "infrastructure",
  EXTERNAL = "external"
}

-- Predefined error mappings
local ERROR_MAPPINGS = {
  -- Database errors
  ["constraint violation"] = {
    status = 409,
    code = "CONFLICT",
    message = "Data conflict occurred",
    category = ERROR_CATEGORIES.INFRASTRUCTURE
  },
  ["foreign key constraint"] = {
    status = 409,
    code = "REFERENCE_ERROR", 
    message = "Referenced resource does not exist",
    category = ERROR_CATEGORIES.BUSINESS_LOGIC
  },
  ["unique constraint"] = {
    status = 409,
    code = "ALREADY_EXISTS",
    message = "Resource already exists",
    category = ERROR_CATEGORIES.BUSINESS_LOGIC
  },
  
  -- Authentication errors
  ["invalid credentials"] = {
    status = 401,
    code = "INVALID_CREDENTIALS",
    message = "Invalid username or password",
    category = ERROR_CATEGORIES.AUTHENTICATION
  },
  ["token expired"] = {
    status = 401,
    code = "TOKEN_EXPIRED", 
    message = "Authentication token has expired",
    category = ERROR_CATEGORIES.AUTHENTICATION
  },
  ["invalid token"] = {
    status = 401,
    code = "INVALID_TOKEN",
    message = "Invalid authentication token",
    category = ERROR_CATEGORIES.AUTHENTICATION
  },
  
  -- Authorization errors
  ["insufficient permissions"] = {
    status = 403,
    code = "INSUFFICIENT_PERMISSIONS",
    message = "You don't have permission to perform this action",
    category = ERROR_CATEGORIES.AUTHORIZATION
  },
  ["access denied"] = {
    status = 403,
    code = "ACCESS_DENIED",
    message = "Access to this resource is denied",
    category = ERROR_CATEGORIES.AUTHORIZATION
  },
  
  -- Resource errors
  ["not found"] = {
    status = 404,
    code = "NOT_FOUND",
    message = "The requested resource was not found",
    category = ERROR_CATEGORIES.RESOURCE
  },
  ["resource not found"] = {
    status = 404,
    code = "NOT_FOUND",
    message = "The requested resource was not found", 
    category = ERROR_CATEGORIES.RESOURCE
  }
}

-- Check if error message matches any predefined patterns
local function match_error_pattern(error_message)
  if not error_message then return nil end
  
  local lower_message = string.lower(error_message)
  
  for pattern, mapping in pairs(ERROR_MAPPINGS) do
    if string.find(lower_message, pattern, 1, true) then
      return mapping
    end
  end
  
  return nil
end

-- Determine error category based on error details
local function categorize_error(error_info)
  if error_info.validation_errors then
    return ERROR_CATEGORIES.VALIDATION
  end
  
  if error_info.status_code then
    if error_info.status_code == 401 then
      return ERROR_CATEGORIES.AUTHENTICATION
    elseif error_info.status_code == 403 then
      return ERROR_CATEGORIES.AUTHORIZATION
    elseif error_info.status_code == 404 then
      return ERROR_CATEGORIES.RESOURCE
    elseif error_info.status_code >= 500 then
      return ERROR_CATEGORIES.INFRASTRUCTURE
    end
  end
  
  return ERROR_CATEGORIES.BUSINESS_LOGIC
end

-- Standardize error information
-- @param error mixed The error (string, table, or error object)
-- @param context table Optional context information
-- @return table Standardized error information
function ErrorHandler.normalize_error(error, context)
  local error_info = {
    original_error = error,
    context = context or {},
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  }
  
  -- Handle different error types
  if type(error) == "string" then
    error_info.message = error
    error_info.type = "generic"
  elseif type(error) == "table" then
    if error.message then
      error_info.message = error.message
      error_info.code = error.code
      error_info.status_code = error.status_code or error.status
      error_info.details = error.details
      error_info.validation_errors = error.validation_errors
      error_info.type = error.type or "structured"
    else
      -- Assume it's validation errors
      error_info.validation_errors = error
      error_info.message = "Validation failed"
      error_info.type = "validation"
    end
  else
    error_info.message = tostring(error)
    error_info.type = "unknown"
  end
  
  -- Try to match against predefined patterns
  local pattern_match = match_error_pattern(error_info.message)
  if pattern_match then
    error_info.status_code = error_info.status_code or pattern_match.status
    error_info.code = error_info.code or pattern_match.code
    error_info.category = pattern_match.category
    -- Keep original message but store suggested message
    error_info.suggested_message = pattern_match.message
  end
  
  -- Determine category if not set
  error_info.category = error_info.category or categorize_error(error_info)
  
  -- Set default status code if not determined
  if not error_info.status_code then
    if error_info.category == ERROR_CATEGORIES.VALIDATION then
      error_info.status_code = 400
    elseif error_info.category == ERROR_CATEGORIES.AUTHENTICATION then
      error_info.status_code = 401
    elseif error_info.category == ERROR_CATEGORIES.AUTHORIZATION then
      error_info.status_code = 403
    elseif error_info.category == ERROR_CATEGORIES.RESOURCE then
      error_info.status_code = 404
    elseif error_info.category == ERROR_CATEGORIES.BUSINESS_LOGIC then
      error_info.status_code = 422
    else
      error_info.status_code = 500
    end
  end
  
  -- Set default error code if not determined
  if not error_info.code then
    if error_info.status_code == 400 then
      error_info.code = "BAD_REQUEST"
    elseif error_info.status_code == 401 then
      error_info.code = "UNAUTHORIZED"
    elseif error_info.status_code == 403 then
      error_info.code = "FORBIDDEN"
    elseif error_info.status_code == 404 then
      error_info.code = "NOT_FOUND"
    elseif error_info.status_code == 422 then
      error_info.code = "UNPROCESSABLE_ENTITY"
    else
      error_info.code = "INTERNAL_ERROR"
    end
  end
  
  return error_info
end

-- Handle and respond to errors
-- @param client table The client connection
-- @param error mixed The error to handle
-- @param context table Optional context information
function ErrorHandler.handle_error(client, error, context)
  local error_info = ErrorHandler.normalize_error(error, context)
  
  -- Log error with appropriate level
  local log_data = {
    request_id = context and context.request_id,
    error_code = error_info.code,
    error_category = error_info.category,
    status_code = error_info.status_code,
    message = error_info.message,
    context = context
  }
  
  if error_info.status_code >= 500 then
    log.error("Server error occurred", log_data)
  elseif error_info.status_code >= 400 then
    log.warn("Client error occurred", log_data)
  else
    log.info("Error handled", log_data)
  end
  
  -- Prepare response details
  local response_details = error_info.details
  if error_info.validation_errors then
    response_details = error_info.validation_errors
  end
  
  -- Use suggested message for client-facing errors, but keep original for server errors
  local client_message = error_info.message
  if error_info.suggested_message and error_info.status_code < 500 then
    client_message = error_info.suggested_message
  end
  
  -- Create standardized error response
  local response = ApiResponse.error(
    error_info.code,
    client_message,
    response_details,
    {
      request_id = context and context.request_id,
      error_category = error_info.category
    }
  )
  
  ApiResponse.send(client, error_info.status_code, response)
end

-- Global error handler middleware
-- @return function The middleware function
function ErrorHandler.middleware()
  return function(client, params, next)
    -- Set up error handling context
    params = params or {}
    
    -- Add error handling function to params
    params.handle_error = function(error, additional_context)
      local context = {
        request_id = params.request_id,
        user_id = params.current_user and params.current_user.id,
        endpoint = params.endpoint,
        method = client.method
      }
      
      -- Merge additional context
      if additional_context then
        for key, value in pairs(additional_context) do
          context[key] = value
        end
      end
      
      ErrorHandler.handle_error(client, error, context)
    end
    
    -- Wrap next() call in protected mode
    if next then
      local success, err = pcall(next)
      if not success then
        -- Unhandled error occurred
        params.handle_error(err, {
          error_type = "unhandled_exception",
          location = "middleware_chain"
        })
      end
    end
  end
end

-- Validation error handler
-- @param validation_errors table Array of validation error messages
-- @param client table The client connection
-- @param context table Optional context information
function ErrorHandler.handle_validation_errors(validation_errors, client, context)
  local error_info = {
    validation_errors = validation_errors,
    message = "Validation failed",
    type = "validation"
  }
  
  ErrorHandler.handle_error(client, error_info, context)
end

-- Business logic error handler
-- @param message string Error message
-- @param code string Optional error code
-- @param client table The client connection
-- @param context table Optional context information
function ErrorHandler.handle_business_error(message, code, client, context)
  local error_info = {
    message = message,
    code = code,
    type = "business_logic"
  }
  
  ErrorHandler.handle_error(client, error_info, context)
end

-- Resource not found error handler
-- @param resource_type string Type of resource that wasn't found
-- @param resource_id mixed ID of the resource that wasn't found
-- @param client table The client connection
-- @param context table Optional context information
function ErrorHandler.handle_not_found(resource_type, resource_id, client, context)
  local message = resource_type and 
    string.format("%s not found", resource_type) or 
    "Resource not found"
  
  if resource_id then
    message = message .. string.format(" (ID: %s)", tostring(resource_id))
  end
  
  local error_info = {
    message = message,
    code = "NOT_FOUND",
    type = "resource",
    details = {
      resource_type = resource_type,
      resource_id = resource_id
    }
  }
  
  ErrorHandler.handle_error(client, error_info, context)
end

-- Export error categories for use in other modules
ErrorHandler.CATEGORIES = ERROR_CATEGORIES

return ErrorHandler
