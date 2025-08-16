-- src/utils/functional.lua
-- Functional programming utilities for Lua using luafun
-- This module serves as the main functional programming interface

-- Import luafun adapter
local luafun_adapter = require("src.utils.luafun_adapter")

-- Re-export all luafun_adapter functions
local functional = {}

-- Core functional operations
functional.each = luafun_adapter.each
functional.map = luafun_adapter.map
functional.filter = luafun_adapter.filter
functional.reduce = luafun_adapter.reduce
functional.range = luafun_adapter.range
functional.zip = luafun_adapter.zip
functional.chain = luafun_adapter.chain
functional.take = luafun_adapter.take
functional.drop = luafun_adapter.drop
functional.head = luafun_adapter.head
functional.tail = luafun_adapter.tail
functional.reverse = luafun_adapter.reverse
functional.duplicate = luafun_adapter.duplicate
functional.enumerate = luafun_adapter.enumerate
functional.partition = luafun_adapter.partition
functional.group_by = luafun_adapter.group_by
functional.length = luafun_adapter.length
functional.all = luafun_adapter.all
functional.any = luafun_adapter.any
functional.min = luafun_adapter.min
functional.max = luafun_adapter.max
functional.sum = luafun_adapter.sum

-- Table-specific operations
functional.map_table = luafun_adapter.map_table
functional.filter_table = luafun_adapter.filter_table
functional.reduce_table = luafun_adapter.reduce_table
functional.pluck = luafun_adapter.pluck
functional.unique = luafun_adapter.unique
functional.from_pairs = luafun_adapter.from_pairs
functional.from_table = luafun_adapter.from_table
functional.average = luafun_adapter.average
functional.omit_keys = luafun_adapter.omit_keys
functional.group_by_func = luafun_adapter.group_by_func

-- Advanced functional operations
functional.compose = luafun_adapter.compose
functional.pipe = luafun_adapter.pipe
functional.curry = luafun_adapter.curry
functional.maybe = luafun_adapter.maybe

return functional
  local result = {}
  if type(tbl) == "table" then
    for i, v in ipairs(tbl) do
      result[i] = func(v)
    end
  end
  return result
end

-- Map function for key-value pairs
-- @param func function The mapping function (receives key, value)
-- @param tbl table The table to map over
-- @return table The mapped table
function functional.map_pairs(func, tbl)
  local result = {}
  if type(tbl) == "table" then
    for k, v in pairs(tbl) do
      local new_k, new_v = func(k, v)
      result[new_k or k] = new_v
    end
  end
  return result
end

-- Filter function that works with tables directly
-- @param predicate function The filter predicate
-- @param tbl table The table to filter
-- @return table The filtered table
function functional.filter_table(predicate, tbl)
  local result = {}
  if type(tbl) == "table" then
    for _, v in ipairs(tbl) do
      if predicate(v) then
        table.insert(result, v)
      end
    end
  end
  return result
end

-- Reduce function that works with tables directly
-- @param func function The reduce function
-- @param initial any The initial value
-- @param tbl table The table to reduce
-- @return any The reduced value
function functional.reduce_table(func, initial, tbl)
  local accumulator = initial
  if type(tbl) == "table" then
    for _, v in ipairs(tbl) do
      accumulator = func(accumulator, v)
    end
  end
  return accumulator
end

-- Find first element matching predicate
-- @param predicate function The predicate function
-- @param tbl table The table to search
-- @return any The first matching element or nil
function functional.find(predicate, tbl)
  if type(tbl) == "table" then
    for _, v in ipairs(tbl) do
      if predicate(v) then
        return v
      end
    end
  end
  return nil
end

-- Check if all elements match predicate
-- @param predicate function The predicate function
-- @param tbl table The table to check
-- @return boolean True if all elements match
function functional.all_match(predicate, tbl)
  if type(tbl) == "table" then
    for _, v in ipairs(tbl) do
      if not predicate(v) then
        return false
      end
    end
  end
  return true
end

-- Check if any element matches predicate
-- @param predicate function The predicate function
-- @param tbl table The table to check
-- @return boolean True if any element matches
function functional.any_match(predicate, tbl)
  if type(tbl) == "table" then
    for _, v in ipairs(tbl) do
      if predicate(v) then
        return true
      end
    end
  end
  return false
end

-- Group elements by key function
-- @param key_func function Function to generate grouping key
-- @param tbl table The table to group
-- @return table Table with keys as groups and values as arrays
function functional.group_by(key_func, tbl)
  local groups = {}
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      local key = key_func(item)
      if not groups[key] then
        groups[key] = {}
      end
      table.insert(groups[key], item)
    end
  end
  return groups
end

-- Partition elements into two tables based on predicate
-- @param predicate function The predicate function
-- @param tbl table The table to partition
-- @return table, table Two tables: matching elements, non-matching elements
function functional.partition_table(predicate, tbl)
  local matches = {}
  local non_matches = {}
  
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      if predicate(item) then
        table.insert(matches, item)
      else
        table.insert(non_matches, item)
      end
    end
  end
  
  return matches, non_matches
end

-- Sort table elements using a comparison function
-- @param compare_func function Comparison function (optional)
-- @param tbl table The table to sort
-- @return table The sorted table
function functional.sort_by(compare_func, tbl)
  local sorted_table = {}
  if type(tbl) == "table" then
    for i, v in ipairs(tbl) do
      sorted_table[i] = v
    end
    if compare_func then
      table.sort(sorted_table, compare_func)
    else
      table.sort(sorted_table)
    end
  end
  return sorted_table
end

-- Unique elements in table
-- @param tbl table The table to get unique elements from
-- @return table Table with unique elements
function functional.unique(tbl)
  local seen = {}
  local result = {}
  
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      if not seen[item] then
        seen[item] = true
        table.insert(result, item)
      end
    end
  end
  
  return result
end

-- Flatten nested tables one level deep
-- @param tbl table The table to flatten
-- @return table The flattened table
function functional.flatten(tbl)
  local result = {}
  
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      if type(item) == "table" then
        for _, sub_item in ipairs(item) do
          table.insert(result, sub_item)
        end
      else
        table.insert(result, item)
      end
    end
  end
  
  return result
end

-- Pluck values from table of objects by key
-- @param key string The key to pluck
-- @param tbl table The table of objects
-- @return table Array of plucked values
function functional.pluck(key, tbl)
  local result = {}
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      if type(item) == "table" and item[key] ~= nil then
        table.insert(result, item[key])
      end
    end
  end
  return result
end

-- Omit keys from objects in table
-- @param keys table Array of keys to omit
-- @param tbl table The table of objects
-- @return table Array of objects with keys omitted
function functional.omit_keys(keys, tbl)
  local key_set = {}
  for _, key in ipairs(keys) do
    key_set[key] = true
  end
  
  local result = {}
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      if type(item) == "table" then
        local new_item = {}
        for k, v in pairs(item) do
          if not key_set[k] then
            new_item[k] = v
          end
        end
        table.insert(result, new_item)
      else
        table.insert(result, item)
      end
    end
  end
  return result
end

-- Pick only specified keys from objects in table
-- @param keys table Array of keys to pick
-- @param tbl table The table of objects
-- @return table Array of objects with only picked keys
function functional.pick_keys(keys, tbl)
  local key_set = {}
  for _, key in ipairs(keys) do
    key_set[key] = true
  end
  
  local result = {}
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      if type(item) == "table" then
        local new_item = {}
        for k, v in pairs(item) do
          if key_set[k] then
            new_item[k] = v
          end
        end
        table.insert(result, new_item)
      else
        table.insert(result, item)
      end
    end
  end
  return result
end

-- Count elements matching predicate
-- @param predicate function The predicate function
-- @param tbl table The table to count
-- @return number The count of matching elements
function functional.count_where(predicate, tbl)
  local count = 0
  if type(tbl) == "table" then
    for _, item in ipairs(tbl) do
      if predicate(item) then
        count = count + 1
      end
    end
  end
  return count
end

-- Sum numeric values in table
-- @param tbl table The table of numbers
-- @return number The sum
function functional.sum(tbl)
  local total = 0
  if type(tbl) == "table" then
    for _, v in ipairs(tbl) do
      if type(v) == "number" then
        total = total + v
      end
    end
  end
  return total
end

-- Get average of numeric values in table
-- @param tbl table The table of numbers
-- @return number The average
function functional.average(tbl)
  if type(tbl) ~= "table" or #tbl == 0 then
    return 0
  end
  
  local sum = functional.sum(tbl)
  local count = #tbl
  return count > 0 and sum / count or 0
end

-- Get minimum value in table
-- @param tbl table The table of comparable values
-- @return any The minimum value
function functional.min(tbl)
  if type(tbl) ~= "table" or #tbl == 0 then
    return nil
  end
  
  local min_val = tbl[1]
  for i = 2, #tbl do
    if tbl[i] < min_val then
      min_val = tbl[i]
    end
  end
  return min_val
end

-- Get maximum value in table
-- @param tbl table The table of comparable values
-- @return any The maximum value
function functional.max(tbl)
  if type(tbl) ~= "table" or #tbl == 0 then
    return nil
  end
  
  local max_val = tbl[1]
  for i = 2, #tbl do
    if tbl[i] > max_val then
      max_val = tbl[i]
    end
  end
  return max_val
end

-- Take first n elements from table
-- @param n number Number of elements to take
-- @param tbl table The table to take from
-- @return table First n elements
function functional.take(n, tbl)
  local result = {}
  if type(tbl) == "table" then
    for i = 1, math.min(n, #tbl) do
      result[i] = tbl[i]
    end
  end
  return result
end

-- Drop first n elements from table
-- @param n number Number of elements to drop
-- @param tbl table The table to drop from
-- @return table Remaining elements
function functional.drop(n, tbl)
  local result = {}
  if type(tbl) == "table" then
    for i = n + 1, #tbl do
      table.insert(result, tbl[i])
    end
  end
  return result
end

-- Convert pairs iterator to array
-- @param tbl table The table to convert
-- @return table Array of {key, value} pairs
function functional.from_pairs(tbl)
  local result = {}
  if type(tbl) == "table" then
    for k, v in pairs(tbl) do
      table.insert(result, {k, v})
    end
  end
  return result
end

-- Helper alias functions for common operations
functional.map = functional.map_table
functional.filter = functional.filter_table
functional.reduce = functional.reduce_table
functional.each = function(func, tbl)
  if type(tbl) == "table" then
    for _, v in ipairs(tbl) do
      func(v)
    end
  end
end

return functional
