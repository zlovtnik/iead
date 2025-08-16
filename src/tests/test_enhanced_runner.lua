-- src/tests/test_enhanced_runner.lua
-- Tests for the enhanced test runner functionality

local test_enhanced_runner = {}

function test_enhanced_runner.test_basic_assertions()
    local EnhancedTestRunner = require("src.tests.enhanced_test_runner")
    local runner = EnhancedTestRunner:new()
    
    -- Test assert_equal
    runner:assert_equal(1, 1, "Numbers should be equal")
    runner:assert_equal("hello", "hello", "Strings should be equal")
    
    -- Test assert_not_nil
    runner:assert_not_nil("test", "String should not be nil")
    runner:assert_not_nil({}, "Table should not be nil")
    
    -- Test assert_nil
    runner:assert_nil(nil, "Nil should be nil")
    
    -- Test assert_true/false
    runner:assert_true(true, "True should be true")
    runner:assert_false(false, "False should be false")
    
    -- Test assert_type
    runner:assert_type("hello", "string", "Should be string type")
    runner:assert_type(42, "number", "Should be number type")
    runner:assert_type({}, "table", "Should be table type")
end

function test_enhanced_runner.test_assert_match()
    local EnhancedTestRunner = require("src.tests.enhanced_test_runner")
    local runner = EnhancedTestRunner:new()
    
    runner:assert_match("hello world", "hello", "Should match pattern")
    runner:assert_match("test@example.com", "@", "Should contain @ symbol")
    runner:assert_match("123-456-7890", "%d%d%d%-%d%d%d%-%d%d%d%d", "Should match phone pattern")
end

function test_enhanced_runner.test_assert_contains()
    local EnhancedTestRunner = require("src.tests.enhanced_test_runner")
    local runner = EnhancedTestRunner:new()
    
    -- Test table contains
    local test_table = {"apple", "banana", "cherry"}
    runner:assert_contains(test_table, "banana", "Table should contain banana")
    
    -- Test string contains
    runner:assert_contains("hello world", "world", "String should contain world")
    runner:assert_contains("test@example.com", "@example", "Email should contain domain part")
end

function test_enhanced_runner.test_format_value()
    local EnhancedTestRunner = require("src.tests.enhanced_test_runner")
    local runner = EnhancedTestRunner:new()
    
    -- Test formatting different value types
    local formatted_nil = runner:format_value(nil)
    assert(formatted_nil == "nil", "Nil should format as 'nil'")
    
    local formatted_string = runner:format_value("hello")
    assert(formatted_string == '"hello"', "String should be quoted")
    
    local formatted_number = runner:format_value(42)
    assert(formatted_number == "42", "Number should format as string")
    
    local formatted_table = runner:format_value({a = 1, b = 2})
    assert(type(formatted_table) == "string", "Table should format as string")
end

function test_enhanced_runner.test_statistics_tracking()
    local EnhancedTestRunner = require("src.tests.enhanced_test_runner")
    local runner = EnhancedTestRunner:new()
    
    -- Initial stats should be zero
    assert(runner.stats.total == 0, "Initial total should be 0")
    assert(runner.stats.passed == 0, "Initial passed should be 0")
    assert(runner.stats.failed == 0, "Initial failed should be 0")
    
    -- Run a passing test
    runner:run_test("passing_test", function()
        runner:assert_true(true, "This should pass")
    end)
    
    assert(runner.stats.total == 1, "Total should be 1 after one test")
    assert(runner.stats.passed == 1, "Passed should be 1 after passing test")
    assert(runner.stats.failed == 0, "Failed should still be 0")
    
    -- Run a failing test
    runner:run_test("failing_test", function()
        runner:assert_true(false, "This should fail")
    end)
    
    assert(runner.stats.total == 2, "Total should be 2 after two tests")
    assert(runner.stats.passed == 1, "Passed should still be 1")
    assert(runner.stats.failed == 1, "Failed should be 1 after failing test")
end

return test_enhanced_runner