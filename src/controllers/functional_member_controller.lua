-- src/controllers/functional_member_controller.lua
-- Enhanced Member controller showcasing advanced functional programming with luafun

local Member = require("src.models.member")
local json_utils = require("src.utils.json")
local fun = require("src.utils.functional")
local validation = require("src.utils.validation")

local FunctionalMemberController = {}

-- Functional pipeline for member data processing
local member_processors = {
    -- Add calculated age field
    function(member)
        if member.date_of_birth then
            local age = math.floor((os.time() - os.time{
                year = member.date_of_birth:match("(%d+)"),
                month = member.date_of_birth:match("%d+%-(%d+)"),
                day = member.date_of_birth:match("%d+%-%d+%-(%d+)")
            }) / (365.25 * 24 * 3600))
            member.age = age
        end
        return member
    end,
    
    -- Add membership duration
    function(member)
        if member.membership_date then
            local duration_days = math.floor((os.time() - os.time{
                year = member.membership_date:match("(%d+)"),
                month = member.membership_date:match("%d+%-(%d+)"),
                day = member.membership_date:match("%d+%-%d+%-(%d+)")
            }) / (24 * 3600))
            member.membership_duration_days = duration_days
        end
        return member
    end,
    
    -- Sanitize sensitive data for display
    function(member)
        return fun.omit_keys({"password_hash", "ssn"}, member)
    end
}

-- Functional filters for member queries
local member_filters = {
    active = function(member) 
        return member.status == "active" 
    end,
    
    adult = function(member) 
        return not member.age or member.age >= 18 
    end,
    
    recent_member = function(member)
        return member.membership_duration_days and member.membership_duration_days <= 365
    end,
    
    has_email = function(member)
        return member.email and member.email ~= ""
    end
}

-- Advanced member listing with functional composition
function FunctionalMemberController.index(client, params)
    -- Start with all members
    local members = Member.find_all() or {}
    
    -- Apply processors using functional composition
    local processed_members = fun.pipe(
        members,
        function(list) return fun.map_table(fun.compose(unpack(member_processors)), list) end
    )
    
    -- Apply filters based on query parameters
    local active_filters = {}
    
    -- Build filter chain functionally
    if params.active == "true" then
        table.insert(active_filters, member_filters.active)
    end
    
    if params.adults_only == "true" then
        table.insert(active_filters, member_filters.adult)
    end
    
    if params.recent_only == "true" then
        table.insert(active_filters, member_filters.recent_member)
    end
    
    if params.with_email == "true" then
        table.insert(active_filters, member_filters.has_email)
    end
    
    -- Apply filters if any are specified
    local filtered_members = #active_filters > 0 and 
        fun.reduce_table(function(acc, filter_func)
            return fun.filter_table(filter_func, acc)
        end, processed_members, active_filters) or processed_members
    
    -- Sort and paginate using functional approach
    local sorted_members = fun.pipe(
        filtered_members,
        function(list) 
            table.sort(list, function(a, b) 
                return (a.name or "") < (b.name or "") 
            end)
            return list
        end
    )
    
    -- Pagination
    local page = tonumber(params.page) or 1
    local per_page = tonumber(params.per_page) or 10
    local start_idx = (page - 1) * per_page + 1
    local end_idx = math.min(start_idx + per_page - 1, #sorted_members)
    
    local paginated_members = {}
    for i = start_idx, end_idx do
        if sorted_members[i] then
            table.insert(paginated_members, sorted_members[i])
        end
    end
    
    -- Response with metadata
    local response = {
        data = paginated_members,
        pagination = {
            current_page = page,
            per_page = per_page,
            total_count = #sorted_members,
            total_pages = math.ceil(#sorted_members / per_page),
            has_next = end_idx < #sorted_members,
            has_prev = page > 1
        },
        filters_applied = fun.map_table(function(filter) 
            for name, func in pairs(member_filters) do
                if func == filter then return name end
            end
            return "unknown"
        end, active_filters)
    }
    
    json_utils.send_json_response(client, 200, response)
end

-- Functional member creation with validation pipeline
function FunctionalMemberController.create(client, params)
    -- Validation pipeline using functional approach
    local validation_pipeline = {
        -- Check required fields
        function(data)
            local required_fields = {"name", "email"}
            local missing_fields = fun.filter_table(function(field) 
                return not data[field] or data[field] == "" 
            end, required_fields)
            
            if #missing_fields > 0 then
                return nil, "Missing required fields: " .. table.concat(missing_fields, ", ")
            end
            return data
        end,
        
        -- Validate email format
        function(data)
            if not validation.is_valid_email(data.email) then
                return nil, "Invalid email format"
            end
            return data
        end,
        
        -- Validate age if date of birth provided
        function(data)
            if data.date_of_birth and not validation.is_valid_date(data.date_of_birth) then
                return nil, "Invalid date of birth format"
            end
            return data
        end,
        
        -- Sanitize input data
        function(data)
            return {
                name = (data.name or ""):gsub("^%s*(.-)%s*$", "%1"), -- trim whitespace
                email = (data.email or ""):lower(),
                phone = data.phone,
                address = data.address,
                date_of_birth = data.date_of_birth,
                membership_date = data.membership_date or os.date("%Y-%m-%d"),
                status = data.status or "active"
            }
        end
    }
    
    -- Execute validation pipeline
    local validated_data = params
    for _, validator in ipairs(validation_pipeline) do
        local result, error_msg = validator(validated_data)
        if not result then
            json_utils.send_json_response(client, 400, { error = error_msg })
            return
        end
        validated_data = result
    end
    
    -- Create member
    local member, err = Member.create(validated_data)
    
    if not member then
        json_utils.send_json_response(client, 400, { error = err or "Failed to create member" })
        return
    end
    
    -- Process created member through enhancement pipeline
    local enhanced_member = fun.pipe(
        member,
        fun.compose(unpack(member_processors))
    )
    
    json_utils.send_json_response(client, 201, enhanced_member)
end

-- Bulk operations using functional approach
function FunctionalMemberController.bulk_update(client, params)
    local member_ids = params.member_ids or {}
    local updates = params.updates or {}
    
    if #member_ids == 0 then
        json_utils.send_json_response(client, 400, { error = "No member IDs provided" })
        return
    end
    
    -- Fetch members to update
    local members_to_update = fun.map_table(function(id)
        return Member.find_by_id(tonumber(id))
    end, member_ids)
    
    -- Filter out members that don't exist
    local existing_members = fun.filter_table(function(member)
        return member ~= nil
    end, members_to_update)
    
    if #existing_members == 0 then
        json_utils.send_json_response(client, 404, { error = "No valid members found" })
        return
    end
    
    -- Apply updates functionally
    local updated_members = fun.map_table(function(member)
        local updated_member = {}
        -- Copy existing data
        for k, v in pairs(member) do
            updated_member[k] = v
        end
        -- Apply updates
        for k, v in pairs(updates) do
            updated_member[k] = v
        end
        return updated_member
    end, existing_members)
    
    -- Save all updates (simplified - in real implementation would use transactions)
    local save_results = fun.map_table(function(member)
        local success, result_or_error = pcall(Member.update, member.id, member)
        return {
            id = member.id,
            success = success,
            result = success and result_or_error or nil,
            error = not success and result_or_error or nil
        }
    end, updated_members)
    
    -- Separate successful and failed updates
    local successful_updates = fun.filter_table(function(result)
        return result.success
    end, save_results)
    
    local failed_updates = fun.filter_table(function(result)
        return not result.success
    end, save_results)
    
    -- Response with detailed results
    local response = {
        total_requested = #member_ids,
        total_found = #existing_members,
        successful_updates = #successful_updates,
        failed_updates = #failed_updates,
        results = save_results
    }
    
    local status_code = #failed_updates > 0 and 207 or 200 -- 207 Multi-Status
    json_utils.send_json_response(client, status_code, response)
end

-- Advanced analytics using functional programming
function FunctionalMemberController.analytics(client, params)
    local members = Member.find_all() or {}
    
    -- Process members through enhancement pipeline
    local processed_members = fun.map_table(
        fun.compose(unpack(member_processors)), 
        members
    )
    
    -- Calculate analytics using functional approach
    local analytics = {
        total_members = #processed_members,
        
        -- Age distribution
        age_distribution = fun.maybe(processed_members)
            :map(function(list) return fun.filter_table(function(m) return m.age end, list) end)
            :map(function(list) return fun.pluck("age", list) end)
            :map(function(ages)
                local age_groups = {
                    children = fun.length(fun.filter(function(age) return age < 18 end, ages)),
                    young_adults = fun.length(fun.filter(function(age) return age >= 18 and age < 35 end, ages)),
                    adults = fun.length(fun.filter(function(age) return age >= 35 and age < 65 end, ages)),
                    seniors = fun.length(fun.filter(function(age) return age >= 65 end, ages))
                }
                return age_groups
            end)
            :get({}),
        
        -- Membership duration stats
        membership_stats = fun.maybe(processed_members)
            :map(function(list) return fun.filter_table(function(m) return m.membership_duration_days end, list) end)
            :map(function(list) return fun.pluck("membership_duration_days", list) end)
            :map(function(durations)
                return {
                    average_days = fun.average(durations),
                    min_days = fun.min(durations),
                    max_days = fun.max(durations),
                    new_members_last_year = fun.length(fun.filter(function(d) return d <= 365 end, durations))
                }
            end)
            :get({}),
        
        -- Status distribution
        status_distribution = fun.pipe(
            processed_members,
            function(list) return fun.pluck("status", list) end,
            function(statuses)
                local counts = {}
                fun.from_table(statuses):each(function(status)
                    counts[status] = (counts[status] or 0) + 1
                end)
                return counts
            end
        )
    }
    
    json_utils.send_json_response(client, 200, analytics)
end

return FunctionalMemberController
