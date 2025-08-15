-- src/controllers/member_controller_with_repository.lua
-- Modern member controller using repository pattern

local json = require("cjson")
local MemberRepository = require("src.infrastructure.repositories.member_repository")

local MemberController = {}

-- Create repository instance
local member_repo = MemberRepository.new()

-- Helper function to send JSON response
local function send_json_response(status, data)
  ngx.status = status
  ngx.header.content_type = "application/json"
  ngx.say(json.encode(data))
  ngx.exit(status)
end

-- Helper function to validate required fields
local function validate_member_data(data)
  local required_fields = {"first_name", "last_name", "email"}
  local errors = {}
  
  for _, field in ipairs(required_fields) do
    if not data[field] or data[field] == "" then
      table.insert(errors, field .. " is required")
    end
  end
  
  -- Validate email format
  if data.email and not string.match(data.email, "^[%w._%+-]+@[%w.-]+%.[%a]+$") then
    table.insert(errors, "Invalid email format")
  end
  
  -- Validate phone format if provided
  if data.phone and data.phone ~= "" then
    local cleaned_phone = string.gsub(data.phone, "[%s%-%(%)%.]", "")
    if not string.match(cleaned_phone, "^%+?%d+$") then
      table.insert(errors, "Invalid phone format")
    end
  end
  
  -- Validate date format if provided
  if data.birth_date and data.birth_date ~= "" then
    if not string.match(data.birth_date, "^%d%d%d%d%-%d%d%-%d%d$") then
      table.insert(errors, "Invalid birth_date format (use YYYY-MM-DD)")
    end
  end
  
  if data.join_date and data.join_date ~= "" then
    if not string.match(data.join_date, "^%d%d%d%d%-%d%d%-%d%d$") then
      table.insert(errors, "Invalid join_date format (use YYYY-MM-DD)")
    end
  end
  
  return #errors == 0, errors
end

-- Get all members with pagination and search
function MemberController.get_all()
  local args = ngx.req.get_uri_args()
  
  local options = {
    page = tonumber(args.page) or 1,
    per_page = tonumber(args.per_page) or 20,
    order_by = args.order_by or "last_name",
    order_direction = args.order_direction or "ASC"
  }
  
  -- Add search functionality
  if args.search and args.search ~= "" then
    local search_results, search_err = member_repo:search(args.search, options)
    if not search_results then
      send_json_response(500, {
        success = false,
        error = "Search failed: " .. (search_err or "Unknown error")
      })
    end
    
    send_json_response(200, {
      success = true,
      data = search_results,
      pagination = {
        page = options.page,
        per_page = options.per_page,
        has_more = #search_results == options.per_page
      }
    })
  end
  
  -- Regular paginated listing
  local result, err = member_repo:paginate(options)
  if not result then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch members: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = result.data,
    pagination = result.pagination
  })
end

-- Get member by ID
function MemberController.get_by_id()
  local id = ngx.var.id
  if not id then
    send_json_response(400, {
      success = false,
      error = "Member ID is required"
    })
  end
  
  local member, err = member_repo:find_by_id(tonumber(id))
  if not member then
    if err then
      send_json_response(500, {
        success = false,
        error = "Failed to fetch member: " .. err
      })
    else
      send_json_response(404, {
        success = false,
        error = "Member not found"
      })
    end
  end
  
  send_json_response(200, {
    success = true,
    data = member
  })
end

-- Create new member
function MemberController.create()
  ngx.req.read_body()
  local body = ngx.req.get_body_data()
  
  if not body then
    send_json_response(400, {
      success = false,
      error = "Request body is required"
    })
  end
  
  local ok, data = pcall(json.decode, body)
  if not ok then
    send_json_response(400, {
      success = false,
      error = "Invalid JSON in request body"
    })
  end
  
  -- Validate data
  local is_valid, validation_errors = validate_member_data(data)
  if not is_valid then
    send_json_response(400, {
      success = false,
      error = "Validation failed",
      details = validation_errors
    })
  end
  
  -- Check for existing email
  local existing, check_err = member_repo:find_by_email(data.email)
  if check_err then
    send_json_response(500, {
      success = false,
      error = "Failed to check existing member: " .. check_err
    })
  end
  
  if existing then
    send_json_response(409, {
      success = false,
      error = "Member with this email already exists"
    })
  end
  
  -- Set default values
  if not data.is_active then
    data.is_active = true
  end
  
  if not data.join_date then
    data.join_date = os.date("%Y-%m-%d")
  end
  
  local member, err = member_repo:create(data)
  if not member then
    send_json_response(500, {
      success = false,
      error = "Failed to create member: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(201, {
    success = true,
    data = member,
    message = "Member created successfully"
  })
end

-- Update member
function MemberController.update()
  local id = ngx.var.id
  if not id then
    send_json_response(400, {
      success = false,
      error = "Member ID is required"
    })
  end
  
  ngx.req.read_body()
  local body = ngx.req.get_body_data()
  
  if not body then
    send_json_response(400, {
      success = false,
      error = "Request body is required"
    })
  end
  
  local ok, data = pcall(json.decode, body)
  if not ok then
    send_json_response(400, {
      success = false,
      error = "Invalid JSON in request body"
    })
  end
  
  -- Validate data if provided
  if data.email or data.first_name or data.last_name then
    local is_valid, validation_errors = validate_member_data(data)
    if not is_valid then
      send_json_response(400, {
        success = false,
        error = "Validation failed",
        details = validation_errors
      })
    end
  end
  
  -- Check if member exists
  local existing, check_err = member_repo:find_by_id(tonumber(id))
  if not existing then
    if check_err then
      send_json_response(500, {
        success = false,
        error = "Failed to check existing member: " .. check_err
      })
    else
      send_json_response(404, {
        success = false,
        error = "Member not found"
      })
    end
  end
  
  -- Check for email conflicts if email is being updated
  if data.email and data.email ~= existing.email then
    local email_exists, email_err = member_repo:find_by_email(data.email)
    if email_err then
      send_json_response(500, {
        success = false,
        error = "Failed to check email availability: " .. email_err
      })
    end
    
    if email_exists then
      send_json_response(409, {
        success = false,
        error = "Member with this email already exists"
      })
    end
  end
  
  local updated_member, err = member_repo:update_by_id(tonumber(id), data)
  if not updated_member then
    send_json_response(500, {
      success = false,
      error = "Failed to update member: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = updated_member,
    message = "Member updated successfully"
  })
end

-- Delete member
function MemberController.delete()
  local id = ngx.var.id
  if not id then
    send_json_response(400, {
      success = false,
      error = "Member ID is required"
    })
  end
  
  -- Check if member exists
  local existing, check_err = member_repo:find_by_id(tonumber(id))
  if not existing then
    if check_err then
      send_json_response(500, {
        success = false,
        error = "Failed to check existing member: " .. check_err
      })
    else
      send_json_response(404, {
        success = false,
        error = "Member not found"
      })
    end
  end
  
  local success, err = member_repo:delete_by_id(tonumber(id))
  if not success then
    send_json_response(500, {
      success = false,
      error = "Failed to delete member: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    message = "Member deleted successfully"
  })
end

-- Get member statistics
function MemberController.get_statistics()
  local stats, err = member_repo:get_member_statistics()
  if not stats then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch statistics: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = stats
  })
end

-- Get members with birthdays in date range
function MemberController.get_birthdays()
  local args = ngx.req.get_uri_args()
  local start_date = args.start_date
  local end_date = args.end_date
  
  if not start_date or not end_date then
    send_json_response(400, {
      success = false,
      error = "start_date and end_date are required (format: MM-DD)"
    })
  end
  
  -- Validate date format
  if not string.match(start_date, "^%d%d%-%d%d$") or not string.match(end_date, "^%d%d%-%d%d$") then
    send_json_response(400, {
      success = false,
      error = "Invalid date format. Use MM-DD"
    })
  end
  
  local birthdays, err = member_repo:find_birthdays_in_range(start_date, end_date)
  if not birthdays then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch birthdays: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = birthdays
  })
end

-- Get today's birthdays
function MemberController.get_todays_birthdays()
  local today = os.date("%m-%d")
  local birthdays, err = member_repo:find_birthdays_in_range(today, today)
  if not birthdays then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch today's birthdays: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = birthdays
  })
end

-- Get upcoming birthdays (next 30 days)
function MemberController.get_upcoming_birthdays()
  local args = ngx.req.get_uri_args()
  local days = tonumber(args.days) or 30
  
  local upcoming, err = member_repo:find_upcoming_birthdays(days)
  if not upcoming then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch upcoming birthdays: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = upcoming
  })
end

-- Get members by age range
function MemberController.get_by_age_range()
  local args = ngx.req.get_uri_args()
  local min_age = tonumber(args.min_age)
  local max_age = tonumber(args.max_age)
  
  if not min_age or not max_age then
    send_json_response(400, {
      success = false,
      error = "min_age and max_age are required"
    })
  end
  
  if min_age < 0 or max_age < 0 or min_age > max_age then
    send_json_response(400, {
      success = false,
      error = "Invalid age range"
    })
  end
  
  local members, err = member_repo:find_by_age_range(min_age, max_age)
  if not members then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch members by age: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = members
  })
end

-- Search members
function MemberController.search()
  local args = ngx.req.get_uri_args()
  local query = args.q or args.query
  
  if not query or query == "" then
    send_json_response(400, {
      success = false,
      error = "Search query is required"
    })
  end
  
  local options = {
    page = tonumber(args.page) or 1,
    per_page = tonumber(args.per_page) or 20,
    order_by = args.order_by or "last_name",
    order_direction = args.order_direction or "ASC"
  }
  
  local results, err = member_repo:search(query, options)
  if not results then
    send_json_response(500, {
      success = false,
      error = "Search failed: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = results,
    pagination = {
      page = options.page,
      per_page = options.per_page,
      has_more = #results == options.per_page
    }
  })
end

-- Toggle member active status
function MemberController.toggle_active_status()
  local id = ngx.var.id
  if not id then
    send_json_response(400, {
      success = false,
      error = "Member ID is required"
    })
  end
  
  -- Get current member
  local member, err = member_repo:find_by_id(tonumber(id))
  if not member then
    if err then
      send_json_response(500, {
        success = false,
        error = "Failed to fetch member: " .. err
      })
    else
      send_json_response(404, {
        success = false,
        error = "Member not found"
      })
    end
  end
  
  -- Toggle status
  local new_status = not member.is_active
  local updated_member, update_err = member_repo:update_by_id(tonumber(id), {is_active = new_status})
  if not updated_member then
    send_json_response(500, {
      success = false,
      error = "Failed to update member status: " .. (update_err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = updated_member,
    message = "Member status updated successfully"
  })
end

-- Batch operations
function MemberController.batch_update()
  ngx.req.read_body()
  local body = ngx.req.get_body_data()
  
  if not body then
    send_json_response(400, {
      success = false,
      error = "Request body is required"
    })
  end
  
  local ok, data = pcall(json.decode, body)
  if not ok then
    send_json_response(400, {
      success = false,
      error = "Invalid JSON in request body"
    })
  end
  
  if not data.member_ids or not data.updates then
    send_json_response(400, {
      success = false,
      error = "member_ids and updates are required"
    })
  end
  
  local results = {}
  local errors = {}
  
  for _, member_id in ipairs(data.member_ids) do
    local updated_member, err = member_repo:update_by_id(tonumber(member_id), data.updates)
    if updated_member then
      table.insert(results, updated_member)
    else
      errors[tostring(member_id)] = err or "Unknown error"
    end
  end
  
  send_json_response(200, {
    success = true,
    data = {
      updated_count = #results,
      updated_members = results,
      errors = errors
    },
    message = string.format("Updated %d of %d members", #results, #data.member_ids)
  })
end

return MemberController
