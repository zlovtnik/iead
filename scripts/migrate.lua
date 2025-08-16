#!/usr/bin/env lua

-- Database Migration System for Church Management
-- Handles schema updates and data migrations between versions

local sqlite3 = require("luasql.sqlite3")
local json = require("cjson")
-- Safe require for LuaFileSystem (lfs)
local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
    io.stderr:write("Error: LuaFileSystem (lfs) is not installed or not found.\n")
    io.stderr:write("Install it with LuaRocks:\n  luarocks install luafilesystem\n\n")
    io.stderr:write("macOS (Homebrew):\n  brew install luarocks && luarocks install luafilesystem\n\n")
    io.stderr:write("Debian/Ubuntu:\n  sudo apt-get update && sudo apt-get install -y luarocks && sudo luarocks install luafilesystem\n")
    os.exit(1)
end

local DatabaseMigrator = {}
DatabaseMigrator.__index = DatabaseMigrator

function DatabaseMigrator:new(db_path)
    local instance = {
        db_path = db_path or "church_management.db",
        env = sqlite3.sqlite3(),
        conn = nil,
        migrations_dir = "src/db/migrations",
        current_version = 0
    }
    setmetatable(instance, self)
    return instance
end

-- Connect to database
function DatabaseMigrator:connect()
    self.conn = self.env:connect(self.db_path)
    if not self.conn then
        error("Failed to connect to database: " .. self.db_path)
    end
    
    -- Create migrations table if it doesn't exist
    local create_migrations_table = [[
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            checksum TEXT NOT NULL
        );
    ]]
    
    local result = self.conn:execute(create_migrations_table)
    if not result then
        error("Failed to create migrations table")
    end
    
    -- Get current schema version
    self.current_version = self:get_current_version()
    print("Current database version: " .. self.current_version)
end

-- Get current schema version
function DatabaseMigrator:get_current_version()
    local cursor = self.conn:execute("SELECT MAX(version) FROM schema_migrations")
    if cursor then
        local version = cursor:fetch()
        cursor:close()
        return tonumber(version) or 0
    end
    return 0
end

-- Calculate checksum for migration content
function DatabaseMigrator:calculate_checksum(content)
    -- Simple checksum calculation (in production, use a proper hash)
    local sum = 0
    for i = 1, #content do
        sum = sum + string.byte(content, i)
    end
    return tostring(sum)
end

-- Load migration files
function DatabaseMigrator:load_migrations()
    local migrations = {}
    
    -- Create migrations directory if it doesn't exist
    if not lfs.attributes(self.migrations_dir) then
        lfs.mkdir(self.migrations_dir)
        print("Created migrations directory: " .. self.migrations_dir)
    end
    
    for file in lfs.dir(self.migrations_dir) do
        if file:match("^%d+_.*%.lua$") then
            local version = tonumber(file:match("^(%d+)_"))
            if version then
                local filepath = self.migrations_dir .. "/" .. file
                local f = io.open(filepath, "r")
                if f then
                    local content = f:read("*all")
                    f:close()
                    
                    migrations[version] = {
                        version = version,
                        filename = file,
                        filepath = filepath,
                        description = file:match("^%d+_(.*)%.lua$"):gsub("_", " "),
                        content = content,
                        checksum = self:calculate_checksum(content)
                    }
                end
            end
        end
    end
    
    return migrations
end

-- Execute a single migration
function DatabaseMigrator:execute_migration(migration)
    print("Applying migration " .. migration.version .. ": " .. migration.description)
    
    -- Begin transaction
    self.conn:execute("BEGIN TRANSACTION")
    
    -- Load and execute the migration
    -- Safer migration execution
    local safe_env = {
        conn = self.conn,
        execute = function(sql) return self.conn:execute(sql) end,
        query = function(sql)
            local cursor = self.conn:execute(sql)
            local rows = {}
            if cursor then
                local row = cursor:fetch({}, "a")
                while row do
                    table.insert(rows, row)
                    row = cursor:fetch({}, "a")
                end
                cursor:close()
            end
            return rows
        end,
        print = print,
        tonumber = tonumber,
        tostring = tostring,
        pairs = pairs,
        ipairs = ipairs,
        table = { insert = table.insert, remove = table.remove, sort = table.sort },
        string = { match = string.match, gsub = string.gsub, find = string.find, format = string.format, lower = string.lower, upper = string.upper },
        math = { abs = math.abs, floor = math.floor, ceil = math.ceil, min = math.min, max = math.max },
    }
    -- Remove dangerous globals
    local chunk, err = load(migration.content, "migration", "t", safe_env)
    if not chunk then
        self.conn:execute("ROLLBACK")
        print("[migrate] Migration load error: " .. tostring(err))
        error("Failed to load migration " .. migration.version .. ": " .. err)
    end
    local success, exec_err = pcall(chunk)
    if not success then
        self.conn:execute("ROLLBACK")
        print("[migrate] Migration execution error: " .. tostring(exec_err))
        error("Migration " .. migration.version .. " failed: " .. tostring(exec_err))
    end

    
    -- Record migration
    local stmt = self.conn:prepare(
        "INSERT INTO schema_migrations (version, description, checksum) VALUES (?, ?, ?)"
    )
    if not stmt then
        self.conn:execute("ROLLBACK")
        error("Failed to prepare migration insert statement")
    end
    local result = stmt:execute(migration.version, migration.description, migration.checksum)
    stmt:close()
    if not result then
        self.conn:execute("ROLLBACK")
        error("Failed to record migration " .. migration.version)
    end
    
    -- Commit transaction
    self.conn:execute("COMMIT")
    print("Migration " .. migration.version .. " applied successfully")
end

-- Run pending migrations
function DatabaseMigrator:migrate()
    local migrations = self:load_migrations()
    
    -- Sort migrations by version
    local sorted_versions = {}
    for version in pairs(migrations) do
        table.insert(sorted_versions, version)
    end
    table.sort(sorted_versions)
    
    local applied_count = 0
    
    for _, version in ipairs(sorted_versions) do
        if version > self.current_version then
            self:execute_migration(migrations[version])
            applied_count = applied_count + 1
        end
    end
    
    if applied_count == 0 then
        print("Database is up to date (version " .. self.current_version .. ")")
    else
        print("Applied " .. applied_count .. " migration(s)")
        self.current_version = self:get_current_version()
        print("Database updated to version " .. self.current_version)
    end
end

-- Create a new migration file
function DatabaseMigrator:create_migration(description)
    if not description or description == "" then
        error("Migration description is required")
    end
    
    local next_version = self:get_current_version() + 1
    local filename = string.format("%04d_%s.lua", next_version, description:gsub("%s+", "_"):lower())
    local filepath = self.migrations_dir .. "/" .. filename
    
    local template = string.format([=[
-- Migration %d: %s
-- Created: %s

-- Add your migration code here
-- Use the provided functions: execute(sql), query(sql), print(message)

-- Example:
-- execute([[
--     ALTER TABLE members ADD COLUMN phone_verified BOOLEAN DEFAULT 0;
-- ]])

-- print("Added phone_verified column to members table")

-- Remember to test your migration thoroughly before applying to production!
]=], next_version, description, os.date("%Y-%m-%d %H:%M:%S"))
    
    local f = io.open(filepath, "w")
    if not f then
        error("Failed to create migration file: " .. filepath)
    end
    
    f:write(template)
    f:close()
    
    print("Created migration file: " .. filepath)
    print("Edit the file to add your migration code, then run migrate() to apply it")
    
    return filepath
end

-- Rollback to a specific version
function DatabaseMigrator:rollback(target_version)
    target_version = target_version or (self.current_version - 1)
    
    if target_version >= self.current_version then
        print("Cannot rollback to version " .. target_version .. " (current: " .. self.current_version .. ")")
        return
    end

    -- Warn that schema changes aren’t actually reversed
    print("WARNING: This rollback only removes migration records.")
    print("It does NOT undo the actual database schema changes!")
    print("You must manually reverse the database changes or restore from backup.")
    print()

    -- Get migrations to rollback (in reverse order)
    local cursor = self.conn:execute(string.format([[
        SELECT version, description FROM schema_migrations 
        WHERE version > %d ORDER BY version DESC
    ]], target_version))

    local migrations_to_rollback = {}
    if cursor then
        local row = cursor:fetch({}, "a")
        while row do
            table.insert(migrations_to_rollback, {
                version = tonumber(row.version),
                description = row.description
            })
            row = cursor:fetch({}, "a")
        end
        cursor:close()
    end
    
    -- Confirm rollback
    print("WARNING: Rolling back from version " .. self.current_version .. " to " .. target_version)
    print("This will undo the following migrations:")
    for _, migration in ipairs(migrations_to_rollback) do
        print("  - " .. migration.version .. ": " .. migration.description)
    end
    
    print("THIS OPERATION CANNOT BE UNDONE!")
    print("Type 'YES' to confirm rollback:")
    local confirmation = io.read()
    
    if confirmation ~= "YES" then
        print("Rollback cancelled")
        return
    end
    
    -- Perform rollback
    self.conn:execute("BEGIN TRANSACTION")
    
    for _, migration in ipairs(migrations_to_rollback) do
        print("Rolling back migration " .. migration.version .. ": " .. migration.description)
        
        -- Remove migration record
        local delete_sql = string.format("DELETE FROM schema_migrations WHERE version = %d", migration.version)
        local result = self.conn:execute(delete_sql)
        
        if not result then
            self.conn:execute("ROLLBACK")
            error("Failed to rollback migration " .. migration.version)
        end
    end
    
    self.conn:execute("COMMIT")
    self.current_version = self:get_current_version()
    print("Rollback completed. Database is now at version " .. self.current_version)
end

-- Show migration status
function DatabaseMigrator:status()
    local migrations = self:load_migrations()
    
    print("Migration Status:")
    print("Current version: " .. self.current_version)
    print()
    
    -- Sort migrations by version
    local sorted_versions = {}
    for version in pairs(migrations) do
        table.insert(sorted_versions, version)
    end
    table.sort(sorted_versions)
    
    for _, version in ipairs(sorted_versions) do
        local migration = migrations[version]
        local status = version <= self.current_version and "APPLIED" or "PENDING"
        local marker = version <= self.current_version and "✓" or "○"
        
        print(string.format("  %s %04d: %s [%s]", marker, version, migration.description, status))
    end
    
    local pending_count = 0
    for version in pairs(migrations) do
        if version > self.current_version then
            pending_count = pending_count + 1
        end
    end
    
    if pending_count > 0 then
        print()
        print("Run migrate() to apply " .. pending_count .. " pending migration(s)")
    end
end

-- Close database connection
function DatabaseMigrator:close()
    if self.conn then
        self.conn:close()
    end
    if self.env then
        self.env:close()
    end
end

-- Command line interface
local function main()
    local migrator = DatabaseMigrator:new()
    migrator:connect()
    
    local command = arg and arg[1] or "status"
    
    if command == "migrate" then
        migrator:migrate()
    elseif command == "status" then
        migrator:status()
    elseif command == "create" then
        local description = arg[2]
        if not description then
            print("Usage: lua migrate.lua create <description>")
            os.exit(1)
        end
        migrator:create_migration(description)
    elseif command == "rollback" then
        local target_version = arg[2] and tonumber(arg[2])
        migrator:rollback(target_version)
    else
        print("Usage: lua migrate.lua [migrate|status|create|rollback]")
        print("  migrate              - Apply pending migrations")
        print("  status               - Show migration status")
        print("  create <description> - Create new migration")
        print("  rollback [version]   - Rollback to version (default: previous)")
    end
    
    migrator:close()
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("migrate%.lua$") then
    main()
end

return DatabaseMigrator
