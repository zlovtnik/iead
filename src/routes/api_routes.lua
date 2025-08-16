-- src/routes/api_routes.lua
-- Example of how to integrate the new standardized API layer with existing routes

local router = require("src.routes.router")
local ApiMiddleware = require("src.application.middlewares.api_middleware")

-- Import controllers
local AuthController = require("src.controllers.auth_controller_secure")
local ExampleController = require("src.controllers.example_standardized_controller")

-- API Routes Module
local ApiRoutes = {}

-- Register all API routes with standardized middleware
function ApiRoutes.register()
  
  -- Authentication endpoints (public, but with validation and rate limiting)
  router.register("/api/v1/auth/login", {
    POST = ApiMiddleware.presets.public({
      validation_schema = ApiMiddleware.schemas.login,
      rate_limiting = true,
      endpoint = "auth.login"
    })(AuthController.login)
  })
  
  router.register("/api/v1/auth/logout", {
    POST = ApiMiddleware.presets.authenticated({
      endpoint = "auth.logout"
    })(AuthController.logout)
  })
  
  router.register("/api/v1/auth/me", {
    GET = ApiMiddleware.presets.authenticated({
      endpoint = "auth.me"
    })(AuthController.me)
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
    GET = ApiMiddleware.presets.public({
      endpoint = "api.info"
    })(function(client, params)
      local version_info = ApiMiddleware.ApiVersioning.get_version_info()
      
      params.send_success({
        api_name = "Church Management System API",
        version = params.api_version or "v1", 
        supported_versions = version_info.supported_versions,
        default_version = version_info.default_version,
        endpoints = {
          authentication = {
            "POST /api/v1/auth/login",
            "POST /api/v1/auth/logout", 
            "GET /api/v1/auth/me"
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
  })
  
  -- Health check endpoint
  router.register("/api/v1/health", {
    GET = ApiMiddleware.presets.public({
      endpoint = "health.check"
    })(function(client, params)
      params.send_success({
        status = "healthy",
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        uptime = os.time(),
        version = params.api_version or "v1"
      }, "System is healthy")
    end)
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
