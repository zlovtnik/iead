-- src/application/middlewares/schema_extractor.lua
-- Utility for extracting OpenAPI schemas from validation rules

local SchemaExtractor = {}

-- Map Lua validation rules to OpenAPI schema types
local TYPE_MAPPING = {
  pattern = "string",
  min_length = "string",
  max_length = "string",
  min_value = "number",
  max_value = "number",
  allowed_values = "string", -- enum
  require_uppercase = "string",
  require_lowercase = "string",
  require_digit = "string",
  require_special = "string"
}

-- Common pattern to OpenAPI format mapping
local PATTERN_FORMATS = {
  ["^[%w._%+-]+@[%w.-]+%.%w+$"] = "email",
  ["^%+?[%d%s%-%.%(%)]+$"] = "phone",
  ["^%d%d%d%d%-%d%d%-%d%d$"] = "date",
  ["^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$"] = "date-time",
  ["^%d+$"] = "integer",
  ["^%d+%.?%d*$"] = "number"
}

-- Extract OpenAPI schema from validation rules
-- @param validation_schema table Lua validation schema
-- @return table OpenAPI schema object
function SchemaExtractor.extract_schema(validation_schema)
  if not validation_schema or type(validation_schema) ~= "table" then
    return {}
  end
  
  local schema = {
    type = "object",
    properties = {},
    required = {}
  }
  
  for field_name, field_rules in pairs(validation_schema) do
    if field_name ~= "_strict" then
      local property = SchemaExtractor.extract_property_schema(field_rules)
      schema.properties[field_name] = property
      
      if field_rules.required then
        table.insert(schema.required, field_name)
      end
    end
  end
  
  return schema
end

-- Extract schema for individual property
-- @param field_rules table Validation rules for a field
-- @return table OpenAPI property schema
function SchemaExtractor.extract_property_schema(field_rules)
  if not field_rules or type(field_rules) ~= "table" then
    return { type = "string" }
  end
  
  local property = {}
  
  -- Determine type from rules
  if field_rules.allowed_values then
    property.type = "string"
    property.enum = field_rules.allowed_values
  elseif field_rules.pattern then
    local format = PATTERN_FORMATS[field_rules.pattern]
    if format == "integer" then
      property.type = "integer"
    elseif format == "number" then
      property.type = "number"
    else
      property.type = "string"
      if format then
        property.format = format
      end
    end
  elseif field_rules.min_value or field_rules.max_value then
    property.type = "number"
  else
    property.type = "string"
  end
  
  -- Add constraints
  if field_rules.min_length then
    property.minLength = field_rules.min_length
  end
  
  if field_rules.max_length then
    property.maxLength = field_rules.max_length
  end
  
  if field_rules.min_value then
    property.minimum = field_rules.min_value
  end
  
  if field_rules.max_value then
    property.maximum = field_rules.max_value
  end
  
  -- Add description based on validation rules
  local descriptions = {}
  
  if field_rules.required then
    table.insert(descriptions, "Required field")
  end
  
  if field_rules.min_length and field_rules.max_length then
    table.insert(descriptions, string.format("Length: %d-%d characters", field_rules.min_length, field_rules.max_length))
  elseif field_rules.min_length then
    table.insert(descriptions, string.format("Minimum length: %d characters", field_rules.min_length))
  elseif field_rules.max_length then
    table.insert(descriptions, string.format("Maximum length: %d characters", field_rules.max_length))
  end
  
  if field_rules.pattern and PATTERN_FORMATS[field_rules.pattern] then
    local format_name = PATTERN_FORMATS[field_rules.pattern]
    table.insert(descriptions, string.format("Format: %s", format_name))
  end
  
  if #descriptions > 0 then
    property.description = table.concat(descriptions, ". ")
  end
  
  return property
end

-- Extract response schema from controller examples
-- @param examples table Response examples
-- @return table OpenAPI response schema
function SchemaExtractor.extract_response_schema(examples)
  if not examples or type(examples) ~= "table" then
    return {
      type = "object",
      properties = {
        success = { type = "boolean" },
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
  end
  
  -- Analyze example structure to infer schema
  local schema = { type = "object", properties = {} }
  
  for key, value in pairs(examples) do
    schema.properties[key] = SchemaExtractor.infer_type_from_value(value)
  end
  
  return schema
end

-- Infer OpenAPI type from Lua value
-- @param value any The value to analyze
-- @return table OpenAPI type definition
function SchemaExtractor.infer_type_from_value(value)
  local value_type = type(value)
  
  if value_type == "string" then
    -- Check if it looks like a date/time
    if value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ?$") then
      return { type = "string", format = "date-time" }
    elseif value:match("^%d%d%d%d%-%d%d%-%d%d$") then
      return { type = "string", format = "date" }
    else
      return { type = "string" }
    end
  elseif value_type == "number" then
    if value == math.floor(value) then
      return { type = "integer" }
    else
      return { type = "number" }
    end
  elseif value_type == "boolean" then
    return { type = "boolean" }
  elseif value_type == "table" then
    if #value > 0 then
      -- Array
      local item_schema = { type = "object" }
      if value[1] then
        item_schema = SchemaExtractor.infer_type_from_value(value[1])
      end
      return {
        type = "array",
        items = item_schema
      }
    else
      -- Object
      local properties = {}
      for k, v in pairs(value) do
        properties[k] = SchemaExtractor.infer_type_from_value(v)
      end
      return {
        type = "object",
        properties = properties
      }
    end
  else
    return { type = "string" }
  end
end

-- Generate parameter schema from route pattern
-- @param route_pattern string Route pattern with parameters
-- @return table Array of parameter definitions
function SchemaExtractor.extract_path_parameters(route_pattern)
  local parameters = {}
  
  -- Find path parameters in pattern like (%d+) or (%w+)
  for param_pattern in route_pattern:gmatch("%(([^%)]+)%)") do
    local param_name = "id" -- Default name, should be overridden
    local param_type = "string"
    
    -- Infer type from pattern
    if param_pattern == "%d+" then
      param_type = "integer"
      param_name = "id"
    elseif param_pattern == "%w+" then
      param_type = "string"
    end
    
    table.insert(parameters, {
      name = param_name,
      ["in"] = "path",
      required = true,
      schema = { type = param_type },
      description = string.format("The %s parameter", param_name)
    })
  end
  
  return parameters
end

-- Create example request/response from schema
-- @param schema table OpenAPI schema
-- @return table Example data
function SchemaExtractor.create_example_from_schema(schema)
  if not schema or not schema.properties then
    return {}
  end
  
  local example = {}
  
  for prop_name, prop_schema in pairs(schema.properties) do
    example[prop_name] = SchemaExtractor.create_example_value(prop_schema)
  end
  
  return example
end

-- Create example value from property schema
-- @param prop_schema table Property schema definition
-- @return any Example value
function SchemaExtractor.create_example_value(prop_schema)
  if not prop_schema then
    return "example"
  end
  
  if prop_schema.enum then
    return prop_schema.enum[1]
  end
  
  local prop_type = prop_schema.type or "string"
  
  if prop_type == "string" then
    if prop_schema.format == "email" then
      return "[email]@example.com"
    elseif prop_schema.format == "date" then
      return "2024-01-01"
    elseif prop_schema.format == "date-time" then
      return "2024-01-01T12:00:00Z"
    else
      return "example string"
    end
  elseif prop_type == "integer" then
    return 1
  elseif prop_type == "number" then
    return 1.0
  elseif prop_type == "boolean" then
    return true
  elseif prop_type == "array" then
    local item_example = SchemaExtractor.create_example_value(prop_schema.items or {})
    return { item_example }
  elseif prop_type == "object" then
    return SchemaExtractor.create_example_from_schema(prop_schema)
  else
    return "example"
  end
end

return SchemaExtractor