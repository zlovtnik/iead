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
local json_utils = require("src.utils.json")
local views = require("src.views.home")

-- Router module
local router = {
  routes = {},
  exact_routes = {},
  pattern_routes = {}
}

-- HTTP Methods
local HTTP_METHODS = {
  GET = true,
  POST = true,
  PUT = true,
  DELETE = true,
  PATCH = true,
  OPTIONS = true,
  HEAD = true
}

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
      -- Method not allowed
      local allowed = {}
      for m, _ in pairs(exact_match) do
        table.insert(allowed, m)
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
        -- Method not allowed
        local allowed = {}
        for m, _ in pairs(handlers) do
          table.insert(allowed, m)
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
  POST = AuthController.login
})

router.register("/auth/logout", {
  POST = AuthController.logout
})

router.register("/auth/refresh", {
  POST = AuthController.refresh_token
})

router.register("/auth/me", {
  GET = AuthController.get_current_user
})

router.register("/auth/password", {
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

router.register("^/users/(%d+)/reset-password$", {
  POST = UserController.reset_password
})

router.register("^/users/(%d+)/change-role$", {
  POST = UserController.change_role
})

-- Members
router.register("/members", {
  GET = MemberController.index,
  POST = MemberController.create
})

router.register("^/members/(%d+)$", {
  GET = MemberController.show,
  PUT = MemberController.update,
  DELETE = MemberController.delete
})

-- Events
router.register("/events", {
  GET = EventController.index,
  POST = EventController.create
})

router.register("^/events/(%d+)$", {
  GET = EventController.show,
  PUT = EventController.update,
  DELETE = EventController.delete
})

-- Attendance
router.register("/attendance", {
  GET = AttendanceController.index,
  POST = AttendanceController.create
})

router.register("^/attendance/(%d+)$", {
  GET = AttendanceController.show,
  PUT = AttendanceController.update,
  DELETE = AttendanceController.delete
})

router.register("^/events/(%d+)/attendance$", {
  GET = AttendanceController.by_event
})

router.register("^/members/(%d+)/attendance$", {
  GET = AttendanceController.by_member
})

-- Donations
router.register("/donations", {
  GET = DonationController.index,
  POST = DonationController.create
})

router.register("^/donations/(%d+)$", {
  GET = DonationController.show,
  PUT = DonationController.update,
  DELETE = DonationController.delete
})

router.register("^/members/(%d+)/donations$", {
  GET = DonationController.by_member
})

-- Tithes
router.register("/tithes", {
  GET = TitheController.index,
  POST = TitheController.create
})

router.register("^/tithes/(%d+)$", {
  GET = TitheController.show,
  PUT = TitheController.update,
  DELETE = TitheController.delete
})

router.register("^/tithes/(%d+)/pay$", {
  POST = TitheController.mark_paid
})

router.register("^/members/(%d+)/tithes$", {
  GET = TitheController.by_member
})

router.register("^/members/(%d+)/tithe-calculation$", {
  GET = TitheController.calculate
})

router.register("/tithes/generate-monthly", {
  POST = TitheController.generate_monthly
})

-- Volunteers
router.register("/volunteers", {
  GET = VolunteerController.index,
  POST = VolunteerController.create
})

router.register("^/volunteers/(%d+)$", {
  GET = VolunteerController.show,
  PUT = VolunteerController.update,
  DELETE = VolunteerController.delete
})

router.register("^/members/(%d+)/volunteers$", {
  GET = VolunteerController.by_member
})

router.register("^/events/(%d+)/volunteers$", {
  GET = VolunteerController.by_event
})

-- Reports
router.register("/reports/member-attendance", {
  GET = ReportController.member_attendance
})

router.register("/reports/event-attendance", {
  GET = ReportController.event_attendance
})

router.register("/reports/donation-summary", {
  GET = ReportController.donation_summary
})

router.register("/reports/top-donors", {
  GET = ReportController.top_donors
})

router.register("/reports/volunteer-hours", {
  GET = ReportController.volunteer_hours
})

return router
