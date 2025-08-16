-- src/utils/luafun_adapter.lua
-- Adapter module for luafun with additional utility functions
-- This module provides a bridge between luafun and our application-specific needs

local fun = require("fun")

-- Compatibility for unpack function
local unpack = unpack or table.unpack

local luafun_adapter = {}

-- Re-export core luafun functions
luafun_adapter.each = fun.each
luafun_adapter.map = fun.map
luafun_adapter.filter = fun.filter
luafun_adapter.reduce = fun.reduce
luafun_adapter.range = fun.range
luafun_adapter.zip = fun.zip
luafun_adapter.chain = fun.chain
luafun_adapter.take = fun.take
luafun_adapter.drop = fun.drop
luafun_adapter.head = fun.head
luafun_adapter.tail = fun.tail
luafun_adapter.reverse = fun.reverse
luafun_adapter.duplicate = fun.duplicate
luafun_adapter.enumerate = fun.enumerate
luafun_adapter.partition = fun.partition
luafun_adapter.group_by = fun.group_by
luafun_adapter.length = fun.length
luafun_adapter.all = fun.all
luafun_adapter.any = fun.any
luafun_adapter.min = fun.min
luafun_adapter.max = fun.max
luafun_adapter.sum = fun.sum

-- Table-specific utility functions
function luafun_adapter.map_table(func, tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    
    local result = {}
    for i, v in ipairs(tbl) do
        result[i] = func(v)
    end
    return result
end

function luafun_adapter.filter_table(predicate, tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    
    local result = {}
    for _, v in ipairs(tbl) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end

function luafun_adapter.reduce_table(func, initial, tbl)
    if type(tbl) ~= "table" then
        return initial
    end
    
    local accumulator = initial
    for _, v in ipairs(tbl) do
        accumulator = func(accumulator, v)
    end
    return accumulator
end

-- Map function for key-value pairs
function luafun_adapter.map_pairs(func, tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    
    local result = {}
    for k, v in pairs(tbl) do
        local new_k, new_v = func(k, v)
        result[new_k or k] = new_v
    end
    return result
end

-- Extract values for a specific key from a table of tables
function luafun_adapter.pluck(key, tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    
    local result = {}
    for _, item in ipairs(tbl) do
        if type(item) == "table" and item[key] ~= nil then
            table.insert(result, item[key])
        end
    end
    return result
end

-- Get unique values from a table
function luafun_adapter.unique(tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    
    local seen = {}
    local result = {}
    
    for _, v in ipairs(tbl) do
        if not seen[v] then
            seen[v] = true
            table.insert(result, v)
        end
    end
    
    return result
end

-- Create iterator from key-value pairs
function luafun_adapter.from_pairs(tbl)
    if type(tbl) ~= "table" then
        return {
            each = function() end
        }
    end
    
    return {
        each = function(self, func)
            for k, v in pairs(tbl) do
                func(k, v)
            end
        end
    }
end

-- Create iterator from array-like table
function luafun_adapter.from_table(tbl)
    if type(tbl) ~= "table" then
        return {
            each = function() end
        }
    end
    
    return {
        each = function(self, func)
            for _, v in ipairs(tbl) do
                func(v)
            end
        end
    }
end

-- Calculate average of numeric values
function luafun_adapter.average(tbl)
    if type(tbl) ~= "table" or #tbl == 0 then
        return 0
    end
    
    local sum = 0
    local count = 0
    
    for _, v in ipairs(tbl) do
        if type(v) == "number" then
            sum = sum + v
            count = count + 1
        end
    end
    
    return count > 0 and (sum / count) or 0
end

-- Remove specified keys from table
function luafun_adapter.omit_keys(keys_to_omit, tbl)
    if type(tbl) ~= "table" or type(keys_to_omit) ~= "table" then
        return tbl
    end
    
    local key_set = {}
    for _, key in ipairs(keys_to_omit) do
        key_set[key] = true
    end
    
    local result = {}
    for k, v in pairs(tbl) do
        if not key_set[k] then
            result[k] = v
        end
    end
    
    return result
end

-- Group table items by a function result
function luafun_adapter.group_by_func(group_func, tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    
    local groups = {}
    for _, item in ipairs(tbl) do
        local key = group_func(item)
        if not groups[key] then
            groups[key] = {}
        end
        table.insert(groups[key], item)
    end
    
    return groups
end

-- Apply multiple transformations to data
function luafun_adapter.compose(...)
    local functions = {...}
    return function(value)
        local result = value
        for i = #functions, 1, -1 do  -- Apply in reverse order
            result = functions[i](result)
        end
        return result
    end
end

-- Functional pipe operator
function luafun_adapter.pipe(value, ...)
    local functions = {...}
    local result = value
    for _, func in ipairs(functions) do
        result = func(result)
    end
    return result
end

-- Curry function to support partial application
function luafun_adapter.curry(func, arity)
    arity = arity or 2
    return function(...)
        local args = {...}
        if #args >= arity then
            return func(unpack(args))
        else
            return function(...)
                local new_args = {}
                for _, arg in ipairs(args) do
                    table.insert(new_args, arg)
                end
                for _, arg in ipairs({...}) do
                    table.insert(new_args, arg)
                end
                return luafun_adapter.curry(func, arity)(unpack(new_args))
            end
        end
    end
end

-- Safe nil handling for chained operations
function luafun_adapter.maybe(value)
    return {
        map = function(self, func)
            if value == nil then
                return luafun_adapter.maybe(nil)
            end
            return luafun_adapter.maybe(func(value))
        end,
        filter = function(self, predicate)
            if value == nil or not predicate(value) then
                return luafun_adapter.maybe(nil)
            end
            return luafun_adapter.maybe(value)
        end,
        get = function(self, default)
            return value ~= nil and value or default
        end
    }
end

return luafun_adapter
