-- src/application/middlewares/api_versioning.lua
-- API versioning middleware to handle multiple API versions

local ApiResponse = require("src.application.middlewares.api_response")
local log = require("src.utils.log")

local ApiVersioning = {}

-- Helper function to get table keys
local function get_table_keys(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

-- Supported API versions
local SUPPORTED_VERSIONS = {
  "v1",   -- Current stable version
  "v2"    -- Future version (when needed)
}

-- Default version when none is specified
local DEFAULT_VERSION = "v1"

-- Version deprecation information
local VERSION_INFO = {
  v1 = {
    status = "stable",
    deprecated = false,
    sunset_date = nil,
    description = "Initial stable API version"
  },
  v2 = {
    status = "development", 
    deprecated = false,
    sunset_date = nil,
    description = "Next generation API (in development)"
  }
}

-- Extract version from different sources
-- @param client table The client connection
-- @return string The API version to use
local function extract_version(client)
  local version = nil
  
  -- 1. Check Accept header (e.g., "application/vnd.church-api.v1+json")
  if client.headers and client.headers["Accept"] then
    local accept = client.headers["Accept"]
    version = string.match(accept, "application/vnd%.church%-api%.([^%+]+)%+json")
  end
  
  -- 2. Check custom version header
  if not version and client.headers then
    version = client.headers["X-API-Version"] or client.headers["x-api-version"]
  end
  
  -- 3. Check query parameter
  if not version and client.query then
    version = client.query.version or client.query.v
  end
  
  -- 4. Check URL path prefix (e.g., /api/v1/users)
  if not version and client.path then
    version = string.match(client.path, "^/api/([^/]+)/")
  end
  
  return version
end

-- Validate if version is supported
-- @param version string The version to validate
-- @return boolean, string Whether version is valid, normalized version
local function validate_version(version)
  if not version then
    return true, DEFAULT_VERSION
  end
  
  -- Normalize version (remove 'v' prefix if present)
  local normalized = version:lower()
  if not normalized:match("^v") then
    normalized = "v" .. normalized
  end
  
  -- Check if version is supported
  for _, supported in ipairs(SUPPORTED_VERSIONS) do
    if normalized == supported then
      return true, normalized
    end
  end
  
  return false, nil
end

-- Get version-specific route handler
-- @param handlers table Map of version to handler function
-- @param version string The requested version
-- @return function The handler for the specified version
local function get_versioned_handler(handlers, version)
  -- Try exact version match first
  if handlers[version] then
    return handlers[version]
  end
  
  -- Fall back to default version
  if handlers[DEFAULT_VERSION] then
    return handlers[DEFAULT_VERSION]
  end
  
  -- Fall back to unversioned handler
  if handlers.default or handlers["*"] then
    return handlers.default or handlers["*"]
  end
  
  return nil
end

-- Add version-specific response headers
-- @param client table The client connection
-- @param version string The API version being used
local function add_version_headers(client, version)
  local version_info = VERSION_INFO[version]
  if not version_info then return end
  
  -- Standard version header
  client.response_headers = client.response_headers or {}
  client.response_headers["X-API-Version"] = version
  
  -- Deprecation warning
  if version_info.deprecated then
    client.response_headers["Warning"] = string.format(
      '299 - "API version %s is deprecated%s"',
      version,
      version_info.sunset_date and (" and will be removed on " .. version_info.sunset_date) or ""
    )
    
    if version_info.sunset_date then
      client.response_headers["Sunset"] = version_info.sunset_date
    end
  end
  
  -- API status
  client.response_headers["X-API-Status"] = version_info.status
end

-- Create version handling middleware
-- @return function The middleware function
function ApiVersioning.middleware()
  return function(client, params, next)
    local request_id = params and params.request_id or "unknown"
    
    -- Extract requested version
    local requested_version = extract_version(client)
    local is_valid, version = validate_version(requested_version)
    
    if not is_valid then
      log.warn("Unsupported API version requested", {
        request_id = request_id,
        requested_version = requested_version,
        supported_versions = SUPPORTED_VERSIONS
      })
      
      if params.handle_error then
        params.handle_error({
          message = string.format("Unsupported API version '%s'. Supported versions: %s", 
            requested_version, table.concat(SUPPORTED_VERSIONS, ", ")),
          code = "UNSUPPORTED_VERSION",
          status_code = 400,
          details = {
            requested_version = requested_version,
            supported_versions = SUPPORTED_VERSIONS
          }
        })
      else
        local response = ApiResponse.error(
          "UNSUPPORTED_VERSION",
          "Unsupported API version",
          {
            requested_version = requested_version,
            supported_versions = SUPPORTED_VERSIONS
          },
          { request_id = request_id }
        )
        ApiResponse.send(client, 400, response)
      end
      return
    end
    
    -- Set version in params
    params = params or {}
    params.api_version = version
    
    -- Add version headers
    add_version_headers(client, version)
    
    -- Log version usage
    log.debug("API version determined", {
      request_id = request_id,
      requested_version = requested_version,
      resolved_version = version,
      path = client.path
    })
    
    -- Continue to next middleware/handler
    if next then
      next()
    end
  end
end

-- Create versioned route handler
-- @param version_handlers table Map of version to handler function
-- @return function Handler that selects appropriate version
function ApiVersioning.versioned_handler(version_handlers)
  return function(client, params)
    local version = params and params.api_version or DEFAULT_VERSION
    local handler = get_versioned_handler(version_handlers, version)
    
    if not handler then
      local request_id = params and params.request_id or "unknown"
      
      log.error("No handler found for API version", {
        request_id = request_id,
        version = version,
        available_versions = get_table_keys(version_handlers)
      })
      
      if params.handle_error then
        params.handle_error({
          message = "No implementation available for this API version",
          code = "VERSION_NOT_IMPLEMENTED",
          status_code = 501
        })
      else
        local response = ApiResponse.error(
          "VERSION_NOT_IMPLEMENTED", 
          "No implementation available for this API version",
          { version = version },
          { request_id = request_id }
        )
        ApiResponse.send(client, 501, response)
      end
      return
    end
    
    -- Call the version-specific handler
    return handler(client, params)
  end
end

-- Helper to create a route that supports multiple versions
-- @param routes table Map of version to route configuration
-- @return table Route configuration with version handling
function ApiVersioning.versioned_route(routes)
  local combined_handlers = {}
  
  for version, route_config in pairs(routes) do
    if type(route_config) == "table" then
      for method, handler in pairs(route_config) do
        combined_handlers[method] = combined_handlers[method] or {}
        combined_handlers[method][version] = handler
      end
    end
  end
  
  -- Create versioned handlers for each HTTP method
  local versioned_route = {}
  for method, version_handlers in pairs(combined_handlers) do
    versioned_route[method] = ApiVersioning.versioned_handler(version_handlers)
  end
  
  return versioned_route
end

-- Get information about API versions
-- @return table Version information for API documentation
function ApiVersioning.get_version_info()
  return {
    supported_versions = SUPPORTED_VERSIONS,
    default_version = DEFAULT_VERSION,
    version_details = VERSION_INFO
  }
end

-- Helper to mark a version as deprecated
-- @param version string The version to deprecate
-- @param sunset_date string Optional sunset date (ISO 8601 format)
function ApiVersioning.deprecate_version(version, sunset_date)
  if VERSION_INFO[version] then
    VERSION_INFO[version].deprecated = true
    VERSION_INFO[version].sunset_date = sunset_date
    VERSION_INFO[version].status = "deprecated"
  end
end

-- Helper to add a new version
-- @param version string The new version identifier
-- @param info table Version information
function ApiVersioning.add_version(version, info)
  table.insert(SUPPORTED_VERSIONS, version)
  VERSION_INFO[version] = info or {
    status = "development",
    deprecated = false,
    sunset_date = nil,
    description = "New API version"
  }
end

-- Helper for version-aware endpoint documentation
-- @param endpoint_docs table Documentation for different versions
-- @return table Combined documentation with version information
function ApiVersioning.document_endpoint(endpoint_docs)
  return {
    versions = endpoint_docs,
    supported_versions = SUPPORTED_VERSIONS,
    default_version = DEFAULT_VERSION,
    version_selection = {
      methods = {
        "Accept header: application/vnd.church-api.v1+json",
        "X-API-Version header: v1",
        "Query parameter: ?version=v1",
        "URL path: /api/v1/endpoint"
      },
      precedence = "Accept header > X-API-Version header > Query parameter > URL path > Default"
    }
  }
end

return ApiVersioning
