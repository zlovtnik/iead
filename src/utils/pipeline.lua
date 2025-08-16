-- src/utils/pipeline.lua
-- Functional pipeline utilities for composing operations

local fun = require("src.utils.functional")

local pipeline = {}

-- Create a new pipeline
-- @param initial_value any The initial value to process
-- @return table Pipeline object
function pipeline.new(initial_value)
  local instance = {
    value = initial_value,
    operations = {}
  }
  setmetatable(instance, {__index = pipeline})
  return instance
end

-- Add a map operation to the pipeline
-- @param map_func function Function to map over each element
-- @return table Pipeline object for chaining
function pipeline:map(map_func)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.map_table(map_func, value)
    else
      return map_func(value)
    end
  end)
  return self
end

-- Add a filter operation to the pipeline
-- @param filter_func function Function to filter elements
-- @return table Pipeline object for chaining
function pipeline:filter(filter_func)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.filter_table(filter_func, value)
    else
      return filter_func(value) and {value} or {}
    end
  end)
  return self
end

-- Add a reduce operation to the pipeline
-- @param reduce_func function Function to reduce elements
-- @param initial any Initial accumulator value
-- @return table Pipeline object for chaining
function pipeline:reduce(reduce_func, initial)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.reduce_table(reduce_func, initial, value)
    else
      return reduce_func(initial, value)
    end
  end)
  return self
end

-- Add a sort operation to the pipeline
-- @param compare_func function Optional comparison function
-- @return table Pipeline object for chaining
function pipeline:sort(compare_func)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.sort_by(compare_func, value)
    else
      return value
    end
  end)
  return self
end

-- Add a unique operation to the pipeline
-- @return table Pipeline object for chaining
function pipeline:unique()
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.unique(value)
    else
      return {value}
    end
  end)
  return self
end

-- Add a flatten operation to the pipeline
-- @return table Pipeline object for chaining
function pipeline:flatten()
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.flatten(value)
    else
      return {value}
    end
  end)
  return self
end

-- Add a group by operation to the pipeline
-- @param key_func function Function to generate grouping key
-- @return table Pipeline object for chaining
function pipeline:group_by(key_func)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.group_by(key_func, value)
    else
      local key = key_func(value)
      return {[key] = {value}}
    end
  end)
  return self
end

-- Add a take operation to the pipeline
-- @param count number Number of elements to take
-- @return table Pipeline object for chaining
function pipeline:take(count)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      local result = {}
      for i = 1, math.min(count, #value) do
        result[i] = value[i]
      end
      return result
    else
      return count > 0 and {value} or {}
    end
  end)
  return self
end

-- Add a drop operation to the pipeline
-- @param count number Number of elements to drop
-- @return table Pipeline object for chaining
function pipeline:drop(count)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      local result = {}
      for i = count + 1, #value do
        table.insert(result, value[i])
      end
      return result
    else
      return count > 0 and {} or {value}
    end
  end)
  return self
end

-- Add a pluck operation to the pipeline
-- @param key string Key to pluck from objects
-- @return table Pipeline object for chaining
function pipeline:pluck(key)
  table.insert(self.operations, function(value)
    if type(value) == "table" then
      return fun.pluck(key, value)
    else
      return value[key] and {value[key]} or {}
    end
  end)
  return self
end

-- Add a custom operation to the pipeline
-- @param operation_func function Custom operation function
-- @return table Pipeline object for chaining
function pipeline:transform(operation_func)
  table.insert(self.operations, operation_func)
  return self
end

-- Add a tap operation (for side effects without modifying the value)
-- @param tap_func function Function to call with the current value
-- @return table Pipeline object for chaining
function pipeline:tap(tap_func)
  table.insert(self.operations, function(value)
    tap_func(value)
    return value
  end)
  return self
end

-- Add a conditional operation to the pipeline
-- @param condition_func function Condition to check
-- @param then_func function Operation to apply if condition is true
-- @param else_func function Optional operation to apply if condition is false
-- @return table Pipeline object for chaining
function pipeline:if_then(condition_func, then_func, else_func)
  table.insert(self.operations, function(value)
    if condition_func(value) then
      return then_func(value)
    elseif else_func then
      return else_func(value)
    else
      return value
    end
  end)
  return self
end

-- Execute the pipeline and return the result
-- @return any The final processed value
function pipeline:execute()
  local result = self.value
  
  for _, operation in ipairs(self.operations) do
    result = operation(result)
  end
  
  return result
end

-- Execute the pipeline and return both the result and the pipeline for further chaining
-- @return any The final processed value
-- @return table The pipeline object for chaining
function pipeline:execute_and_continue()
  local result = self:execute()
  self.value = result
  self.operations = {}
  return result, self
end

-- Create a reusable pipeline template
-- @param operations table Array of operation functions
-- @return function Pipeline factory function
function pipeline.create_template(operations)
  return function(initial_value)
    local p = pipeline.new(initial_value)
    for _, operation in ipairs(operations) do
      table.insert(p.operations, operation)
    end
    return p
  end
end

-- Compose multiple functions into a single function
-- @param ... function Functions to compose (right to left)
-- @return function Composed function
function pipeline.compose(...)
  local functions = {...}
  return function(value)
    local result = value
    for i = #functions, 1, -1 do
      result = functions[i](result)
    end
    return result
  end
end

-- Pipe value through multiple functions (left to right)
-- @param value any Initial value
-- @param ... function Functions to pipe through
-- @return any Final result
function pipeline.pipe(value, ...)
  local functions = {...}
  local result = value
  for _, func in ipairs(functions) do
    result = func(result)
  end
  return result
end

-- Create a parallel pipeline that processes multiple values
-- @param values table Array of initial values
-- @return table Parallel pipeline object
function pipeline.parallel(values)
  local instance = {
    values = values or {},
    operations = {}
  }
  
  -- Add methods for parallel processing
  function instance:map(map_func)
    table.insert(self.operations, function(vals)
      return fun.map_table(function(val)
        return pipeline.new(val):map(map_func):execute()
      end, vals)
    end)
    return self
  end
  
  function instance:filter(filter_func)
    table.insert(self.operations, function(vals)
      return fun.filter_table(function(val)
        return pipeline.new(val):filter(filter_func):execute()
      end, vals)
    end)
    return self
  end
  
  function instance:execute()
    local result = self.values
    for _, operation in ipairs(self.operations) do
      result = operation(result)
    end
    return result
  end
  
  return instance
end

-- Utility functions for common pipeline operations

-- Create a pipeline for data processing
-- @param data table Initial data
-- @return table Pipeline object
function pipeline.for_data(data)
  return pipeline.new(data)
end

-- Create a pipeline for array processing
-- @param array table Initial array
-- @return table Pipeline object  
function pipeline.for_array(array)
  return pipeline.new(array)
end

-- Create a pipeline for object processing
-- @param object table Initial object
-- @return table Pipeline object
function pipeline.for_object(object)
  return pipeline.new(object)
end

-- Common pipeline templates

-- Data cleaning pipeline template
pipeline.data_cleaning = pipeline.create_template({
  function(data) return fun.filter_table(function(item) return item ~= nil end, data) end,
  function(data) return fun.map_table(function(item) return type(item) == "string" and item:gsub("^%s+", ""):gsub("%s+$", "") or item end, data) end
})

-- Data validation pipeline template
pipeline.data_validation = function(validator_func)
  return pipeline.create_template({
    function(data) 
      local valid, invalid = fun.partition_table(validator_func, data)
      return {valid = valid, invalid = invalid}
    end
  })
end

-- Data transformation pipeline template
pipeline.data_transformation = function(transformers)
  return pipeline.create_template({
    function(data)
      local result = data
      for _, transformer in ipairs(transformers) do
        result = fun.map_table(transformer, result)
      end
      return result
    end
  })
end

return pipeline
