-- docs/generator/route_analyzer.lua
-- Analyzer for extracting route information from existing route definitions

local RouteAnalyzer = {}

-- Analyze route file and extract endpoint information
-- @param route_file_path string Path to route file
-- @return table Array of endpoint information
function RouteAnalyzer.analyze_route_file(route_file_path)
  local endpoints = {}
  
  -- Read route file
  local file = io.open(route_file_path, "r")
  if not file then
    return endpoints
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Parse route registrations
  endpoints = RouteAnalyzer.parse_route_registrations(content)
  
  return endpoints
end

-- Parse route registrations from file content
-- @param content string File content
-- @return table Array of endpoint information
function RouteAnalyzer.parse_route_registrations(content)
  local endpoints = {}
  
  -- Pattern to match router.register calls
  local register_pattern = 'router%.register%s*%(%s*"([^"]+)"%s*,%s*{([^}]+)}'
  
  for path, methods_block in content:gmatch(register_pattern) do
    local methods = RouteAnalyzer.parse_methods_block(methods_block)
    
    for method, handler_info in pairs(methods) do
      table.insert(endpoints, {
        path = path,
        method = method,
        handler = handler_info.handler,
        middleware = handler_info.middleware,
        controller = handler_info.controller,
        action = handler_info.action
      })
    end
  end
  
  return endpoints
end

-- Parse methods block from route registration
-- @param methods_block string Methods block content
-- @return table Map of method to handler info
function RouteAnalyzer.parse_methods_block(methods_block)
  local methods = {}
  
  -- Pattern to match method assignments
  local method_pattern = '(%w+)%s*=%s*([^\n,]+)'
  
  for method, handler_expr in methods_block:gmatch(method_pattern) do
    local handler_info = RouteAnalyzer.parse_handler_expression(handler_expr)
    methods[method:upper()] = handler_info
  end
  
  return methods
end

-- Parse handler expression to extract controller and action info
-- @param handler_expr string Handler expression
-- @return table Handler information
function RouteAnalyzer.parse_handler_expression(handler_expr)
  local handler_info = {
    handler = handler_expr:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""),
    middleware = nil,
    controller = nil,
    action = nil
  }
  
  -- Check for middleware wrapper patterns
  if handler_expr:find("ApiMiddleware%.") then
    handler_info.middleware = "ApiMiddleware"
    
    -- Extract controller and action from wrapped handler
    local controller_action = handler_expr:match("([%w%.]+%.[%w_]+)")
    if controller_action then
      local controller, action = controller_action:match("([^%.]+)%.([^%.]+)$")
      handler_info.controller = controller
      handler_info.action = action
    end
  else
    -- Direct controller method call
    local controller_action = handler_expr:match("([%w%.]+%.[%w_]+)")
    if controller_action then
      local controller, action = controller_action:match("([^%.]+)%.([^%.]+)$")
      handler_info.controller = controller
      handler_info.action = action
    end
  end
  
  return handler_info
end

-- Extract authentication requirements from middleware configuration
-- @param handler_expr string Handler expression
-- @return string|nil Authentication requirement
function RouteAnalyzer.extract_auth_requirement(handler_expr)
  -- Look for authentication patterns in middleware
  if handler_expr:find("presets%.public") then
    return nil -- No authentication required
  elseif handler_expr:find("presets%.authenticated") then
    return "member"
  elseif handler_expr:find("presets%.admin_only") then
    return "admin"
  elseif handler_expr:find("presets%.pastor_only") then
    return "pastor"
  elseif handler_expr:find('authentication%s*=%s*"([^"]+)"') then
    return handler_expr:match('authentication%s*=%s*"([^"]+)"')
  end
  
  return "member" -- Default assumption
end

-- Extract validation schema from middleware configuration
-- @param handler_expr string Handler expression
-- @return string|nil Validation schema name
function RouteAnalyzer.extract_validation_schema(handler_expr)
  -- Look for validation_schema patterns
  local schema = handler_expr:match('validation_schema%s*=%s*ApiMiddleware%.schemas%.([%w_]+)')
  if schema then
    return schema
  end
  
  -- Look for direct schema references
  schema = handler_expr:match('validation_schema%s*=%s*([%w_%.]+)')
  if schema then
    return schema
  end
  
  return nil
end

-- Generate endpoint documentation from route analysis
-- @param endpoints table Array of endpoint information
-- @return table Map of endpoint_id to documentation
function RouteAnalyzer.generate_endpoint_docs(endpoints)
  local docs = {}
  
  for _, endpoint in ipairs(endpoints) do
    local endpoint_id = RouteAnalyzer.generate_endpoint_id(endpoint)
    
    docs[endpoint_id] = {
      id = endpoint_id,
      path = endpoint.path,
      method = endpoint.method,
      controller = endpoint.controller,
      action = endpoint.action,
      auth_required = RouteAnalyzer.extract_auth_requirement(endpoint.handler),
      validation_schema = RouteAnalyzer.extract_validation_schema(endpoint.handler),
      summary = RouteAnalyzer.generate_summary(endpoint),
      description = RouteAnalyzer.generate_description(endpoint),
      tags = RouteAnalyzer.generate_tags(endpoint),
      parameters = RouteAnalyzer.extract_path_parameters(endpoint.path),
      responses = RouteAnalyzer.generate_default_responses(endpoint)
    }
  end
  
  return docs
end

-- Generate endpoint ID from endpoint information
-- @param endpoint table Endpoint information
-- @return string Endpoint ID
function RouteAnalyzer.generate_endpoint_id(endpoint)
  if endpoint.controller and endpoint.action then
    return endpoint.controller:lower() .. "." .. endpoint.action:lower()
  else
    -- Fallback to path and method
    local path_key = endpoint.path:gsub("[^%w]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
    return path_key:lower() .. "_" .. endpoint.method:lower()
  end
end

-- Generate summary from endpoint information
-- @param endpoint table Endpoint information
-- @return string Summary
function RouteAnalyzer.generate_summary(endpoint)
  if endpoint.action then
    local action_summaries = {
      index = "List " .. (endpoint.controller or "resources"):lower(),
      show = "Get " .. (endpoint.controller or "resource"):lower() .. " by ID",
      create = "Create new " .. (endpoint.controller or "resource"):lower(),
      update = "Update " .. (endpoint.controller or "resource"):lower(),
      delete = "Delete " .. (endpoint.controller or "resource"):lower(),
      login = "User login",
      logout = "User logout",
      me = "Get current user information"
    }
    
    return action_summaries[endpoint.action:lower()] or (endpoint.method .. " " .. endpoint.path)
  end
  
  return endpoint.method .. " " .. endpoint.path
end

-- Generate description from endpoint information
-- @param endpoint table Endpoint information
-- @return string Description
function RouteAnalyzer.generate_description(endpoint)
  if endpoint.action then
    local action_descriptions = {
      index = "Retrieve a paginated list of " .. (endpoint.controller or "resources"):lower(),
      show = "Retrieve a specific " .. (endpoint.controller or "resource"):lower() .. " by its unique identifier",
      create = "Create a new " .. (endpoint.controller or "resource"):lower() .. " record",
      update = "Update an existing " .. (endpoint.controller or "resource"):lower() .. " record",
      delete = "Delete an existing " .. (endpoint.controller or "resource"):lower() .. " record",
      login = "Authenticate user credentials and create a new session",
      logout = "Invalidate the current user session",
      me = "Get information about the currently authenticated user"
    }
    
    return action_descriptions[endpoint.action:lower()] or ("Endpoint for " .. endpoint.path)
  end
  
  return "Endpoint for " .. endpoint.path
end

-- Generate tags from endpoint information
-- @param endpoint table Endpoint information
-- @return table Array of tags
function RouteAnalyzer.generate_tags(endpoint)
  local tags = {}
  
  if endpoint.controller then
    local controller_name = endpoint.controller:lower():gsub("controller", "")
    table.insert(tags, controller_name)
  end
  
  -- Add authentication tag for auth endpoints
  if endpoint.path:find("/auth/") then
    table.insert(tags, "authentication")
  end
  
  return tags
end

-- Extract path parameters from route path
-- @param path string Route path
-- @return table Array of parameter definitions
function RouteAnalyzer.extract_path_parameters(path)
  local parameters = {}
  
  -- Convert Lua pattern to OpenAPI parameter
  local param_patterns = {
    ["%(%%d%+%)"] = { name = "id", type = "integer", description = "Numeric identifier" },
    ["%(%%w%+%)"] = { name = "param", type = "string", description = "String parameter" }
  }
  
  for pattern, param_def in pairs(param_patterns) do
    if path:find(pattern) then
      table.insert(parameters, {
        name = param_def.name,
        ["in"] = "path",
        required = true,
        schema = { type = param_def.type },
        description = param_def.description
      })
    end
  end
  
  -- Convert OpenAPI path format
  local openapi_path = path:gsub("%(%%d%+%)", "{id}"):gsub("%(%%w%+%)", "{param}")
  
  return parameters, openapi_path
end

-- Generate default responses for endpoint
-- @param endpoint table Endpoint information
-- @return table Response definitions
function RouteAnalyzer.generate_default_responses(endpoint)
  local responses = {
    ["400"] = { ["$ref"] = "#/components/responses/ValidationError" },
    ["500"] = { description = "Internal server error" }
  }
  
  -- Add authentication responses if required
  if endpoint.auth_required then
    responses["401"] = { ["$ref"] = "#/components/responses/Unauthorized" }
    responses["403"] = { ["$ref"] = "#/components/responses/Forbidden" }
  end
  
  -- Add method-specific responses
  if endpoint.method == "GET" then
    responses["200"] = { description = "Successful response" }
    if endpoint.action == "show" then
      responses["404"] = { ["$ref"] = "#/components/responses/NotFound" }
    end
  elseif endpoint.method == "POST" then
    responses["201"] = { description = "Resource created successfully" }
  elseif endpoint.method == "PUT" or endpoint.method == "PATCH" then
    responses["200"] = { description = "Resource updated successfully" }
    responses["404"] = { ["$ref"] = "#/components/responses/NotFound" }
  elseif endpoint.method == "DELETE" then
    responses["200"] = { description = "Resource deleted successfully" }
    responses["404"] = { ["$ref"] = "#/components/responses/NotFound" }
  end
  
  return responses
end

-- Analyze all route files in a directory
-- @param routes_dir string Directory containing route files
-- @return table Combined endpoint documentation
function RouteAnalyzer.analyze_routes_directory(routes_dir)
  local all_endpoints = {}
  
  -- Get list of Lua files in routes directory
  local files = RouteAnalyzer.get_lua_files(routes_dir)
  
  for _, file_path in ipairs(files) do
    local endpoints = RouteAnalyzer.analyze_route_file(file_path)
    local endpoint_docs = RouteAnalyzer.generate_endpoint_docs(endpoints)
    
    -- Merge into all_endpoints
    for endpoint_id, docs in pairs(endpoint_docs) do
      all_endpoints[endpoint_id] = docs
    end
  end
  
  return all_endpoints
end

-- Get list of Lua files in directory
-- @param dir_path string Directory path
-- @return table Array of file paths
function RouteAnalyzer.get_lua_files(dir_path)
  local files = {}
  
  -- Simple implementation - in production, use proper directory traversal
  local common_route_files = {
    dir_path .. "/api_routes.lua",
    dir_path .. "/auth_routes.lua",
    dir_path .. "/member_routes.lua",
    dir_path .. "/event_routes.lua"
  }
  
  for _, file_path in ipairs(common_route_files) do
    local file = io.open(file_path, "r")
    if file then
      file:close()
      table.insert(files, file_path)
    end
  end
  
  return files
end

return RouteAnalyzer