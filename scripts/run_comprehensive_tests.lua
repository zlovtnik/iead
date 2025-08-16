#!/usr/bin/env luajit
-- scripts/run_comprehensive_tests.lua
-- Comprehensive test runner with coverage and structured output

local EnhancedTestRunner = require("src.tests.enhanced_test_runner")

-- Parse command line arguments
local args = {...}
local options = {
    output_format = "console",
    output_file = nil,
    coverage_enabled = false,
    verbose = false,
    filter = nil
}

for i, arg in ipairs(args) do
    if arg == "--json" then
        options.output_format = "json"
    elseif arg == "--output" and args[i + 1] then
        options.output_file = args[i + 1]
    elseif arg == "--coverage" then
        options.coverage_enabled = true
    elseif arg == "--verbose" or arg == "-v" then
        options.verbose = true
    elseif arg == "--filter" and args[i + 1] then
        options.filter = args[i + 1]
    elseif arg == "--help" then
        print("Usage: lua scripts/run_comprehensive_tests.lua [options]")
        print("")
        print("Options:")
        print("  --json              Output results in JSON format")
        print("  --output FILE       Save results to file")
        print("  --coverage          Enable coverage tracking")
        print("  --verbose, -v       Verbose output")
        print("  --filter PATTERN    Run only tests matching pattern")
        print("  --help              Show this help message")
        print("")
        return
    end
end

-- Initialize test runner
local runner = EnhancedTestRunner:new(options)

-- Test suites to run
local test_suites = {
    {
        name = "Member Model Tests",
        module = "src.tests.test_member",
        setup = function()
            runner:track_coverage("src/models/member.lua")
        end
    },
    {
        name = "Event Model Tests", 
        module = "src.tests.test_event",
        setup = function()
            runner:track_coverage("src/models/event.lua")
        end
    },
    {
        name = "Attendance Model Tests",
        module = "src.tests.test_attendance",
        setup = function()
            runner:track_coverage("src/models/attendance.lua")
        end
    },
    {
        name = "Donation Model Tests",
        module = "src.tests.test_donation", 
        setup = function()
            runner:track_coverage("src/models/donation.lua")
        end
    },
    {
        name = "Tithe Model Tests",
        module = "src.tests.test_tithe",
        setup = function()
            runner:track_coverage("src/models/tithe.lua")
        end
    },
    {
        name = "Volunteer Model Tests",
        module = "src.tests.test_volunteer",
        setup = function()
            runner:track_coverage("src/models/volunteer.lua")
        end
    },
    {
        name = "User Model Tests",
        module = "src.tests.test_user",
        setup = function()
            runner:track_coverage("src/models/user.lua")
        end
    },
    {
        name = "Session Model Tests",
        module = "src.tests.test_session",
        setup = function()
            runner:track_coverage("src/models/session.lua")
        end
    },
    {
        name = "HTTP Utils Tests",
        module = "src.tests.test_http_utils",
        setup = function()
            runner:track_coverage("src/utils/http_utils.lua")
        end
    },
    {
        name = "Validation Tests",
        module = "src.tests.test_validation",
        setup = function()
            runner:track_coverage("src/application/validators/input_validator.lua")
        end
    },
    {
        name = "DateTime Tests",
        module = "src.tests.test_datetime",
        setup = function()
            runner:track_coverage("src/utils/datetime.lua")
        end
    },
    {
        name = "Controller Tests",
        module = "src.tests.test_controllers",
        setup = function()
            runner:track_coverage("src/controllers/member_controller.lua")
            runner:track_coverage("src/controllers/auth_controller.lua")
        end
    },
    {
        name = "Auth Middleware Tests",
        module = "src.tests.test_auth_middleware",
        setup = function()
            runner:track_coverage("src/application/middlewares/auth_middleware.lua")
        end
    },
    {
        name = "API Layer Tests",
        module = "src.tests.test_api_layer",
        setup = function()
            runner:track_coverage("src/application/middlewares/api_middleware.lua")
            runner:track_coverage("src/application/middlewares/api_response.lua")
        end
    },
    {
        name = "Security Tests",
        module = "src.tests.test_security",
        setup = function()
            runner:track_coverage("src/utils/security.lua")
        end
    },
    {
        name = "Rate Limiter Tests",
        module = "src.tests.test_rate_limiter",
        setup = function()
            runner:track_coverage("src/utils/rate_limiter.lua")
        end
    }
}

-- Setup test environment
if options.output_format == "console" then
    print("🧪 Church Management System - Comprehensive Test Suite")
    print("=" .. string.rep("=", 55))
    print("Setting up test environment...")
end

local cleanup = runner:setup_test_db()
if not cleanup then
    print("❌ Failed to setup test database")
    os.exit(1)
end

-- Run test suites
local total_suites = 0
local passed_suites = 0

for _, suite_info in ipairs(test_suites) do
    -- Apply filter if specified
    if not options.filter or suite_info.name:lower():find(options.filter:lower()) then
        total_suites = total_suites + 1
        
        local success, test_module = pcall(require, suite_info.module)
        if success and test_module then
            local suite_options = {
                setup = suite_info.setup,
                teardown = suite_info.teardown
            }
            
            local suite_stats = runner:run_suite(suite_info.name, test_module, suite_options)
            if suite_stats.failed == 0 then
                passed_suites = passed_suites + 1
            end
        else
            if options.output_format == "console" then
                print("⚠️  Failed to load test suite: " .. suite_info.name)
                if options.verbose then
                    print("   Error: " .. (test_module or "unknown error"))
                end
            end
        end
    end
end

-- Print final results
runner:print_results()

-- Additional summary for console output
if options.output_format == "console" then
    print("\n" .. string.rep("=", 60))
    print(string.format("Test Suites: %d/%d passed", passed_suites, total_suites))
    
    if runner.stats.failed == 0 then
        print("🎉 All tests passed!")
    else
        print("❌ Some tests failed")
    end
    
    print("\nFor CI integration:")
    print("  - JSON output: --json --output test-results.json")
    print("  - Coverage: --coverage")
    print("  - Verbose: --verbose")
end

-- Cleanup
if options.output_format == "console" then
    print("\nCleaning up test environment...")
end
cleanup()

-- Exit with appropriate code
if runner.stats.failed > 0 then
    os.exit(1)
else
    os.exit(0)
end