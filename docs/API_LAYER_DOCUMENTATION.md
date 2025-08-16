# Standardized API Layer Documentation

This document describes the new standardized API layer implementation for the Church Management System.

## Overview

The API layer provides:
- ✅ **Standardized responses** - Consistent JSON response format
- ✅ **Error handling** - Centralized error processing and user-friendly messages  
- ✅ **Request validation** - Schema-based input validation and sanitization
- ✅ **API versioning** - Support for multiple API versions with deprecation handling

## Components

### 1. API Response Middleware (`api_response.lua`)

Provides standardized response format:

```lua
-- Success response
{
  "success": true,
  "data": { ... },           -- Response payload
  "message": "Optional message",
  "meta": {
    "timestamp": "2025-01-08T10:30:00Z",
    "request_id": "abc123",
    "version": "v1"
  },
  "pagination": { ... }      -- For paginated responses
}

-- Error response  
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "details": { ... }       -- Additional error details
  },
  "meta": {
    "timestamp": "2025-01-08T10:30:00Z", 
    "request_id": "abc123",
    "version": "v1"
  }
}
```

### 2. Error Handler Middleware (`error_handler.lua`)

Centralized error handling with:
- Error categorization (validation, authentication, authorization, etc.)
- Predefined error mappings
- Appropriate HTTP status codes
- Structured logging

### 3. Request Validator Middleware (`request_validator.lua`)

Schema-based validation with:
- Type checking and conversion
- Length and range validation
- Pattern matching (email, phone, etc.)
- Custom validation functions
- Input sanitization

### 4. API Versioning Middleware (`api_versioning.lua`)

Support for multiple API versions via:
- Accept headers: `application/vnd.church-api.v1+json`
- Custom headers: `X-API-Version: v1`
- Query parameters: `?version=v1`
- URL paths: `/api/v1/endpoint`

## Usage Examples

### Basic Usage

```lua
local ApiMiddleware = require("src.application.middlewares.api_middleware")

-- Simple protected endpoint
local protected_handler = ApiMiddleware.protect(function(client, params)
  -- Handler logic here
  params.send_success({ message = "Hello World" })
end, {
  authentication = "member",
  validation_schema = {
    name = { required = true, type = "string", length = { min = 1, max = 100 } }
  }
})
```

### Using Presets

```lua
-- CRUD operations with validation
local member_controller = {
  index = ApiMiddleware.presets.pastor_only({
    validation_schema = ApiMiddleware.RequestValidator.combine_schemas(
      ApiMiddleware.schemas.pagination,
      ApiMiddleware.schemas.search
    )
  }),
  
  create = ApiMiddleware.presets.pastor_only({
    validation_schema = ApiMiddleware.schemas.member_create
  }),
  
  show = ApiMiddleware.presets.authenticated(),
  
  destroy = ApiMiddleware.presets.admin_only()
}
```

### Versioned Endpoints

```lua
local versioned_handler = ApiMiddleware.versioned_protect({
  v1 = function(client, params)
    -- Version 1 implementation
    params.send_success({ version = "v1", data = legacy_data })
  end,
  
  v2 = function(client, params) 
    -- Version 2 implementation
    params.send_success({ version = "v2", data = enhanced_data })
  end
}, {
  authentication = "member"
})
```

### Router Integration

```lua
local router = require("src.routes.router")
local ExampleController = require("src.controllers.example_standardized_controller")

-- Register routes with middleware
router.register("/api/v1/members", {
  GET = ApiMiddleware.protect(ExampleController.index, ExampleController.middleware.index),
  POST = ApiMiddleware.protect(ExampleController.create, ExampleController.middleware.create)
})

router.register("^/api/v1/members/(%d+)$", {
  GET = ApiMiddleware.protect(ExampleController.show, ExampleController.middleware.show),
  PUT = ApiMiddleware.protect(ExampleController.update, ExampleController.middleware.update),
  DELETE = ApiMiddleware.protect(ExampleController.destroy, ExampleController.middleware.destroy)
})
```

## Available Presets

### `public(options)`
- No authentication required
- Rate limiting enabled
- No CSRF protection

### `authenticated(options)`  
- Member-level authentication required
- CSRF protection enabled
- Rate limiting enabled

### `admin_only(options)`
- Admin authentication required
- CSRF protection enabled
- No rate limiting (admins trusted)

### `pastor_only(options)`
- Pastor/Admin authentication required  
- CSRF protection enabled
- No rate limiting

### `crud(validation_schema, options)`
- Member authentication required
- Custom validation schema
- CSRF protection and rate limiting enabled

### `read_only(options)`
- Member authentication required
- No CSRF protection (read operations)
- Rate limiting enabled

## Response Helpers

Available in all protected routes via `params`:

```lua
-- Success responses
params.send_success(data, message, meta, pagination)
params.send_created(data, message, meta)

-- Error responses  
params.send_error(status_code, error_code, message, details, meta)
params.send_validation_error(validation_errors, meta)
params.send_not_found(resource_type, meta)
params.send_unauthorized(message, meta)
params.send_forbidden(message, meta)

-- Generic error handling
params.handle_error(error, additional_context)
```

## Validation Schemas

Pre-defined schemas available:

```lua
ApiMiddleware.schemas = {
  login = { username = {...}, password = {...} },
  user_create = { username = {...}, email = {...}, ... },
  user_update = { email = {...}, role = {...}, ... },
  member_create = { first_name = {...}, last_name = {...}, ... },
  member_update = { first_name = {...}, last_name = {...}, ... },
  pagination = { page = {...}, per_page = {...}, ... },
  search = { q = {...}, search = {...} }
}
```

## Error Codes

Standard error codes:

```lua
-- Validation errors
VALIDATION_FAILED, REQUIRED_FIELD_MISSING, INVALID_FORMAT, INVALID_VALUE

-- Authentication/Authorization  
UNAUTHORIZED, FORBIDDEN, INVALID_CREDENTIALS, TOKEN_EXPIRED, INVALID_TOKEN

-- Resource errors
NOT_FOUND, ALREADY_EXISTS, CONFLICT

-- Server errors
INTERNAL_ERROR, DATABASE_ERROR, SERVICE_UNAVAILABLE
```

## Migration Guide

### From Old Controllers

**Before:**
```lua
function Controller.action(client, params)
  ngx.status = 200
  ngx.header.content_type = "application/json"
  ngx.say(json.encode({ success = true, data = result }))
end
```

**After:**
```lua
local Controller = {}

function Controller.action(client, params)
  -- Business logic here
  local result = get_data()
  
  params.send_success(result, "Data retrieved successfully")
end

-- Add middleware configuration
Controller.middleware = {
  action = ApiMiddleware.presets.authenticated({
    validation_schema = { ... }
  })
}

return Controller
```

### Router Registration

**Before:**
```lua
router.register("/endpoint", {
  GET = auth.protect(Controller.action, auth.require_member())
})
```

**After:**
```lua
router.register("/api/v1/endpoint", {
  GET = ApiMiddleware.protect(Controller.action, Controller.middleware.action)
})
```

## Best Practices

1. **Always use presets** - Start with a preset and customize as needed
2. **Define validation schemas** - Validate all input data  
3. **Use response helpers** - Don't manually construct responses
4. **Handle errors properly** - Use `params.handle_error()` for unexpected errors
5. **Add request IDs** - Essential for debugging and monitoring
6. **Version your APIs** - Plan for future changes from the start
7. **Document your endpoints** - Include version information

## Testing

The standardized API layer is fully testable:

```lua
local function test_endpoint()
  local mock_client = create_mock_client()
  local mock_params = {}
  
  -- Test with middleware
  local protected_handler = ApiMiddleware.protect(handler, config)
  protected_handler(mock_client, mock_params)
  
  -- Verify response format
  assert(mock_client.response_body.success ~= nil)
  assert(mock_client.response_body.meta.request_id)
end
```

This standardized approach ensures consistency, maintainability, and a better developer experience across the entire API.
