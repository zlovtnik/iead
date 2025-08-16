#!/usr/bin/env lua
-- scripts/test_both_runtimes.lua
-- Test that our functional programming setup works with both Lua 5.4 and LuaJIT

local function detect_runtime()
    local version = _VERSION
    local is_luajit = type(jit) == "table"
    
    if is_luajit then
        return "LuaJIT " .. jit.version
    else
        return version
    end
end

local function test_functional_basic()
    print("Testing basic functional operations...")
    
    local fun = require("src.utils.functional")
    
    -- Test map_table
    local numbers = {1, 2, 3, 4, 5}
    local doubled = fun.map_table(function(x) return x * 2 end, numbers)
    assert(#doubled == 5 and doubled[1] == 2 and doubled[5] == 10, "map_table failed")
    
    -- Test filter_table
    local evens = fun.filter_table(function(x) return x % 2 == 0 end, doubled)
    assert(#evens == 5, "filter_table failed")
    
    -- Test reduce_table
    local sum = fun.reduce_table(function(acc, x) return acc + x end, 0, evens)
    assert(sum == 30, "reduce_table failed")
    
    -- Test pluck
    local people = {
        {name = "Alice", age = 30},
        {name = "Bob", age = 25},
        {name = "Charlie", age = 35}
    }
    local names = fun.pluck("name", people)
    assert(#names == 3 and names[1] == "Alice", "pluck failed")
    
    print("✓ Basic functional operations working")
    return true
end

local function test_luafun_direct()
    print("Testing direct luafun usage...")
    
    local luafun = require("fun")
    
    -- Test range and reduce
    local sum = luafun.reduce(function(acc, x) return acc + x end, 0, luafun.range(1, 5))
    assert(sum == 15, "luafun direct usage failed")
    
    -- Test map and totable
    local doubled = luafun.totable(luafun.map(function(x) return x * 2 end, {1, 2, 3}))
    assert(#doubled == 3 and doubled[1] == 2, "luafun map failed")
    
    print("✓ Direct luafun usage working")
    return true
end

local function test_composition()
    print("Testing function composition...")
    
    local fun = require("src.utils.functional")
    
    -- Test pipe
    local result = fun.pipe(
        {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
        function(list) return fun.filter_table(function(x) return x % 2 == 0 end, list) end,
        function(list) return fun.map_table(function(x) return x * x end, list) end,
        function(list) return fun.reduce_table(function(acc, x) return acc + x end, 0, list) end
    )
    -- Even numbers: 2,4,6,8,10 -> squares: 4,16,36,64,100 -> sum: 220
    assert(result == 220, "pipe composition failed")
    
    print("✓ Function composition working")
    return true
end

local function test_advanced_features()
    print("Testing advanced functional features...")
    
    local advanced = require("src.utils.advanced_functional")
    
    -- Test Maybe monad
    local maybe_result = advanced.Maybe(10)
        :map(function(x) return x * 2 end)
        :filter(function(x) return x > 15 end)
        :map(function(x) return x + 5 end)
        :get_or_else(0)
    
    assert(maybe_result == 25, "Maybe monad failed")
    
    -- Test Result monad
    local success_result = advanced.Success("hello")
        :map(string.upper)
        :map(function(s) return s .. " WORLD" end)
    
    assert(success_result.value == "HELLO WORLD", "Result monad failed")
    
    print("✓ Advanced functional features working")
    return true
end

local function main()
    local runtime = detect_runtime()
    print("=== Functional Programming Test ===")
    print("Runtime: " .. runtime)
    print("Lua Path: " .. (package.path or "default"))
    print("")
    
    local tests = {
        test_functional_basic,
        test_luafun_direct,
        test_composition,
        test_advanced_features
    }
    
    local passed = 0
    local total = #tests
    
    for i, test in ipairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            print("✗ Test " .. i .. " failed: " .. tostring(err))
        end
    end
    
    print("")
    print("=== Results ===")
    print(string.format("Passed: %d/%d tests", passed, total))
    print("Runtime: " .. runtime)
    
    if passed == total then
        print("✓ All functional programming features working correctly!")
        return 0
    else
        print("✗ Some tests failed")
        return 1
    end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("test_both_runtimes%.lua$") then
    local exit_code = main()
    os.exit(exit_code)
end

return { main = main }
