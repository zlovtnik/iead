-- src/tests/enhanced_test_runner.lua
-- Enhanced test runner with coverage tracking and structured output

local json = require("cjson")

local EnhancedTestRunner = {}
EnhancedTestRunner.__index = EnhancedTestRunner

function EnhancedTestRunner:new(options)
    options = options or {}
    
    local instance = {
        stats = {
            passed = 0,
            failed = 0,
            total = 0,
            skipped = 0,
            failures = {},
            start_time = os.time(),
            end_time = nil
        },
        coverage = {
            files_covered = {},
            total_lines = 0,
            covered_lines = 0,
            coverage_percentage = 0
        },
        output_format = options.output_format or "console", -- console, json, junit
        output_file = options.output_file,
        coverage_enabled = options.coverage_enabled or false,
        verbose = options.verbose or false
    }
    
    setmetatable(instance, self)
    return instance
end

-- Colors for console output
local colors = {
    green = "\27[32m",
    red = "\27[31m",
    yellow = "\27[33m",
    blue = "\27[34m",
    cyan = "\27[36m",
    reset = "\27[0m"
}

-- Assert functions with better error reporting
function EnhancedTestRunner:assert_equal(actual, expected, message)
    if actual == expected then
        return true
    else
        local error_msg = string.format(
            "%s\n  Expected: %s\n  Actual: %s", 
            message or "Assertion failed", 
            self:format_value(expected), 
            self:format_value(actual)
        )
        error(error_msg)
    end
end

function EnhancedTestRunner:assert_not_nil(value, message)
    if value ~= nil then
        return true
    else
        error(message or "Expected value to not be nil")
    end
end

function EnhancedTestRunner:assert_nil(value, message)
    if value == nil then
        return true
    else
        error(string.format("%s\n  Expected: nil\n  Actual: %s", 
            message or "Assertion failed", self:format_value(value)))
    end
end

function EnhancedTestRunner:assert_true(value, message)
    if value == true then
        return true
    else
        error(string.format("%s\n  Expected: true\n  Actual: %s", 
            message or "Assertion failed", self:format_value(value)))
    end
end

function EnhancedTestRunner:assert_false(value, message)
    if value == false then
        return true
    else
        error(string.format("%s\n  Expected: false\n  Actual: %s", 
            message or "Assertion failed", self:format_value(value)))
    end
end

function EnhancedTestRunner:assert_type(value, expected_type, message)
    if type(value) == expected_type then
        return true
    else
        error(string.format("%s\n  Expected type: %s\n  Actual type: %s", 
            message or "Type assertion failed", expected_type, type(value)))
    end
end

function EnhancedTestRunner:assert_match(value, pattern, message)
    if type(value) == "string" and value:match(pattern) then
        return true
    else
        error(string.format("%s\n  Pattern: %s\n  Value: %s", 
            message or "Pattern match failed", pattern, self:format_value(value)))
    end
end

function EnhancedTestRunner:assert_contains(table_or_string, item, message)
    if type(table_or_string) == "table" then
        for _, v in pairs(table_or_string) do
            if v == item then
                return true
            end
        end
        error(string.format("%s\n  Item not found: %s", 
            message or "Contains assertion failed", self:format_value(item)))
    elseif type(table_or_string) == "string" then
        if table_or_string:find(item, 1, true) then
            return true
        else
            error(string.format("%s\n  Substring not found: %s\n  In string: %s", 
                message or "Contains assertion failed", item, table_or_string))
        end
    else
        error("assert_contains expects table or string as first argument")
    end
end

-- Format values for better error messages
function EnhancedTestRunner:format_value(value)
    if value == nil then
        return "nil"
    elseif type(value) == "string" then
        return '"' .. value .. '"'
    elseif type(value) == "table" then
        local items = {}
        for k, v in pairs(value) do
            table.insert(items, string.format("%s=%s", k, self:format_value(v)))
        end
        return "{" .. table.concat(items, ", ") .. "}"
    else
        return tostring(value)
    end
end

-- Run a single test with enhanced error handling
function EnhancedTestRunner:run_test(name, test_func, suite_name)
    self.stats.total = self.stats.total + 1
    
    local start_time = os.clock()
    local success, err = pcall(test_func)
    local duration = os.clock() - start_time
    
    if success then
        self.stats.passed = self.stats.passed + 1
        if self.output_format == "console" then
            print(colors.green .. "✓ " .. name .. colors.reset .. 
                  (self.verbose and string.format(" (%.3fs)", duration) or ""))
        end
    else
        self.stats.failed = self.stats.failed + 1
        local failure = {
            name = name,
            suite = suite_name,
            error = err,
            duration = duration,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        table.insert(self.stats.failures, failure)
        
        if self.output_format == "console" then
            print(colors.red .. "✗ " .. name .. colors.reset)
            print(colors.red .. "  " .. err .. colors.reset)
            if self.verbose then
                print(colors.yellow .. string.format("  Duration: %.3fs", duration) .. colors.reset)
            end
        end
    end
    
    return success
end

-- Run a test suite with setup/teardown support
function EnhancedTestRunner:run_suite(suite_name, tests, options)
    options = options or {}
    
    if self.output_format == "console" then
        print(colors.blue .. "\n=== " .. suite_name .. " ===" .. colors.reset)
    end
    
    local suite_stats = { passed = 0, failed = 0, total = 0 }
    
    -- Run setup if provided
    if options.setup then
        local success, err = pcall(options.setup)
        if not success then
            print(colors.red .. "Suite setup failed: " .. err .. colors.reset)
            return suite_stats
        end
    end
    
    -- Run tests
    for name, test_func in pairs(tests) do
        if type(test_func) == "function" then
            local success = self:run_test(name, test_func, suite_name)
            suite_stats.total = suite_stats.total + 1
            if success then
                suite_stats.passed = suite_stats.passed + 1
            else
                suite_stats.failed = suite_stats.failed + 1
            end
        end
    end
    
    -- Run teardown if provided
    if options.teardown then
        local success, err = pcall(options.teardown)
        if not success then
            print(colors.yellow .. "Suite teardown failed: " .. err .. colors.reset)
        end
    end
    
    if self.output_format == "console" then
        print(colors.cyan .. string.format("Suite results: %d/%d passed", 
            suite_stats.passed, suite_stats.total) .. colors.reset)
    end
    
    return suite_stats
end

-- Simple coverage tracking (line-based)
function EnhancedTestRunner:track_coverage(file_path)
    if not self.coverage_enabled then
        return
    end
    
    local file = io.open(file_path, "r")
    if not file then
        return
    end
    
    local lines = {}
    local line_number = 1
    for line in file:lines() do
        -- Simple heuristic: non-empty, non-comment lines are "coverable"
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^%-%-") then
            lines[line_number] = {
                content = line,
                covered = false -- Would need actual execution tracking
            }
        end
        line_number = line_number + 1
    end
    file:close()
    
    self.coverage.files_covered[file_path] = lines
end

-- Calculate coverage statistics
function EnhancedTestRunner:calculate_coverage()
    if not self.coverage_enabled then
        return
    end
    
    local total_lines = 0
    local covered_lines = 0
    
    for file_path, lines in pairs(self.coverage.files_covered) do
        for line_num, line_info in pairs(lines) do
            total_lines = total_lines + 1
            if line_info.covered then
                covered_lines = covered_lines + 1
            end
        end
    end
    
    self.coverage.total_lines = total_lines
    self.coverage.covered_lines = covered_lines
    self.coverage.coverage_percentage = total_lines > 0 and (covered_lines / total_lines * 100) or 0
end

-- Print results in various formats
function EnhancedTestRunner:print_results()
    self.stats.end_time = os.time()
    local duration = self.stats.end_time - self.stats.start_time
    
    if self.output_format == "console" then
        self:print_console_results(duration)
    elseif self.output_format == "json" then
        self:print_json_results(duration)
    elseif self.output_format == "junit" then
        self:print_junit_results(duration)
    end
    
    -- Save to file if specified
    if self.output_file then
        self:save_results_to_file(duration)
    end
end

function EnhancedTestRunner:print_console_results(duration)
    print(colors.blue .. "\n=== Test Results ===" .. colors.reset)
    print(string.format("Total: %d", self.stats.total))
    print(colors.green .. string.format("Passed: %d", self.stats.passed) .. colors.reset)
    
    if self.stats.failed > 0 then
        print(colors.red .. string.format("Failed: %d", self.stats.failed) .. colors.reset)
        print(colors.yellow .. "\nFailures:" .. colors.reset)
        for _, failure in ipairs(self.stats.failures) do
            print(colors.red .. "- " .. failure.name .. ": " .. failure.error .. colors.reset)
        end
    end
    
    local success_rate = self.stats.total > 0 and (self.stats.passed / self.stats.total * 100) or 0
    print(string.format("\nSuccess rate: %.1f%%", success_rate))
    print(string.format("Duration: %ds", duration))
    
    -- Coverage results
    if self.coverage_enabled then
        self:calculate_coverage()
        print(colors.cyan .. "\n=== Coverage Results ===" .. colors.reset)
        print(string.format("Coverage: %.1f%% (%d/%d lines)", 
            self.coverage.coverage_percentage, 
            self.coverage.covered_lines, 
            self.coverage.total_lines))
    end
end

function EnhancedTestRunner:print_json_results(duration)
    local results = {
        summary = {
            total = self.stats.total,
            passed = self.stats.passed,
            failed = self.stats.failed,
            skipped = self.stats.skipped,
            success_rate = self.stats.total > 0 and (self.stats.passed / self.stats.total * 100) or 0,
            duration = duration,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        },
        failures = self.stats.failures,
        coverage = self.coverage_enabled and {
            percentage = self.coverage.coverage_percentage,
            covered_lines = self.coverage.covered_lines,
            total_lines = self.coverage.total_lines,
            files = self.coverage.files_covered
        } or nil
    }
    
    print(json.encode(results))
end

function EnhancedTestRunner:save_results_to_file(duration)
    local file = io.open(self.output_file, "w")
    if not file then
        print(colors.red .. "Failed to open output file: " .. self.output_file .. colors.reset)
        return
    end
    
    if self.output_format == "json" then
        local results = {
            summary = {
                total = self.stats.total,
                passed = self.stats.passed,
                failed = self.stats.failed,
                skipped = self.stats.skipped,
                success_rate = self.stats.total > 0 and (self.stats.passed / self.stats.total * 100) or 0,
                duration = duration,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            },
            failures = self.stats.failures,
            coverage = self.coverage_enabled and {
                percentage = self.coverage.coverage_percentage,
                covered_lines = self.coverage.covered_lines,
                total_lines = self.coverage.total_lines
            } or nil
        }
        file:write(json.encode(results))
    end
    
    file:close()
    print(colors.green .. "Results saved to: " .. self.output_file .. colors.reset)
end

-- Setup test database with better error handling
function EnhancedTestRunner:setup_test_db()
    local db_config = require("src.config.database")
    local original_db = db_config.db_file
    
    -- Use test database
    db_config.db_file = "test_church_management.db"
    
    -- Remove existing test database
    os.remove(db_config.db_file)
    
    -- Initialize schema
    local success, err = pcall(function()
        local schema = require("src.db.schema")
        schema.init()
    end)
    
    if not success then
        print(colors.red .. "Failed to initialize test database: " .. (err or "unknown error") .. colors.reset)
        db_config.db_file = original_db
        return nil
    end
    
    return function()
        -- Cleanup function
        db_config.db_file = original_db
        os.remove("test_church_management.db")
    end
end

-- Skip a test (for incomplete or problematic tests)
function EnhancedTestRunner:skip_test(name, reason)
    self.stats.total = self.stats.total + 1
    self.stats.skipped = self.stats.skipped + 1
    
    if self.output_format == "console" then
        print(colors.yellow .. "⊘ " .. name .. " (SKIPPED: " .. (reason or "no reason") .. ")" .. colors.reset)
    end
end

return EnhancedTestRunner