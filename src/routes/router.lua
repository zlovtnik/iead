-- src/routes/router.lua
-- Router for Church Management System

-- Using Lua 5.4 standard library

local MemberController = require("src.controllers.member_controller")
local EventController = require("src.controllers.event_controller")
local AttendanceController = require("src.controllers.attendance_controller")
local DonationController = require("src.controllers.donation_controller")
local VolunteerController = require("src.controllers.volunteer_controller")
local ReportController = require("src.controllers.report_controller")
local TitheController = require("src.controllers.tithe_controller")
local AuthController = require("src.controllers.auth_controller")
local UserController = require("src.controllers.user_controller")
local auth = require("src.middleware.auth")
local json_utils = require("src.utils.json")
local views = require("src.views.home")
local fun = require("src.utils.functional")
local pipeline = require("src.utils.pipeline")

-- Router module
local router = {
  routes = {},
  exact_routes = {},
  pattern_routes = {}
}

-- Middleware composer using functional programming
-- @param middlewares table Array of middleware functions
-- @param final_handler function Final handler function
-- @return function Composed middleware chain
function router.compose_middleware(middlewares, final_handler)
  if not middlewares or #middlewares == 0 then
    return final_handler
  end
  
  return fun.reduce_table(function(composed, middleware)
    return function(client, params, ...)
      return middleware(client, params, function()
        return composed(client, params, ...)
      end, ...)
    end
  end, final_handler, middlewares)
end

-- Enhanced route registration with middleware support
-- @param path string Route path
-- @param handlers table Method handlers with optional middleware
-- @param middlewares table Optional array of middleware functions for all methods
-- @return boolean Success status
-- @return string Error message if any
function router.register_with_middleware(path, handlers, middlewares)
  if not path or type(handlers) ~= "table" then
    return false, "Invalid route configuration"
  end
  
  local enhanced_handlers = {}
  
  for method, handler in pairs(handlers) do
    if type(handler) == "function" then
      -- Apply middleware composition
      enhanced_handlers[method] = router.compose_middleware(middlewares or {}, handler)
    elseif type(handler) == "table" and handler.handler and type(handler.handler) == "function" then
      -- Handler with specific middleware
      local handler_middlewares = handler.middleware or {}
      local combined_middlewares = {}
      
      -- Combine global and handler-specific middleware
      for _, mw in ipairs(middlewares or {}) do
        table.insert(combined_middlewares, mw)
      end
      for _, mw in ipairs(handler_middlewares) do
        table.insert(combined_middlewares, mw)
      end
      
      enhanced_handlers[method] = router.compose_middleware(combined_middlewares, handler.handler)
    else
      enhanced_handlers[method] = handler
    end
  end
  
  return router.register(path, enhanced_handlers)
end

-- HTTP Methods (using functional approach)
local HTTP_METHODS = {}
local methods = {"GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"}
for _, method in ipairs(methods) do
  HTTP_METHODS[method] = true
end

-- Route registration function
function router.register(path, handlers)
  if not path or type(handlers) ~= "table" then
    return false, "Invalid route configuration"
  end
  
  -- Check if it's a pattern route (starts with ^)
  if type(path) == "string" and path:sub(1, 1) == "^" then
    router.pattern_routes[path] = handlers
  else
    router.exact_routes[path] = handlers
  end
  
  -- Store in combined routes table for backward compatibility
  router.routes[path] = handlers
  
  return true
end

-- Response helpers
local response = {
  not_found = function(client)
    json_utils.send_json_response(client, 404, { error = "Not found" })
  end,
  
  method_not_allowed = function(client, allowed_methods)
    json_utils.send_json_response(client, 405, { 
      error = "Method not allowed",
      allowed = allowed_methods
    })
  end,
  
  server_error = function(client, err)
    json_utils.send_json_response(client, 500, { error = "Server error", message = err })
  end
}

-- Match route and execute handler
function router.match(path, method, client, params)
  params = params or {}
  
  -- Handle CORS preflight OPTIONS requests
  if method == "OPTIONS" then
    local json_utils = require("src.utils.json")
    json_utils.send_response(client, 200, {
      ["Content-Type"] = "text/plain"
    }, "")
    return true
  end

  -- Validate method
  if not HTTP_METHODS[method] then
    response.method_not_allowed(client, {})
    return false
  end
  
  -- First try exact match
  local exact_match = router.exact_routes[path]
  if exact_match then
    if exact_match[method] then
      local success, err = pcall(function()
        exact_match[method](client, params)
      end)
      
      if not success then
        response.server_error(client, err)
      end
      return true
    else
      -- Method not allowed - use functional approach to get allowed methods
      local allowed = {}
      for method, _ in pairs(exact_match) do
        table.insert(allowed, method)
      end
      response.method_not_allowed(client, allowed)
      return true
    end
  end
  
  -- Then try pattern matching
  for pattern, handlers in pairs(router.pattern_routes) do
    local matches = {path:match(pattern)}
    if #matches > 0 then
      if handlers[method] then
        local success, err = pcall(function()
          handlers[method](client, params, table.unpack(matches))
        end)
        
        if not success then
          response.server_error(client, err)
        end
        return true
      else
        -- Method not allowed - use functional approach
        local allowed = {}
        for method, _ in pairs(handlers) do
          table.insert(allowed, method)
        end
        response.method_not_allowed(client, allowed)
        return true
      end
    end
  end
  
  -- Not found
  response.not_found(client)
  return false
end

-- Register core routes

-- System routes
router.register("/health", {
  GET = function(client, params)
    json_utils.send_json_response(client, 200, { status = "ok" })
  end
})

router.register("/", {
  GET = function(client, params)
    views.home_page(client)
  end
})

-- Resource routes

-- Authentication routes
router.register("/auth/login", {
  OPTIONS = function(client, params)
    -- Handle CORS preflight
    json_utils.send_response(client, 200, {
      ["Access-Control-Allow-Origin"] = "http://localhost:5173",
      ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
      ["Access-Control-Allow-Headers"] = "Content-Type, Authorization",
      ["Access-Control-Allow-Credentials"] = "true"
    }, "")
  end,
  POST = AuthController.login
})

router.register("/auth/logout", {
  OPTIONS = function(client, params)
    -- Handle CORS preflight
    json_utils.send_response(client, 200, {
      ["Access-Control-Allow-Origin"] = "http://localhost:5173",
      ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
      ["Access-Control-Allow-Headers"] = "Content-Type, Authorization",
      ["Access-Control-Allow-Credentials"] = "true"
    }, "")
  end,
  POST = AuthController.logout
})

router.register("/auth/refresh", {
  OPTIONS = function(client, params)
    -- Handle CORS preflight
    json_utils.send_response(client, 200, {
      ["Access-Control-Allow-Origin"] = "http://localhost:5173",
      ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
      ["Access-Control-Allow-Headers"] = "Content-Type, Authorization",
      ["Access-Control-Allow-Credentials"] = "true"
    }, "")
  end,
  POST = AuthController.refresh_token
})

router.register("/auth/me", {
  OPTIONS = function(client, params)
    -- Handle CORS preflight
    json_utils.send_response(client, 200, {
      ["Access-Control-Allow-Origin"] = "http://localhost:5173",
      ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
      ["Access-Control-Allow-Headers"] = "Content-Type, Authorization",
      ["Access-Control-Allow-Credentials"] = "true"
    }, "")
  end,
  GET = AuthController.get_current_user
})

router.register("/auth/password", {
  OPTIONS = function(client, params)
    -- Handle CORS preflight
    json_utils.send_response(client, 200, {
      ["Access-Control-Allow-Origin"] = "http://localhost:5173",
      ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
      ["Access-Control-Allow-Headers"] = "Content-Type, Authorization",
      ["Access-Control-Allow-Credentials"] = "true"
    }, "")
  end,
  PUT = AuthController.change_password
})

-- User management routes (Admin only)
router.register("/users", {
  GET = UserController.list_users,
  POST = UserController.create_user
})

router.register("^/users/(%d+)$", {
  GET = UserController.get_user,
  PUT = UserController.update_user,
  DELETE = UserController.deactivate_user
})

router.register("^/users/(%d+)/activate$", {
  POST = UserController.activate_user
})

router.register("^/users/(%d+)/reset%-password$", {
  POST = UserController.reset_password
})

router.register("^/users/(%d+)/change%-role$", {
  POST = UserController.change_role
})

-- Members
router.register("/members", {
  GET = auth.protect(MemberController.index, auth.require_pastor()),
  POST = auth.protect(MemberController.create, auth.require_pastor())
})

router.register("^/members/(%d+)$", {
  GET = auth.protect(MemberController.show, auth.require_member_access()),
  PUT = auth.protect(MemberController.update, auth.require_member_access()),
  DELETE = auth.protect(MemberController.delete, auth.require_pastor())
})

-- Events
router.register("/events", {
  GET = auth.protect(EventController.index, auth.require_member()),
  POST = auth.protect(EventController.create, auth.require_pastor())
})

router.register("^/events/(%d+)$", {
  GET = auth.protect(EventController.show, auth.require_member()),
  PUT = auth.protect(EventController.update, auth.require_pastor()),
  DELETE = auth.protect(EventController.delete, auth.require_pastor())
})

-- Attendance
router.register("/attendance", {
  GET = auth.protect(AttendanceController.index, auth.require_pastor()),
  POST = auth.protect(AttendanceController.create, auth.require_pastor())
})

router.register("^/attendance/(%d+)$", {
  GET = auth.protect(AttendanceController.show, auth.require_pastor()),
  PUT = auth.protect(AttendanceController.update, auth.require_pastor()),
  DELETE = auth.protect(AttendanceController.delete, auth.require_pastor())
})

router.register("^/events/(%d+)/attendance$", {
  GET = auth.protect(AttendanceController.by_event, auth.require_pastor())
})

router.register("^/members/(%d+)/attendance$", {
  GET = auth.protect(AttendanceController.by_member, auth.require_member_access())
})

-- Donations
router.register("/donations", {
  GET = auth.protect(DonationController.index, auth.require_pastor()),
  POST = auth.protect(DonationController.create, auth.require_pastor())
})

router.register("^/donations/(%d+)$", {
  GET = auth.protect(DonationController.show, auth.require_pastor()),
  PUT = auth.protect(DonationController.update, auth.require_pastor()),
  DELETE = auth.protect(DonationController.delete, auth.require_pastor())
})

router.register("^/members/(%d+)/donations$", {
  GET = auth.protect(DonationController.by_member, auth.require_member_access())
})

-- Tithes
router.register("/tithes", {
  GET = auth.protect(TitheController.index, auth.require_pastor()),
  POST = auth.protect(TitheController.create, auth.require_pastor())
})

router.register("^/tithes/(%d+)$", {
  GET = auth.protect(TitheController.show, auth.require_pastor()),
  PUT = auth.protect(TitheController.update, auth.require_pastor()),
  DELETE = auth.protect(TitheController.delete, auth.require_pastor())
})

router.register("^/tithes/(%d+)/pay$", {
  POST = auth.protect(TitheController.mark_paid, auth.require_pastor())
})

router.register("^/members/(%d+)/tithes$", {
  GET = auth.protect(TitheController.by_member, auth.require_member_access())
})

router.register("^/members/(%d+)/tithe-calculation$", {
  GET = auth.protect(TitheController.calculate, auth.require_member_access())
})

router.register("/tithes/generate-monthly", {
  POST = auth.protect(TitheController.generate_monthly, auth.require_pastor())
})

-- Volunteers
router.register("/volunteers", {
  GET = auth.protect(VolunteerController.index, auth.require_pastor()),
  POST = auth.protect(VolunteerController.create, auth.require_pastor())
})

router.register("^/volunteers/(%d+)$", {
  GET = auth.protect(VolunteerController.show, auth.require_pastor()),
  PUT = auth.protect(VolunteerController.update, auth.require_pastor()),
  DELETE = auth.protect(VolunteerController.delete, auth.require_pastor())
})

router.register("^/members/(%d+)/volunteers$", {
  GET = auth.protect(VolunteerController.by_member, auth.require_member_access())
})

router.register("^/events/(%d+)/volunteers$", {
  GET = auth.protect(VolunteerController.by_event, auth.require_member())
})

-- Reports
router.register("/reports/member-attendance", {
  GET = auth.protect(ReportController.member_attendance, auth.require_pastor())
})

router.register("/reports/event-attendance", {
  GET = auth.protect(ReportController.event_attendance, auth.require_pastor())
})

router.register("/reports/donation-summary", {
  GET = auth.protect(ReportController.donation_summary, auth.require_pastor())
})

router.register("/reports/top-donors", {
  GET = auth.protect(ReportController.top_donors, auth.require_pastor())
})

router.register("/reports/volunteer-hours", {
  GET = auth.protect(ReportController.volunteer_hours, auth.require_pastor())
})

return router
