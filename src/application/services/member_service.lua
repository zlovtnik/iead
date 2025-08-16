-- src/application/services/member_service.lua
-- Member service layer with functional programming patterns

local MemberRepository = require("src.infrastructure.repositories.member_repository")
local fun = require("src.utils.functional")
local DataProcessor = require("src.infrastructure.utils.data_processor")
local log = require("src.utils.log")

local MemberService = {}

-- Create new MemberService instance
function MemberService.new()
  local instance = {
    member_repo = MemberRepository.new()
  }
  setmetatable(instance, {__index = MemberService})
  return instance
end

-- Get members with advanced filtering and processing
-- @param filter_options table Filtering and processing options
-- @return table Processed members
-- @return string Error message if any
function MemberService:get_members_advanced(filter_options)
  filter_options = filter_options or {}
  
  -- Get base members
  local members, err = self.member_repo:find_all()
  if not members then
    return nil, err
  end
  
  -- Apply business logic transformations
  local transformations = {}
  
  -- Add computed fields for all members
  table.insert(transformations, function(member)
    return DataProcessor.add_computed_fields({member}, {
      full_name = function(m) return self.member_repo:get_full_name(m) end,
      display_name = function(m) 
        return m.first_name and (m.first_name .. " " .. (m.last_name or "")) or "Unknown"
      end,
      status = function(m) return m.is_active == 1 and "Active" or "Inactive" end,
      age = function(m)
        if m.date_of_birth then
          local birth_year = m.date_of_birth:match("(%d%d%d%d)")
          if birth_year then
            return tonumber(os.date("%Y")) - tonumber(birth_year)
          end
        end
        return nil
      end,
      membership_duration = function(m)
        if m.membership_date then
          local membership_year = m.membership_date:match("(%d%d%d%d)")
          if membership_year then
            local years = tonumber(os.date("%Y")) - tonumber(membership_year)
            return years .. " year" .. (years == 1 and "" or "s")
          end
        end
        return "Unknown"
      end,
      contact_methods = function(m)
        local methods = {}
        if m.email then table.insert(methods, "email") end
        if m.phone then table.insert(methods, "phone") end
        return methods
      end
    })[1]
  end)
  
  -- Apply transformations
  local processed_members = DataProcessor.process_results(members, transformations)
  
  -- Apply business logic filters
  local filters = {}
  
  -- Filter by active status
  if filter_options.active_only then
    table.insert(filters, function(member)
      return member.is_active == 1
    end)
  end
  
  -- Filter by age range
  if filter_options.min_age or filter_options.max_age then
    table.insert(filters, function(member)
      if not member.age then return false end
      if filter_options.min_age and member.age < filter_options.min_age then
        return false
      end
      if filter_options.max_age and member.age > filter_options.max_age then
        return false
      end
      return true
    end)
  end
  
  -- Filter by membership duration
  if filter_options.min_membership_years then
    table.insert(filters, function(member)
      if not member.date_of_birth then return false end
      local membership_year = member.membership_date and member.membership_date:match("(%d%d%d%d)")
      if not membership_year then return false end
      
      local years = tonumber(os.date("%Y")) - tonumber(membership_year)
      return years >= filter_options.min_membership_years
    end)
  end
  
  -- Filter by contact availability
  if filter_options.has_phone then
    table.insert(filters, function(member)
      return member.phone and member.phone ~= ""
    end)
  end
  
  if filter_options.has_email then
    table.insert(filters, function(member)
      return member.email and member.email ~= ""
    end)
  end
  
  -- Apply filters
  if #filters > 0 then
    processed_members = DataProcessor.apply_filters(processed_members, filters)
  end
  
  -- Apply sorting
  if filter_options.sort_by then
    local sort_criteria = {{
      field = filter_options.sort_by,
      direction = filter_options.sort_direction or "asc"
    }}
    processed_members = DataProcessor.sort_results(processed_members, sort_criteria)
  end
  
  -- Apply pagination
  if filter_options.page and filter_options.per_page then
    return DataProcessor.paginate_results(processed_members, filter_options.page, filter_options.per_page)
  end
  
  return processed_members, nil
end

-- Get member statistics using functional programming
-- @return table Member statistics
-- @return string Error message if any
function MemberService:get_member_statistics()
  local members, err = self.member_repo:find_all()
  if not members then
    return nil, err
  end
  
  -- Calculate various statistics using functional approach
  local stats = {}
  
  -- Basic counts
  stats.total_members = #members
  stats.active_members = fun.count_where(function(m) return m.is_active == 1 end, members)
  stats.inactive_members = stats.total_members - stats.active_members
  
  -- Age statistics
  local members_with_age = fun.filter_table(function(member)
    return member.date_of_birth and member.date_of_birth:match("(%d%d%d%d)")
  end, members)
  
  if #members_with_age > 0 then
    local ages = fun.map_table(function(member)
      local birth_year = member.date_of_birth:match("(%d%d%d%d)")
      return tonumber(os.date("%Y")) - tonumber(birth_year)
    end, members_with_age)
    
    stats.age_statistics = DataProcessor.calculate_aggregations(
      fun.map_table(function(age) return {age = age} end, ages), 
      "age"
    )
  end
  
  -- Membership year breakdown
  local membership_by_year = DataProcessor.group_results(members, function(member)
    if member.membership_date then
      return member.membership_date:match("(%d%d%d%d)") or "unknown"
    end
    return "unknown"
  end)
  
  stats.membership_by_year = fun.from_pairs(membership_by_year):map(function(year, member_list)
    return {year = year, count = #member_list}
  end):totable()
  
  -- Contact information completeness
  stats.contact_completeness = {
    with_phone = fun.count_where(function(m) return m.phone and m.phone ~= "" end, members),
    with_email = fun.count_where(function(m) return m.email and m.email ~= "" end, members),
    with_address = fun.count_where(function(m) return m.address and m.address ~= "" end, members),
    complete_profiles = fun.count_where(function(m) 
      return m.phone and m.phone ~= "" and m.email and m.email ~= "" and m.address and m.address ~= ""
    end, members)
  }
  
  -- Birthday analysis
  local current_month = tonumber(os.date("%m"))
  stats.birthdays_this_month = fun.count_where(function(member)
    if member.date_of_birth then
      local birth_month = member.date_of_birth:match("%d%d%d%d-(%d%d)")
      return birth_month and tonumber(birth_month) == current_month
    end
    return false
  end, members)
  
  return stats, nil
end

-- Search members with advanced criteria
-- @param search_query string Search query
-- @param search_options table Search options
-- @return table Search results
-- @return string Error message if any
function MemberService:search_members(search_query, search_options)
  search_options = search_options or {}
  
  -- Get all members first
  local members, err = self.member_repo:find_all()
  if not members then
    return nil, err
  end
  
  -- Add computed fields for searching
  local enhanced_members = fun.map_table(function(member)
    local enhanced = {}
    fun.from_pairs(member):each(function(k, v) enhanced[k] = v end)
    
    enhanced.full_name = self.member_repo:get_full_name(member)
    enhanced.searchable_text = string.lower(
      (enhanced.full_name or "") .. " " ..
      (enhanced.email or "") .. " " ..
      (enhanced.phone or "") .. " " ..
      (enhanced.address or "")
    )
    
    return enhanced
  end, members)
  
  -- Apply search filter
  local search_term = string.lower(search_query or "")
  local search_results = enhanced_members
  
  if search_term and search_term ~= "" then
    search_results = fun.filter_table(function(member)
      return string.find(member.searchable_text, search_term, 1, true) ~= nil
    end, enhanced_members)
  end
  
  -- Apply additional filters from search options
  if search_options.active_only then
    search_results = fun.filter_table(function(m) return m.is_active == 1 end, search_results)
  end
  
  -- Sort results (prioritize exact matches)
  if search_term and search_term ~= "" then
    search_results = DataProcessor.sort_results(search_results, {
      function(a, b)
        local a_exact = string.find(string.lower(a.full_name or ""), search_term, 1, true) == 1
        local b_exact = string.find(string.lower(b.full_name or ""), search_term, 1, true) == 1
        
        if a_exact and not b_exact then return true end
        if b_exact and not a_exact then return false end
        
        return (a.full_name or "") < (b.full_name or "")
      end
    })
  end
  
  -- Remove searchable_text field from results
  search_results = fun.omit_keys({"searchable_text"}, search_results)
  
  -- Apply pagination if specified
  if search_options.page and search_options.per_page then
    return DataProcessor.paginate_results(search_results, search_options.page, search_options.per_page)
  end
  
  return search_results, nil
end

-- Validate member data using functional approach
-- @param member_data table Member data to validate
-- @return boolean Is valid
-- @return table Validation errors
function MemberService:validate_member_data(member_data)
  if not member_data then
    return false, {"Member data is required"}
  end
  
  local errors = {}
  
  -- Define validation rules
  local validation_rules = {
    {
      field = "first_name",
      required = true,
      validator = function(value) return value and value ~= "" end,
      message = "First name is required"
    },
    {
      field = "last_name", 
      required = true,
      validator = function(value) return value and value ~= "" end,
      message = "Last name is required"
    },
    {
      field = "email",
      required = true,
      validator = function(value) 
        return value and value ~= "" and string.match(value, "^[%w._%+-]+@[%w.-]+%.[%a]+$")
      end,
      message = "Valid email is required"
    },
    {
      field = "phone",
      required = false,
      validator = function(value)
        if not value or value == "" then return true end
        local cleaned = string.gsub(value, "[%s%-%(%)%.]", "")
        return string.match(cleaned, "^%+?%d+$") ~= nil
      end,
      message = "Invalid phone format"
    },
    {
      field = "date_of_birth",
      required = false,
      validator = function(value)
        if not value or value == "" then return true end
        return string.match(value, "^%d%d%d%d%-%d%d%-%d%d$") ~= nil
      end,
      message = "Date of birth must be in YYYY-MM-DD format"
    },
    {
      field = "membership_date",
      required = false,
      validator = function(value)
        if not value or value == "" then return true end
        return string.match(value, "^%d%d%d%d%-%d%d%-%d%d$") ~= nil
      end,
      message = "Membership date must be in YYYY-MM-DD format"
    }
  }
  
  -- Apply validation rules using functional approach
  fun.from_table(validation_rules):each(function(rule)
    local value = member_data[rule.field]
    if not rule.validator(value) then
      table.insert(errors, rule.message)
    end
  end)
  
  return #errors == 0, errors
end

-- Create member with business logic validation
-- @param member_data table Member data
-- @return table Created member or nil
-- @return string Error message if any
function MemberService:create_member(member_data)
  -- Validate input data
  local is_valid, validation_errors = self:validate_member_data(member_data)
  if not is_valid then
    return nil, "Validation failed: " .. table.concat(validation_errors, ", ")
  end
  
  -- Check for existing email
  local existing_member, err = self.member_repo:find_by_email(member_data.email)
  if err then
    return nil, "Failed to check existing member: " .. err
  end
  
  if existing_member then
    return nil, "Member with this email already exists"
  end
  
  -- Set default values
  local processed_data = {}
  fun.from_pairs(member_data):each(function(k, v) processed_data[k] = v end)
  
  if processed_data.is_active == nil then
    processed_data.is_active = 1
  end
  
  if not processed_data.membership_date then
    processed_data.membership_date = os.date("%Y-%m-%d")
  end
  
  -- Create member
  return self.member_repo:create(processed_data)
end

-- Update member with business logic validation  
-- @param member_id number Member ID
-- @param update_data table Update data
-- @return table Updated member or nil
-- @return string Error message if any
function MemberService:update_member(member_id, update_data)
  -- Get existing member
  local existing_member, err = self.member_repo:find_by_id(member_id)
  if err then
    return nil, err
  end
  
  if not existing_member then
    return nil, "Member not found"
  end
  
  -- Merge existing data with updates for validation
  local merged_data = {}
  fun.from_pairs(existing_member):each(function(k, v) merged_data[k] = v end)
  fun.from_pairs(update_data):each(function(k, v) merged_data[k] = v end)
  
  -- Validate merged data
  local is_valid, validation_errors = self:validate_member_data(merged_data)
  if not is_valid then
    return nil, "Validation failed: " .. table.concat(validation_errors, ", ")
  end
  
  -- Check email uniqueness if email is being updated
  if update_data.email and update_data.email ~= existing_member.email then
    local email_exists, check_err = self.member_repo:find_by_email(update_data.email)
    if check_err then
      return nil, "Failed to check email uniqueness: " .. check_err
    end
    
    if email_exists then
      return nil, "Another member with this email already exists"
    end
  end
  
  -- Update member
  return self.member_repo:update_by_id(member_id, update_data)
end

return MemberService
