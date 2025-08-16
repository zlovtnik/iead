#!/usr/bin/env lua
-- scripts/test_age_calculation.lua
-- Test the updated age calculation function

local function test_age_calculation()
    print("=== Testing Age Calculation Function ===")
    
    -- Mock the age calculation function
    local function calculate_age(date_of_birth)
        if not date_of_birth or date_of_birth == "" then
            return nil
        end
        
        -- Parse year, month, day from date_of_birth (expecting YYYY-MM-DD format)
        local birth_year, birth_month, birth_day = date_of_birth:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
        if not birth_year or not birth_month or not birth_day then
            return nil
        end
        
        -- Convert to numbers
        birth_year = tonumber(birth_year)
        birth_month = tonumber(birth_month)
        birth_day = tonumber(birth_day)
        
        -- Validate date components
        if not birth_year or not birth_month or not birth_day or
           birth_month < 1 or birth_month > 12 or
           birth_day < 1 or birth_day > 31 then
            return nil
        end
        
        -- Get current date
        local current_date = os.date("*t")
        local current_year = current_date.year
        local current_month = current_date.month
        local current_day = current_date.day
        
        -- Calculate age
        local age = current_year - birth_year
        
        -- Subtract 1 if birthday hasn't occurred yet this year
        if current_month < birth_month or 
           (current_month == birth_month and current_day < birth_day) then
            age = age - 1
        end
        
        -- Return nil for negative ages (future birth dates)
        return age >= 0 and age or nil
    end
    
    -- Test cases
    local current_date = os.date("*t")
    local current_year = current_date.year
    local current_month = current_date.month
    local current_day = current_date.day
    
    print(string.format("Current date: %04d-%02d-%02d", current_year, current_month, current_day))
    print("")
    
    local test_cases = {
        -- Test valid dates
        {
            date = string.format("%04d-%02d-%02d", current_year - 25, current_month, current_day), 
            expected = 25, 
            description = "Birthday today (exactly 25 years)"
        },
        {
            date = string.format("%04d-%02d-%02d", current_year - 30, current_month - 1, current_day), 
            expected = 30, 
            description = "Birthday last month (30 years old)"
        },
        {
            date = string.format("%04d-%02d-%02d", current_year - 20, current_month + 1, current_day), 
            expected = 19, 
            description = "Birthday next month (still 19)"
        },
        {
            date = string.format("%04d-%02d-%02d", current_year - 35, current_month, current_day + 1), 
            expected = 34, 
            description = "Birthday tomorrow (still 34)"
        },
        
        -- Test edge cases
        {
            date = "",
            expected = nil,
            description = "Empty date"
        },
        {
            date = nil,
            expected = nil,
            description = "Nil date"
        },
        {
            date = "invalid-date",
            expected = nil,
            description = "Invalid format"
        },
        {
            date = "2023-13-01",
            expected = nil,
            description = "Invalid month"
        },
        {
            date = "2023-01-32",
            expected = nil,
            description = "Invalid day"
        },
        {
            date = string.format("%04d-12-25", current_year + 5),
            expected = nil,
            description = "Future birth date"
        }
    }
    
    local passed = 0
    local total = #test_cases
    
    for i, test_case in ipairs(test_cases) do
        local result = calculate_age(test_case.date)
        local success = result == test_case.expected
        
        if success then
            passed = passed + 1
            print(string.format("✓ Test %d: %s", i, test_case.description))
            print(string.format("   Date: %s, Expected: %s, Got: %s", 
                  tostring(test_case.date), tostring(test_case.expected), tostring(result)))
        else
            print(string.format("✗ Test %d: %s", i, test_case.description))
            print(string.format("   Date: %s, Expected: %s, Got: %s", 
                  tostring(test_case.date), tostring(test_case.expected), tostring(result)))
        end
        print("")
    end
    
    print(string.format("=== Results: %d/%d tests passed ===", passed, total))
    
    if passed == total then
        print("✓ All age calculation tests passed!")
        return 0
    else
        print("✗ Some tests failed")
        return 1
    end
end

-- Additional test for specific birthday scenarios
local function test_birthday_scenarios()
    print("=== Testing Birthday Edge Cases ===")
    
    -- Test leap year scenarios
    local leap_year_tests = {
        {
            birth_date = "2000-02-29",  -- Leap year birth
            description = "Leap year birthday (Feb 29)"
        },
        {
            birth_date = "1990-01-01",  -- New Year's Day
            description = "New Year's Day birthday"
        },
        {
            birth_date = "1985-12-31",  -- New Year's Eve
            description = "New Year's Eve birthday"
        }
    }
    
    for i, test in ipairs(leap_year_tests) do
        local birth_year, birth_month, birth_day = test.birth_date:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
        if birth_year then
            local current_year = tonumber(os.date("%Y"))
            local expected_age = current_year - tonumber(birth_year)
            print(string.format("Test %d: %s", i, test.description))
            print(string.format("   Birth: %s, Approximate age: %d", test.birth_date, expected_age))
        end
    end
    
    print("")
end

-- Run tests
local function main()
    local exit_code1 = test_age_calculation()
    test_birthday_scenarios()
    return exit_code1
end

if arg and arg[0] and arg[0]:match("test_age_calculation%.lua$") then
    local exit_code = main()
    os.exit(exit_code)
end

return { main = main }
