#!/usr/bin/env lua

-- Log Aggregation and Analysis System
-- Comprehensive logging solution for Church Management System

local json = require("cjson")
local socket = require("socket")
local lfs = require("lfs")

local LogAggregator = {}
LogAggregator.__index = LogAggregator

function LogAggregator:new(config)
    local instance = {
        log_dir = config.log_dir or "/app/logs",
        error_log = config.error_log or "/app/logs/error.log",
        access_log = config.access_log or "/app/logs/access.log",
        app_log = config.app_log or "/app/logs/app.log",
        max_log_size = config.max_log_size or 100 * 1024 * 1024, -- 100MB
        retention_days = config.retention_days or 30,
        aggregation_window = config.aggregation_window or 300, -- 5 minutes
        alert_thresholds = config.alert_thresholds or {
            error_rate = 10,      -- errors per minute
            response_time = 5000, -- milliseconds
            memory_usage = 90     -- percentage
        }
    }
    setmetatable(instance, self)
    return instance
end

-- Initialize logging system
function LogAggregator:init()
    -- Create log directory if it doesn't exist
    if not lfs.attributes(self.log_dir) then
        lfs.mkdir(self.log_dir)
    end
    
    -- Create log files if they don't exist
    local log_files = {self.error_log, self.access_log, self.app_log}
    for _, log_file in ipairs(log_files) do
        local file = io.open(log_file, "a")
        if file then
            file:close()
        end
    end
    
    print("Log aggregation system initialized")
    print("Log directory: " .. self.log_dir)
end

-- Log rotation
function LogAggregator:rotate_logs()
    local log_files = {self.error_log, self.access_log, self.app_log}
    
    for _, log_file in ipairs(log_files) do
        local attr = lfs.attributes(log_file)
        if attr and attr.size > self.max_log_size then
            local timestamp = os.date("%Y%m%d_%H%M%S")
            local rotated_name = log_file .. "." .. timestamp
            
            -- Move current log to rotated name
            os.rename(log_file, rotated_name)
            
            -- Create new log file
            local file = io.open(log_file, "w")
            if file then
                file:close()
            end
            
            -- Compress rotated log
            os.execute("gzip " .. rotated_name)
            
            print("Rotated log: " .. log_file .. " -> " .. rotated_name .. ".gz")
        end
    end
end

-- Clean old logs
function LogAggregator:cleanup_old_logs()
    local cutoff_time = os.time() - (self.retention_days * 24 * 60 * 60)
    
    for file in lfs.dir(self.log_dir) do
        if file:match("%.log%.%d+%.gz$") then
            local filepath = self.log_dir .. "/" .. file
            local attr = lfs.attributes(filepath)
            
            if attr and attr.modification < cutoff_time then
                os.remove(filepath)
                print("Deleted old log: " .. file)
            end
        end
    end
end

-- Parse log entry
function LogAggregator:parse_log_entry(line, log_type)
    local entry = {}
    
    if log_type == "access" then
        -- Parse access log format: IP - - [timestamp] "method path protocol" status size "referer" "user-agent" response_time
        local pattern = '(%S+) %- %- %[([^%]]+)%] "(%S+) (%S+) (%S+)" (%d+) (%d+) "([^"]*)" "([^"]*)" (%S+)'
        local ip, timestamp, method, path, protocol, status, size, referer, user_agent, response_time = line:match(pattern)
        
        if ip then
            entry = {
                type = "access",
                timestamp = timestamp,
                ip = ip,
                method = method,
                path = path,
                protocol = protocol,
                status = tonumber(status),
                size = tonumber(size),
                referer = referer,
                user_agent = user_agent,
                response_time = tonumber(response_time)
            }
        end
    elseif log_type == "error" then
        -- Parse JSON error log format
        local success, parsed = pcall(json.decode, line)
        if success then
            entry = parsed
            entry.type = "error"
        else
            -- Fallback to simple parsing
            entry = {
                type = "error",
                timestamp = os.date("%Y-%m-%d %H:%M:%S"),
                message = line,
                level = "ERROR"
            }
        end
    elseif log_type == "app" then
        -- Parse JSON app log format
        local success, parsed = pcall(json.decode, line)
        if success then
            entry = parsed
            entry.type = "app"
        else
            -- Fallback to simple parsing
            entry = {
                type = "app",
                timestamp = os.date("%Y-%m-%d %H:%M:%S"),
                message = line,
                level = "INFO"
            }
        end
    end
    
    return entry
end

-- Analyze logs for patterns and alerts
function LogAggregator:analyze_logs(since_time)
    local stats = {
        total_requests = 0,
        error_count = 0,
        status_codes = {},
        response_times = {},
        error_messages = {},
        top_endpoints = {},
        top_ips = {},
        alerts = {}
    }
    
    since_time = since_time or (os.time() - self.aggregation_window)
    
    -- Analyze access logs
    local access_file = io.open(self.access_log, "r")
    if access_file then
        for line in access_file:lines() do
            local entry = self:parse_log_entry(line, "access")
            
            if entry.timestamp then
                -- Convert timestamp to epoch time for comparison
                local entry_time = self:parse_timestamp(entry.timestamp)
                
                if entry_time >= since_time then
                    stats.total_requests = stats.total_requests + 1
                    
                    -- Status code stats
                    stats.status_codes[entry.status] = (stats.status_codes[entry.status] or 0) + 1
                    
                    -- Error counting
                    if entry.status >= 400 then
                        stats.error_count = stats.error_count + 1
                    end
                    
                    -- Response time stats
                    if entry.response_time then
                        table.insert(stats.response_times, entry.response_time)
                    end
                    
                    -- Top endpoints
                    local endpoint = entry.method .. " " .. entry.path
                    stats.top_endpoints[endpoint] = (stats.top_endpoints[endpoint] or 0) + 1
                    
                    -- Top IPs
                    stats.top_ips[entry.ip] = (stats.top_ips[entry.ip] or 0) + 1
                end
            end
        end
        access_file:close()
    end
    
    -- Analyze error logs
    local error_file = io.open(self.error_log, "r")
    if error_file then
        for line in error_file:lines() do
            local entry = self:parse_log_entry(line, "error")
            
            if entry.timestamp then
                local entry_time = self:parse_timestamp(entry.timestamp)
                
                if entry_time >= since_time then
                    local message_key = entry.message or "unknown error"
                    stats.error_messages[message_key] = (stats.error_messages[message_key] or 0) + 1
                end
            end
        end
        error_file:close()
    end
    
    -- Calculate derived metrics
    if #stats.response_times > 0 then
        table.sort(stats.response_times)
        local count = #stats.response_times
        stats.avg_response_time = self:calculate_average(stats.response_times)
        stats.p95_response_time = stats.response_times[math.ceil(count * 0.95)]
        stats.p99_response_time = stats.response_times[math.ceil(count * 0.99)]
    end
    
    stats.error_rate = stats.total_requests > 0 and (stats.error_count / stats.total_requests * 100) or 0
    
    -- Check for alerts
    self:check_alerts(stats)
    
    return stats
end

-- Parse timestamp to epoch time
function LogAggregator:parse_timestamp(timestamp_str)
    -- Handle different timestamp formats
    local patterns = {
        "(%d+)/(%w+)/(%d+):(%d+):(%d+):(%d+)", -- Apache format: 01/Jan/2024:12:00:00
        "(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)", -- ISO format: 2024-01-01 12:00:00
        "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)" -- ISO with T: 2024-01-01T12:00:00
    }
    
    for _, pattern in ipairs(patterns) do
        local matches = {timestamp_str:match(pattern)}
        if #matches >= 6 then
            -- Convert to standard format and parse
            local year, month, day, hour, min, sec
            
            if pattern:find("(%w+)") then -- Apache format with month name
                day, month, year, hour, min, sec = unpack(matches)
                local months = {Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6,
                              Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12}
                month = months[month] or 1
            else -- Numeric formats
                year, month, day, hour, min, sec = unpack(matches)
            end
            
            return os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })
        end
    end
    
    return os.time() -- Fallback to current time
end

-- Calculate average
function LogAggregator:calculate_average(numbers)
    local sum = 0
    for _, num in ipairs(numbers) do
        sum = sum + num
    end
    return sum / #numbers
end

-- Check for alerts
function LogAggregator:check_alerts(stats)
    local alerts = {}
    
    -- High error rate alert
    if stats.error_rate > self.alert_thresholds.error_rate then
        table.insert(alerts, {
            type = "high_error_rate",
            severity = "warning",
            message = string.format("High error rate: %.2f%% (threshold: %d%%)", 
                     stats.error_rate, self.alert_thresholds.error_rate),
            value = stats.error_rate,
            threshold = self.alert_thresholds.error_rate
        })
    end
    
    -- High response time alert
    if stats.p95_response_time and stats.p95_response_time > self.alert_thresholds.response_time then
        table.insert(alerts, {
            type = "high_response_time",
            severity = "warning",
            message = string.format("High response time: %.2fms P95 (threshold: %dms)", 
                     stats.p95_response_time, self.alert_thresholds.response_time),
            value = stats.p95_response_time,
            threshold = self.alert_thresholds.response_time
        })
    end
    
    -- Too many 5xx errors
    local server_errors = (stats.status_codes[500] or 0) + (stats.status_codes[502] or 0) + 
                         (stats.status_codes[503] or 0) + (stats.status_codes[504] or 0)
    if server_errors > 10 then
        table.insert(alerts, {
            type = "server_errors",
            severity = "critical",
            message = string.format("High number of server errors: %d", server_errors),
            value = server_errors,
            threshold = 10
        })
    end
    
    stats.alerts = alerts
end

-- Generate report
function LogAggregator:generate_report(stats)
    print("=" .. string.rep("=", 60))
    print("             LOG ANALYSIS REPORT")
    print("=" .. string.rep("=", 60))
    print("Analysis Period: " .. os.date("%Y-%m-%d %H:%M:%S", os.time() - self.aggregation_window) .. 
          " to " .. os.date("%Y-%m-%d %H:%M:%S"))
    print()
    
    -- Summary
    print("SUMMARY:")
    print(string.format("  Total Requests: %d", stats.total_requests))
    print(string.format("  Error Count: %d", stats.error_count))
    print(string.format("  Error Rate: %.2f%%", stats.error_rate))
    
    if stats.avg_response_time then
        print(string.format("  Avg Response Time: %.2fms", stats.avg_response_time))
        print(string.format("  P95 Response Time: %.2fms", stats.p95_response_time or 0))
        print(string.format("  P99 Response Time: %.2fms", stats.p99_response_time or 0))
    end
    print()
    
    -- Alerts
    if #stats.alerts > 0 then
        print("ALERTS:")
        for _, alert in ipairs(stats.alerts) do
            local icon = alert.severity == "critical" and "🔴" or "🟡"
            print(string.format("  %s %s: %s", icon, alert.type, alert.message))
        end
        print()
    end
    
    -- Status codes
    if next(stats.status_codes) then
        print("STATUS CODES:")
        local sorted_codes = {}
        for code, count in pairs(stats.status_codes) do
            table.insert(sorted_codes, {code = code, count = count})
        end
        table.sort(sorted_codes, function(a, b) return a.count > b.count end)
        
        for i = 1, math.min(10, #sorted_codes) do
            local item = sorted_codes[i]
            print(string.format("  %d: %d requests", item.code, item.count))
        end
        print()
    end
    
    -- Top endpoints
    if next(stats.top_endpoints) then
        print("TOP ENDPOINTS:")
        local sorted_endpoints = {}
        for endpoint, count in pairs(stats.top_endpoints) do
            table.insert(sorted_endpoints, {endpoint = endpoint, count = count})
        end
        table.sort(sorted_endpoints, function(a, b) return a.count > b.count end)
        
        for i = 1, math.min(10, #sorted_endpoints) do
            local item = sorted_endpoints[i]
            print(string.format("  %s: %d", item.endpoint, item.count))
        end
        print()
    end
    
    -- Error messages
    if next(stats.error_messages) then
        print("TOP ERROR MESSAGES:")
        local sorted_errors = {}
        for message, count in pairs(stats.error_messages) do
            table.insert(sorted_errors, {message = message, count = count})
        end
        table.sort(sorted_errors, function(a, b) return a.count > b.count end)
        
        for i = 1, math.min(5, #sorted_errors) do
            local item = sorted_errors[i]
            local truncated_message = item.message:sub(1, 50) .. (item.message:len() > 50 and "..." or "")
            print(string.format("  %s: %d", truncated_message, item.count))
        end
        print()
    end
    
    print("=" .. string.rep("=", 60))
end

-- Export metrics for monitoring systems
function LogAggregator:export_metrics(stats)
    local metrics = {
        timestamp = os.time(),
        total_requests = stats.total_requests,
        error_count = stats.error_count,
        error_rate = stats.error_rate,
        avg_response_time = stats.avg_response_time or 0,
        p95_response_time = stats.p95_response_time or 0,
        p99_response_time = stats.p99_response_time or 0,
        status_codes = stats.status_codes,
        alerts = stats.alerts
    }
    
    -- Write to metrics file for Prometheus scraping
    local metrics_file = io.open(self.log_dir .. "/metrics.json", "w")
    if metrics_file then
        metrics_file:write(json.encode(metrics))
        metrics_file:close()
    end
    
    -- Write Prometheus format metrics
    local prom_file = io.open(self.log_dir .. "/metrics.prom", "w")
    if prom_file then
        prom_file:write("# HELP church_management_requests_total Total HTTP requests\n")
        prom_file:write("# TYPE church_management_requests_total counter\n")
        prom_file:write("church_management_requests_total " .. stats.total_requests .. "\n")
        
        prom_file:write("# HELP church_management_errors_total Total HTTP errors\n")
        prom_file:write("# TYPE church_management_errors_total counter\n")
        prom_file:write("church_management_errors_total " .. stats.error_count .. "\n")
        
        prom_file:write("# HELP church_management_error_rate HTTP error rate percentage\n")
        prom_file:write("# TYPE church_management_error_rate gauge\n")
        prom_file:write("church_management_error_rate " .. stats.error_rate .. "\n")
        
        if stats.avg_response_time then
            prom_file:write("# HELP church_management_response_time_ms Average response time in milliseconds\n")
            prom_file:write("# TYPE church_management_response_time_ms gauge\n")
            prom_file:write("church_management_response_time_ms " .. stats.avg_response_time .. "\n")
        end
        
        prom_file:close()
    end
end

-- Main function
function LogAggregator:run()
    self:init()
    self:rotate_logs()
    
    local stats = self:analyze_logs()
    self:generate_report(stats)
    self:export_metrics(stats)
    
    self:cleanup_old_logs()
    
    -- Return exit code based on alerts
    local critical_alerts = 0
    for _, alert in ipairs(stats.alerts) do
        if alert.severity == "critical" then
            critical_alerts = critical_alerts + 1
        end
    end
    
    return critical_alerts == 0 and 0 or 1
end

-- Command line interface
local function main()
    local config = {
        log_dir = arg[2] or "/app/logs",
        aggregation_window = tonumber(arg[3]) or 300
    }
    
    local aggregator = LogAggregator:new(config)
    
    local command = arg and arg[1] or "analyze"
    
    if command == "analyze" then
        local exit_code = aggregator:run()
        os.exit(exit_code)
    elseif command == "rotate" then
        aggregator:rotate_logs()
    elseif command == "cleanup" then
        aggregator:cleanup_old_logs()
    elseif command == "init" then
        aggregator:init()
    else
        print("Usage: lua log_aggregator.lua [analyze|rotate|cleanup|init] [log_dir] [window_seconds]")
        print("  analyze  - Analyze logs and generate report (default)")
        print("  rotate   - Rotate large log files")
        print("  cleanup  - Clean up old log files")
        print("  init     - Initialize log directory structure")
    end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("log_aggregator%.lua$") then
    main()
end

return LogAggregator
