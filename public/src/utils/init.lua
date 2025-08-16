-- src/utils/init.lua
-- Utility functions module for Church Management System (no globals)

-- Load table utilities
local table_utils = require("src.utils.table_utils")

-- Local helper: get table keys
local function get_table_keys(tbl)
    if type(tbl) ~= "table" then
        return {}
    end

    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

-- Local helper: get table values
local function get_table_values(tbl)
    return table_utils.get_table_values(tbl)
end

local function is_table_empty(tbl)
    return table_utils.is_empty(tbl)
end

local function get_table_size(tbl)
    return table_utils.table_size(tbl)
end

-- Return the module for explicit require usage
return {
    get_table_keys = get_table_keys,
    get_table_values = get_table_values,
    is_table_empty = is_table_empty,
    get_table_size = get_table_size
}
