-- src/infrastructure/db/base_repository.lua
-- Base repository implementation providing common CRUD operations

local db = require("src.infrastructure.db.connection")
local validation = require("src.utils.validation")
local log = require("src.utils.log")

local BaseRepository = {}
BaseRepository.__index = BaseRepository

-- Create a new repository instance
-- @param table_name string The database table name
-- @param schema table Optional schema definition for validation
-- @return BaseRepository instance
function BaseRepository.new(table_name, schema)
  local instance = {
    table_name = table_name,
    schema = schema or {},
    primary_key = "id"  -- Default primary key column
  }
  setmetatable(instance, BaseRepository)
  return instance
end

-- Set the primary key column name (default is "id")
-- @param key_name string The primary key column name
function BaseRepository:set_primary_key(key_name)
  self.primary_key = key_name
end

-- Validate data against schema if defined
-- @param data table The data to validate
-- @return sanitized_data, errors
function BaseRepository:validate(data)
  if not self.schema or not next(self.schema) then
    return data, nil
  end
  
  local sanitized = {}
  local errors = {}
  
  for field, rules in pairs(self.schema) do
    local value = data[field]
    
    -- Check required fields
    if rules.required and (value == nil or value == "") then
      table.insert(errors, field .. " is required")
    end
    
    -- Type validation
    if value ~= nil and rules.type then
      local expected_type = rules.type
      local actual_type = type(value)
      
      if expected_type == "number" and actual_type == "string" then
        local num_value = tonumber(value)
        if num_value then
          sanitized[field] = num_value
        else
          table.insert(errors, field .. " must be a valid number")
        end
      elseif expected_type == "string" and actual_type ~= "string" then
        sanitized[field] = tostring(value)
      elseif actual_type == expected_type then
        sanitized[field] = value
      else
        table.insert(errors, field .. " must be of type " .. expected_type)
      end
    else
      sanitized[field] = value
    end
    
    -- Length validation for strings
    if sanitized[field] and rules.max_length and type(sanitized[field]) == "string" then
      if #sanitized[field] > rules.max_length then
        table.insert(errors, field .. " must be " .. rules.max_length .. " characters or less")
      end
    end
    
    if sanitized[field] and rules.min_length and type(sanitized[field]) == "string" then
      if #sanitized[field] < rules.min_length then
        table.insert(errors, field .. " must be at least " .. rules.min_length .. " characters")
      end
    end
  end
  
  -- Add non-schema fields as-is
  for field, value in pairs(data) do
    if not self.schema[field] then
      sanitized[field] = value
    end
  end
  
  if #errors > 0 then
    return nil, errors
  end
  
  return sanitized, nil
end

-- Build WHERE clause from conditions
-- @param conditions table Key-value pairs for WHERE conditions
-- @return where_clause, params
function BaseRepository:build_where_clause(conditions)
  if not conditions or not next(conditions) then
    return "", {}
  end
  
  local where_parts = {}
  local params = {}
  
  for field, value in pairs(conditions) do
    if type(value) == "table" and value.operator then
      -- Handle complex conditions like {operator = "LIKE", value = "%search%"}
      if value.operator == "=" and value.value == nil then
        table.insert(where_parts, field .. " IS NULL")
      else
        table.insert(where_parts, field .. " " .. value.operator .. " ?")
        table.insert(params, value.value)
      end
    elseif type(value) == "table" and value["in"] then
      -- Handle IN conditions like {in = {1, 2, 3}}
      local placeholders = {}
      for _, v in ipairs(value["in"]) do
        table.insert(placeholders, "?")
        table.insert(params, v)
      end
      table.insert(where_parts, field .. " IN (" .. table.concat(placeholders, ",") .. ")")
    else
      -- Simple equality condition
      if value == nil then
        table.insert(where_parts, field .. " IS NULL")
      else
        table.insert(where_parts, field .. " = ?")
        table.insert(params, value)
      end
    end
  end
  
  return "WHERE " .. table.concat(where_parts, " AND "), params
end

-- Find all records with optional conditions, ordering, and pagination
-- @param options table {
--   conditions = {field = value, ...},
--   order_by = "field_name",
--   order_direction = "ASC|DESC",
--   limit = number,
--   offset = number
-- }
-- @return records, error
function BaseRepository:find_all(options)
  options = options or {}
  
  local query = "SELECT * FROM " .. self.table_name
  local params = {}
  
  -- Add WHERE clause
  if options.conditions then
    local where_clause, where_params = self:build_where_clause(options.conditions)
    query = query .. " " .. where_clause
    for _, param in ipairs(where_params) do
      table.insert(params, param)
    end
  end
  
  -- Add ORDER BY clause
  if options.order_by then
    local direction = options.order_direction or "ASC"
    query = query .. " ORDER BY " .. options.order_by .. " " .. direction
  end
  
  -- Add LIMIT and OFFSET
  if options.limit then
    query = query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset then
      query = query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return db.query_all(query, params)
end

-- Find a single record by conditions
-- @param conditions table Key-value pairs for WHERE conditions
-- @return record, error
function BaseRepository:find_one(conditions)
  local where_clause, params = self:build_where_clause(conditions)
  local query = "SELECT * FROM " .. self.table_name .. " " .. where_clause .. " LIMIT 1"
  
  return db.query_one(query, params)
end

-- Find a record by primary key
-- @param id mixed The primary key value
-- @return record, error
function BaseRepository:find_by_id(id)
  return self:find_one({[self.primary_key] = id})
end

-- Create a new record
-- @param data table The data to insert
-- @return record, error
function BaseRepository:create(data)
  -- Validate data
  local sanitized_data, validation_errors = self:validate(data)
  if validation_errors then
    return nil, "Validation failed: " .. table.concat(validation_errors, ", ")
  end
  
  -- Build INSERT query
  local fields = {}
  local placeholders = {}
  local params = {}
  
  for field, value in pairs(sanitized_data) do
    table.insert(fields, field)
    table.insert(placeholders, "?")
    table.insert(params, value)
  end
  
  local query = string.format(
    "INSERT INTO %s (%s) VALUES (%s)",
    self.table_name,
    table.concat(fields, ", "),
    table.concat(placeholders, ", ")
  )
  
  local affected_rows, err = db.execute(query, params)
  if not affected_rows then
    return nil, err
  end
  
  -- Get the created record
  local last_id, id_err = db.last_insert_id()
  if not last_id then
    return nil, id_err
  end
  
  return self:find_by_id(last_id)
end

-- Update records by conditions
-- @param conditions table WHERE conditions
-- @param data table Data to update
-- @return affected_rows, error
function BaseRepository:update(conditions, data)
  -- Validate data
  local sanitized_data, validation_errors = self:validate(data)
  if validation_errors then
    return nil, "Validation failed: " .. table.concat(validation_errors, ", ")
  end
  
  -- Build UPDATE query
  local set_parts = {}
  local params = {}
  
  for field, value in pairs(sanitized_data) do
    table.insert(set_parts, field .. " = ?")
    table.insert(params, value)
  end
  
  local where_clause, where_params = self:build_where_clause(conditions)
  for _, param in ipairs(where_params) do
    table.insert(params, param)
  end
  
  local query = string.format(
    "UPDATE %s SET %s %s",
    self.table_name,
    table.concat(set_parts, ", "),
    where_clause
  )
  
  return db.execute(query, params)
end

-- Update a record by primary key
-- @param id mixed The primary key value
-- @param data table Data to update
-- @return record, error
function BaseRepository:update_by_id(id, data)
  local affected_rows, err = self:update({[self.primary_key] = id}, data)
  if not affected_rows then
    return nil, err
  end
  
  if affected_rows == 0 then
    return nil, "Record not found"
  end
  
  return self:find_by_id(id)
end

-- Delete records by conditions
-- @param conditions table WHERE conditions
-- @return affected_rows, error
function BaseRepository:delete(conditions)
  local where_clause, params = self:build_where_clause(conditions)
  local query = "DELETE FROM " .. self.table_name .. " " .. where_clause
  
  return db.execute(query, params)
end

-- Delete a record by primary key
-- @param id mixed The primary key value
-- @return success, error
function BaseRepository:delete_by_id(id)
  local affected_rows, err = self:delete({[self.primary_key] = id})
  if not affected_rows then
    return false, err
  end
  
  return affected_rows > 0, affected_rows == 0 and "Record not found" or nil
end

-- Count records with optional conditions
-- @param conditions table Optional WHERE conditions
-- @return count, error
function BaseRepository:count(conditions)
  local query = "SELECT COUNT(*) as count FROM " .. self.table_name
  local params = {}
  
  if conditions then
    local where_clause, where_params = self:build_where_clause(conditions)
    query = query .. " " .. where_clause
    params = where_params
  end
  
  local result, err = db.query_one(query, params)
  if not result then
    return nil, err
  end
  
  return tonumber(result.count), nil
end

-- Check if a record exists with given conditions
-- @param conditions table WHERE conditions
-- @return exists, error
function BaseRepository:exists(conditions)
  local count, err = self:count(conditions)
  if not count then
    return false, err
  end
  
  return count > 0, nil
end

-- Execute a custom query
-- @param query string SQL query with ? placeholders
-- @param params table Parameters for the query
-- @return results, error
function BaseRepository:execute_query(query, params)
  return db.query_all(query, params)
end

-- Execute a custom query and return first result
-- @param query string SQL query with ? placeholders
-- @param params table Parameters for the query
-- @return result, error
function BaseRepository:execute_query_one(query, params)
  return db.query_one(query, params)
end

-- Paginate results
-- @param options table {
--   page = number (1-based),
--   per_page = number,
--   conditions = table,
--   order_by = string,
--   order_direction = string
-- }
-- @return {records, total_count, total_pages, current_page, per_page}, error
function BaseRepository:paginate(options)
  options = options or {}
  local page = options.page or 1
  local per_page = options.per_page or 10
  
  -- Ensure page is at least 1
  if page < 1 then page = 1 end
  
  -- Get total count
  local total_count, count_err = self:count(options.conditions)
  if not total_count then
    return nil, count_err
  end
  
  -- Calculate pagination
  local total_pages = math.ceil(total_count / per_page)
  local offset = (page - 1) * per_page
  
  -- Get records for current page
  local find_options = {
    conditions = options.conditions,
    order_by = options.order_by,
    order_direction = options.order_direction,
    limit = per_page,
    offset = offset
  }
  
  local records, err = self:find_all(find_options)
  if not records then
    return nil, err
  end
  
  return {
    records = records,
    total_count = total_count,
    total_pages = total_pages,
    current_page = page,
    per_page = per_page,
    has_next = page < total_pages,
    has_prev = page > 1
  }, nil
end

return BaseRepository
