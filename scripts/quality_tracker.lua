#!/usr/bin/env luajitjit

-- Quality Metrics Tracker
-- Part of Phase 4: Testing & Quality implementation
-- Tracks code quality metrics over time and generates trend reports

local function safe_require(modname)
    local ok, mod = pcall(require, modname)
    if not ok then
        print(string.format("[quality_tracker] Error: Required Lua module '%s' is missing.", modname))
        os.exit(1)
    end
    return mod
end

local json = safe_require("cjson")
local lfs = safe_require("lfs")
local os = os
local io = io
local string = string
local table = table

local QualityTracker = {}
QualityTracker.__index = QualityTracker

function QualityTracker:new()
    local instance = {
        project_root = os.getenv("PWD") or ".",
        metrics_file = "quality-metrics.json",
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        current_metrics = {}
    }
    setmetatable(instance, self)
    return instance
end

-- Calculate code complexity metrics
function QualityTracker:calculate_complexity_metrics()
    local metrics = {
        total_lines = 0,
        total_files = 0,
        avg_lines_per_file = 0,
        max_lines_per_file = 0,
        files_over_200_lines = 0,
        files_over_500_lines = 0
    }
    
    -- Scan Lua files
    local function scan_directory(root, pattern)
        local files = {}
        local stack = {root}
        while #stack > 0 do
            local path = table.remove(stack)
            local attr = lfs.attributes(path)
            if not attr or attr.mode ~= "directory" then
                print(string.format("[quality_tracker] Error: Path %s is not a directory or cannot be accessed.", path))
            else
                local ok, err = pcall(function()
                    for file in lfs.dir(path) do
                        if file ~= "." and file ~= ".." then
                            local file_path = path .. "/" .. file
                            file_path = file_path:gsub("//", "/")
                            local ok_attr, attr = pcall(lfs.attributes, file_path)
                            if not ok_attr or not attr or not attr.mode then
                                print(string.format("[quality_tracker] Warning: Cannot stat %s", file_path))
                            else
                                if attr.mode == "directory" then
                                    table.insert(stack, file_path)
                                elseif attr.mode == "file" and file:match(pattern) then
                                    table.insert(files, file_path)
                                end
                            end
                        end
                    end
                end)
                if not ok then
                    print(string.format("[quality_tracker] Warning: Cannot read directory %s: %s", path, err))
                end
            end
        end
        return files
    end

    local lua_files = scan_directory(self.project_root .. "/src", "%.lua$")
    
    for _, file_path in ipairs(lua_files) do
        local file = io.open(file_path, "r")
        if file then
            local line_count = 0
            for _ in file:lines() do
                line_count = line_count + 1
            end
            file:close()
            
            metrics.total_files = metrics.total_files + 1
            metrics.total_lines = metrics.total_lines + line_count
            
            if line_count > metrics.max_lines_per_file then
                metrics.max_lines_per_file = line_count
            end
        end
    end
    
    if metrics.total_files > 0 then
        metrics.avg_lines_per_file = math.floor(metrics.total_lines / metrics.total_files)
    end
    
    -- Count files with excessive lines
    for _, file_path in ipairs(lua_files) do
        local file = io.open(file_path, "r")
        if file then
            local line_count = 0
            for _ in file:lines() do
                line_count = line_count + 1
            end
            file:close()
            
            if line_count > 200 then
                metrics.files_over_200_lines = metrics.files_over_200_lines + 1
            end
            if line_count > 500 then
                metrics.files_over_500_lines = metrics.files_over_500_lines + 1
            end
        end
    end
    
    return metrics
end

-- Calculate test coverage metrics
function QualityTracker:calculate_test_coverage()
    local coverage = {
        backend_coverage = 0,
        frontend_coverage = 0,
        total_tests = 0,
        passing_tests = 0,
        failing_tests = 0
    }
    
    -- Run backend coverage calculation
    local backend_result = os.execute("cd " .. self.project_root .. " && lua scripts/calculate_coverage.lua > /dev/null 2>&1")
    
    -- Always try to read the coverage file, regardless of return code
    local coverage_file = "/tmp/test_output.txt"
    local f = io.open(coverage_file, "r")
    if f then
        local output = f:read("*all")
        f:close()
        -- Try to extract coverage percent (e.g., "Coverage: 87.5%" or similar)
        local percent = string.match(output, "[Cc]overage:?%s*([%d%.]+)%%")
        if percent then
            coverage.backend_coverage = tonumber(percent)
            
            -- Also extract test counts
            local passed = string.match(output, "Tests passed:%s*(%d+)")
            local failed = string.match(output, "Tests failed:%s*(%d+)")
            if passed then coverage.passing_tests = tonumber(passed) end
            if failed then coverage.failing_tests = tonumber(failed) end
            coverage.total_tests = (coverage.passing_tests or 0) + (coverage.failing_tests or 0)
        else
            coverage.backend_coverage = nil
            print("[quality_tracker] Warning: Could not extract backend coverage percent from test output.")
        end
    else
        coverage.backend_coverage = nil
        print("[quality_tracker] Warning: Could not open backend test output file for coverage.")
    end
    
    -- Check frontend test coverage if available
    local frontend_coverage_file = self.project_root .. "/public/coverage/coverage-summary.json"
    local file = io.open(frontend_coverage_file, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local coverage_data = json.decode(content)
        if coverage_data and coverage_data.total and coverage_data.total.lines then
            coverage.frontend_coverage = coverage_data.total.lines.pct or 0
        end
    end
    
    return coverage
end

-- Calculate security metrics
function QualityTracker:calculate_security_metrics()
    local security = {
        vulnerabilities_high = 0,
        vulnerabilities_medium = 0,
        vulnerabilities_low = 0,
        dependencies_outdated = 0,
        security_score = 100
    }
    
    -- Run security audit and parse results
    local audit_result = os.execute("cd " .. self.project_root .. "/public && npm audit --json > /tmp/audit_output.json 2>/dev/null")
    
    local audit_file = io.open("/tmp/audit_output.json", "r")
    if audit_file then
        local content = audit_file:read("*all")
        audit_file:close()
        
        local success, audit_data = pcall(json.decode, content)
        if success and audit_data and audit_data.metadata then
            local vulnerabilities = audit_data.metadata.vulnerabilities or {}
            security.vulnerabilities_high = vulnerabilities.high or 0
            security.vulnerabilities_medium = vulnerabilities.moderate or 0
            security.vulnerabilities_low = vulnerabilities.low or 0
            
            -- Calculate security score
            local total_vulns = security.vulnerabilities_high + security.vulnerabilities_medium + security.vulnerabilities_low
            security.security_score = math.max(0, 100 - (security.vulnerabilities_high * 20) - (security.vulnerabilities_medium * 5) - (security.vulnerabilities_low * 1))
        end
    end
    
    return security
end

-- Calculate performance metrics
function QualityTracker:calculate_performance_metrics()
    local performance = {
        avg_response_time = 0,
        p95_response_time = 0,
        memory_usage = 0,
        bundle_size = 0,
        lighthouse_score = 0
    }
    
    -- Check if bundle analysis exists
    local bundle_file = io.open(self.project_root .. "/bundle-analysis.json", "r")
    if bundle_file then
        local content = bundle_file:read("*all")
        bundle_file:close()
        
        local success, bundle_data = pcall(json.decode, content)
        if success and bundle_data and bundle_data.totalSize then
            performance.bundle_size = bundle_data.totalSize
        end
    end
    
    -- Run quick performance test if server is available
    local perf_result = os.execute("curl -s -w '%{time_total}' http://localhost:8080/api/health > /tmp/perf_test.txt 2>/dev/null")
    if perf_result == 0 then
        local perf_file = io.open("/tmp/perf_test.txt", "r")
        if perf_file then
            local response_time = perf_file:read("*all")
            perf_file:close()
            performance.avg_response_time = tonumber(response_time) or 0
        end
    end
    
    return performance
end

-- Calculate technical debt metrics
function QualityTracker:calculate_debt_metrics()
    local debt = {
        todo_comments = 0,
        fixme_comments = 0,
        code_duplications = 0,
        cyclomatic_complexity = 0,
        debt_ratio = 0
    }
    
    -- Scan for TODO and FIXME comments
    local search_patterns = {
        todo = "TODO",
        fixme = "FIXME",
        hack = "HACK",
        xxx = "XXX"
    }
    
    for pattern_name, pattern in pairs(search_patterns) do
        local cmd = string.format("grep -r '%s' %s/src/ 2>/dev/null | wc -l", pattern, self.project_root)
        local handle = io.popen(cmd)
        if handle then
            local count = tonumber(handle:read("*all")) or 0
            handle:close()
            
            if pattern_name == "todo" then
                debt.todo_comments = count
            elseif pattern_name == "fixme" then
                debt.fixme_comments = count
            end
        end
    end
    
    -- Calculate overall debt ratio
    local total_comments = debt.todo_comments + debt.fixme_comments
    local total_lines = 1
    if self.current_metrics and self.current_metrics.complexity and self.current_metrics.complexity.total_lines then
        total_lines = tonumber(self.current_metrics.complexity.total_lines) or 1
        if total_lines <= 0 then total_lines = 1 end
    end
    debt.debt_ratio = total_comments / total_lines * 100
    
    return debt
end

-- Collect all metrics
function QualityTracker:collect_metrics()
    print("📊 Collecting quality metrics...")
    
    self.current_metrics = {
        timestamp = self.timestamp,
        complexity = self:calculate_complexity_metrics(),
        coverage = self:calculate_test_coverage(),
        security = self:calculate_security_metrics(),
        performance = self:calculate_performance_metrics()
    }
    
    -- Calculate debt metrics after complexity is available
    self.current_metrics.debt = self:calculate_debt_metrics()
    
    print("✅ Metrics collection completed")
    return self.current_metrics
end

-- Load historical metrics
function QualityTracker:load_historical_metrics()
    local file = io.open(self.metrics_file, "r")
    if not file then
        return {}
    end
    
    local content = file:read("*all")
    file:close()
    
    local success, data = pcall(json.decode, content)
    if success and data then
        return data
    else
        return {}
    end
end

-- Save metrics to file
function QualityTracker:save_metrics()
    local historical_data = self:load_historical_metrics()
    table.insert(historical_data, self.current_metrics)
    
    -- Keep only last 30 entries
    if #historical_data > 30 then
        for i = 1, #historical_data - 30 do
            table.remove(historical_data, 1)
        end
    end
    
    local file = io.open(self.metrics_file, "w")
    if file then
        file:write(json.encode(historical_data))
        file:close()
        print("💾 Metrics saved to " .. self.metrics_file)
    else
        print("❌ Failed to save metrics")
    end
end

-- Generate quality report
function QualityTracker:generate_report()
    local metrics = self.current_metrics
    local historical_data = self:load_historical_metrics()
    
    print("\n" .. string.rep("=", 60))
    print("                 QUALITY METRICS REPORT")
    print(string.rep("=", 60))
    print("Generated: " .. self.timestamp)
    print()
    
    -- Complexity Metrics
    print("📈 CODE COMPLEXITY")
    print(string.format("  Total Files: %d", metrics.complexity.total_files))
    print(string.format("  Total Lines: %d", metrics.complexity.total_lines))
    print(string.format("  Avg Lines/File: %d", metrics.complexity.avg_lines_per_file))
    print(string.format("  Max Lines/File: %d", metrics.complexity.max_lines_per_file))
    print(string.format("  Files >200 lines: %d", metrics.complexity.files_over_200_lines))
    print(string.format("  Files >500 lines: %d", metrics.complexity.files_over_500_lines))
    print()
    
    -- Test Coverage
    print("🧪 TEST COVERAGE")
    local backend_cov = tonumber(metrics.coverage.backend_coverage) or 0
    local frontend_cov = tonumber(metrics.coverage.frontend_coverage) or 0
    print(string.format("  Backend Coverage: %.1f%%", backend_cov))
    print(string.format("  Frontend Coverage: %.1f%%", frontend_cov))
    print(string.format("  Passing Tests: %d", metrics.coverage.passing_tests))
    print(string.format("  Failing Tests: %d", metrics.coverage.failing_tests))
    print()
    
    -- Security Metrics
    print("🔒 SECURITY")
    print(string.format("  Security Score: %d/100", metrics.security.security_score))
    print(string.format("  High Vulnerabilities: %d", metrics.security.vulnerabilities_high))
    print(string.format("  Medium Vulnerabilities: %d", metrics.security.vulnerabilities_medium))
    print(string.format("  Low Vulnerabilities: %d", metrics.security.vulnerabilities_low))
    print()
    
    -- Performance Metrics
    print("⚡ PERFORMANCE")
    print(string.format("  Avg Response Time: %.3fs", metrics.performance.avg_response_time))
    print(string.format("  Bundle Size: %.1fKB", metrics.performance.bundle_size / 1024))
    print()
    
    -- Technical Debt
    print("💸 TECHNICAL DEBT")
    print(string.format("  TODO Comments: %d", metrics.debt.todo_comments))
    print(string.format("  FIXME Comments: %d", metrics.debt.fixme_comments))
    print(string.format("  Debt Ratio: %.2f%%", metrics.debt.debt_ratio))
    print()
    
    -- Trends (if historical data available)
    if #historical_data > 1 then
    print("📊 TRENDS")
    local prev_metrics = historical_data[#historical_data - 1]
    local curr_lines = tonumber(metrics.complexity.total_lines) or 0
    local prev_lines = tonumber(prev_metrics.complexity.total_lines) or 0
    local curr_coverage = tonumber(metrics.coverage.backend_coverage) or 0
    local prev_coverage = tonumber(prev_metrics.coverage.backend_coverage) or 0
    local curr_security = tonumber(metrics.security.security_score) or 0
    local prev_security = tonumber(prev_metrics.security.security_score) or 0
    local complexity_trend = curr_lines - prev_lines
    local coverage_trend = curr_coverage - prev_coverage
    local security_trend = curr_security - prev_security
    print(string.format("  Code Growth: %+d lines", complexity_trend))
    print(string.format("  Coverage Change: %+.1f%%", coverage_trend))
    print(string.format("  Security Change: %+d points", security_trend))
    print()
    end
    
    -- Quality Score
    local quality_score = self:calculate_quality_score(metrics)
    print("🏆 OVERALL QUALITY SCORE")
    print(string.format("  Score: %.1f/100", quality_score))
    print(self:get_quality_grade(quality_score))
    print()
    
    print(string.rep("=", 60))
end

-- Calculate overall quality score
function QualityTracker:calculate_quality_score(metrics)
    local score = 0
    
    -- Coverage contribution (30%)
    local backend_cov = tonumber(metrics.coverage.backend_coverage) or 0
    local frontend_cov = tonumber(metrics.coverage.frontend_coverage) or 0
    score = score + (backend_cov * 0.15)
    score = score + (frontend_cov * 0.15)
    
    -- Security contribution (25%)
    score = score + (metrics.security.security_score * 0.25)
    
    -- Complexity contribution (20%)
    local complexity_score = 100
    if metrics.complexity.avg_lines_per_file > 200 then
        complexity_score = complexity_score - 20
    end
    if metrics.complexity.files_over_500_lines > 0 then
        complexity_score = complexity_score - 30
    end
    score = score + (complexity_score * 0.20)
    
    -- Technical debt contribution (15%)
    local debt_score = math.max(0, 100 - metrics.debt.debt_ratio * 10)
    score = score + (debt_score * 0.15)
    
    -- Performance contribution (10%)
    local perf_score = 100
    if metrics.performance.avg_response_time > 1.0 then
        perf_score = perf_score - 30
    elseif metrics.performance.avg_response_time > 0.5 then
        perf_score = perf_score - 10
    end
    score = score + (perf_score * 0.10)
    
    return math.min(100, math.max(0, score))
end

-- Get quality grade
function QualityTracker:get_quality_grade(score)
    if score >= 90 then
        return "  Grade: A+ (Excellent) 🌟"
    elseif score >= 80 then
        return "  Grade: A (Very Good) ✅"
    elseif score >= 70 then
        return "  Grade: B (Good) 👍"
    elseif score >= 60 then
        return "  Grade: C (Fair) ⚠️"
    elseif score >= 50 then
        return "  Grade: D (Poor) ❌"
    else
        return "  Grade: F (Failing) 💥"
    end
end

-- Main execution
local function main()
    local tracker = QualityTracker:new()
    
    -- Collect current metrics
    tracker:collect_metrics()
    
    -- Generate and display report
    tracker:generate_report()
    
    -- Save metrics for historical tracking
    tracker:save_metrics()
    
    print("📄 Run 'cat quality-metrics.json' to see historical data")
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("quality_tracker%.lua$") then
    main()
end

return QualityTracker
