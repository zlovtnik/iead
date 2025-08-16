-- src/utils/table_utils.lua
-- Table utility functions for Church Management System

local table_utils = {}

-- Get all keys from a table
function table_utils.get_table_keys(tbl)
    if type(tbl) ~= "table" then
        return {}
    end

    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

-- (Removed) legacy global compatibility to avoid global pollution

-- Get all values from a table
function table_utils.get_table_values(tbl)
    if type(tbl) ~= "table" then
        return {}
    end

    local values = {}
    for _, value in pairs(tbl) do
        table.insert(values, value)
    end
    return values
end

-- Check if table is empty
function table_utils.is_empty(tbl)
    if type(tbl) ~= "table" then
        return true
    end
    return next(tbl) == nil
end

-- Get table size/length
function table_utils.table_size(tbl)
    if type(tbl) ~= "table" then
-- Merge two tables
function table_utils.merge_tables(t1, t2)
    local result = {}

    -- Normalize inputs
    if type(t1) ~= "table" then t1 = {} end
    if type(t2) ~= "table" then t2 = {} end

    -- Copy t1
    for k, v in pairs(t1) do
        result[k] = v
    end

    -- Copy t2 (overwriting any duplicate keys)
    for k, v in pairs(t2) do
        result[k] = v
    end

    return result
end
    end

    -- Copy t2 (overwriting any duplicate keys)
    for k, v in pairs(t2) do
        result[k] = v
    end

    return result
end

-- Deep copy with cycle detection and metatable preservation
local function deep_copy_internal(orig, visited)
    if type(orig) ~= 'table' then
        return orig
    end

    if visited[orig] then
        return visited[orig]
    end

    local copy = {}
    visited[orig] = copy

    for orig_key, orig_value in next, orig, nil do
        local new_key = deep_copy_internal(orig_key, visited)
        local new_value = deep_copy_internal(orig_value, visited)
        copy[new_key] = new_value
    end

    -- Preserve original metatable reference (do not deep-copy metatables)
    local mt = getmetatable(orig)
    if mt ~= nil then
        setmetatable(copy, mt)
    end

    return copy
end

function table_utils.deep_copy(orig)
    return deep_copy_internal(orig, {})
end

return table_utils
