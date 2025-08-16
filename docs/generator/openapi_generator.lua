-- docs/generator/openapi_generator.lua
-- OpenAPI 3.0 specification generator

local json = require("cjson")
local ApiMiddleware = require("src.application.middlewares.api_middleware")
local SchemaExtractor = require("src.application.middlewares.schema_extractor")
local ControllerAnnotations = require("src.application.middlewares.controller_annotations")

local OpenAPIGenerator = {}

-- Default OpenAPI specification structure
local DEFAULT_SPEC = {
  openapi = "3.0.3",
  info = {
    title = "Church Management System API",
    description = "Comprehensive API for church operations management",
    version = "1.0.0",
    contact = {
      name = "API Support",
      email = "[email]@example.com"
    },
    license = {
      name = "MIT",
      url = "https://opensource.org/licenses/MIT"
    }
  },
  servers = {
    {
      url = "http://localhost:8080",
      description = "Development server"
    }
  },
  components = {
    securitySchemes = {
      bearerAuth = {
        type = "http",
        scheme = "bearer",
        bearerFormat = "JWT",
        description = "JWT token obtained from login endpoint"
      },
      sessionAuth = {
        type = "apiKey",
        ["in"] = "cookie",
        name = "session_token",
        description = "Session-based authentication"
      }
    },
    schemas = {},
    responses = {
      ValidationError = {
        description = "Validation error response",
        content = {
          ["application/json"] = {
            schema = {
              type = "object",
              properties = {
                success = { type = "boolean", example = false },
                error = {
                  type = "object",
                  properties = {
                    code = { type = "string", example = "VALIDATION_FAILED" },
                    message = { type = "string", example = "The request data is invalid" },
                    details = {
                      type = "object",
                      additionalProperties = { type = "string" }
                    }
                  }
                },
                meta = {
                  type = "object",
                  properties = {
                    timestamp = { type = "string", format = "date-time" },
                    request_id = { type = "string" },
                    version = { type = "string" }
                  }
                }
              }
            }
          }
        }
      },
      NotFound = {
        description = "Resource not found",
        content = {
          ["application/json"] = {
            schema = {
              type = "object",
              properties = {
                success = { type = "boolean", example = false },
                error = {
                  type = "object",
                  properties = {
                    code = { type = "string", example = "NOT_FOUND" },
                    message = { type = "string", example = "Resource not found" }
                  }
                }
              }
            }
          }
        }
      },
      Unauthorized = {
        description = "Authentication required",
        content = {
          ["application/json"] = {
            schema = {
              type = "object",
              properties = {
                success = { type = "boolean", example = false },
                error = {
                  type = "object",
                  properties = {
                    code = { type = "string", example = "UNAUTHORIZED" },
                    message = { type = "string", example = "Authentication required" }
                  }
                }
              }
            }
          }
        }
      },
      Forbidden = {
        description = "Access denied",
        content = {
          ["application/json"] = {
            schema = {
              type = "object",
              properties = {
                success = { type = "boolean", example = false },
                error = {
                  type = "object",
                  properties = {
                    code = { type = "string", example = "FORBIDDEN" },
                    message = { type = "string", example = "Access denied" }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  paths = {},
  tags = {}
}

-- Generate complete OpenAPI specification
-- @param config table Configuration options
-- @return table OpenAPI specification
function OpenAPIGenerator.generate_spec(config)
  config = config or {}
  
  local spec = OpenAPIGenerator.deep_copy(DEFAULT_SPEC)
  
  -- Update info from config
  if config.title then spec.info.title = config.title end
  if config.description then spec.info.description = config.description end
  if config.version then spec.info.version = config.version end
  if config.servers then spec.servers = config.servers end
  
  -- Generate paths from registered endpoints
  local endpoint_docs = ApiMiddleware.get_all_endpoint_docs()
  local controller_annotations = ControllerAnnotations.get_all_annotations()
  
  -- Combine endpoint docs and controller annotations
  local all_endpoints = OpenAPIGenerator.merge_endpoint_data(endpoint_docs, controller_annotations)
  
  -- Generate paths
  for endpoint_id, endpoint_data in pairs(all_endpoints) do
    OpenAPIGenerator.add_endpoint_to_spec(spec, endpoint_id, endpoint_data)
  end
  
  -- Generate schemas from validation rules
  OpenAPIGenerator.generate_schemas(spec)
  
  -- Generate tags
  OpenAPIGenerator.generate_tags(spec)
  
  return spec
end

-- Merge endpoint documentation and controller annotations
-- @param endpoint_docs table Endpoint documentation from middleware
-- @param controller_annotations table Controller annotations
-- @return table Merged endpoint data
function OpenAPIGenerator.merge_endpoint_data(endpoint_docs, controller_annotations)
  local merged = {}
  
  -- Start with endpoint docs
  for endpoint_id, docs in pairs(endpoint_docs) do
    merged[endpoint_id] = OpenAPIGenerator.deep_copy(docs)
  end
  
  -- Merge controller annotations
  for annotation_key, annotation in pairs(controller_annotations) do
    -- Try to match annotation to endpoint
    local endpoint_id = OpenAPIGenerator.find_matching_endpoint(annotation, endpoint_docs)
    
    if endpoint_id then
      if not merged[endpoint_id] then
        merged[endpoint_id] = {}
      end
      
      -- Merge annotation data
      merged[endpoint_id] = OpenAPIGenerator.merge_annotation_data(merged[endpoint_id], annotation)
    else
      -- Create new endpoint from annotation
      merged[annotation_key] = annotation
    end
  end
  
  return merged
end

-- Find matching endpoint for controller annotation
-- @param annotation table Controller annotation
-- @param endpoint_docs table Registered endpoint docs
-- @return string|nil Matching endpoint ID
function OpenAPIGenerator.find_matching_endpoint(annotation, endpoint_docs)
  -- Simple matching based on operation_id or controller.method pattern
  for endpoint_id, docs in pairs(endpoint_docs) do
    if docs.operation_id == annotation.operation_id then
      return endpoint_id
    end
    
    -- Try to match based on naming patterns
    local controller_method = annotation.controller:lower() .. "_" .. annotation.method:lower()
    if endpoint_id:find(controller_method) then
      return endpoint_id
    end
  end
  
  return nil
end

-- Merge annotation data into endpoint data
-- @param endpoint_data table Existing endpoint data
-- @param annotation table Controller annotation
-- @return table Merged data
function OpenAPIGenerator.merge_annotation_data(endpoint_data, annotation)
  local merged = OpenAPIGenerator.deep_copy(endpoint_data)
  
  -- Merge fields, with annotation taking precedence
  merged.summary = annotation.summary or merged.summary
  merged.description = annotation.description or merged.description
  merged.tags = annotation.tags or merged.tags
  merged.parameters = annotation.parameters or merged.parameters
  merged.request_body = annotation.request_body or merged.request_body
  merged.responses = annotation.responses or merged.responses
  merged.examples = annotation.examples or merged.examples
  merged.security = annotation.security or merged.security
  merged.deprecated = annotation.deprecated or merged.deprecated
  merged.operation_id = annotation.operation_id or merged.operation_id
  
  return merged
end

-- Add endpoint to OpenAPI specification
-- @param spec table OpenAPI specification
-- @param endpoint_id string Endpoint identifier
-- @param endpoint_data table Endpoint documentation data
function OpenAPIGenerator.add_endpoint_to_spec(spec, endpoint_id, endpoint_data)
  -- Extract path and method from endpoint_id or endpoint_data
  local path, method = OpenAPIGenerator.extract_path_and_method(endpoint_id, endpoint_data)
  
  if not path or not method then
    return -- Skip if we can't determine path/method
  end
  
  -- Ensure path exists in spec
  if not spec.paths[path] then
    spec.paths[path] = {}
  end
  
  -- Create operation object
  local operation = {
    summary = endpoint_data.summary,
    description = endpoint_data.description,
    operationId = endpoint_data.operation_id or endpoint_id,
    tags = endpoint_data.tags or {},
    parameters = endpoint_data.parameters or {},
    responses = endpoint_data.responses or {}
  }
  
  -- Add request body if present
  if endpoint_data.request_body then
    operation.requestBody = endpoint_data.request_body
  end
  
  -- Add security if present
  if endpoint_data.security then
    operation.security = endpoint_data.security
  end
  
  -- Add deprecation if present
  if endpoint_data.deprecated then
    operation.deprecated = endpoint_data.deprecated
  end
  
  -- Add examples if present
  if endpoint_data.examples then
    -- Add examples to responses
    for status_code, response in pairs(operation.responses) do
      if response.content and response.content["application/json"] and endpoint_data.examples[status_code] then
        response.content["application/json"].example = endpoint_data.examples[status_code]
      end
    end
  end
  
  -- Add operation to spec
  spec.paths[path][method:lower()] = operation
end

-- Extract path and method from endpoint identifier
-- @param endpoint_id string Endpoint identifier
-- @param endpoint_data table Endpoint data
-- @return string|nil, string|nil Path and method
function OpenAPIGenerator.extract_path_and_method(endpoint_id, endpoint_data)
  -- Try to extract from endpoint_data first
  if endpoint_data.path and endpoint_data.method then
    return endpoint_data.path, endpoint_data.method
  end
  
  -- Try to parse from endpoint_id (format: "controller.method" or "path:method")
  if endpoint_id:find(":") then
    local path, method = endpoint_id:match("^(.+):(.+)$")
    return path, method
  end
  
  -- Default patterns for common endpoints
  local patterns = {
    ["auth%.login"] = { "/api/v1/auth/login", "POST" },
    ["auth%.logout"] = { "/api/v1/auth/logout", "POST" },
    ["auth%.me"] = { "/api/v1/auth/me", "GET" },
    ["member%.index"] = { "/api/v1/members", "GET" },
    ["member%.create"] = { "/api/v1/members", "POST" },
    ["member%.show"] = { "/api/v1/members/{id}", "GET" },
    ["member%.update"] = { "/api/v1/members/{id}", "PUT" },
    ["member%.delete"] = { "/api/v1/members/{id}", "DELETE" }
  }
  
  local pattern_match = patterns[endpoint_id]
  if pattern_match then
    return pattern_match[1], pattern_match[2]
  end
  
  return nil, nil
end

-- Generate schemas from validation rules
-- @param spec table OpenAPI specification
function OpenAPIGenerator.generate_schemas(spec)
  local validator = require("src.application.validators.input_validator")
  
  -- Generate schemas from validation schemas
  for schema_name, validation_schema in pairs(validator.schemas) do
    local openapi_schema = SchemaExtractor.extract_schema(validation_schema)
    
    -- Convert schema name to PascalCase
    local schema_key = OpenAPIGenerator.to_pascal_case(schema_name)
    spec.components.schemas[schema_key] = openapi_schema
  end
  
  -- Add common response schemas
  spec.components.schemas.SuccessResponse = {
    type = "object",
    properties = {
      success = { type = "boolean", example = true },
      data = { type = "object" },
      message = { type = "string" },
      meta = {
        type = "object",
        properties = {
          timestamp = { type = "string", format = "date-time" },
          request_id = { type = "string" },
          version = { type = "string" }
        }
      }
    }
  }
  
  spec.components.schemas.PaginatedResponse = {
    allOf = {
      { ["$ref"] = "#/components/schemas/SuccessResponse" },
      {
        type = "object",
        properties = {
          pagination = {
            type = "object",
            properties = {
              current_page = { type = "integer" },
              per_page = { type = "integer" },
              total_items = { type = "integer" },
              total_pages = { type = "integer" },
              has_next = { type = "boolean" },
              has_previous = { type = "boolean" }
            }
          }
        }
      }
    }
  }
end

-- Generate tags from endpoints
-- @param spec table OpenAPI specification
function OpenAPIGenerator.generate_tags(spec)
  local tags = {}
  
  -- Collect tags from all operations
  for path, path_item in pairs(spec.paths) do
    for method, operation in pairs(path_item) do
      if operation.tags then
        for _, tag in ipairs(operation.tags) do
          if not tags[tag] then
            tags[tag] = {
              name = tag,
              description = OpenAPIGenerator.generate_tag_description(tag)
            }
          end
        end
      end
    end
  end
  
  -- Convert to array
  spec.tags = {}
  for tag_name, tag_info in pairs(tags) do
    table.insert(spec.tags, tag_info)
  end
  
  -- Sort tags alphabetically
  table.sort(spec.tags, function(a, b) return a.name < b.name end)
end

-- Generate tag description
-- @param tag_name string Tag name
-- @return string Tag description
function OpenAPIGenerator.generate_tag_description(tag_name)
  local descriptions = {
    authentication = "User authentication and session management",
    member = "Church member management operations",
    event = "Event and activity management",
    donation = "Donation and financial tracking",
    tithe = "Tithe management and reporting",
    user = "User account management",
    report = "Reporting and analytics"
  }
  
  return descriptions[tag_name] or ("Operations related to " .. tag_name)
end

-- Convert string to PascalCase
-- @param str string Input string
-- @return string PascalCase string
function OpenAPIGenerator.to_pascal_case(str)
  return str:gsub("_(%w)", function(c) return c:upper() end):gsub("^%w", string.upper)
end

-- Deep copy table
-- @param orig table Original table
-- @return table Deep copy
function OpenAPIGenerator.deep_copy(orig)
  local copy
  if type(orig) == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[OpenAPIGenerator.deep_copy(orig_key)] = OpenAPIGenerator.deep_copy(orig_value)
    end
    setmetatable(copy, OpenAPIGenerator.deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

-- Generate OpenAPI specification file
-- @param output_path string Output file path
-- @param config table Configuration options
-- @return boolean Success status
function OpenAPIGenerator.generate_file(output_path, config)
  local spec = OpenAPIGenerator.generate_spec(config)
  
  -- Convert to JSON
  local json_str = json.encode(spec)
  
  -- Write to file
  local file, err = io.open(output_path, "w")
  if not file then
    return false, "Failed to open file: " .. (err or "unknown error")
  end
  
  file:write(json_str)
  file:close()
  
  return true
end

-- Generate YAML format (basic conversion)
-- @param spec table OpenAPI specification
-- @return string YAML string
function OpenAPIGenerator.to_yaml(spec)
  -- Simple YAML conversion (for basic cases)
  -- For production use, consider using a proper YAML library
  local function to_yaml_recursive(obj, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    local result = {}
    
    if type(obj) == "table" then
      if #obj > 0 then
        -- Array
        for _, value in ipairs(obj) do
          table.insert(result, indent_str .. "- " .. to_yaml_recursive(value, indent + 1):gsub("^%s*", ""))
        end
      else
        -- Object
        for key, value in pairs(obj) do
          if type(value) == "table" then
            table.insert(result, indent_str .. key .. ":")
            table.insert(result, to_yaml_recursive(value, indent + 1))
          else
            table.insert(result, indent_str .. key .. ": " .. tostring(value))
          end
        end
      end
    else
      return tostring(obj)
    end
    
    return table.concat(result, "\n")
  end
  
  return to_yaml_recursive(spec)
end

return OpenAPIGenerator