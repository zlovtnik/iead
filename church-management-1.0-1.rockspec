package = "church-management"
version = "1.0-1"
source = {
   url = "git://github.com/user/church-management",
   tag = "v1.0"
}
description = {
   summary = "Church Management System",
   detailed = [[
      A web-based church management system built with pure Lua and SQLite.
      This application provides a RESTful API for managing church members,
      events, attendance, donations, volunteers, and reporting.
   ]],
   homepage = "https://github.com/user/church-management",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "luasql-sqlite3",
   "lua-cjson",
   "luasocket",
   "luafilesystem",
   "bcrypt"
}
build = {
   type = "builtin",
   modules = {
      ["app"] = "app.lua",
      ["src.config.database"] = "src/config/database.lua",
      ["src.controllers.member_controller"] = "src/controllers/member_controller.lua",
      ["src.controllers.event_controller"] = "src/controllers/event_controller.lua",
      ["src.controllers.attendance_controller"] = "src/controllers/attendance_controller.lua",
      ["src.controllers.donation_controller"] = "src/controllers/donation_controller.lua",
      ["src.controllers.volunteer_controller"] = "src/controllers/volunteer_controller.lua",
      ["src.controllers.report_controller"] = "src/controllers/report_controller.lua",
      ["src.models.member"] = "src/models/member.lua",
      ["src.models.event"] = "src/models/event.lua",
      ["src.models.attendance"] = "src/models/attendance.lua",
      ["src.models.donation"] = "src/models/donation.lua",
      ["src.models.volunteer"] = "src/models/volunteer.lua",
      ["src.models.report"] = "src/models/report.lua",
      ["src.routes.router"] = "src/routes/router.lua",
      ["src.utils.http"] = "src/utils/http.lua",
      ["src.utils.json"] = "src/utils/json.lua",
      ["src.utils.security"] = "src/utils/security.lua",
      ["src.views.home"] = "src/views/home.lua",
      ["src.db.schema"] = "src/db/schema.lua"
   },
   install = {
      bin = {
         "bin/church-management"
      }
   }
}
