-- src/utils/init.lua
-- Utility functions module for Church Management System (no globals)

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
    if type(tbl) ~= "table" then
        return {}
    end

    local values = {}
    for _, value in pairs(tbl) do
        table.insert(values, value)
    end
    return values
end

local function is_table_empty(tbl)
    if type(tbl) ~= "table" then
        return true
    end
    
    for _ in pairs(tbl) do
        return false
    end
    return true
end

local function get_table_size(tbl)
    if type(tbl) ~= "table" then
        return 0
    end
    
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Return the module for explicit require usage
return {
    get_table_keys = get_table_keys,
    get_table_values = get_table_values,
    is_table_empty = is_table_empty,
    get_table_size = get_table_size
}
