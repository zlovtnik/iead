-- src/tests/test_repository_pattern.lua
-- Comprehensive test suite for repository pattern implementation

local BaseRepository = require("src.infrastructure.db.base_repository")
local UserRepository = require("src.infrastructure.repositories.user_repository")
local MemberRepository = require("src.infrastructure.repositories.member_repository")
local EventRepository = require("src.infrastructure.repositories.event_repository")
local DonationRepository = require("src.infrastructure.repositories.donation_repository")
local AttendanceRepository = require("src.infrastructure.repositories.attendance_repository")
local TitheRepository = require("src.infrastructure.repositories.tithe_repository")
local VolunteerRepository = require("src.infrastructure.repositories.volunteer_repository")
local EventService = require("src.application.services.event_service")

-- Test utilities
local test_utils = {
    passed = 0,
    failed = 0,
    tests = {}
}

function test_utils.assert_equal(actual, expected, message)
    if actual == expected then
        test_utils.passed = test_utils.passed + 1
        print("✓ " .. (message or "Test passed"))
        return true
    else
        test_utils.failed = test_utils.failed + 1
        print("✗ " .. (message or "Test failed") .. " - Expected: " .. tostring(expected) .. ", Got: " .. tostring(actual))
        return false
    end
end

function test_utils.assert_not_nil(value, message)
    if value ~= nil then
        test_utils.passed = test_utils.passed + 1
        print("✓ " .. (message or "Value is not nil"))
        return true
    else
        test_utils.failed = test_utils.failed + 1
        print("✗ " .. (message or "Value should not be nil"))
        return false
    end
end

function test_utils.assert_nil(value, message)
    if value == nil then
        test_utils.passed = test_utils.passed + 1
        print("✓ " .. (message or "Value is nil"))
        return true
    else
        test_utils.failed = test_utils.failed + 1
        print("✗ " .. (message or "Value should be nil") .. " - Got: " .. tostring(value))
        return false
    end
end

function test_utils.assert_error(func, message)
    local success, err = pcall(func)
    if not success then
        test_utils.passed = test_utils.passed + 1
        print("✓ " .. (message or "Function threw expected error"))
        return true
    else
        test_utils.failed = test_utils.failed + 1
        print("✗ " .. (message or "Function should have thrown error"))
        return false
    end
end

function test_utils.run_test(name, test_func)
    print("\n--- Running test: " .. name .. " ---")
    table.insert(test_utils.tests, name)
    test_func()
end

function test_utils.print_summary()
    print("\n" .. string.rep("=", 50))
    print("TEST SUMMARY")
    print(string.rep("=", 50))
    print("Total tests run: " .. #test_utils.tests)
    print("Assertions passed: " .. test_utils.passed)
    print("Assertions failed: " .. test_utils.failed)
    print("Success rate: " .. string.format("%.1f%%", (test_utils.passed / (test_utils.passed + test_utils.failed)) * 100))
    
    if test_utils.failed == 0 then
        print("🎉 All tests passed!")
    else
        print("❌ Some tests failed")
    end
    print(string.rep("=", 50))
end

-- Test BaseRepository
test_utils.run_test("BaseRepository Creation", function()
    local schema = {
        name = {type = "string", required = true},
        age = {type = "number", required = false}
    }
    
    local repo = BaseRepository.new("test_table", schema)
    test_utils.assert_not_nil(repo, "Repository should be created")
    test_utils.assert_equal(repo.table_name, "test_table", "Table name should be set")
    test_utils.assert_not_nil(repo.schema, "Schema should be set")
end)

test_utils.run_test("BaseRepository Validation", function()
    local schema = {
        name = {type = "string", required = true, max_length = 10},
        age = {type = "number", required = false}
    }
    
    local repo = BaseRepository.new("test_table", schema)
    
    -- Test valid data
    local valid_data = {name = "John", age = 25}
    local is_valid, errors = repo:validate(valid_data)
    test_utils.assert_equal(is_valid, true, "Valid data should pass validation")
    test_utils.assert_equal(#errors, 0, "Valid data should have no errors")
    
    -- Test missing required field
    local invalid_data = {age = 25}
    is_valid, errors = repo:validate(invalid_data)
    test_utils.assert_equal(is_valid, false, "Missing required field should fail validation")
    test_utils.assert_equal(#errors > 0, true, "Should have validation errors")
    
    -- Test string too long
    local long_name_data = {name = "ThisNameIsTooLong", age = 25}
    is_valid, errors = repo:validate(long_name_data)
    test_utils.assert_equal(is_valid, false, "String too long should fail validation")
    
    -- Test wrong type
    local wrong_type_data = {name = "John", age = "not_a_number"}
    is_valid, errors = repo:validate(wrong_type_data)
    test_utils.assert_equal(is_valid, false, "Wrong type should fail validation")
end)

-- Test UserRepository
test_utils.run_test("UserRepository Creation", function()
    local user_repo = UserRepository.new()
    test_utils.assert_not_nil(user_repo, "UserRepository should be created")
    test_utils.assert_not_nil(user_repo.base, "UserRepository should have base repository")
end)

test_utils.run_test("UserRepository Password Hashing", function()
    local user_repo = UserRepository.new()
    
    local password = "test_password_123"
    local hashed = user_repo:hash_password(password)
    
    test_utils.assert_not_nil(hashed, "Password should be hashed")
    test_utils.assert_equal(hashed ~= password, true, "Hashed password should be different from original")
    
    -- Test password verification
    local is_valid = user_repo:verify_password(password, hashed)
    test_utils.assert_equal(is_valid, true, "Password verification should work")
    
    local is_invalid = user_repo:verify_password("wrong_password", hashed)
    test_utils.assert_equal(is_invalid, false, "Wrong password should not verify")
end)

-- Test MemberRepository
test_utils.run_test("MemberRepository Creation", function()
    local member_repo = MemberRepository.new()
    test_utils.assert_not_nil(member_repo, "MemberRepository should be created")
    test_utils.assert_not_nil(member_repo.base, "MemberRepository should have base repository")
end)

test_utils.run_test("MemberRepository Age Calculation", function()
    local member_repo = MemberRepository.new()
    
    -- Test age calculation for someone born 25 years ago
    local birth_year = tonumber(os.date("%Y")) - 25
    local birth_date = birth_year .. "-06-15"
    
    local age = member_repo:calculate_age(birth_date)
    -- Age should be approximately 25 (might be 24 or 25 depending on current date)
    test_utils.assert_equal(age >= 24 and age <= 25, true, "Age calculation should be accurate")
end)

-- Test EventRepository
test_utils.run_test("EventRepository Creation", function()
    local event_repo = EventRepository.new()
    test_utils.assert_not_nil(event_repo, "EventRepository should be created")
    test_utils.assert_not_nil(event_repo.base, "EventRepository should have base repository")
end)

-- Test DonationRepository
test_utils.run_test("DonationRepository Creation", function()
    local donation_repo = DonationRepository.new()
    test_utils.assert_not_nil(donation_repo, "DonationRepository should be created")
    test_utils.assert_not_nil(donation_repo.base, "DonationRepository should have base repository")
end)

-- Test AttendanceRepository
test_utils.run_test("AttendanceRepository Creation", function()
    local attendance_repo = AttendanceRepository.new()
    test_utils.assert_not_nil(attendance_repo, "AttendanceRepository should be created")
    test_utils.assert_not_nil(attendance_repo.base, "AttendanceRepository should have base repository")
end)

-- Test TitheRepository
test_utils.run_test("TitheRepository Creation", function()
    local tithe_repo = TitheRepository.new()
    test_utils.assert_not_nil(tithe_repo, "TitheRepository should be created")
    test_utils.assert_not_nil(tithe_repo.base, "TitheRepository should have base repository")
end)

-- Test VolunteerRepository
test_utils.run_test("VolunteerRepository Creation", function()
    local volunteer_repo = VolunteerRepository.new()
    test_utils.assert_not_nil(volunteer_repo, "VolunteerRepository should be created")
    test_utils.assert_not_nil(volunteer_repo.base, "VolunteerRepository should have base repository")
end)

-- Test EventService
test_utils.run_test("EventService Creation", function()
    local event_service = EventService.new()
    test_utils.assert_not_nil(event_service, "EventService should be created")
    test_utils.assert_not_nil(event_service.event_repo, "EventService should have event repository")
    test_utils.assert_not_nil(event_service.attendance_repo, "EventService should have attendance repository")
end)

-- Test integration between repositories
test_utils.run_test("Repository Integration Test", function()
    local member_repo = MemberRepository.new()
    local event_repo = EventRepository.new()
    local attendance_repo = AttendanceRepository.new()
    
    -- All repositories should be independent but compatible
    test_utils.assert_not_nil(member_repo, "Member repository should be created")
    test_utils.assert_not_nil(event_repo, "Event repository should be created")
    test_utils.assert_not_nil(attendance_repo, "Attendance repository should be created")
    
    -- They should all have the same base interface
    test_utils.assert_not_nil(member_repo.find_all, "Member repo should have find_all method")
    test_utils.assert_not_nil(event_repo.find_all, "Event repo should have find_all method")
    test_utils.assert_not_nil(attendance_repo.find_all, "Attendance repo should have find_all method")
end)

-- Test query building
test_utils.run_test("Query Building", function()
    local schema = {
        name = {type = "string", required = true},
        age = {type = "number", required = false}
    }
    
    local repo = BaseRepository.new("test_table", schema)
    
    -- Test simple query building
    local query, params = repo:build_select_query({name = "John"})
    test_utils.assert_not_nil(query, "Query should be built")
    test_utils.assert_not_nil(params, "Parameters should be provided")
    test_utils.assert_equal(#params, 1, "Should have one parameter")
    test_utils.assert_equal(params[1], "John", "Parameter should match condition value")
    
    -- Test multiple conditions
    query, params = repo:build_select_query({name = "John", age = 25})
    test_utils.assert_equal(#params, 2, "Should have two parameters")
end)

-- Test pagination
test_utils.run_test("Pagination Options", function()
    local schema = {name = {type = "string", required = true}}
    local repo = BaseRepository.new("test_table", schema)
    
    local options = {
        page = 2,
        per_page = 10,
        order_by = "name",
        order_direction = "DESC"
    }
    
    local query, params = repo:build_select_query({}, options)
    test_utils.assert_not_nil(query, "Paginated query should be built")
    
    -- Check that query contains ORDER BY and LIMIT clauses
    test_utils.assert_equal(string.find(query, "ORDER BY") ~= nil, true, "Query should contain ORDER BY")
    test_utils.assert_equal(string.find(query, "LIMIT") ~= nil, true, "Query should contain LIMIT")
end)

-- Test error handling
test_utils.run_test("Error Handling", function()
    local schema = {name = {type = "string", required = true}}
    local repo = BaseRepository.new("test_table", schema)
    
    -- Test validation error
    test_utils.assert_error(function()
        repo:validate({}) -- Missing required field
    end, "Should throw validation error for missing required field")
    
    -- Test invalid schema
    test_utils.assert_error(function()
        BaseRepository.new("test", {invalid_field = {type = "invalid_type"}})
    end, "Should throw error for invalid schema type")
end)

-- Run all tests
print("🧪 Repository Pattern Test Suite")
print("=" .. string.rep("=", 49))

-- Print test summary
test_utils.print_summary()

-- Return test results for external use
return {
    passed = test_utils.passed,
    failed = test_utils.failed,
    total_tests = #test_utils.tests,
    success_rate = (test_utils.passed / (test_utils.passed + test_utils.failed)) * 100
}
