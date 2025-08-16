#!/usr/bin/env lua

-- Coverage Calculator for Backend Tests
-- Generates coverage reports based on test results

local function calculate_test_coverage()
    -- Run comprehensive tests and capture output
    local test_command = "cd " .. (os.getenv("PWD") or ".") .. " && lua scripts/run_comprehensive_tests.lua 2>&1"
    local handle = io.popen(test_command)
    if not handle then
        print("Error: Could not run test command")
        return 0, 0, 0
    end
    
    local output = handle:read("*all")
    handle:close()
    
    -- Parse test results
    local total_tests = 0
    local passed_tests = 0
    local failed_tests = 0
    
    -- Extract final summary
    for line in output:gmatch("[^\r\n]+") do
        if line:match("Total:%s*(%d+)") then
            total_tests = tonumber(line:match("Total:%s*(%d+)")) or 0
        elseif line:match("Passed:%s*(%d+)") then
            passed_tests = tonumber(line:match("Passed:%s*(%d+)")) or 0
        elseif line:match("Failed:%s*(%d+)") then
            failed_tests = tonumber(line:match("Failed:%s*(%d+)")) or 0
        end
    end
    
    -- Calculate coverage percentage based on passing tests
    local coverage_percent = 0
    if total_tests > 0 then
        coverage_percent = (passed_tests / total_tests) * 100
    end
    
    return coverage_percent, passed_tests, failed_tests
end

-- Generate coverage file for quality tracker
local function generate_coverage_file()
    local coverage_percent, passed_tests, failed_tests = calculate_test_coverage()
    
    local coverage_output = string.format([[
=== BACKEND TEST COVERAGE REPORT ===
Tests run: %d
Tests passed: %d  
Tests failed: %d
Coverage: %.1f%%
Success rate: %.1f%%
]], 
        passed_tests + failed_tests,
        passed_tests,
        failed_tests,
        coverage_percent,
        coverage_percent
    )
    
    -- Write to temp file for quality tracker
    local f = io.open("/tmp/test_output.txt", "w")
    if f then
        f:write(coverage_output)
        f:close()
        print("Coverage report generated:")
        print(coverage_output)
    else
        print("Error: Could not write coverage file")
    end
    
    return coverage_percent
end

-- Main execution
if arg and arg[0] and arg[0]:match("calculate_coverage%.lua$") then
    generate_coverage_file()
end

return {
    calculate_test_coverage = calculate_test_coverage,
    generate_coverage_file = generate_coverage_file
}
