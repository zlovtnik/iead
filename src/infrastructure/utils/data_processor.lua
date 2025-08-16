-- src/infrastructure/utils/data_processor.lua
-- Functional data processing utilities for repositories and controllers

local fun = require("src.utils.functional")

local DataProcessor = {}

-- Process query results with functional transformations
-- @param results table Raw database results
-- @param transformers table Array of transformation functions
-- @return table Processed results
function DataProcessor.process_results(results, transformers)
  if not results or #results == 0 then
    return results
  end
  
  local processed = results
  
  -- Apply each transformer function in sequence
  fun.from_table(transformers):each(function(transformer)
    processed = fun.map_table(transformer, processed)
  end)
  
  return processed
end

-- Filter results based on multiple predicates
-- @param results table Results to filter
-- @param filters table Array of filter functions
-- @return table Filtered results
function DataProcessor.apply_filters(results, filters)
  if not results or #results == 0 or not filters or #filters == 0 then
    return results
  end
  
  return fun.reduce_table(function(acc, filter_func)
    return fun.filter_table(filter_func, acc)
  end, results, filters)
end

-- Group results by a field or function
-- @param results table Results to group
-- @param group_by_func function Function to determine grouping key
-- @return table Grouped results
function DataProcessor.group_results(results, group_by_func)
  if not results or #results == 0 then
    return {}
  end
  
  return fun.group_by(group_by_func, results)
end

-- Sort results by multiple criteria
-- @param results table Results to sort
-- @param sort_criteria table Array of {field, direction} or sort functions
-- @return table Sorted results
function DataProcessor.sort_results(results, sort_criteria)
  if not results or #results == 0 or not sort_criteria then
    return results
  end
  
  local sorted = fun.map_table(function(x) return x end, results)
  
  table.sort(sorted, function(a, b)
    for _, criterion in ipairs(sort_criteria) do
      local aVal, bVal
      
      if type(criterion) == "function" then
        return criterion(a, b)
      elseif type(criterion) == "table" then
        local field = criterion.field or criterion[1]
        local direction = criterion.direction or criterion[2] or "asc"
        
        aVal = a[field]
        bVal = b[field]
        
        if aVal ~= bVal then
          if direction:lower() == "desc" then
            return (aVal or "") > (bVal or "")
          else
            return (aVal or "") < (bVal or "")
          end
        end
      end
    end
    return false
  end)
  
  return sorted
end

-- Paginate results
-- @param results table Results to paginate
-- @param page number Page number (1-based)
-- @param per_page number Items per page
-- @return table Paginated results
-- @return table Pagination metadata
function DataProcessor.paginate_results(results, page, per_page)
  if not results then
    return {}, {page = 1, per_page = per_page, total = 0, total_pages = 0}
  end
  
  page = page or 1
  per_page = per_page or 10
  
  local total = #results
  local total_pages = math.ceil(total / per_page)
  local start_index = (page - 1) * per_page + 1
  local end_index = math.min(start_index + per_page - 1, total)
  
  local paginated = {}
  if start_index <= total then
    for i = start_index, end_index do
      table.insert(paginated, results[i])
    end
  end
  
  local pagination = {
    page = page,
    per_page = per_page,
    total = total,
    total_pages = total_pages,
    has_next = page < total_pages,
    has_previous = page > 1
  }
  
  return paginated, pagination
end

-- Extract unique values from a field across all results
-- @param results table Results to process
-- @param field string Field name to extract
-- @return table Array of unique values
function DataProcessor.extract_unique_values(results, field)
  if not results or #results == 0 then
    return {}
  end
  
  local values = fun.pluck(field, results)
  return fun.unique(fun.filter_table(function(v) return v ~= nil end, values))
end

-- Calculate aggregations on numeric fields
-- @param results table Results to aggregate
-- @param field string Field name to aggregate
-- @return table Aggregation results {sum, avg, min, max, count}
function DataProcessor.calculate_aggregations(results, field)
  if not results or #results == 0 then
    return {sum = 0, avg = 0, min = nil, max = nil, count = 0}
  end
  
  local values = fun.filter_table(function(item)
    return item[field] and type(item[field]) == "number"
  end, results)
  
  if #values == 0 then
    return {sum = 0, avg = 0, min = nil, max = nil, count = 0}
  end
  
  local numeric_values = fun.pluck(field, values)
  
  return {
    sum = fun.sum(numeric_values),
    avg = fun.average(numeric_values),
    min = fun.min(numeric_values),
    max = fun.max(numeric_values),
    count = #numeric_values
  }
end

-- Transform field names (e.g., snake_case to camelCase)
-- @param results table Results to transform
-- @param field_mapping table Map of old_field -> new_field
-- @return table Results with transformed field names
function DataProcessor.transform_field_names(results, field_mapping)
  if not results or #results == 0 or not field_mapping then
    return results
  end
  
  return fun.map_table(function(item)
    local transformed = {}
    fun.from_pairs(item):each(function(key, value)
      local new_key = field_mapping[key] or key
      transformed[new_key] = value
    end)
    return transformed
  end, results)
end

-- Remove sensitive fields from results
-- @param results table Results to sanitize
-- @param sensitive_fields table Array of field names to remove
-- @return table Sanitized results
function DataProcessor.sanitize_results(results, sensitive_fields)
  if not results or #results == 0 or not sensitive_fields then
    return results
  end
  
  return fun.omit_keys(sensitive_fields, results)
end

-- Add computed fields to results
-- @param results table Results to enhance
-- @param computed_fields table Map of field_name -> computation_function
-- @return table Enhanced results
function DataProcessor.add_computed_fields(results, computed_fields)
  if not results or #results == 0 or not computed_fields then
    return results
  end
  
  return fun.map_table(function(item)
    local enhanced = {}
    -- Copy original fields
    fun.from_pairs(item):each(function(key, value)
      enhanced[key] = value
    end)
    
    -- Add computed fields
    fun.from_pairs(computed_fields):each(function(field_name, computation_func)
      enhanced[field_name] = computation_func(item)
    end)
    
    return enhanced
  end, results)
end

-- Flatten nested structures in results
-- @param results table Results to flatten
-- @param nested_field string Field containing nested data
-- @param prefix string Optional prefix for flattened fields
-- @return table Flattened results
function DataProcessor.flatten_nested_fields(results, nested_field, prefix)
  if not results or #results == 0 then
    return results
  end
  
  prefix = prefix or (nested_field .. "_")
  
  return fun.map_table(function(item)
    local flattened = {}
    
    -- Copy non-nested fields
    fun.from_pairs(item):each(function(key, value)
      if key ~= nested_field then
        flattened[key] = value
      elseif type(value) == "table" then
        -- Flatten nested object
        fun.from_pairs(value):each(function(nested_key, nested_value)
          flattened[prefix .. nested_key] = nested_value
        end)
      end
    end)
    
    return flattened
  end, results)
end

-- Validate results against schema
-- @param results table Results to validate
-- @param schema table Validation schema
-- @return table Valid results
-- @return table Invalid results
function DataProcessor.validate_results(results, schema)
  if not results or #results == 0 or not schema then
    return results, {}
  end
  
  return fun.partition_table(function(item)
    return fun.all_match(function(field_rule)
      local field = field_rule[1]
      local validator = field_rule[2]
      return validator(item[field])
    end, fun.from_pairs(schema):totable())
  end, results)
end

return DataProcessor
