-- src/routes/api_routes.lua
-- Example of how to integrate the new standardized API layer with existing routes

local router = require("src.routes.router")
local ApiMiddleware = require("src.application.middlewares.api_middleware")
local security_config = require("src.infrastructure.config.security")

-- Import controllers
local AuthController = require("src.controllers.auth_controller_secure")
local ExampleController = require("src.controllers.example_standardized_controller")

-- API Routes Module
local ApiRoutes = {}

-- Determine allowed CORS origin once at module init
local function derive_allowed_origin()
  -- Prefer explicit env override, then security config, fallback to local dev
  local raw = os.getenv("ALLOWED_ORIGIN")
  if not raw or raw == "" then
    local cfg = security_config and security_config.web_security and security_config.web_security.cors
    raw = (cfg and cfg.allowed_origins) or "http://localhost:5173"
  end
  -- If comma-separated list, pick the first non-empty trimmed value
  local first = raw:match("^%s*([^,%s]+)") or raw
  -- If wildcard is configured but credentials are used, fallback to dev default
  if first == "*" then
    first = "http://localhost:5173"
  end
  return first
end

local allowed_origin = derive_allowed_origin()

-- Reusable CORS preflight handler
local function send_cors_options(client)
  local json_utils = require("src.utils.json")
  local headers = {
    ["Access-Control-Allow-Origin"] = allowed_origin,
    ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
    ["Access-Control-Allow-Headers"] = "Content-Type, Authorization",
    ["Access-Control-Allow-Credentials"] = "true"
  }
  json_utils.send_response(client, 200, headers, "")
end

-- Register all API routes with standardized middleware
function ApiRoutes.register()
  
  -- Authentication endpoints (public, but with validation and rate limiting)
  router.register("/api/v1/auth/login", {
    OPTIONS = function(client, params)
      send_cors_options(client)
    end,
    POST = function(client, params)
      local middleware = ApiMiddleware.presets.public({
        validation_schema = ApiMiddleware.schemas.login,
        rate_limiting = true,
        endpoint = "auth.login"
      })

      middleware(client, params, function()
        AuthController.login(client, params)
      end)
    end
  })
  
  router.register("/api/v1/auth/logout", {
    OPTIONS = function(client, params)
      send_cors_options(client)
    end,
    POST = function(client, params)
      local middleware = ApiMiddleware.presets.authenticated({
        endpoint = "auth.logout"
      })

      middleware(client, params, function()
        AuthController.logout(client, params)
      end)
    end
  })
  
  router.register("/api/v1/auth/me", {
    OPTIONS = function(client, params)
      send_cors_options(client)
    end,
    GET = function(client, params)
      local middleware = ApiMiddleware.presets.authenticated({
        endpoint = "auth.me"
      })

      middleware(client, params, function()
        AuthController.me(client, params)
      end)
    end
  })
  
  -- Member management endpoints
  router.register("/api/v1/members", {
    GET = ApiMiddleware.protect(ExampleController.index, ExampleController.middleware.index),
    POST = ApiMiddleware.protect(ExampleController.create, ExampleController.middleware.create)
  })
  
  router.register("^/api/v1/members/(%d+)$", {
    GET = ApiMiddleware.protect(ExampleController.show, ExampleController.middleware.show),
    PUT = ApiMiddleware.protect(ExampleController.update, ExampleController.middleware.update),
    DELETE = ApiMiddleware.protect(ExampleController.destroy, ExampleController.middleware.destroy)
  })

  -- API documentation endpoint
  router.register("/api/v1/info", {
    GET = function(client, params)
      local middleware = ApiMiddleware.presets.public({
        endpoint = "api.info"
      })

      middleware(client, params, function()
        local version_info = ApiMiddleware.ApiVersioning.get_version_info()

        params.send_success({
          api_name = "Church Management System API",
          version = params.api_version or "v1",
          supported_versions = version_info.supported_versions,
          default_version = version_info.default_version,
          endpoints = {
            authentication = {
              "POST /auth/login",
              "POST /auth/logout",
              "GET /auth/me"
            },
            members = {
              "GET /api/v1/members",
              "POST /api/v1/members",
              "GET /api/v1/members/:id",
              "PUT /api/v1/members/:id",
              "DELETE /api/v1/members/:id"
            }
          },
          documentation = "See /docs/API_LAYER_DOCUMENTATION.md"
        }, "API information retrieved successfully")
      end)
    end
  })

  -- Health check endpoint
  router.register("/api/v1/health", {
    GET = function(client, params)
      local middleware = ApiMiddleware.presets.public({
        endpoint = "health.check"
      })

      middleware(client, params, function()
        params.send_success({
          status = "healthy",
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
          uptime = os.time(),
          version = params.api_version or "v1"
        }, "System is healthy")
      end)
    end
  })
  
end

-- Backward compatibility - wrap existing controllers with basic error handling
function ApiRoutes.wrap_legacy_controller(controller_function)
  return ApiMiddleware.with_error_handling(controller_function)
end

-- Helper to quickly convert existing routes to standardized format
function ApiRoutes.migrate_route(handler, auth_level, validation_schema)
  local middleware_config = {
    authentication = auth_level or "member",
    validation_schema = validation_schema
  }
  
  return ApiMiddleware.protect(handler, middleware_config)
end

return ApiRoutes
