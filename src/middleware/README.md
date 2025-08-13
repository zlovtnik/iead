# Authentication Middleware

This directory contains the authentication middleware for the Church Management System. The middleware provides session-based authentication, role-based access control, and rate limiting functionality.

## Features

- **Session Token Authentication**: Validates Bearer tokens from Authorization headers
- **Role-Based Access Control (RBAC)**: Three-tier permission system (Admin, Pastor, Member)
- **Rate Limiting**: Prevents brute force attacks on authentication endpoints
- **Member Data Access Control**: Ensures members can only access their own data
- **Middleware Chaining**: Combine multiple middleware functions
- **Route Protection**: Easy integration with existing route handlers

## Usage Examples

### Basic Authentication

```lua
local auth = require("src.middleware.auth")
local router = require("src.routes.router")

-- Protect a route with basic authentication
router.register("/protected", {
  GET = auth.protect(function(client, params)
    -- Handler code here
    -- params.current_user contains authenticated user info
    json_utils.send_json_response(client, 200, {
      message = "Access granted",
      user = params.current_user
    })
  end, auth.require_member())
})
```

### Role-Based Access Control

```lua
-- Admin-only endpoint
router.register("/admin/users", {
  GET = auth.protect(UserController.index, auth.require_admin()),
  POST = auth.protect(UserController.create, auth.require_admin())
})

-- Pastor or Admin access
router.register("/reports", {
  GET = auth.protect(ReportController.index, auth.require_pastor())
})

-- Any authenticated user
router.register("/profile", {
  GET = auth.protect(ProfileController.show, auth.require_member())
})
```

### Member Data Access Control

```lua
-- Ensure members can only access their own data
router.register("^/members/(%d+)$", {
  GET = auth.protect(MemberController.show, auth.require_member_access()),
  PUT = auth.protect(MemberController.update, auth.require_member_access())
})

-- With custom member ID parameter name
router.register("/member-donations", {
  GET = auth.protect(DonationController.by_member, 
    auth.require_member_access("member_id"))
})
```

### Rate Limiting

```lua
-- Rate limit login attempts by username
router.register("/auth/login", {
  POST = auth.protect(AuthController.login, auth.login_rate_limit("username"))
})

-- Custom rate limiting
router.register("/sensitive-endpoint", {
  POST = auth.protect(SomeController.action, 
    auth.rate_limit(function(client, params)
      return params.user_id or "unknown"
    end))
})
```

### Middleware Chaining

```lua
-- Combine multiple middleware functions
local combined_middleware = auth.chain({
  auth.require_pastor(),
  auth.rate_limit(function(client, params)
    return params.current_user.username
  end),
  function(client, params)
    -- Custom validation
    if not params.custom_header then
      json_utils.send_json_response(client, 400, {
        error = "Custom header required"
      })
      return false
    end
    return true
  end
})

router.register("/complex-endpoint", {
  POST = auth.protect(ComplexController.action, combined_middleware)
})
```

## Middleware Functions

### Authentication Functions

- `auth.authenticate_request(client, params)` - Basic token validation
- `auth.require_role(role)` - Require specific role
- `auth.require_admin()` - Require Admin role
- `auth.require_pastor()` - Require Pastor or Admin role
- `auth.require_member()` - Require any authenticated user

### Access Control Functions

- `auth.require_member_access(param_name)` - Member data access control
- `auth.can_access_member_data(user, member_id)` - Check member data access

### Rate Limiting Functions

- `auth.rate_limit(identifier_func)` - Generic rate limiting
- `auth.login_rate_limit(username_param)` - Login-specific rate limiting
- `auth.clear_rate_limit(identifier)` - Clear rate limit for identifier

### Utility Functions

- `auth.protect(handler, middleware)` - Wrap handler with middleware
- `auth.chain(middlewares)` - Combine multiple middleware functions
- `auth.extract_token(client)` - Extract Bearer token from headers
- `auth.get_current_user(params)` - Get authenticated user from params
- `auth.has_permission(params, level)` - Check permission level

## Permission Levels

The system uses a hierarchical permission model:

- **Admin (Level 3)**: Full system access, user management
- **Pastor (Level 2)**: Read/write access to all church data
- **Member (Level 1)**: Read-only access to own data

## Error Responses

The middleware returns standardized error responses:

```json
{
  "error": "Human-readable error message",
  "code": "ERROR_CODE",
  "timestamp": "2025-01-08T10:30:00Z"
}
```

Common error codes:
- `MISSING_TOKEN` (401) - No Authorization header
- `INVALID_TOKEN` (401) - Invalid or expired token
- `TOKEN_EXPIRED` (401) - Token has expired
- `ACCOUNT_DEACTIVATED` (401) - User account is deactivated
- `INSUFFICIENT_PERMISSIONS` (403) - User lacks required role
- `ACCESS_DENIED` (403) - Cannot access requested resource
- `RATE_LIMIT_EXCEEDED` (429) - Too many requests

## Integration with Existing Routes

To add authentication to existing routes, wrap the handlers:

```lua
-- Before (unprotected)
router.register("/members", {
  GET = MemberController.index,
  POST = MemberController.create
})

-- After (protected)
router.register("/members", {
  GET = auth.protect(MemberController.index, auth.require_pastor()),
  POST = auth.protect(MemberController.create, auth.require_pastor())
})
```

## Testing

The middleware includes comprehensive unit tests and integration tests:

```bash
# Run all tests including middleware tests
lua src/tests/run_all.lua

# Run only middleware tests
lua -e "
local test_runner = require('src.tests.test_runner')
local auth_tests = require('src.tests.test_auth_middleware')
test_runner.run_suite('Auth Middleware Tests', auth_tests)
"
```

## Configuration

Rate limiting and other settings can be configured by modifying the constants at the top of `src/middleware/auth.lua`:

```lua
-- Rate limiting configuration
local RATE_LIMIT_MAX_ATTEMPTS = 5
local RATE_LIMIT_WINDOW = 15 * 60 -- 15 minutes

-- Role hierarchy
local ROLE_HIERARCHY = {
  Admin = 3,
  Pastor = 2,
  Member = 1
}
```