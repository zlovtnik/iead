-- docs/generator/endpoint_processor.lua
-- Processor for generating comprehensive endpoint documentation

local RouteAnalyzer = require("docs.generator.route_analyzer")
local SchemaExtractor = require("src.application.middlewares.schema_extractor")
local ApiMiddleware = require("src.application.middlewares.api_middleware")

local EndpointProcessor = {}

-- Process all endpoints and generate comprehensive documentation
-- @param config table Configuration options
-- @return table Processed endpoint documentation
function EndpointProcessor.process_all_endpoints(config)
  config = config or {}
  
  local processed_endpoints = {}
  
  -- Get endpoints from multiple sources
  local route_endpoints = EndpointProcessor.get_route_endpoints(config.routes_dir or "src/routes")
  local middleware_endpoints = ApiMiddleware.get_all_endpoint_docs()
  local annotation_endpoints = ApiMiddleware.ControllerAnnotations.get_all_annotations()
  
  -- Merge all endpoint sources
  local all_endpoints = EndpointProcessor.merge_endpoint_sources(
    route_endpoints,
    middleware_endpoints,
    annotation_endpoints
  )
  
  -- Process each endpoint
  for endpoint_id, endpoint_data in pairs(all_endpoints) do
    processed_endpoints[endpoint_id] = EndpointProcessor.process_single_endpoint(endpoint_id, endpoint_data, config)
  end
  
  return processed_endpoints
end

-- Get endpoints from route files
-- @param routes_dir string Routes directory path
-- @return table Route endpoints
function EndpointProcessor.get_route_endpoints(routes_dir)
  return RouteAnalyzer.analyze_routes_directory(routes_dir)
end

-- Merge endpoint data from multiple sources
-- @param route_endpoints table Endpoints from route analysis
-- @param middleware_endpoints table Endpoints from middleware registry
-- @param annotation_endpoints table Endpoints from controller annotations
-- @return table Merged endpoint data
function EndpointProcessor.merge_endpoint_sources(route_endpoints, middleware_endpoints, annotation_endpoints)
  local merged = {}
  
  -- Start with route endpoints as base
  for endpoint_id, endpoint_data in pairs(route_endpoints) do
    merged[endpoint_id] = EndpointProcessor.deep_copy(endpoint_data)
  end
  
  -- Merge middleware endpoints
  for endpoint_id, endpoint_data in pairs(middleware_endpoints) do
    if merged[endpoint_id] then
      merged[endpoint_id] = EndpointProcessor.merge_endpoint_data(merged[endpoint_id], endpoint_data)
    else
      merged[endpoint_id] = EndpointProcessor.deep_copy(endpoint_data)
    end
  end
  
  -- Merge annotation endpoints
  for annotation_key, annotation_data in pairs(annotation_endpoints) do
    local endpoint_id = EndpointProcessor.find_matching_endpoint_id(annotation_data, merged)
    
    if endpoint_id then
      merged[endpoint_id] = EndpointProcessor.merge_endpoint_data(merged[endpoint_id], annotation_data)
    else
      -- Create new endpoint from annotation
      merged[annotation_key] = EndpointProcessor.convert_annotation_to_endpoint(annotation_data)
    end
  end
  
  return merged
end

-- Find matching endpoint ID for annotation
-- @param annotation_data table Annotation data
-- @param existing_endpoints table Existing endpoints
-- @return string|nil Matching endpoint ID
function EndpointProcessor.find_matching_endpoint_id(annotation_data, existing_endpoints)
  -- Try to match by operation_id
  for endpoint_id, endpoint_data in pairs(existing_endpoints) do
    if endpoint_data.operation_id == annotation_data.operation_id then
      return endpoint_id
    end
    
    -- Try to match by controller and method
    if endpoint_data.controller and endpoint_data.action and
       annotation_data.controller and annotation_data.method then
      if endpoint_data.controller:lower() == annotation_data.controller:lower() and
         endpoint_data.action:lower() == annotation_data.method:lower() then
        return endpoint_id
      end
    end
  end
  
  return nil
end

-- Convert annotation to endpoint format
-- @param annotation_data table Annotation data
-- @return table Endpoint data
function EndpointProcessor.convert_annotation_to_endpoint(annotation_data)
  return {
    id = annotation_data.operation_id or (annotation_data.controller .. "." .. annotation_data.method),
    controller = annotation_data.controller,
    action = annotation_data.method,
    summary = annotation_data.summary,
    description = annotation_data.description,
    tags = annotation_data.tags,
    parameters = annotation_data.parameters,
    request_body = annotation_data.request_body,
    responses = annotation_data.responses,
    examples = annotation_data.examples,
    security = annotation_data.security,
    deprecated = annotation_data.deprecated
  }
end

-- Merge two endpoint data objects
-- @param base table Base endpoint data
-- @param overlay table Overlay endpoint data
-- @return table Merged endpoint data
function EndpointProcessor.merge_endpoint_data(base, overlay)
  local merged = EndpointProcessor.deep_copy(base)
  
  -- Merge fields, with overlay taking precedence
  for key, value in pairs(overlay) do
    if key == "parameters" then
      -- Merge parameters arrays
      merged[key] = EndpointProcessor.merge_parameters(merged[key] or {}, value or {})
    elseif key == "responses" then
      -- Merge responses objects
      merged[key] = EndpointProcessor.merge_responses(merged[key] or {}, value or {})
    elseif key == "tags" then
      -- Merge tags arrays
      merged[key] = EndpointProcessor.merge_tags(merged[key] or {}, value or {})
    elseif key == "examples" then
      -- Merge examples objects
      merged[key] = EndpointProcessor.merge_examples(merged[key] or {}, value or {})
    else
      -- Direct override for other fields
      if value ~= nil then
        merged[key] = value
      end
    end
  end
  
  return merged
end

-- Merge parameter arrays
-- @param base_params table Base parameters
-- @param overlay_params table Overlay parameters
-- @return table Merged parameters
function EndpointProcessor.merge_parameters(base_params, overlay_params)
  local merged = EndpointProcessor.deep_copy(base_params)
  local param_names = {}
  
  -- Track existing parameter names
  for _, param in ipairs(merged) do
    param_names[param.name] = true
  end
  
  -- Add new parameters from overlay
  for _, param in ipairs(overlay_params) do
    if not param_names[param.name] then
      table.insert(merged, param)
    end
  end
  
  return merged
end

-- Merge response objects
-- @param base_responses table Base responses
-- @param overlay_responses table Overlay responses
-- @return table Merged responses
function EndpointProcessor.merge_responses(base_responses, overlay_responses)
  local merged = EndpointProcessor.deep_copy(base_responses)
  
  for status_code, response in pairs(overlay_responses) do
    merged[status_code] = response
  end
  
  return merged
end

-- Merge tag arrays
-- @param base_tags table Base tags
-- @param overlay_tags table Overlay tags
-- @return table Merged tags
function EndpointProcessor.merge_tags(base_tags, overlay_tags)
  local merged = EndpointProcessor.deep_copy(base_tags)
  local tag_set = {}
  
  -- Track existing tags
  for _, tag in ipairs(merged) do
    tag_set[tag] = true
  end
  
  -- Add new tags from overlay
  for _, tag in ipairs(overlay_tags) do
    if not tag_set[tag] then
      table.insert(merged, tag)
    end
  end
  
  return merged
end

-- Merge example objects
-- @param base_examples table Base examples
-- @param overlay_examples table Overlay examples
-- @return table Merged examples
function EndpointProcessor.merge_examples(base_examples, overlay_examples)
  local merged = EndpointProcessor.deep_copy(base_examples)
  
  for key, example in pairs(overlay_examples) do
    merged[key] = example
  end
  
  return merged
end

-- Process single endpoint to generate comprehensive documentation
-- @param endpoint_id string Endpoint identifier
-- @param endpoint_data table Raw endpoint data
-- @param config table Configuration options
-- @return table Processed endpoint documentation
function EndpointProcessor.process_single_endpoint(endpoint_id, endpoint_data, config)
  local processed = EndpointProcessor.deep_copy(endpoint_data)
  
  -- Ensure required fields
  processed.id = processed.id or endpoint_id
  processed.summary = processed.summary or EndpointProcessor.generate_default_summary(processed)
  processed.description = processed.description or EndpointProcessor.generate_default_description(processed)
  processed.tags = processed.tags or EndpointProcessor.generate_default_tags(processed)
  
  -- Generate code examples
  processed.code_examples = EndpointProcessor.generate_code_examples(processed, config)
  
  -- Generate request/response examples
  processed.request_example = EndpointProcessor.generate_request_example(processed)
  processed.response_examples = EndpointProcessor.generate_response_examples(processed)
  
  -- Add metadata
  processed.metadata = {
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    endpoint_id = endpoint_id,
    has_authentication = processed.auth_required ~= nil,
    has_validation = processed.validation_schema ~= nil,
    parameter_count = processed.parameters and #processed.parameters or 0,
    response_count = processed.responses and EndpointProcessor.count_table_keys(processed.responses) or 0
  }
  
  return processed
end

-- Generate default summary for endpoint
-- @param endpoint_data table Endpoint data
-- @return string Default summary
function EndpointProcessor.generate_default_summary(endpoint_data)
  if endpoint_data.action and endpoint_data.controller then
    local action_summaries = {
      index = "List " .. endpoint_data.controller:lower() .. "s",
      show = "Get " .. endpoint_data.controller:lower() .. " by ID",
      create = "Create new " .. endpoint_data.controller:lower(),
      update = "Update " .. endpoint_data.controller:lower(),
      delete = "Delete " .. endpoint_data.controller:lower()
    }
    
    return action_summaries[endpoint_data.action:lower()] or (endpoint_data.method .. " " .. (endpoint_data.path or ""))
  end
  
  return endpoint_data.method .. " " .. (endpoint_data.path or endpoint_data.id)
end

-- Generate default description for endpoint
-- @param endpoint_data table Endpoint data
-- @return string Default description
function EndpointProcessor.generate_default_description(endpoint_data)
  if endpoint_data.action and endpoint_data.controller then
    local resource_name = endpoint_data.controller:lower()
    local action_descriptions = {
      index = "Retrieve a paginated list of " .. resource_name .. "s with optional filtering and sorting",
      show = "Retrieve detailed information for a specific " .. resource_name .. " by its unique identifier",
      create = "Create a new " .. resource_name .. " record with the provided data",
      update = "Update an existing " .. resource_name .. " record with new data",
      delete = "Permanently delete a " .. resource_name .. " record from the system"
    }
    
    return action_descriptions[endpoint_data.action:lower()] or ("Endpoint for " .. (endpoint_data.path or endpoint_data.id))
  end
  
  return "API endpoint for " .. (endpoint_data.path or endpoint_data.id)
end

-- Generate default tags for endpoint
-- @param endpoint_data table Endpoint data
-- @return table Array of tags
function EndpointProcessor.generate_default_tags(endpoint_data)
  local tags = {}
  
  if endpoint_data.controller then
    local controller_name = endpoint_data.controller:lower():gsub("controller", "")
    table.insert(tags, controller_name)
  end
  
  if endpoint_data.path then
    if endpoint_data.path:find("/auth/") then
      table.insert(tags, "authentication")
    elseif endpoint_data.path:find("/api/") then
      table.insert(tags, "api")
    end
  end
  
  return tags
end

-- Generate code examples for endpoint
-- @param endpoint_data table Endpoint data
-- @param config table Configuration options
-- @return table Code examples in different languages
function EndpointProcessor.generate_code_examples(endpoint_data, config)
  local examples = {}
  
  local base_url = (config and config.base_url) or "http://localhost:8080"
  local path = endpoint_data.path or "/api/endpoint"
  local method = endpoint_data.method or "GET"
  
  -- Generate curl example
  examples.curl = EndpointProcessor.generate_curl_example(base_url, path, method, endpoint_data)
  
  -- Generate JavaScript example
  examples.javascript = EndpointProcessor.generate_javascript_example(base_url, path, method, endpoint_data)
  
  -- Generate Python example
  examples.python = EndpointProcessor.generate_python_example(base_url, path, method, endpoint_data)
  
  return examples
end

-- Generate curl example
-- @param base_url string Base URL
-- @param path string Endpoint path
-- @param method string HTTP method
-- @param endpoint_data table Endpoint data
-- @return string Curl command
function EndpointProcessor.generate_curl_example(base_url, path, method, endpoint_data)
  local curl_parts = {"curl"}
  
  -- Add method
  if method ~= "GET" then
    table.insert(curl_parts, "-X " .. method)
  end
  
  -- Add headers
  table.insert(curl_parts, "-H 'Content-Type: application/json'")
  
  -- Add authentication if required
  if endpoint_data.auth_required then
    table.insert(curl_parts, "-H 'Authorization: Bearer YOUR_TOKEN'")
  end
  
  -- Add request body for POST/PUT methods
  if (method == "POST" or method == "PUT") and endpoint_data.request_example then
    local json = require("cjson")
    local body = json.encode(endpoint_data.request_example)
    table.insert(curl_parts, "-d '" .. body .. "'")
  end
  
  -- Add URL
  local url = base_url .. path
  -- Replace path parameters with examples
  url = url:gsub("{id}", "1"):gsub("{(%w+)}", "example_%1")
  table.insert(curl_parts, "'" .. url .. "'")
  
  return table.concat(curl_parts, " \\\n  ")
end

-- Generate JavaScript example
-- @param base_url string Base URL
-- @param path string Endpoint path
-- @param method string HTTP method
-- @param endpoint_data table Endpoint data
-- @return string JavaScript code
function EndpointProcessor.generate_javascript_example(base_url, path, method, endpoint_data)
  local js_lines = {}
  
  -- Replace path parameters
  local url = base_url .. path:gsub("{id}", "1"):gsub("{(%w+)}", "example_%1")
  
  -- Create fetch options
  table.insert(js_lines, "const response = await fetch('" .. url .. "', {")
  table.insert(js_lines, "  method: '" .. method .. "',")
  table.insert(js_lines, "  headers: {")
  table.insert(js_lines, "    'Content-Type': 'application/json',")
  
  if endpoint_data.auth_required then
    table.insert(js_lines, "    'Authorization': 'Bearer ' + token,")
  end
  
  table.insert(js_lines, "  },")
  
  -- Add body for POST/PUT methods
  if (method == "POST" or method == "PUT") and endpoint_data.request_example then
    local json = require("cjson")
    local body = json.encode(endpoint_data.request_example)
    table.insert(js_lines, "  body: JSON.stringify(" .. body .. "),")
  end
  
  table.insert(js_lines, "});")
  table.insert(js_lines, "")
  table.insert(js_lines, "const data = await response.json();")
  table.insert(js_lines, "console.log(data);")
  
  return table.concat(js_lines, "\n")
end

-- Generate Python example
-- @param base_url string Base URL
-- @param path string Endpoint path
-- @param method string HTTP method
-- @param endpoint_data table Endpoint data
-- @return string Python code
function EndpointProcessor.generate_python_example(base_url, path, method, endpoint_data)
  local py_lines = {}
  
  table.insert(py_lines, "import requests")
  table.insert(py_lines, "import json")
  table.insert(py_lines, "")
  
  -- Replace path parameters
  local url = base_url .. path:gsub("{id}", "1"):gsub("{(%w+)}", "example_%1")
  
  table.insert(py_lines, "url = '" .. url .. "'")
  
  -- Headers
  table.insert(py_lines, "headers = {")
  table.insert(py_lines, "    'Content-Type': 'application/json',")
  
  if endpoint_data.auth_required then
    table.insert(py_lines, "    'Authorization': 'Bearer ' + token,")
  end
  
  table.insert(py_lines, "}")
  
  -- Data for POST/PUT methods
  if (method == "POST" or method == "PUT") and endpoint_data.request_example then
    local json_lib = require("cjson")
    local body = json_lib.encode(endpoint_data.request_example)
    table.insert(py_lines, "data = " .. body)
    table.insert(py_lines, "")
    table.insert(py_lines, "response = requests." .. method:lower() .. "(url, headers=headers, json=data)")
  else
    table.insert(py_lines, "")
    table.insert(py_lines, "response = requests." .. method:lower() .. "(url, headers=headers)")
  end
  
  table.insert(py_lines, "")
  table.insert(py_lines, "if response.status_code == 200:")
  table.insert(py_lines, "    data = response.json()")
  table.insert(py_lines, "    print(json.dumps(data, indent=2))")
  table.insert(py_lines, "else:")
  table.insert(py_lines, "    print(f'Error: {response.status_code} - {response.text}')")
  
  return table.concat(py_lines, "\n")
end

-- Generate request example from schema
-- @param endpoint_data table Endpoint data
-- @return table|nil Request example
function EndpointProcessor.generate_request_example(endpoint_data)
  if not endpoint_data.request_body or not endpoint_data.request_body.content then
    return nil
  end
  
  local json_content = endpoint_data.request_body.content["application/json"]
  if not json_content or not json_content.schema then
    return nil
  end
  
  return SchemaExtractor.create_example_from_schema(json_content.schema)
end

-- Generate response examples
-- @param endpoint_data table Endpoint data
-- @return table Response examples by status code
function EndpointProcessor.generate_response_examples(endpoint_data)
  local examples = {}
  
  if not endpoint_data.responses then
    return examples
  end
  
  for status_code, response_def in pairs(endpoint_data.responses) do
    if response_def.content and response_def.content["application/json"] and response_def.content["application/json"].schema then
      examples[status_code] = SchemaExtractor.create_example_from_schema(response_def.content["application/json"].schema)
    elseif status_code == "200" then
      -- Generate default success response
      examples[status_code] = {
        success = true,
        data = {},
        message = "Operation completed successfully",
        meta = {
          timestamp = "2024-01-01T12:00:00Z",
          request_id = "req_123456789",
          version = "v1"
        }
      }
    end
  end
  
  return examples
end

-- Count keys in table
-- @param tbl table Input table
-- @return number Number of keys
function EndpointProcessor.count_table_keys(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

-- Deep copy table
-- @param orig table Original table
-- @return table Deep copy
function EndpointProcessor.deep_copy(orig)
  local copy
  if type(orig) == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[EndpointProcessor.deep_copy(orig_key)] = EndpointProcessor.deep_copy(orig_value)
    end
    setmetatable(copy, EndpointProcessor.deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

return EndpointProcessor