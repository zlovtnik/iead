-- src/infrastructure/db/connection.lua
-- Database connection and query utilities with prepared statement support

local luasql = require("luasql.sqlite3")
local log = require("src.utils.log")

local db = {}

-- Database configuration
local DB_CONFIG = {
    path = os.getenv("DB_PATH") or "church_management.db",
    timeout = tonumber(os.getenv("DB_TIMEOUT")) or 30,
    journal_mode = os.getenv("DB_JOURNAL_MODE") or "WAL",
    synchronous = os.getenv("DB_SYNCHRONOUS") or "NORMAL",
    foreign_keys = true
}

-- Connection pool (simple implementation)
local connection_pool = {
    connections = {},
    max_connections = tonumber(os.getenv("DB_MAX_CONNECTIONS")) or 10,
    current_connections = 0
}

-- Initialize database environment
local env = luasql.sqlite3()

-- Get database connection from pool or create new one
-- @return connection, error
function db.get_connection()
    -- Try to get connection from pool
    if #connection_pool.connections > 0 then
        local conn = table.remove(connection_pool.connections)
        -- Test connection
        local success, err = pcall(function()
            conn:execute("SELECT 1")
        end)
        if success then
            return conn, nil
        end
        -- Connection is stale, create new one
        connection_pool.current_connections = connection_pool.current_connections - 1
    end

    -- Create new connection if under limit
    if connection_pool.current_connections < connection_pool.max_connections then
        local conn, err = env:connect(DB_CONFIG.path)
        if not conn then
            return nil, "Failed to connect to database: " .. (err or "unknown error")
        end

        -- Configure connection
        conn:execute("PRAGMA journal_mode = " .. DB_CONFIG.journal_mode)
        conn:execute("PRAGMA synchronous = " .. DB_CONFIG.synchronous)
        if DB_CONFIG.foreign_keys then
            conn:execute("PRAGMA foreign_keys = ON")
        end
        
        connection_pool.current_connections = connection_pool.current_connections + 1
        return conn, nil
    end

    return nil, "Maximum connection limit reached"
end

-- Return connection to pool
-- @param conn table Database connection
function db.release_connection(conn)
    if not conn then return end
    
    if #connection_pool.connections < connection_pool.max_connections then
        table.insert(connection_pool.connections, conn)
    else
        conn:close()
        connection_pool.current_connections = connection_pool.current_connections - 1
    end
end

-- Close all connections in pool
function db.close_all_connections()
    for _, conn in ipairs(connection_pool.connections) do
        conn:close()
    end
    connection_pool.connections = {}
    connection_pool.current_connections = 0
end

-- Escape SQL string value for safe interpolation
-- Note: This is a fallback for cases where prepared statements can't be used
-- @param value string The value to escape
-- @return string The escaped value
function db.escape_string(value)
    if value == nil then
        return "NULL"
    end
    if type(value) == "string" then
        return "'" .. value:gsub("'", "''") .. "'"
    end
    return tostring(value)
end

-- Execute a parameterized query safely
-- @param query string SQL query with ? placeholders
-- @param params table Array of parameters to bind
-- @return cursor, error
function db.execute_prepared(query, params)
    local conn, err = db.get_connection()
    if not conn then
        return nil, err
    end

    -- Simple parameter substitution for SQLite
    -- Note: Real prepared statements would be better, but luasql.sqlite3 has limited support
    local safe_query = query
    if params then
        for i, param in ipairs(params) do
            local safe_param
            if param == nil then
                safe_param = "NULL"
            elseif type(param) == "string" then
                safe_param = "'" .. param:gsub("'", "''") .. "'"
            elseif type(param) == "number" then
                safe_param = tostring(param)
            elseif type(param) == "boolean" then
                safe_param = param and "1" or "0"
            else
                safe_param = "'" .. tostring(param):gsub("'", "''") .. "'"
            end
            
            -- Replace first occurrence of ? with the parameter
            safe_query = safe_query:gsub("%?", safe_param, 1)
        end
    end

    local success, result = pcall(function()
        return conn:execute(safe_query)
    end)

    if not success then
        db.release_connection(conn)
        return nil, result
    end

    -- Check if result is a cursor (SELECT query) or just affected rows count
    if type(result) == "userdata" then
        -- For SELECT queries, return cursor and connection separately
        -- We'll handle connection cleanup in the calling functions
        return result, nil, conn
    else
        -- For non-SELECT queries, release connection immediately
        db.release_connection(conn)
        return result, nil
    end
end

-- Execute query and fetch all results
-- @param query string SQL query with ? placeholders
-- @param params table Array of parameters to bind
-- @return rows, error
function db.query_all(query, params)
    local cursor, err, conn = db.execute_prepared(query, params)
    if not cursor then
        return nil, err
    end
    
    -- Handle case where cursor is actually affected rows count (for non-SELECT queries)
    if type(cursor) ~= "userdata" then
        return {}, nil
    end

    local rows = {}
    local row = cursor:fetch({}, "a")
    while row do
        table.insert(rows, row)
        row = cursor:fetch({}, "a")
    end

    cursor:close()
    if conn then
        db.release_connection(conn)
    end

    return rows, nil
end

-- Execute query and fetch first result
-- @param query string SQL query with ? placeholders
-- @param params table Array of parameters to bind
-- @return row, error
function db.query_one(query, params)
    local cursor, err, conn = db.execute_prepared(query, params)
    if not cursor then
        return nil, err
    end
    
    -- Handle case where cursor is actually affected rows count (for non-SELECT queries)
    if type(cursor) ~= "userdata" then
        return nil, nil
    end

    -- Debug: Check if cursor has the fetch method
    if not cursor.fetch then
        if conn then
            db.release_connection(conn)
        end
        return nil, "Cursor does not have fetch method. Type: " .. type(cursor) .. ", Metatable: " .. tostring(getmetatable(cursor))
    end

    local row = cursor:fetch({}, "a")
    cursor:close()
    if conn then
        db.release_connection(conn)
    end

    return row, nil
end

-- Execute non-query statement (INSERT, UPDATE, DELETE)
-- @param query string SQL query with ? placeholders
-- @param params table Array of parameters to bind
-- @return affected_rows, error
function db.execute(query, params)
    local conn, err = db.get_connection()
    if not conn then
        return nil, err
    end

    -- Simple parameter substitution for SQLite
    local safe_query = query
    if params then
        for i, param in ipairs(params) do
            local safe_param
            if param == nil then
                safe_param = "NULL"
            elseif type(param) == "string" then
                safe_param = "'" .. param:gsub("'", "''") .. "'"
            elseif type(param) == "number" then
                safe_param = tostring(param)
            elseif type(param) == "boolean" then
                safe_param = param and "1" or "0"
            else
                safe_param = "'" .. tostring(param):gsub("'", "''") .. "'"
            end
            
            safe_query = safe_query:gsub("%?", safe_param, 1)
        end
    end

    local success, affected_rows = pcall(function()
        return conn:execute(safe_query)
    end)

    db.release_connection(conn)

    if not success then
        return nil, affected_rows
    end

    return affected_rows, nil
end

-- Execute multiple queries in a transaction
-- @param queries table Array of {query, params} objects
-- @return success, error
function db.transaction(queries)
    local conn, err = db.get_connection()
    if not conn then
        return false, err
    end

    local success, result = pcall(function()
        conn:execute("BEGIN TRANSACTION")
        
        for _, query_info in ipairs(queries) do
            local query = query_info[1] or query_info.query
            local params = query_info[2] or query_info.params
            
            local safe_query = query
            if params then
                for i, param in ipairs(params) do
                    local safe_param
                    if param == nil then
                        safe_param = "NULL"
                    elseif type(param) == "string" then
                        safe_param = "'" .. param:gsub("'", "''") .. "'"
                    elseif type(param) == "number" then
                        safe_param = tostring(param)
                    elseif type(param) == "boolean" then
                        safe_param = param and "1" or "0"
                    else
                        safe_param = "'" .. tostring(param):gsub("'", "''") .. "'"
                    end
                    
                    safe_query = safe_query:gsub("%?", safe_param, 1)
                end
            end
            
            conn:execute(safe_query)
        end
        
        conn:execute("COMMIT")
        return true
    end)

    if not success then
        pcall(function() conn:execute("ROLLBACK") end)
        db.release_connection(conn)
        return false, result
    end

    db.release_connection(conn)
    return true, nil
end

-- Get last insert ID
-- @return id, error
function db.last_insert_id()
    local conn, err = db.get_connection()
    if not conn then
        return nil, err
    end

    local cursor = conn:execute("SELECT last_insert_rowid()")
    local row = cursor:fetch()
    cursor:close()
    db.release_connection(conn)

    return tonumber(row), nil
end

return db
