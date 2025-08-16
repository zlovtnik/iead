-- docs/generator/api_doc_generator.lua
-- Main API documentation generator that coordinates all components

local OpenAPIGenerator = require("docs.generator.openapi_generator")
local EndpointProcessor = require("docs.generator.endpoint_processor")
local RouteAnalyzer = require("docs.generator.route_analyzer")
local json = require("cjson")

local APIDocGenerator = {}

-- Generate complete API documentation
-- @param config table Configuration options
-- @return table Generated documentation
function APIDocGenerator.generate_complete_docs(config)
  config = config or {}
  
  local docs = {
    openapi_spec = nil,
    endpoint_summaries = {},
    code_examples = {},
    metadata = {
      generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      generator_version = "1.0.0",
      api_version = config.api_version or "v1"
    }
  }
  
  -- Process all endpoints
  local processed_endpoints = EndpointProcessor.process_all_endpoints(config)
  
  -- Generate OpenAPI specification
  docs.openapi_spec = OpenAPIGenerator.generate_spec({
    title = config.title or "Church Management System API",
    description = config.description or "Comprehensive API for church operations management",
    version = config.version or "1.0.0",
    servers = config.servers or {{ url = "http://localhost:8080", description = "Development server" }}
  })
  
  -- Generate endpoint summaries
  docs.endpoint_summaries = APIDocGenerator.generate_endpoint_summaries(processed_endpoints)
  
  -- Extract code examples
  docs.code_examples = APIDocGenerator.extract_code_examples(processed_endpoints)
  
  -- Add statistics
  docs.metadata.statistics = APIDocGenerator.generate_statistics(processed_endpoints, docs.openapi_spec)
  
  return docs
end

-- Generate endpoint summaries for quick reference
-- @param processed_endpoints table Processed endpoint data
-- @return table Endpoint summaries
function APIDocGenerator.generate_endpoint_summaries(processed_endpoints)
  local summaries = {}
  
  for endpoint_id, endpoint_data in pairs(processed_endpoints) do
    summaries[endpoint_id] = {
      id = endpoint_id,
      method = endpoint_data.method,
      path = endpoint_data.path,
      summary = endpoint_data.summary,
      description = endpoint_data.description,
      tags = endpoint_data.tags,
      auth_required = endpoint_data.auth_required,
      parameters = APIDocGenerator.summarize_parameters(endpoint_data.parameters),
      responses = APIDocGenerator.summarize_responses(endpoint_data.responses)
    }
  end
  
  return summaries
end

-- Summarize parameters for quick reference
-- @param parameters table Parameter definitions
-- @return table Parameter summaries
function APIDocGenerator.summarize_parameters(parameters)
  if not parameters then
    return {}
  end
  
  local summaries = {}
  
  for _, param in ipairs(parameters) do
    table.insert(summaries, {
      name = param.name,
      location = param["in"],
      type = param.schema and param.schema.type or "string",
      required = param.required or false,
      description = param.description
    })
  end
  
  return summaries
end

-- Summarize responses for quick reference
-- @param responses table Response definitions
-- @return table Response summaries
function APIDocGenerator.summarize_responses(responses)
  if not responses then
    return {}
  end
  
  local summaries = {}
  
  for status_code, response_def in pairs(responses) do
    summaries[status_code] = {
      status_code = status_code,
      description = response_def.description or "Response",
      has_schema = response_def.content and response_def.content["application/json"] and response_def.content["application/json"].schema ~= nil
    }
  end
  
  return summaries
end

-- Extract code examples from processed endpoints
-- @param processed_endpoints table Processed endpoint data
-- @return table Code examples organized by endpoint
function APIDocGenerator.extract_code_examples(processed_endpoints)
  local examples = {}
  
  for endpoint_id, endpoint_data in pairs(processed_endpoints) do
    if endpoint_data.code_examples then
      examples[endpoint_id] = {
        curl = endpoint_data.code_examples.curl,
        javascript = endpoint_data.code_examples.javascript,
        python = endpoint_data.code_examples.python,
        request_example = endpoint_data.request_example,
        response_examples = endpoint_data.response_examples
      }
    end
  end
  
  return examples
end

-- Generate documentation statistics
-- @param processed_endpoints table Processed endpoint data
-- @param openapi_spec table OpenAPI specification
-- @return table Statistics
function APIDocGenerator.generate_statistics(processed_endpoints, openapi_spec)
  local stats = {
    total_endpoints = 0,
    endpoints_by_method = {},
    endpoints_by_tag = {},
    authenticated_endpoints = 0,
    endpoints_with_validation = 0,
    total_schemas = 0,
    coverage = {}
  }
  
  -- Count endpoints
  for endpoint_id, endpoint_data in pairs(processed_endpoints) do
    stats.total_endpoints = stats.total_endpoints + 1
    
    -- Count by method
    local method = endpoint_data.method or "UNKNOWN"
    stats.endpoints_by_method[method] = (stats.endpoints_by_method[method] or 0) + 1
    
    -- Count by tag
    if endpoint_data.tags then
      for _, tag in ipairs(endpoint_data.tags) do
        stats.endpoints_by_tag[tag] = (stats.endpoints_by_tag[tag] or 0) + 1
      end
    end
    
    -- Count authenticated endpoints
    if endpoint_data.auth_required then
      stats.authenticated_endpoints = stats.authenticated_endpoints + 1
    end
    
    -- Count endpoints with validation
    if endpoint_data.validation_schema or endpoint_data.request_body then
      stats.endpoints_with_validation = stats.endpoints_with_validation + 1
    end
  end
  
  -- Count schemas
  if openapi_spec.components and openapi_spec.components.schemas then
    for _ in pairs(openapi_spec.components.schemas) do
      stats.total_schemas = stats.total_schemas + 1
    end
  end
  
  -- Calculate coverage metrics
  stats.coverage = {
    endpoints_with_summaries = APIDocGenerator.count_endpoints_with_field(processed_endpoints, "summary"),
    endpoints_with_descriptions = APIDocGenerator.count_endpoints_with_field(processed_endpoints, "description"),
    endpoints_with_examples = APIDocGenerator.count_endpoints_with_field(processed_endpoints, "code_examples"),
    endpoints_with_tags = APIDocGenerator.count_endpoints_with_field(processed_endpoints, "tags")
  }
  
  return stats
end

-- Count endpoints with specific field
-- @param processed_endpoints table Processed endpoint data
-- @param field_name string Field name to check
-- @return number Count of endpoints with field
function APIDocGenerator.count_endpoints_with_field(processed_endpoints, field_name)
  local count = 0
  
  for _, endpoint_data in pairs(processed_endpoints) do
    if endpoint_data[field_name] and 
       (type(endpoint_data[field_name]) ~= "table" or next(endpoint_data[field_name])) then
      count = count + 1
    end
  end
  
  return count
end

-- Generate documentation files
-- @param docs table Generated documentation
-- @param output_dir string Output directory
-- @param config table Configuration options
-- @return boolean Success status
function APIDocGenerator.generate_files(docs, output_dir, config)
  config = config or {}
  
  -- Ensure output directory exists
  os.execute("mkdir -p " .. output_dir)
  
  local success = true
  
  -- Generate OpenAPI specification file
  if docs.openapi_spec then
    local openapi_file = output_dir .. "/openapi.json"
    local file, err = io.open(openapi_file, "w")
    if file then
      file:write(json.encode(docs.openapi_spec))
      file:close()
    else
      print("Error writing OpenAPI spec: " .. (err or "unknown error"))
      success = false
    end
    
    -- Generate YAML version if requested
    if config.generate_yaml then
      local yaml_file = output_dir .. "/openapi.yaml"
      local yaml_content = OpenAPIGenerator.to_yaml(docs.openapi_spec)
      local yaml_file_handle, yaml_err = io.open(yaml_file, "w")
      if yaml_file_handle then
        yaml_file_handle:write(yaml_content)
        yaml_file_handle:close()
      else
        print("Error writing OpenAPI YAML: " .. (yaml_err or "unknown error"))
      end
    end
  end
  
  -- Generate endpoint summaries file
  if docs.endpoint_summaries then
    local summaries_file = output_dir .. "/endpoint_summaries.json"
    local file, err = io.open(summaries_file, "w")
    if file then
      file:write(json.encode(docs.endpoint_summaries))
      file:close()
    else
      print("Error writing endpoint summaries: " .. (err or "unknown error"))
      success = false
    end
  end
  
  -- Generate code examples file
  if docs.code_examples then
    local examples_file = output_dir .. "/code_examples.json"
    local file, err = io.open(examples_file, "w")
    if file then
      file:write(json.encode(docs.code_examples))
      file:close()
    else
      print("Error writing code examples: " .. (err or "unknown error"))
      success = false
    end
  end
  
  -- Generate metadata file
  if docs.metadata then
    local metadata_file = output_dir .. "/metadata.json"
    local file, err = io.open(metadata_file, "w")
    if file then
      file:write(json.encode(docs.metadata))
      file:close()
    else
      print("Error writing metadata: " .. (err or "unknown error"))
      success = false
    end
  end
  
  -- Generate human-readable summary
  APIDocGenerator.generate_summary_file(docs, output_dir .. "/README.md")
  
  return success
end

-- Generate human-readable summary file
-- @param docs table Generated documentation
-- @param output_file string Output file path
function APIDocGenerator.generate_summary_file(docs, output_file)
  local lines = {}
  
  table.insert(lines, "# API Documentation Summary")
  table.insert(lines, "")
  table.insert(lines, "Generated on: " .. (docs.metadata.generated_at or "unknown"))
  table.insert(lines, "")
  
  -- Statistics
  if docs.metadata.statistics then
    local stats = docs.metadata.statistics
    table.insert(lines, "## Statistics")
    table.insert(lines, "")
    table.insert(lines, "- **Total Endpoints**: " .. stats.total_endpoints)
    table.insert(lines, "- **Authenticated Endpoints**: " .. stats.authenticated_endpoints)
    table.insert(lines, "- **Endpoints with Validation**: " .. stats.endpoints_with_validation)
    table.insert(lines, "- **Total Schemas**: " .. stats.total_schemas)
    table.insert(lines, "")
    
    -- Endpoints by method
    table.insert(lines, "### Endpoints by Method")
    table.insert(lines, "")
    for method, count in pairs(stats.endpoints_by_method) do
      table.insert(lines, "- **" .. method .. "**: " .. count)
    end
    table.insert(lines, "")
    
    -- Endpoints by tag
    if next(stats.endpoints_by_tag) then
      table.insert(lines, "### Endpoints by Category")
      table.insert(lines, "")
      for tag, count in pairs(stats.endpoints_by_tag) do
        table.insert(lines, "- **" .. tag .. "**: " .. count)
      end
      table.insert(lines, "")
    end
    
    -- Coverage
    if stats.coverage then
      table.insert(lines, "### Documentation Coverage")
      table.insert(lines, "")
      table.insert(lines, "- **Endpoints with Summaries**: " .. stats.coverage.endpoints_with_summaries .. "/" .. stats.total_endpoints)
      table.insert(lines, "- **Endpoints with Descriptions**: " .. stats.coverage.endpoints_with_descriptions .. "/" .. stats.total_endpoints)
      table.insert(lines, "- **Endpoints with Examples**: " .. stats.coverage.endpoints_with_examples .. "/" .. stats.total_endpoints)
      table.insert(lines, "- **Endpoints with Tags**: " .. stats.coverage.endpoints_with_tags .. "/" .. stats.total_endpoints)
      table.insert(lines, "")
    end
  end
  
  -- Files generated
  table.insert(lines, "## Generated Files")
  table.insert(lines, "")
  table.insert(lines, "- `openapi.json` - OpenAPI 3.0 specification")
  table.insert(lines, "- `openapi.yaml` - OpenAPI 3.0 specification (YAML format)")
  table.insert(lines, "- `endpoint_summaries.json` - Quick reference for all endpoints")
  table.insert(lines, "- `code_examples.json` - Code examples in multiple languages")
  table.insert(lines, "- `metadata.json` - Generation metadata and statistics")
  table.insert(lines, "")
  
  -- Usage instructions
  table.insert(lines, "## Usage")
  table.insert(lines, "")
  table.insert(lines, "### OpenAPI Specification")
  table.insert(lines, "")
  table.insert(lines, "The `openapi.json` file can be used with:")
  table.insert(lines, "- Swagger UI for interactive API exploration")
  table.insert(lines, "- Postman for API testing")
  table.insert(lines, "- Code generation tools")
  table.insert(lines, "- API validation tools")
  table.insert(lines, "")
  
  table.insert(lines, "### Code Examples")
  table.insert(lines, "")
  table.insert(lines, "The `code_examples.json` file contains ready-to-use code snippets in:")
  table.insert(lines, "- cURL commands")
  table.insert(lines, "- JavaScript (fetch API)")
  table.insert(lines, "- Python (requests library)")
  table.insert(lines, "")
  
  -- Write to file
  local file = io.open(output_file, "w")
  if file then
    file:write(table.concat(lines, "\n"))
    file:close()
  end
end

-- Main entry point for generating API documentation
-- @param config table Configuration options
-- @return boolean Success status
function APIDocGenerator.generate(config)
  config = config or {}
  
  print("Generating API documentation...")
  
  -- Set default configuration
  config.output_dir = config.output_dir or "docs/api"
  config.routes_dir = config.routes_dir or "src/routes"
  config.base_url = config.base_url or "http://localhost:8080"
  
  -- Generate complete documentation
  local docs = APIDocGenerator.generate_complete_docs(config)
  
  -- Write files
  local success = APIDocGenerator.generate_files(docs, config.output_dir, config)
  
  if success then
    print("API documentation generated successfully in " .. config.output_dir)
    if docs.metadata.statistics then
      print("Generated documentation for " .. docs.metadata.statistics.total_endpoints .. " endpoints")
    end
  else
    print("Error generating API documentation")
  end
  
  return success
end

return APIDocGenerator