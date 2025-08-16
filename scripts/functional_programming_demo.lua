#!/usr/bin/env luajit
-- scripts/functional_programming_demo.lua
-- Comprehensive demonstration of functional programming in the Church Management System

local fun = require("src.utils.functional")
local advanced = require("src.utils.advanced_functional")

local demo = {}

-- Sample data for demonstrations
local sample_members = {
    {id = 1, name = "John Doe", age = 35, email = "john@example.com", status = "active", membership_date = "2020-01-15", donation_total = 1200},
    {id = 2, name = "Jane Smith", age = 28, email = "jane@example.com", status = "active", membership_date = "2021-03-10", donation_total = 800},
    {id = 3, name = "Bob Johnson", age = 45, email = "bob@example.com", status = "inactive", membership_date = "2019-06-20", donation_total = 2100},
    {id = 4, name = "Alice Williams", age = 22, email = "alice@example.com", status = "active", membership_date = "2022-08-05", donation_total = 450},
    {id = 5, name = "Charlie Brown", age = 67, email = "charlie@example.com", status = "active", membership_date = "2018-12-01", donation_total = 3200}
}

function demo.basic_functional_operations()
    print("=== Basic Functional Operations ===")
    
    -- Map: Transform data
    local ages = fun.map_table(function(member) return member.age end, sample_members)
    print("Ages:", table.concat(ages, ", "))
    
    -- Filter: Select data
    local active_members = fun.filter_table(function(member) return member.status == "active" end, sample_members)
    print("Active members count:", #active_members)
    
    -- Reduce: Aggregate data
    local total_donations = fun.reduce_table(function(acc, member) return acc + member.donation_total end, 0, sample_members)
    print("Total donations: $" .. total_donations)
    
    -- Composition
    local young_active_count = fun.pipe(
        sample_members,
        function(members) return fun.filter_table(function(m) return m.status == "active" end, members) end,
        function(members) return fun.filter_table(function(m) return m.age < 30 end, members) end,
        function(members) return #members end
    )
    print("Young active members:", young_active_count)
    
    print()
end

function demo.advanced_transformations()
    print("=== Advanced Transformations ===")
    
    -- Complex data processing pipeline
    local member_analytics = fun.pipe(
        sample_members,
        -- Add calculated fields
        function(members)
            return fun.map_table(function(member)
                local enhanced = {}
                for k, v in pairs(member) do
                    enhanced[k] = v
                end
                enhanced.age_group = member.age < 30 and "young" or (member.age < 50 and "middle" or "senior")
                enhanced.donation_category = member.donation_total < 500 and "low" or (member.donation_total < 1500 and "medium" or "high")
                return enhanced
            end, members)
        end,
        -- Group by age group
        function(members)
            return fun.group_by_func(function(member) return member.age_group end, members)
        end
    )
    
    print("Member analytics by age group:")
    for group, members in pairs(member_analytics) do
        local avg_donation = fun.average(fun.pluck("donation_total", members))
        print(string.format("  %s: %d members, avg donation: $%.2f", group, #members, avg_donation))
    end
    
    print()
end

function demo.monadic_operations()
    print("=== Monadic Operations ===")
    
    -- Maybe monad for safe operations
    local safe_division = function(a, b)
        return advanced.Maybe(b ~= 0 and a / b or nil)
    end
    
    local result1 = safe_division(10, 2):map(function(x) return x * 2 end):get_or_else(0)
    local result2 = safe_division(10, 0):map(function(x) return x * 2 end):get_or_else(0)
    
    print("Safe division 10/2 * 2:", result1)
    print("Safe division 10/0 * 2:", result2)
    
    -- Result monad for error handling
    local parse_member = function(data)
        if not data.name or data.name == "" then
            return advanced.Error("Name is required")
        end
        if not data.email or not data.email:match("@") then
            return advanced.Error("Valid email is required")
        end
        return advanced.Success({
            name = data.name,
            email = data.email:lower(),
            status = data.status or "active"
        })
    end
    
    local valid_result = parse_member({name = "Test User", email = "test@example.com"})
        :map(function(member) member.processed = true; return member end)
    
    local invalid_result = parse_member({name = "", email = "invalid"})
        :map(function(member) member.processed = true; return member end)
    
    print("Valid member parsing:", valid_result.is_success and "Success" or "Error: " .. valid_result.error)
    print("Invalid member parsing:", invalid_result.is_success and "Success" or "Error: " .. invalid_result.error)
    
    print()
end

function demo.lazy_evaluation()
    print("=== Lazy Evaluation ===")
    
    local expensive_computation = advanced.Lazy(function()
        print("  Computing expensive result...")
        return 42 * 42
    end)
    
    local lazy_chain = expensive_computation
        :map(function(x) print("  Doubling result..."); return x * 2 end)
        :map(function(x) print("  Adding 10..."); return x + 10 end)
    
    print("Lazy computation created (not executed yet)")
    print("Result:", lazy_chain:force())
    print("Result (cached):", lazy_chain:force())
    
    print()
end

function demo.memoization()
    print("=== Memoization ===")
    
    local call_count = 0
    local fibonacci
    fibonacci = advanced.memoize(function(n)
        call_count = call_count + 1
        if n <= 1 then return n end
        return fibonacci(n-1) + fibonacci(n-2)
    end)
    
    print("Computing fibonacci(10)...")
    local result = fibonacci(10)
    print("Result:", result, "Function calls:", call_count)
    
    call_count = 0
    print("Computing fibonacci(10) again (memoized)...")
    result = fibonacci(10)
    print("Result:", result, "Function calls:", call_count)
    
    print()
end

function demo.partial_application()
    print("=== Partial Application ===")
    
    local add = function(a, b, c) return a + b + c end
    local add_five = advanced.partial(add, 5, advanced._, advanced._)
    local add_five_and_ten = advanced.partial(add, 5, 10, advanced._)
    
    print("add(5, 3, 2):", add_five(3, 2))
    print("add(5, 10, 7):", add_five_and_ten(7))
    
    -- Partial application with member operations
    local filter_by_status = advanced.partial(fun.filter_table, advanced._, sample_members)
    local active_filter = function(member) return member.status == "active" end
    local active_members = filter_by_status(active_filter)
    
    print("Active members (partial application):", #active_members)
    
    print()
end

function demo.lens_operations()
    print("=== Lens Operations ===")
    
    local member = {name = "John Doe", contact = {email = "john@example.com", phone = "123-456-7890"}}
    
    local name_lens = advanced.prop("name")
    local email_lens = advanced.prop("contact"):compose(advanced.prop("email"))
    
    print("Original member name:", name_lens:get(member))
    print("Original member email:", email_lens:get(member))
    
    local updated_member = name_lens:set("John Smith", member)
    local updated_email = email_lens:set("johnsmith@example.com", updated_member)
    
    print("Updated member name:", name_lens:get(updated_email))
    print("Updated member email:", email_lens:get(updated_email))
    
    print()
end

function demo.transducers()
    print("=== Transducers ===")
    
    local numbers = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    
    -- Compose transducers
    local xform = advanced.comp(
        advanced.filtering(function(x) return x % 2 == 0 end), -- even numbers
        advanced.mapping(function(x) return x * x end),        -- square them
        advanced.taking(3)                                     -- take first 3
    )
    
    local result = advanced.transduce(
        xform,
        function(acc, x) table.insert(acc, x); return acc end,
        {},
        numbers
    )
    
    print("Transducer result (even squares, take 3):", table.concat(result, ", "))
    
    print()
end

function demo.church_management_examples()
    print("=== Church Management System Examples ===")
    
    -- Complex member reporting using functional composition
    local generate_member_report = fun.compose(
        -- Final formatting
        function(stats)
            return string.format(
                "Report: %d total members, %d active (%.1f%%), avg age: %.1f, total donations: $%.2f",
                stats.total_count,
                stats.active_count,
                stats.active_percentage,
                stats.average_age,
                stats.total_donations
            )
        end,
        -- Calculate statistics
        function(processed_members)
            local active_members = fun.filter_table(function(m) return m.status == "active" end, processed_members)
            local ages = fun.pluck("age", processed_members)
            local donations = fun.pluck("donation_total", processed_members)
            
            return {
                total_count = #processed_members,
                active_count = #active_members,
                active_percentage = (#active_members / #processed_members) * 100,
                average_age = fun.average(ages),
                total_donations = fun.sum(donations)
            }
        end,
        -- Data validation and cleaning
        function(raw_members)
            return fun.filter_table(function(member)
                return member.name and member.age and member.donation_total
            end, raw_members)
        end
    )
    
    local report = generate_member_report(sample_members)
    print(report)
    
    -- Member segmentation using functional approach
    local segment_members = function(members)
        local segments = {
            high_value = fun.filter_table(function(m) return m.donation_total > 2000 end, members),
            new_members = fun.filter_table(function(m) return m.membership_date > "2022-01-01" end, members),
            senior_members = fun.filter_table(function(m) return m.age >= 60 end, members),
            young_professionals = fun.filter_table(function(m) return m.age >= 25 and m.age < 40 and m.status == "active" end, members)
        }
        
        return fun.map_pairs(function(segment_name, segment_members)
            return segment_name, {
                count = #segment_members,
                names = fun.pluck("name", segment_members),
                avg_donation = fun.average(fun.pluck("donation_total", segment_members))
            }
        end, segments)
    end
    
    local segments = segment_members(sample_members)
    print("\nMember Segmentation:")
    for segment_name, segment_data in pairs(segments) do
        print(string.format("  %s: %d members, avg donation: $%.2f", 
              segment_name, segment_data.count, segment_data.avg_donation))
    end
    
    print()
end

function demo.run_all()
    print("Church Management System - Functional Programming Demonstration")
    print("Using Lua 5.1/LuaJIT with luafun")
    print(string.rep("=", 70))
    print()
    
    demo.basic_functional_operations()
    demo.advanced_transformations()
    demo.monadic_operations()
    demo.lazy_evaluation()
    demo.memoization()
    demo.partial_application()
    demo.lens_operations()
    demo.transducers()
    demo.church_management_examples()
    
    print(string.rep("=", 70))
    print("Functional programming demonstration complete!")
    print("The Church Management System now uses advanced functional programming")
    print("patterns throughout the codebase for better maintainability,")
    print("composability, and error handling.")
end

-- Run demo if called directly
if arg and arg[0] and arg[0]:match("functional_programming_demo%.lua$") then
    demo.run_all()
end

return demo
