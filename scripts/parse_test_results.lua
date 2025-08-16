#!/usr/bin/env lua
-- scripts/parse_test_results.lua
-- Parse test results and generate CI-friendly output

local json = require("cjson")

local function parse_test_results(results_file)
    local file = io.open(results_file, "r")
    if not file then
        print("Error: Could not open test results file: " .. results_file)
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    local success, data = pcall(json.decode, content)
    if not success then
        print("Error: Could not parse JSON from test results")
        return nil
    end
    
    return data
end

local function generate_github_summary(test_data)
    if not test_data or not test_data.summary then
        return
    end
    
    local summary = test_data.summary
    local status_emoji = summary.failed == 0 and "✅" or "❌"
    
    print("## " .. status_emoji .. " Test Results Summary")
    print("")
    print("| Metric | Value |")
    print("|--------|-------|")
    print(string.format("| **Total Tests** | %d |", summary.total))
    print(string.format("| **Passed** | %d |", summary.passed))
    print(string.format("| **Failed** | %d |", summary.failed))
    print(string.format("| **Success Rate** | %.1f%% |", summary.success_rate))
    print(string.format("| **Duration** | %ds |", summary.duration))
    
    if test_data.coverage then
        print(string.format("| **Coverage** | %.1f%% |", test_data.coverage.percentage))
    end
    
    print("")
    
    if summary.failed > 0 and test_data.failures then
        print("### ❌ Failed Tests")
        print("")
        for _, failure in ipairs(test_data.failures) do
            print(string.format("- **%s** (%s)", failure.name, failure.suite or "Unknown Suite"))
            print(string.format("  ```\n  %s\n  ```", failure.error))
        end
        print("")
    end
    
    if test_data.coverage and test_data.coverage.percentage then
        local coverage_emoji = "🟢"
        if test_data.coverage.percentage < 80 then
            coverage_emoji = "🟡"
        end
        if test_data.coverage.percentage < 60 then
            coverage_emoji = "🔴"
        end
        
        print("### " .. coverage_emoji .. " Coverage Report")
        print("")
        print(string.format("**Overall Coverage: %.1f%%**", test_data.coverage.percentage))
        print(string.format("- Covered Lines: %d", test_data.coverage.covered_lines))
        print(string.format("- Total Lines: %d", test_data.coverage.total_lines))
        print("")
    end
end

local function generate_junit_xml(test_data, output_file)
    if not test_data or not test_data.summary then
        return
    end
    
    local summary = test_data.summary
    local xml_lines = {}
    
    table.insert(xml_lines, '<?xml version="1.0" encoding="UTF-8"?>')
    table.insert(xml_lines, string.format('<testsuite name="Church Management System Tests" tests="%d" failures="%d" time="%d" timestamp="%s">',
        summary.total, summary.failed, summary.duration, summary.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")))
    
    -- Add test cases (we'll need to enhance the test runner to provide individual test results)
    if test_data.failures then
        for _, failure in ipairs(test_data.failures) do
            table.insert(xml_lines, string.format('  <testcase name="%s" classname="%s" time="%.3f">',
                failure.name, failure.suite or "Unknown", failure.duration or 0))
            table.insert(xml_lines, string.format('    <failure message="%s">%s</failure>',
                failure.error:gsub('"', '&quot;'), failure.error:gsub('<', '&lt;'):gsub('>', '&gt;')))
            table.insert(xml_lines, '  </testcase>')
        end
    end
    
    -- Add passed tests (simplified - we'd need more detailed test data)
    local passed_count = summary.passed
    for i = 1, passed_count do
        table.insert(xml_lines, string.format('  <testcase name="Test_%d" classname="PassedTests" time="0.001"/>', i))
    end
    
    table.insert(xml_lines, '</testsuite>')
    
    local file = io.open(output_file, "w")
    if file then
        file:write(table.concat(xml_lines, "\n"))
        file:close()
        print("JUnit XML report saved to: " .. output_file)
    else
        print("Error: Could not save JUnit XML report")
    end
end

local function set_github_output(key, value)
    local github_output = os.getenv("GITHUB_OUTPUT")
    if github_output then
        local file = io.open(github_output, "a")
        if file then
            file:write(string.format("%s=%s\n", key, value))
            file:close()
        end
    end
end

-- Main execution
local function main()
    local args = arg or {}
    local results_file = "test-results.json"
    local format = "github"
    local output_file = nil
    
    for i, arg in ipairs(args) do
        if arg == "--file" and args[i + 1] then
            results_file = args[i + 1]
        elseif arg == "--format" and args[i + 1] then
            format = args[i + 1]
        elseif arg == "--output" and args[i + 1] then
            output_file = args[i + 1]
        elseif arg == "--help" then
            print("Usage: lua scripts/parse_test_results.lua [options]")
            print("")
            print("Options:")
            print("  --file FILE         Test results JSON file (default: test-results.json)")
            print("  --format FORMAT     Output format: github, junit (default: github)")
            print("  --output FILE       Output file for junit format")
            print("  --help              Show this help message")
            print("")
            return
        end
    end
    
    local test_data = parse_test_results(results_file)
    if not test_data then
        os.exit(1)
    end
    
    if format == "github" then
        generate_github_summary(test_data)
        
        -- Set GitHub Actions outputs
        if test_data.summary then
            set_github_output("total_tests", test_data.summary.total)
            set_github_output("passed_tests", test_data.summary.passed)
            set_github_output("failed_tests", test_data.summary.failed)
            set_github_output("success_rate", string.format("%.1f", test_data.summary.success_rate))
        end
        
        if test_data.coverage then
            set_github_output("coverage_percentage", string.format("%.1f", test_data.coverage.percentage))
        end
        
    elseif format == "junit" then
        if not output_file then
            output_file = "test-results.xml"
        end
        generate_junit_xml(test_data, output_file)
    end
    
    -- Exit with error code if tests failed
    if test_data.summary and test_data.summary.failed > 0 then
        os.exit(1)
    end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("parse_test_results%.lua$") then
    main()
end