#!/usr/bin/env luajit
-- scripts/validate_functional_setup.lua
-- Final validation of LuaJIT and functional programming setup

local function test_core_functional()
    local fun = require("src.utils.functional")
    
    -- Test basic operations
    local numbers = {1, 2, 3, 4, 5}
    local doubled = fun.map_table(function(x) return x * 2 end, numbers)
    local evens = fun.filter_table(function(x) return x % 2 == 0 end, doubled)
    local sum = fun.reduce_table(function(acc, x) return acc + x end, 0, evens)
    
    assert(#doubled == 5, "Map operation failed")
    assert(#evens == 5, "Filter operation failed") 
    assert(sum == 30, "Reduce operation failed")
    
    print("✓ Core functional operations working")
    return true
end

local function test_advanced_functional()
    local advanced = require("src.utils.advanced_functional")
    
    -- Test Maybe monad
    local maybe_result = advanced.Maybe(10)
        :map(function(x) return x * 2 end)
        :map(function(x) return x + 5 end)
        :get_or_else(0)
    
    assert(maybe_result == 25, "Maybe monad failed")
    
    -- Test partial application
    local add = function(a, b, c) return a + b + c end
    local add_five = advanced.partial(add, 5, advanced._, advanced._)
    local result = add_five(3, 2)
    
    assert(result == 10, "Partial application failed")
    
    print("✓ Advanced functional patterns working")
    return true
end

local function test_luafun_integration()
    local fun_core = require("fun")
    
    -- Test native luafun
    local range_sum = fun_core.reduce(function(acc, x) return acc + x end, 0, fun_core.range(1, 5))
    assert(range_sum == 15, "luafun integration failed") -- 1+2+3+4+5 = 15
    
    print("✓ luafun integration working")
    return true
end

local function main()
    print("=== LuaJIT & Functional Programming Validation ===")
    print("")
    
    print("Testing core functional operations...")
    test_core_functional()
    
    print("Testing advanced functional patterns...")
    test_advanced_functional()
    
    print("Testing luafun integration...")
    test_luafun_integration()
    
    print("")
    print("=== All Tests Passed ===")
    print("✓ LuaJIT runtime operational")
    print("✓ luafun library integrated")
    print("✓ Functional programming patterns available")
    print("✓ Advanced monadic operations working")
    print("✓ Church Management System ready for functional programming")
    print("")
    print("To run the full demonstration:")
    print("  luajit scripts/functional_programming_demo.lua")
    print("")
    print("To run tests:")
    print("  luajit scripts/run_comprehensive_tests.lua")
    
    return 0
end

if arg and arg[0] and arg[0]:match("validate_functional_setup%.lua$") then
    local exit_code = main()
    os.exit(exit_code)
end

return { main = main }
