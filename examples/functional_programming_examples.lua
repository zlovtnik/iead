-- examples/functional_programming_examples.lua
-- Examples demonstrating functional programming patterns in the church management system

local fun = require("src.utils.functional")
local pipeline = require("src.utils.pipeline")
local DataProcessor = require("src.infrastructure.utils.data_processor")
local MemberService = require("src.application.services.member_service")

-- Example 1: Basic functional operations
print("=== Example 1: Basic Functional Operations ===")

local members = {
  {id = 1, name = "John Doe", age = 30, is_active = 1, email = "john@example.com"},
  {id = 2, name = "Jane Smith", age = 25, is_active = 1, email = "jane@example.com"},
  {id = 3, name = "Bob Johnson", age = 35, is_active = 0, email = "bob@example.com"},
  {id = 4, name = "Alice Brown", age = 28, is_active = 1, email = "alice@example.com"}
}

-- Filter active members
local active_members = fun.filter_table(function(member)
  return member.is_active == 1
end, members)

print("Active members:", #active_members)

-- Get member names
local member_names = fun.pluck("name", members)
print("Member names:", table.concat(member_names, ", "))

-- Calculate average age
local ages = fun.pluck("age", members)
local average_age = fun.average(ages)
print("Average age:", average_age)

-- Example 2: Using pipelines for data processing
print("\n=== Example 2: Pipeline Data Processing ===")

local processed_members = pipeline.for_array(members)
  :filter(function(member) return member.is_active == 1 end)
  :map(function(member) 
    return {
      id = member.id,
      display_name = member.name,
      age_group = member.age < 30 and "young" or "mature",
      contact = member.email
    }
  end)
  :sort(function(a, b) return a.display_name < b.display_name end)
  :execute()

print("Processed members:")
for _, member in ipairs(processed_members) do
  print("  " .. member.display_name .. " (" .. member.age_group .. ")")
end

-- Example 3: Advanced data analysis with functional programming
print("\n=== Example 3: Advanced Data Analysis ===")

-- Group members by age range
local age_groups = fun.group_by(function(member)
  if member.age < 25 then return "under_25"
  elseif member.age < 35 then return "25_34"
  else return "35_plus"
  end
end, members)

print("Age group distribution:")
for group, group_members in pairs(age_groups) do
  print("  " .. group .. ": " .. #group_members .. " members")
end

-- Example 4: Validation pipeline
print("\n=== Example 4: Validation Pipeline ===")

local member_data_to_validate = {
  {name = "Valid Member", email = "valid@example.com", age = 25},
  {name = "", email = "invalid-email", age = 25}, -- Invalid: empty name, bad email
  {name = "Another Valid", email = "another@example.com", age = 30},
  {name = "No Email", email = "", age = 22} -- Invalid: no email
}

local validation_pipeline = pipeline.data_validation(function(member)
  return member.name and member.name ~= "" and
         member.email and member.email:match("^[%w%._%+%-]+@[%w%._%+%-]+%.%w+$") and
         member.age and member.age > 0
end)

local validation_result = validation_pipeline(member_data_to_validate):execute()

print("Valid members:", #validation_result.valid)
print("Invalid members:", #validation_result.invalid)

-- Example 5: Complex data transformation
print("\n=== Example 5: Complex Data Transformation ===")

local events = {
  {id = 1, title = "Sunday Service", date = "2024-01-07", attendees = {1, 2, 4}},
  {id = 2, title = "Bible Study", date = "2024-01-10", attendees = {1, 3}},
  {id = 3, title = "Prayer Meeting", date = "2024-01-14", attendees = {2, 3, 4}}
}

-- Create a comprehensive event report
local event_report = pipeline.for_array(events)
  :map(function(event)
    -- Add computed fields
    local member_lookup = fun.reduce_table(function(acc, member)
      acc[member.id] = member
      return acc
    end, {}, members)
    
    local attendee_names = fun.map_table(function(id)
      return member_lookup[id] and member_lookup[id].name or "Unknown"
    end, event.attendees)
    
    return {
      id = event.id,
      title = event.title,
      date = event.date,
      attendee_count = #event.attendees,
      attendee_names = attendee_names,
      attendance_rate = #event.attendees / #members
    }
  end)
  :sort(function(a, b) return a.attendance_rate > b.attendance_rate end)
  :execute()

print("Event attendance report (sorted by attendance rate):")
for _, event in ipairs(event_report) do
  print(string.format("  %s: %d attendees (%.1f%%) - %s", 
    event.title, 
    event.attendee_count, 
    event.attendance_rate * 100,
    table.concat(event.attendee_names, ", ")
  ))
end

-- Example 6: Functional approach to data aggregation
print("\n=== Example 6: Data Aggregation ===")

local donations = {
  {member_id = 1, amount = 100, date = "2024-01-01"},
  {member_id = 2, amount = 50, date = "2024-01-01"},
  {member_id = 1, amount = 75, date = "2024-01-08"},
  {member_id = 3, amount = 200, date = "2024-01-08"},
  {member_id = 2, amount = 25, date = "2024-01-15"}
}

-- Calculate donation statistics
local donation_stats = {
  total = fun.sum(fun.pluck("amount", donations)),
  average = fun.average(fun.pluck("amount", donations)),
  max = fun.max(fun.pluck("amount", donations)),
  min = fun.min(fun.pluck("amount", donations)),
  count = #donations
}

print("Donation statistics:")
print("  Total: $" .. donation_stats.total)
print("  Average: $" .. string.format("%.2f", donation_stats.average))
print("  Max: $" .. donation_stats.max)
print("  Min: $" .. donation_stats.min)
print("  Count: " .. donation_stats.count)

-- Group donations by member
local donations_by_member = fun.group_by(function(donation)
  return donation.member_id
end, donations)

print("Donations by member:")
for member_id, member_donations in pairs(donations_by_member) do
  local member_total = fun.sum(fun.pluck("amount", member_donations))
  local member_name = fun.find(function(m) return m.id == member_id end, members)
  member_name = member_name and member_name.name or "Unknown"
  print("  " .. member_name .. ": $" .. member_total .. " (" .. #member_donations .. " donations)")
end

-- Example 7: Parallel processing simulation
print("\n=== Example 7: Parallel Processing Simulation ===")

local large_dataset = {}
for i = 1, 100 do
  table.insert(large_dataset, {id = i, value = math.random(1, 1000)})
end

-- Process in batches using functional approach
local batch_size = 25
local batches = {}
for i = 1, #large_dataset, batch_size do
  local batch = {}
  for j = i, math.min(i + batch_size - 1, #large_dataset) do
    table.insert(batch, large_dataset[j])
  end
  table.insert(batches, batch)
end

-- Process each batch and combine results
local batch_results = fun.map_table(function(batch)
  return {
    count = #batch,
    total = fun.sum(fun.pluck("value", batch)),
    average = fun.average(fun.pluck("value", batch))
  }
end, batches)

local overall_total = fun.sum(fun.pluck("total", batch_results))
local overall_count = fun.sum(fun.pluck("count", batch_results))

print("Batch processing results:")
print("  Processed " .. #batches .. " batches")
print("  Total items: " .. overall_count)
print("  Overall total: " .. overall_total)
print("  Overall average: " .. string.format("%.2f", overall_total / overall_count))

-- Example 8: Functional composition
print("\n=== Example 8: Functional Composition ===")

-- Create reusable functions
local is_adult = function(person) return person.age >= 18 end
local is_active = function(person) return person.is_active == 1 end
local get_email = function(person) return person.email end

-- Compose functions
local get_adult_active_emails = pipeline.compose(
  function(people) return fun.pluck("email", people) end,
  function(people) return fun.filter_table(is_active, people) end,
  function(people) return fun.filter_table(is_adult, people) end
)

local adult_active_emails = get_adult_active_emails(members)
print("Adult active member emails:", table.concat(adult_active_emails, ", "))

print("\n=== All Examples Complete ===")

-- Return the examples table for potential use as a module
return {
  members = members,
  events = events,
  donations = donations,
  donation_stats = donation_stats,
  processed_members = processed_members,
  age_groups = age_groups,
  event_report = event_report
}
