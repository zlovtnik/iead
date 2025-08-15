#!/usr/bin/env lua

-- Health Check System for Church Management
-- Comprehensive system health monitoring and reporting

local json = require("cjson")
local socket = require("socket")
local http = require("socket.http")

local HealthChecker = {}
HealthChecker.__index = HealthChecker

function HealthChecker:new()
    local instance = {
        checks = {},
        results = {},
        start_time = socket.gettime()
    }
    setmetatable(instance, self)
    return instance
end

-- Add a health check
function HealthChecker:add_check(name, check_function, critical)
    self.checks[name] = {
        func = check_function,
        critical = critical or false,
        timeout = 5  -- 5 second timeout
    }
end

-- Database connectivity check
function HealthChecker:check_database()
    local success, err = pcall(function()
        local sqlite3 = require("luasql.sqlite3")
        local env = sqlite3.sqlite3()
        local conn = env:connect("church_management.db")
        
        if not conn then
            error("Cannot connect to database")
        end
        
        -- Test query
        local cursor = conn:execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'")
        if not cursor then
            error("Cannot execute test query")
        end
        
        local count = cursor:fetch()
        cursor:close()
        conn:close()
        env:close()
        
        if not count or tonumber(count) == 0 then
            error("No tables found in database")
        end
        
        return {
            status = "healthy",
            message = "Database connection successful",
            table_count = tonumber(count),
            response_time_ms = 0
        }
    end)
    
    if success then
        return err
    else
        return {
            status = "unhealthy",
            message = "Database check failed: " .. tostring(err),
            response_time_ms = 0
        }
    end
end

-- Redis connectivity check
function HealthChecker:check_redis()
    local success, result = pcall(function()
        -- Try to connect to Redis
        local redis_host = os.getenv("REDIS_HOST") or "localhost"
        local redis_port = tonumber(os.getenv("REDIS_PORT")) or 6379
        
        local sock = socket.tcp()
        sock:settimeout(5)
        
        local ok, err = sock:connect(redis_host, redis_port)
        if not ok then
            error("Cannot connect to Redis: " .. (err or "unknown error"))
        end
        
        -- Send PING command
        sock:send("PING\r\n")
        local response = sock:receive()
        sock:close()
        
        if response and response:match("PONG") then
            return {
                status = "healthy",
                message = "Redis connection successful",
                host = redis_host,
                port = redis_port,
                response_time_ms = 0
            }
        else
            error("Redis did not respond with PONG")
        end
    end)
    
    if success then
        return result
    else
        return {
            status = "unhealthy",
            message = "Redis check failed: " .. tostring(result),
            response_time_ms = 0
        }
    end
end

-- Memory usage check
function HealthChecker:check_memory()
    local success, result = pcall(function()
        -- Read memory info from /proc/meminfo
        local file = io.open("/proc/meminfo", "r")
        if not file then
            error("Cannot read memory information")
        end
        
        local mem_total, mem_free, mem_available = 0, 0, 0
        
        for line in file:lines() do
            local key, value = line:match("([^:]+):%s*(%d+)")
            if key and value then
                value = tonumber(value) * 1024  -- Convert from KB to bytes
                if key == "MemTotal" then
                    mem_total = value
                elseif key == "MemFree" then
                    mem_free = value
                elseif key == "MemAvailable" then
                    mem_available = value
                end
            end
        end
        file:close()
        
        local mem_used = mem_total - mem_available
        local mem_usage_percent = (mem_used / mem_total) * 100
        
        local status = "healthy"
        local message = "Memory usage normal"
        
        if mem_usage_percent > 90 then
            status = "critical"
            message = "Critical memory usage"
        elseif mem_usage_percent > 80 then
            status = "warning"
            message = "High memory usage"
        end
        
        return {
            status = status,
            message = message,
            memory_total_mb = math.floor(mem_total / 1024 / 1024),
            memory_used_mb = math.floor(mem_used / 1024 / 1024),
            memory_free_mb = math.floor(mem_free / 1024 / 1024),
            memory_usage_percent = math.floor(mem_usage_percent * 100) / 100,
            response_time_ms = 0
        }
    end)
    
    if success then
        return result
    else
        return {
            status = "unhealthy",
            message = "Memory check failed: " .. tostring(result),
            response_time_ms = 0
        }
    end
end

-- Disk space check
function HealthChecker:check_disk_space()
    local success, result = pcall(function()
        -- Use df command to check disk space
        local handle = io.popen("df -h / | tail -1")
        if not handle then
            error("Cannot check disk space")
        end
        
        local output = handle:read("*all")
        handle:close()
        
        -- Parse df output: Filesystem Size Used Avail Use% Mounted
        local filesystem, size, used, avail, use_percent, mounted = output:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%d+)%%%s+(%S+)")
        
        if not use_percent then
            error("Cannot parse disk space information")
        end
        
        local usage = tonumber(use_percent)
        local status = "healthy"
        local message = "Disk space normal"
        
        if usage > 95 then
            status = "critical"
            message = "Critical disk space"
        elseif usage > 85 then
            status = "warning"
            message = "Low disk space"
        end
        
        return {
            status = status,
            message = message,
            filesystem = filesystem,
            size = size,
            used = used,
            available = avail,
            usage_percent = usage,
            mounted_on = mounted,
            response_time_ms = 0
        }
    end)
    
    if success then
        return result
    else
        return {
            status = "unhealthy",
            message = "Disk check failed: " .. tostring(result),
            response_time_ms = 0
        }
    end
end

-- API endpoints check
function HealthChecker:check_api_endpoints()
    local success, result = pcall(function()
        local base_url = os.getenv("API_BASE_URL") or "http://localhost:8080"
        local endpoints = {
            "/api/health",
            "/api/members",
            "/api/events",
            "/api/auth/status"
        }
        
        local results = {}
        local all_healthy = true
        
        for _, endpoint in ipairs(endpoints) do
            local start_time = socket.gettime()
            local url = base_url .. endpoint
            
            local response, status = http.request{
                url = url,
                method = "GET",
                headers = {
                    ["Accept"] = "application/json"
                },
                timeout = 5
            }
            
            local response_time = (socket.gettime() - start_time) * 1000
            local endpoint_status = "healthy"
            local message = "OK"
            
            if not response or not status or status ~= 200 then
                endpoint_status = "unhealthy"
                message = "HTTP " .. (status or "timeout")
                all_healthy = false
            end
            
            results[endpoint] = {
                status = endpoint_status,
                message = message,
                response_time_ms = math.floor(response_time),
                http_status = status
            }
        end
        
        return {
            status = all_healthy and "healthy" or "unhealthy",
            message = all_healthy and "All endpoints healthy" or "Some endpoints unhealthy",
            endpoints = results,
            response_time_ms = 0
        }
    end)
    
    if success then
        return result
    else
        return {
            status = "unhealthy",
            message = "API endpoints check failed: " .. tostring(result),
            response_time_ms = 0
        }
    end
end

-- Run all health checks
function HealthChecker:run_all_checks()
    -- Add default checks
    self:add_check("database", function() return self:check_database() end, true)
    self:add_check("redis", function() return self:check_redis() end, false)
    self:add_check("memory", function() return self:check_memory() end, false)
    self:add_check("disk_space", function() return self:check_disk_space() end, false)
    self:add_check("api_endpoints", function() return self:check_api_endpoints() end, true)
    
    local overall_status = "healthy"
    local critical_failures = {}
    local warnings = {}
    
    for name, check in pairs(self.checks) do
        local start_time = socket.gettime()
        
        local success, result = pcall(check.func)
        
        local response_time = (socket.gettime() - start_time) * 1000
        
        if success then
            result.response_time_ms = math.floor(response_time)
            self.results[name] = result
            
            if result.status == "unhealthy" or result.status == "critical" then
                if check.critical then
                    overall_status = "unhealthy"
                    table.insert(critical_failures, name)
                else
                    table.insert(warnings, name)
                end
            end
        else
            self.results[name] = {
                status = "unhealthy",
                message = "Check failed: " .. tostring(result),
                response_time_ms = math.floor(response_time)
            }
            
            if check.critical then
                overall_status = "unhealthy"
                table.insert(critical_failures, name)
            else
                table.insert(warnings, name)
            end
        end
    end
    
    -- Calculate uptime
    local uptime_seconds = socket.gettime() - self.start_time
    
    -- Build overall response
    local health_response = {
        status = overall_status,
        timestamp = os.date("%Y-%m-%dT%H:%M:%SZ"),
        uptime_seconds = math.floor(uptime_seconds),
        version = os.getenv("APP_VERSION") or "1.0.0",
        environment = os.getenv("NODE_ENV") or "development",
        checks = self.results,
        summary = {
            total_checks = 0,
            healthy_checks = 0,
            unhealthy_checks = 0,
            critical_failures = critical_failures,
            warnings = warnings
        }
    }
    
    -- Calculate summary
    for name, result in pairs(self.results) do
        health_response.summary.total_checks = health_response.summary.total_checks + 1
        if result.status == "healthy" then
            health_response.summary.healthy_checks = health_response.summary.healthy_checks + 1
        else
            health_response.summary.unhealthy_checks = health_response.summary.unhealthy_checks + 1
        end
    end
    
    return health_response
end

-- Generate detailed health report
function HealthChecker:generate_report()
    local health_data = self:run_all_checks()
    
    print("=" .. string.rep("=", 60))
    print("           CHURCH MANAGEMENT SYSTEM HEALTH REPORT")
    print("=" .. string.rep("=", 60))
    print("Status: " .. string.upper(health_data.status))
    print("Timestamp: " .. health_data.timestamp)
    print("Uptime: " .. math.floor(health_data.uptime_seconds / 3600) .. "h " .. 
          math.floor((health_data.uptime_seconds % 3600) / 60) .. "m " .. 
          (health_data.uptime_seconds % 60) .. "s")
    print("Version: " .. health_data.version)
    print("Environment: " .. health_data.environment)
    print()
    
    print("SUMMARY:")
    print("  Total Checks: " .. health_data.summary.total_checks)
    print("  Healthy: " .. health_data.summary.healthy_checks)
    print("  Unhealthy: " .. health_data.summary.unhealthy_checks)
    print()
    
    if #health_data.summary.critical_failures > 0 then
        print("CRITICAL FAILURES:")
        for _, failure in ipairs(health_data.summary.critical_failures) do
            print("  ❌ " .. failure)
        end
        print()
    end
    
    if #health_data.summary.warnings > 0 then
        print("WARNINGS:")
        for _, warning in ipairs(health_data.summary.warnings) do
            print("  ⚠️  " .. warning)
        end
        print()
    end
    
    print("DETAILED RESULTS:")
    for name, result in pairs(health_data.checks) do
        local icon = result.status == "healthy" and "✅" or "❌"
        print(string.format("  %s %s: %s (%dms)", icon, name, result.message, result.response_time_ms))
        
        -- Show additional details for specific checks
        if name == "memory" and result.memory_usage_percent then
            print(string.format("      Memory: %d%% used (%dMB / %dMB)", 
                  result.memory_usage_percent, result.memory_used_mb, result.memory_total_mb))
        elseif name == "disk_space" and result.usage_percent then
            print(string.format("      Disk: %d%% used (%s / %s)", 
                  result.usage_percent, result.used, result.size))
        elseif name == "api_endpoints" and result.endpoints then
            for endpoint, endpoint_result in pairs(result.endpoints) do
                local endpoint_icon = endpoint_result.status == "healthy" and "✅" or "❌"
                print(string.format("      %s %s: %s (%dms)", 
                      endpoint_icon, endpoint, endpoint_result.message, endpoint_result.response_time_ms))
            end
        end
    end
    
    print()
    print("=" .. string.rep("=", 60))
    
    return health_data
end

-- Command line interface
local function main()
    local checker = HealthChecker:new()
    
    local format = arg and arg[1] or "report"
    
    if format == "json" then
        local health_data = checker:run_all_checks()
        print(json.encode(health_data))
    elseif format == "report" then
        local health_data = checker:generate_report()
        -- Set exit code based on health status
        if health_data.status ~= "healthy" then
            os.exit(1)
        end
    elseif format == "status" then
        local health_data = checker:run_all_checks()
        print(health_data.status)
        if health_data.status ~= "healthy" then
            os.exit(1)
        end
    else
        print("Usage: lua health_check.lua [json|report|status]")
        print("  json   - Output health data as JSON")
        print("  report - Output detailed health report (default)")
        print("  status - Output only the status")
    end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("health_check%.lua$") then
    main()
end

return HealthChecker
