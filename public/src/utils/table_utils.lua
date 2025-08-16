-- src/utils/table_utils.lua
-- Table utility functions for Church Management System

local table_utils = {}

-- Get all keys from a table
function get_table_keys(tbl)
    if type(tbl) ~= "table" then
        return {}
    end

    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

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
    return next(tbl) == nil
end

-- Get table size/length
function table_utils.table_size(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Merge two tables
function table_utils.merge_tables(t1, t2)
    local result = {}

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

-- Deep copy a table
function table_utils.deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table_utils.deep_copy(orig_key)] = table_utils.deep_copy(orig_value)
        end
        setmetatable(copy, table_utils.deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return table_utils
