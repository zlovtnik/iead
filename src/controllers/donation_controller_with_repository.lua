-- src/controllers/donation_controller_with_repository.lua
-- Modern donation controller using repository pattern

local json = require("cjson")
local DonationRepository = require("src.infrastructure.repositories.donation_repository")

local DonationController = {}

-- Create repository instance
local donation_repo = DonationRepository.new()

-- Helper function to send JSON response
local function send_json_response(status, data)
  ngx.status = status
  ngx.header.content_type = "application/json"
  ngx.say(json.encode(data))
  ngx.exit(status)
end

-- Helper function to validate donation data
local function validate_donation_data(data)
  local errors = {}
  
  -- Required fields
  if not data.amount or data.amount == "" then
    table.insert(errors, "amount is required")
  else
    local amt = tonumber(data.amount)
    if not amt or amt <= 0 then
      table.insert(errors, "amount must be greater than 0")
    end
  end
  
  if not data.category or data.category == "" then
    table.insert(errors, "category is required")
  end
  
  -- Validate date format if provided
  if data.donation_date and data.donation_date ~= "" then
    if not string.match(data.donation_date, "^%d%d%d%d%-%d%d%-%d%d$") then
      table.insert(errors, "Invalid donation_date format (use YYYY-MM-DD)")
    end
  end
  
  -- Validate payment method
  if data.payment_method and data.payment_method ~= "" then
    local valid_methods = {Cash = true, Check = true, ["Credit Card"] = true, ["Bank Transfer"] = true, Online = true}
    if not valid_methods[data.payment_method] then
      table.insert(errors, "Invalid payment_method")
    end
  end
  
  return #errors == 0, errors
end

-- Get all donations with pagination and filtering
function DonationController.get_all()
  local args = ngx.req.get_uri_args()
  
  local options = {
    page = tonumber(args.page) or 1,
    per_page = tonumber(args.per_page) or 20,
    order_by = args.order_by or "donation_date",
    order_direction = args.order_direction or "DESC"
  }
  
  -- Add filtering conditions
  if args.member_id then
    options.conditions = options.conditions or {}
    options.conditions.member_id = tonumber(args.member_id)
  end
  
  if args.category then
    options.conditions = options.conditions or {}
    options.conditions.category = args.category
  end
  
  if args.payment_method then
    options.conditions = options.conditions or {}
    options.conditions.payment_method = args.payment_method
  end
  
  if args.start_date and args.end_date then
    local date_filter_result, date_err = donation_repo:find_by_date_range(args.start_date, args.end_date, options)
    if not date_filter_result then
      send_json_response(500, {
        success = false,
        error = "Failed to fetch donations: " .. (date_err or "Unknown error")
      })
    end
    
    send_json_response(200, {
      success = true,
      data = date_filter_result,
      pagination = {
        page = options.page,
        per_page = options.per_page,
        has_more = #date_filter_result == options.per_page
      }
    })
  end
  
  -- Search functionality
  if args.search and args.search ~= "" then
    local search_results, search_err = donation_repo:search_with_member_details(args.search, options)
    if not search_results then
      send_json_response(500, {
        success = false,
        error = "Search failed: " .. (search_err or "Unknown error")
      })
      return
    end
    
    -- Get total count for search results
    local total_count, count_err = donation_repo:count_search_with_member_details(args.search, {conditions = options.conditions})
    if not total_count then
      -- Fallback to result count if search count fails
      total_count = #search_results
    end
    
    send_json_response(200, {
      success = true,
      data = search_results,
      pagination = {
        page = options.page,
        per_page = options.per_page,
        total_count = total_count,
        total_pages = math.ceil(total_count / options.per_page),
        has_next = (options.page * options.per_page) < total_count,
        has_previous = options.page > 1
      }
    })
    return
  end
  
  -- Regular paginated listing
  local result, err = donation_repo:paginate(options)
  if not result then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch donations: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = result.data,
    pagination = result.pagination
  })
end

-- Get donation by ID
function DonationController.get_by_id()
  local id = ngx.var.id
  if not id then
    send_json_response(400, {
      success = false,
      error = "Donation ID is required"
    })
  end
  
  local donation, err = donation_repo:find_by_id(tonumber(id))
  if not donation then
    if err then
      send_json_response(500, {
        success = false,
        error = "Failed to fetch donation: " .. err
      })
    else
      send_json_response(404, {
        success = false,
        error = "Donation not found"
      })
    end
  end
  
  send_json_response(200, {
    success = true,
    data = donation
  })
end

-- Create new donation
function DonationController.create()
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
  local is_valid, validation_errors = validate_donation_data(data)
  if not is_valid then
    send_json_response(400, {
      success = false,
      error = "Validation failed",
      details = validation_errors
    })
  end
  
  -- Set default values
  if not data.donation_date then
    data.donation_date = os.date("%Y-%m-%d")
  end
  
  if not data.payment_method then
    data.payment_method = "Cash"
  end
  
  local donation, err = donation_repo:create(data)
  if not donation then
    send_json_response(500, {
      success = false,
      error = "Failed to create donation: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(201, {
    success = true,
    data = donation,
    message = "Donation created successfully"
  })
end

-- Update donation
function DonationController.update()
  local id = ngx.var.id
  if not id then
    send_json_response(400, {
      success = false,
      error = "Donation ID is required"
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
  
  -- Validate data if key fields are provided
  if data.amount or data.category then
    local is_valid, validation_errors = validate_donation_data(data)
    if not is_valid then
      send_json_response(400, {
        success = false,
        error = "Validation failed",
        details = validation_errors
      })
    end
  end
  
  -- Check if donation exists
  local existing, check_err = donation_repo:find_by_id(tonumber(id))
  if not existing then
    if check_err then
      send_json_response(500, {
        success = false,
        error = "Failed to check existing donation: " .. check_err
      })
    else
      send_json_response(404, {
        success = false,
        error = "Donation not found"
      })
    end
  end
  
  local updated_donation, err = donation_repo:update_by_id(tonumber(id), data)
  if not updated_donation then
    send_json_response(500, {
      success = false,
      error = "Failed to update donation: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = updated_donation,
    message = "Donation updated successfully"
  })
end

-- Delete donation
function DonationController.delete()
  local id = ngx.var.id
  if not id then
    send_json_response(400, {
      success = false,
      error = "Donation ID is required"
    })
  end
  
  -- Check if donation exists
  local existing, check_err = donation_repo:find_by_id(tonumber(id))
  if not existing then
    if check_err then
      send_json_response(500, {
        success = false,
        error = "Failed to check existing donation: " .. check_err
      })
    else
      send_json_response(404, {
        success = false,
        error = "Donation not found"
      })
    end
  end
  
  local success, err = donation_repo:delete_by_id(tonumber(id))
  if not success then
    send_json_response(500, {
      success = false,
      error = "Failed to delete donation: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    message = "Donation deleted successfully"
  })
end

-- Get donations by member
function DonationController.get_by_member()
  local member_id = ngx.var.member_id
  if not member_id then
    send_json_response(400, {
      success = false,
      error = "Member ID is required"
    })
  end
  
  local args = ngx.req.get_uri_args()
  local options = {
    page = tonumber(args.page) or 1,
    per_page = tonumber(args.per_page) or 20,
    order_by = args.order_by or "donation_date",
    order_direction = args.order_direction or "DESC"
  }
  
  local donations, err = donation_repo:find_by_member(tonumber(member_id), options)
  if not donations then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch member donations: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = donations,
    pagination = {
      page = options.page,
      per_page = options.per_page,
      has_more = #donations == options.per_page
    }
  })
end

-- Get donations by date range
function DonationController.get_by_date_range()
  local args = ngx.req.get_uri_args()
  local start_date = args.start_date
  local end_date = args.end_date
  
  if not start_date or not end_date then
    send_json_response(400, {
      success = false,
      error = "start_date and end_date are required"
    })
  end
  
  -- Validate date format
  if not string.match(start_date, "^%d%d%d%d%-%d%d%-%d%d$") or not string.match(end_date, "^%d%d%d%d%-%d%d%-%d%d$") then
    send_json_response(400, {
      success = false,
      error = "Invalid date format. Use YYYY-MM-DD"
    })
  end
  
  local options = {
    page = tonumber(args.page) or 1,
    per_page = tonumber(args.per_page) or 20,
    order_by = args.order_by or "donation_date",
    order_direction = args.order_direction or "DESC"
  }
  
  local donations, err = donation_repo:find_by_date_range(start_date, end_date, options)
  if not donations then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch donations: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = donations,
    pagination = {
      page = options.page,
      per_page = options.per_page,
      has_more = #donations == options.per_page
    }
  })
end

-- Get donation statistics
function DonationController.get_statistics()
  local args = ngx.req.get_uri_args()
  local start_date = args.start_date
  local end_date = args.end_date
  
  local stats, err = donation_repo:get_donation_statistics(start_date, end_date)
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

-- Get top donors
function DonationController.get_top_donors()
  local args = ngx.req.get_uri_args()
  local start_date = args.start_date
  local end_date = args.end_date
  local limit = tonumber(args.limit) or 10
  
  local top_donors, err = donation_repo:get_top_donors(start_date, end_date, limit)
  if not top_donors then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch top donors: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = top_donors
  })
end

-- Get donation trends
function DonationController.get_trends()
  local args = ngx.req.get_uri_args()
  local start_date = args.start_date
  local end_date = args.end_date
  local interval = args.interval or "month" -- month, quarter, year
  
  if not start_date or not end_date then
    send_json_response(400, {
      success = false,
      error = "start_date and end_date are required"
    })
  end
  
  local valid_intervals = {month = true, quarter = true, year = true}
  if not valid_intervals[interval] then
    send_json_response(400, {
      success = false,
      error = "Invalid interval. Must be 'month', 'quarter', or 'year'"
    })
  end
  
  local trends, err = donation_repo:get_donation_trends(start_date, end_date, interval)
  if not trends then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch trends: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = trends
  })
end

-- Get donations by type
function DonationController.get_by_category()
  local category = ngx.var.category
  if not category then
    send_json_response(400, {
      success = false,
      error = "Category is required"
    })
  end
  
  local args = ngx.req.get_uri_args()
  local options = {
    page = tonumber(args.page) or 1,
    per_page = tonumber(args.per_page) or 20,
    order_by = args.order_by or "donation_date",
    order_direction = args.order_direction or "DESC"
  }
  
  local donations, err = donation_repo:find_by_category(category, options)
  if not donations then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch donations by category: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = donations,
    pagination = {
      page = options.page,
      per_page = options.per_page,
      has_more = #donations == options.per_page
    }
  })
end

-- Get member donation summary
function DonationController.get_member_summary()
  local member_id = ngx.var.member_id
  if not member_id then
    send_json_response(400, {
      success = false,
      error = "Member ID is required"
    })
  end
  
  local args = ngx.req.get_uri_args()
  local start_date = args.start_date
  local end_date = args.end_date
  
  local summary, err = donation_repo:get_member_donation_summary(tonumber(member_id), start_date, end_date)
  if not summary then
    send_json_response(500, {
      success = false,
      error = "Failed to fetch member summary: " .. (err or "Unknown error")
    })
  end
  
  send_json_response(200, {
    success = true,
    data = summary
  })
end

-- Search donations
function DonationController.search()
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
    order_by = args.order_by or "donation_date",
    order_direction = args.order_direction or "DESC"
  }
  
  local results, err = donation_repo:search_with_member_details(query, options)
  if not results then
    send_json_response(500, {
      success = false,
      error = "Search failed: " .. (err or "Unknown error")
    })
    return
  end
  
  -- Get total count for search results
  local total_count, count_err = donation_repo:count_search_with_member_details(query, {conditions = options.conditions})
  if not total_count then
    -- Fallback to result count if search count fails
    total_count = #results
  end
  
  send_json_response(200, {
    success = true,
    data = results,
    pagination = {
      page = options.page,
      per_page = options.per_page,
      total_count = total_count,
      total_pages = math.ceil(total_count / options.per_page),
      has_next = (options.page * options.per_page) < total_count,
      has_previous = options.page > 1
    }
  })
end

-- Bulk create donations
function DonationController.bulk_create()
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
  
  if not data.donations or type(data.donations) ~= "table" then
    send_json_response(400, {
      success = false,
      error = "donations array is required"
    })
  end
  
  local results = {}
  local errors = {}
  
  for i, donation_data in ipairs(data.donations) do
    -- Validate each donation
    local is_valid, validation_errors = validate_donation_data(donation_data)
    if not is_valid then
      errors[tostring(i)] = validation_errors
    else
      -- Set default values
      if not donation_data.donation_date then
        donation_data.donation_date = os.date("%Y-%m-%d")
      end
      
      if not donation_data.payment_method then
        donation_data.payment_method = "Cash"
      end
      
      local donation, err = donation_repo:create(donation_data)
      if donation then
        table.insert(results, donation)
      else
        errors[tostring(i)] = err or "Unknown error"
      end
    end
  end
  
  send_json_response(200, {
    success = true,
    data = {
      created_count = #results,
      created_donations = results,
      errors = errors
    },
    message = string.format("Created %d of %d donations", #results, #data.donations)
  })
end

return DonationController
