-- src/application/middlewares/api_response.lua
-- Standardized API response middleware for consistent response format

local json_utils = require("src.utils.json")
local log = require("src.utils.log")

local ApiResponse = {}

-- Standard response structure
local RESPONSE_STRUCTURE = {
  success = true,      -- boolean indicating if request was successful
  data = nil,          -- response payload (object, array, or primitive)
  message = nil,       -- human-readable message (optional)
  error = nil,         -- error information (only present if success = false)
  meta = {             -- metadata about the response
    timestamp = nil,
    request_id = nil,
    version = "v1"
  },
  pagination = nil     -- pagination info (only for paginated responses)
}

-- Generate request ID for tracking
local function generate_request_id()
  return string.format("%d-%s", os.time(), string.sub(tostring(math.random()), 3, 8))
end

-- Get current timestamp in ISO 8601 format
local function get_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Create standardized success response
-- @param data mixed The response data
-- @param message string Optional success message
-- @param meta table Optional metadata
-- @param pagination table Optional pagination info
-- @return table Standardized response structure
function ApiResponse.success(data, message, meta, pagination)
  local response = {
    success = true,
    data = data,
    message = message,
    meta = {
      timestamp = get_timestamp(),
      request_id = (meta and meta.request_id) or generate_request_id(),
      version = (meta and meta.version) or "v1"
    }
  }
  
  if pagination then
    response.pagination = pagination
  end
  
  -- Add any additional meta fields
  if meta then
    for key, value in pairs(meta) do
      if key ~= "request_id" and key ~= "version" then
        response.meta[key] = value
      end
    end
  end
  
  return response
end

-- Create standardized error response
-- @param error_code string Machine-readable error code
-- @param message string Human-readable error message
-- @param details mixed Optional detailed error information
-- @param meta table Optional metadata
-- @return table Standardized error response structure
function ApiResponse.error(error_code, message, details, meta)
  local response = {
    success = false,
    data = nil,
    error = {
      code = error_code,
      message = message,
      details = details
    },
    meta = {
      timestamp = get_timestamp(),
      request_id = (meta and meta.request_id) or generate_request_id(),
      version = (meta and meta.version) or "v1"
    }
  }
  
  -- Add any additional meta fields
  if meta then
    for key, value in pairs(meta) do
      if key ~= "request_id" and key ~= "version" then
        response.meta[key] = value
      end
    end
  end
  
  return response
end

-- Create paginated response
-- @param data array The paginated data
-- @param page number Current page number
-- @param per_page number Items per page
-- @param total_count number Total number of items (optional)
-- @param message string Optional message
-- @param meta table Optional metadata
-- @return table Standardized paginated response
function ApiResponse.paginated(data, page, per_page, total_count, message, meta)
  local pagination = {
    current_page = page,
    per_page = per_page,
    total_items = total_count,
    has_next = data and #data == per_page,
    has_previous = page > 1
  }
  
  if total_count then
    pagination.total_pages = math.ceil(total_count / per_page)
    pagination.has_next = page < pagination.total_pages
  end
  
  return ApiResponse.success(data, message, meta, pagination)
end

-- Send standardized JSON response
-- @param client table The client connection
-- @param status_code number HTTP status code
-- @param response_data table The response data (should be from success() or error())
function ApiResponse.send(client, status_code, response_data)
  -- Ensure response has proper structure
  if not response_data.meta then
    response_data.meta = {
      timestamp = get_timestamp(),
      request_id = generate_request_id(),
      version = "v1"
    }
  end
  
  -- Add appropriate headers
  local headers = {
    ["Content-Type"] = "application/json; charset=utf-8",
    ["X-API-Version"] = response_data.meta.version or "v1",
    ["X-Request-ID"] = response_data.meta.request_id,
    ["Cache-Control"] = "no-cache, no-store, must-revalidate"
  }
  
  -- Log response for monitoring
  local log_data = {
    request_id = response_data.meta.request_id,
    status_code = status_code,
    success = response_data.success,
    version = response_data.meta.version
  }
  
  if not response_data.success and response_data.error then
    log_data.error_code = response_data.error.code
    log.warn("API error response", log_data)
  else
    log.info("API response", log_data)
  end
  
  -- Send response using existing JSON utility
  json_utils.send_response(client, status_code, headers, require("cjson").encode(response_data))
end

-- Middleware to add response helpers to request context
-- @return function The middleware function
function ApiResponse.middleware()
  return function(client, params, next)
    -- Add response helpers to params
    params = params or {}
    
    -- Generate request ID for this request
    local request_id = generate_request_id()
    params.request_id = request_id
    
    -- Add response helper functions
    params.send_success = function(data, message, meta, pagination)
      local response_meta = meta or {}
      response_meta.request_id = request_id
      
      local response = pagination and 
        ApiResponse.paginated(data, pagination.page, pagination.per_page, pagination.total_count, message, response_meta) or
        ApiResponse.success(data, message, response_meta)
      
      ApiResponse.send(client, 200, response)
    end
    
    params.send_created = function(data, message, meta)
      local response_meta = meta or {}
      response_meta.request_id = request_id
      
      local response = ApiResponse.success(data, message or "Resource created successfully", response_meta)
      ApiResponse.send(client, 201, response)
    end
    
    params.send_error = function(status_code, error_code, message, details, meta)
      local response_meta = meta or {}
      response_meta.request_id = request_id
      
      local response = ApiResponse.error(error_code, message, details, response_meta)
      ApiResponse.send(client, status_code, response)
    end
    
    params.send_validation_error = function(validation_errors, meta)
      local response_meta = meta or {}
      response_meta.request_id = request_id
      
      local response = ApiResponse.error(
        "VALIDATION_FAILED",
        "The request data is invalid",
        validation_errors,
        response_meta
      )
      ApiResponse.send(client, 400, response)
    end
    
    params.send_not_found = function(resource_type, meta)
      local response_meta = meta or {}
      response_meta.request_id = request_id
      
      local message = resource_type and 
        string.format("%s not found", resource_type) or 
        "Resource not found"
      
      local response = ApiResponse.error("NOT_FOUND", message, nil, response_meta)
      ApiResponse.send(client, 404, response)
    end
    
    params.send_unauthorized = function(message, meta)
      local response_meta = meta or {}
      response_meta.request_id = request_id
      
      local response = ApiResponse.error(
        "UNAUTHORIZED",
        message or "Authentication required",
        nil,
        response_meta
      )
      ApiResponse.send(client, 401, response)
    end
    
    params.send_forbidden = function(message, meta)
      local response_meta = meta or {}
      response_meta.request_id = request_id
      
      local response = ApiResponse.error(
        "FORBIDDEN",
        message or "Access denied",
        nil,
        response_meta
      )
      ApiResponse.send(client, 403, response)
    end
    
    -- Continue to next middleware/handler
    if next then
      next()
    end
  end
end

-- Common HTTP status codes and their meanings
ApiResponse.STATUS_CODES = {
  OK = 200,
  CREATED = 201,
  NO_CONTENT = 204,
  BAD_REQUEST = 400,
  UNAUTHORIZED = 401,
  FORBIDDEN = 403,
  NOT_FOUND = 404,
  METHOD_NOT_ALLOWED = 405,
  CONFLICT = 409,
  UNPROCESSABLE_ENTITY = 422,
  TOO_MANY_REQUESTS = 429,
  INTERNAL_SERVER_ERROR = 500,
  BAD_GATEWAY = 502,
  SERVICE_UNAVAILABLE = 503
}

-- Common error codes
ApiResponse.ERROR_CODES = {
  -- Validation errors
  VALIDATION_FAILED = "VALIDATION_FAILED",
  REQUIRED_FIELD_MISSING = "REQUIRED_FIELD_MISSING",
  INVALID_FORMAT = "INVALID_FORMAT",
  INVALID_VALUE = "INVALID_VALUE",
  
  -- Authentication/Authorization errors
  UNAUTHORIZED = "UNAUTHORIZED",
  FORBIDDEN = "FORBIDDEN",
  INVALID_CREDENTIALS = "INVALID_CREDENTIALS",
  TOKEN_EXPIRED = "TOKEN_EXPIRED",
  INVALID_TOKEN = "INVALID_TOKEN",
  INSUFFICIENT_PERMISSIONS = "INSUFFICIENT_PERMISSIONS",
  
  -- Resource errors
  NOT_FOUND = "NOT_FOUND",
  ALREADY_EXISTS = "ALREADY_EXISTS",
  CONFLICT = "CONFLICT",
  
  -- Rate limiting
  RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED",
  
  -- Server errors
  INTERNAL_ERROR = "INTERNAL_ERROR",
  DATABASE_ERROR = "DATABASE_ERROR",
  SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
}

return ApiResponse
