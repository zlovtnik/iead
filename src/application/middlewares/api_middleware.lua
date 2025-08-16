-- src/application/middlewares/api_middleware.lua
-- Composer for API layer middlewares

local ApiResponse = require("src.application.middlewares.api_response")
local ErrorHandler = require("src.application.middlewares.error_handler")
local RequestValidator = require("src.application.middlewares.request_validator")
local ApiVersioning = require("src.application.middlewares.api_versioning")
local auth = require("src.application.middlewares.auth_middleware")
local SchemaExtractor = require("src.application.middlewares.schema_extractor")
local ControllerAnnotations = require("src.application.middlewares.controller_annotations")

local ApiMiddleware = {}

-- Middleware execution order (important for proper functioning)
local MIDDLEWARE_ORDER = {
  "api_response",      -- Must be first to set up response helpers
  "error_handling",    -- Must be early to catch all errors
  "api_versioning",    -- Version resolution before other processing
  "request_validation", -- Validate and sanitize input
  "authentication",    -- Authenticate user
  "authorization",     -- Check permissions
  "rate_limiting",     -- Rate limiting (if enabled)
  "csrf_protection"    -- CSRF protection (if enabled)
}

-- Create a middleware chain with proper order
-- @param middlewares table Array of middleware functions
-- @return function Combined middleware function
local function chain_middlewares(middlewares)
  return function(client, params, final_handler)
    local index = 1
    
    local function next()
      if index <= #middlewares then
        local middleware = middlewares[index]
        index = index + 1
        middleware(client, params, next)
      elseif final_handler then
        final_handler(client, params)
      end
    end
    
    next()
  end
end

-- Standard API middleware stack
-- @param options table Configuration options
-- @return function Complete API middleware function
function ApiMiddleware.create_standard_stack(options)
  options = options or {}
  
  local middlewares = {}
  
  -- 1. API Response middleware (always first)
  table.insert(middlewares, ApiResponse.middleware())
  
  -- 2. Error handling middleware (always second)
  table.insert(middlewares, ErrorHandler.middleware())
  
  -- 3. API versioning middleware (if enabled)
  if options.versioning ~= false then
    table.insert(middlewares, ApiVersioning.middleware())
  end
  
  -- 4. Request validation middleware (if schema provided)
  if options.validation_schema then
    table.insert(middlewares, RequestValidator.create_validator(
      options.validation_schema,
      { endpoint = options.endpoint }
    ))
  end
  
  -- 5. Authentication middleware (if required)
  if options.authentication then
    if options.authentication == true then
      table.insert(middlewares, auth.require_member())
    elseif type(options.authentication) == "string" then
      -- Role-based authentication
      if options.authentication == "admin" then
        table.insert(middlewares, auth.require_admin())
      elseif options.authentication == "pastor" then
        table.insert(middlewares, auth.require_pastor())
      elseif options.authentication == "member" then
        table.insert(middlewares, auth.require_member())
      end
    elseif type(options.authentication) == "function" then
      table.insert(middlewares, options.authentication)
    end
  end
  
  -- 6. Additional authorization middleware
  if options.authorization and type(options.authorization) == "function" then
    table.insert(middlewares, options.authorization)
  end
  
  -- 7. Rate limiting (if enabled)
  if options.rate_limiting then
    if type(options.rate_limiting) == "function" then
      table.insert(middlewares, options.rate_limiting)
    else
      -- Default rate limiting - only add if auth.rate_limit exists
      if auth.rate_limit then
        table.insert(middlewares, auth.rate_limit(function(client, params)
          return params.current_user and params.current_user.id or client.ip or "anonymous"
        end))
      end
    end
  end
  
  -- 8. CSRF protection (if enabled)
  if options.csrf_protection then
    if auth.csrf_protection then
      table.insert(middlewares, auth.csrf_protection())
    end
  end
  
  -- 9. Custom middleware
  if options.custom_middleware then
    for _, middleware in ipairs(options.custom_middleware) do
      table.insert(middlewares, middleware)
    end
  end
  
  return chain_middlewares(middlewares)
end

-- Helper function to deep extend tables (replaces vim.tbl_deep_extend)
local function deep_extend(behavior, ...)
  local tables = {...}
  if #tables < 2 then
    return tables[1] or {}
  end
  
  local result = {}
  
  -- Copy first table
  for k, v in pairs(tables[1] or {}) do
    if type(v) == "table" then
      result[k] = {}
      for k2, v2 in pairs(v) do
        result[k][k2] = v2
      end
    else
      result[k] = v
    end
  end
  
  -- Merge remaining tables
  for i = 2, #tables do
    local t = tables[i] or {}
    for k, v in pairs(t) do
      if type(v) == "table" and type(result[k]) == "table" then
        for k2, v2 in pairs(v) do
          result[k][k2] = v2
        end
      else
        result[k] = v
      end
    end
  end
  
  return result
end

-- Predefined middleware configurations for common scenarios
ApiMiddleware.presets = {
  -- Public API endpoint (no authentication)
  public = function(options)
    return ApiMiddleware.create_documented_stack(deep_extend("force", {
      authentication = false,
      csrf_protection = false,
      rate_limiting = true
    }, options or {}))
  end,
  
  -- Authenticated API endpoint
  authenticated = function(options)
    return ApiMiddleware.create_documented_stack(deep_extend("force", {
      authentication = "member",
      csrf_protection = true,
      rate_limiting = true
    }, options or {}))
  end,
  
  -- Admin-only API endpoint
  admin_only = function(options)
    return ApiMiddleware.create_documented_stack(deep_extend("force", {
      authentication = "admin",
      csrf_protection = true,
      rate_limiting = false  -- Admins typically don't need rate limiting
    }, options or {}))
  end,
  
  -- Pastor/Admin API endpoint
  pastor_only = function(options)
    return ApiMiddleware.create_documented_stack(deep_extend("force", {
      authentication = "pastor",
      csrf_protection = true,
      rate_limiting = false
    }, options or {}))
  end,
  
  -- CRUD operations with validation
  crud = function(validation_schema, options)
    return ApiMiddleware.create_documented_stack(deep_extend("force", {
      authentication = "member",
      validation_schema = validation_schema,
      csrf_protection = true,
      rate_limiting = true
    }, options or {}))
  end,
  
  -- Read-only operations
  read_only = function(options)
    return ApiMiddleware.create_documented_stack(deep_extend("force", {
      authentication = "member",
      csrf_protection = false,  -- No CSRF for read operations
      rate_limiting = true
    }, options or {}))
  end
}

-- Create protected route with middleware
-- @param handler function The route handler
-- @param middleware_config table|function Middleware configuration or function
-- @return function Protected route handler
function ApiMiddleware.protect(handler, middleware_config)
  local middleware
  
  if type(middleware_config) == "function" then
    middleware = middleware_config
  else
    middleware = ApiMiddleware.create_standard_stack(middleware_config or {})
  end
  
  return function(client, params)
    middleware(client, params, function()
      handler(client, params)
    end)
  end
end

-- Helper to create versioned and protected routes
-- @param version_handlers table Map of version to handler
-- @param middleware_config table Middleware configuration
-- @return function Protected versioned route handler
function ApiMiddleware.versioned_protect(version_handlers, middleware_config)
  local versioned_handler = ApiVersioning.versioned_handler(version_handlers)
  return ApiMiddleware.protect(versioned_handler, middleware_config)
end

-- Standard error handling for unprotected routes
-- @param handler function The route handler
-- @return function Handler with basic error handling
function ApiMiddleware.with_error_handling(handler)
  return function(client, params)
    local middleware = chain_middlewares({
      ApiResponse.middleware(),
      ErrorHandler.middleware()
    })
    
    middleware(client, params, function()
      handler(client, params)
    end)
  end
end

-- Global registry for API documentation metadata
ApiMiddleware._documentation_registry = {}

-- Helper to create API documentation middleware
-- @param docs table API documentation
-- @return function Documentation middleware
function ApiMiddleware.documentation(docs)
  return function(client, params, next)
    params = params or {}
    params.api_docs = docs
    
    if next then
      next()
    end
  end
end

-- Register endpoint documentation metadata
-- @param endpoint_id string Unique identifier for the endpoint
-- @param metadata table Documentation metadata
function ApiMiddleware.register_endpoint_docs(endpoint_id, metadata)
  if not endpoint_id or not metadata then
    return
  end
  
  ApiMiddleware._documentation_registry[endpoint_id] = {
    id = endpoint_id,
    summary = metadata.summary,
    description = metadata.description,
    tags = metadata.tags or {},
    parameters = metadata.parameters or {},
    request_body = metadata.request_body,
    responses = metadata.responses or {},
    examples = metadata.examples or {},
    auth_required = metadata.auth_required,
    deprecated = metadata.deprecated or false,
    version = metadata.version or "v1",
    registered_at = os.time()
  }
end

-- Get all registered endpoint documentation
-- @return table All registered documentation metadata
function ApiMiddleware.get_all_endpoint_docs()
  return ApiMiddleware._documentation_registry
end

-- Get documentation for specific endpoint
-- @param endpoint_id string The endpoint identifier
-- @return table|nil Documentation metadata or nil if not found
function ApiMiddleware.get_endpoint_docs(endpoint_id)
  return ApiMiddleware._documentation_registry[endpoint_id]
end

-- Enhanced middleware creation with documentation capture
-- @param options table Configuration options including documentation
-- @return function Complete API middleware function with documentation
function ApiMiddleware.create_documented_stack(options)
  options = options or {}
  
  -- Register documentation if provided
  if options.endpoint and options.documentation then
    ApiMiddleware.register_endpoint_docs(options.endpoint, options.documentation)
  end
  
  -- Create standard middleware stack
  local middleware = ApiMiddleware.create_standard_stack(options)
  
  -- Wrap with documentation capture
  return function(client, params)
    params = params or {}
    
    -- Add endpoint documentation to params
    if options.endpoint then
      params.endpoint_id = options.endpoint
      params.endpoint_docs = ApiMiddleware.get_endpoint_docs(options.endpoint)
    end
    
    -- Add route information for documentation extraction
    params.route_info = {
      path = client.path,
      method = client.method,
      endpoint_id = options.endpoint,
      validation_schema = options.validation_schema,
      authentication = options.authentication,
      rate_limiting = options.rate_limiting
    }
    
    middleware(client, params)
  end
end

-- Debugging middleware to log request/response details
-- @param options table Logging options
-- @return function Debug middleware
function ApiMiddleware.debug(options)
  options = options or {}
  
  return function(client, params, next)
    local log = require("src.utils.log")
    local request_id = params and params.request_id or "unknown"
    
    -- Log request details
    if options.log_requests ~= false then
      log.info("API Request", {
        request_id = request_id,
        method = client.method,
        path = client.path,
        user_id = params.current_user and params.current_user.id,
        api_version = params.api_version
      })
    end
    
    -- Log response details (if enabled)
    if options.log_responses then
      -- Wrap response functions to log
      local original_send_success = params.send_success
      if original_send_success then
        params.send_success = function(...)
          log.info("API Success Response", {
            request_id = request_id,
            method = client.method,
            path = client.path
          })
          return original_send_success(...)
        end
      end
    end
    
    if next then
      next()
    end
  end
end

-- Export validation schemas for convenience
ApiMiddleware.schemas = RequestValidator.schemas

-- Export response helpers for use outside middleware
ApiMiddleware.ApiResponse = ApiResponse
ApiMiddleware.ErrorHandler = ErrorHandler
ApiMiddleware.RequestValidator = RequestValidator
ApiMiddleware.ApiVersioning = ApiVersioning
ApiMiddleware.SchemaExtractor = SchemaExtractor
ApiMiddleware.ControllerAnnotations = ControllerAnnotations

-- Helper to extract documentation from validation schema
-- @param validation_schema table The validation schema
-- @param endpoint_info table Additional endpoint information
-- @return table Documentation metadata
function ApiMiddleware.extract_docs_from_schema(validation_schema, endpoint_info)
  endpoint_info = endpoint_info or {}
  
  local docs = {
    request_body = nil,
    responses = {
      ["200"] = {
        description = "Successful response",
        content = {
          ["application/json"] = {
            schema = {
              type = "object",
              properties = {
                success = { type = "boolean" },
                data = { type = "object" },
                message = { type = "string" },
                meta = {
                  type = "object",
                  properties = {
                    timestamp = { type = "string", format = "date-time" },
                    request_id = { type = "string" },
                    version = { type = "string" }
                  }
                }
              }
            }
          }
        }
      },
      ["400"] = {
        description = "Validation error"
      },
      ["401"] = {
        description = "Authentication required"
      },
      ["403"] = {
        description = "Access denied"
      },
      ["500"] = {
        description = "Internal server error"
      }
    }
  }
  
  -- Extract request body schema from validation
  if validation_schema then
    local request_schema = SchemaExtractor.extract_schema(validation_schema)
    docs.request_body = {
      required = true,
      content = {
        ["application/json"] = {
          schema = request_schema
        }
      }
    }
  end
  
  -- Add authentication requirements
  if endpoint_info.auth_required then
    docs.security = { { bearerAuth = {} } }
  end
  
  return docs
end

return ApiMiddleware
