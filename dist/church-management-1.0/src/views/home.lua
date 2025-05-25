-- src/views/home.lua
-- Home page view for Church Management System

local json_utils = require("src.utils.json")
local views = {}

-- Render home page
function views.home_page(client)
  local html = [[
<!DOCTYPE html>
<html>
<head>
  <title>Church Management System</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; line-height: 1.6; }
    h1 { color: #333; }
    .container { max-width: 800px; margin: 0 auto; }
    .card { border: 1px solid #ddd; border-radius: 4px; padding: 20px; margin-bottom: 20px; }
    .endpoints { background-color: #f5f5f5; padding: 15px; border-radius: 4px; }
    code { background-color: #f1f1f1; padding: 2px 5px; border-radius: 3px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Church Management System</h1>
    <div class="card">
      <h2>Welcome to the Church Management API</h2>
      <p>This is a simple CRUD API for managing church members.</p>
    </div>
    
    <div class="card endpoints">
      <h3>Available Endpoints:</h3>
      <ul>
        <li><code>GET /health</code> - Check if the API is running</li>
        <li><code>GET /members</code> - List all members</li>
        <li><code>POST /members</code> - Create a new member</li>
        <li><code>GET /members/{id}</code> - Get a member by ID</li>
        <li><code>PUT /members/{id}</code> - Update a member</li>
        <li><code>DELETE /members/{id}</code> - Delete a member</li>
      </ul>
    </div>
  </div>
</body>
</html>
  ]]
  
  json_utils.send_response(client, 200, {
    ["Content-Type"] = "text/html",
    ["Content-Length"] = #html
  }, html)
end

return views
