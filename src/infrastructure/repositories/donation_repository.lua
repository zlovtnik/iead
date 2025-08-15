-- src/infrastructure/repositories/donation_repository.lua
-- Donation repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")

local DonationRepository = {}
DonationRepository.__index = DonationRepository

-- Create a new DonationRepository instance
function DonationRepository.new()
  local schema = {
    member_id = {
      type = "number",
      required = false  -- Anonymous donations allowed
    },
    amount = {
      type = "number",
      required = true
    },
    donation_date = {
      type = "string",
      required = true
    },
    payment_method = {
      type = "string",
      required = true,
      max_length = 50
    },
    category = {
      type = "string",
      required = false,
      max_length = 100
    },
    notes = {
      type = "string",
      required = false
    }
  }
  
  local base_repo = BaseRepository.new("donations", schema)
  local instance = {
    base = base_repo
  }
  setmetatable(instance, DonationRepository)
  return instance
end

-- Delegate to base repository methods
function DonationRepository:find_all(options)
  return self.base:find_all(options)
end

function DonationRepository:find_one(conditions)
  return self.base:find_one(conditions)
end

function DonationRepository:find_by_id(id)
  return self.base:find_by_id(id)
end

function DonationRepository:update_by_id(id, data)
  return self.base:update_by_id(id, data)
end

function DonationRepository:delete_by_id(id)
  return self.base:delete_by_id(id)
end

function DonationRepository:count(conditions)
  return self.base:count(conditions)
end

function DonationRepository:exists(conditions)
  return self.base:exists(conditions)
end

function DonationRepository:paginate(options)
  return self.base:paginate(options)
end

-- Custom create method with default values
function DonationRepository:create(data)
  -- Set default donation date to today if not provided
  if not data.donation_date then
    data.donation_date = os.date("!%Y-%m-%d")
  end
  
  -- Set default payment method if not provided
  if not data.payment_method then
    data.payment_method = "Cash"
  end
  
  return self.base:create(data)
end

-- Custom update method (delegates to base)
function DonationRepository:update(conditions, data)
  return self.base:update(conditions, data)
end

-- Find donations by member
function DonationRepository:find_by_member(member_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.member_id = member_id
  
  if not options.order_by then
    options.order_by = "donation_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find donations in date range
function DonationRepository:find_by_date_range(start_date, end_date, options)
  options = options or {}
  
  local query = [[
    SELECT d.*, m.first_name, m.last_name, m.email
    FROM donations d
    LEFT JOIN members m ON d.member_id = m.id
    WHERE d.donation_date >= ? AND d.donation_date <= ?
  ]]
  
  local params = {start_date, end_date}
  
  -- Add additional conditions
  if options.conditions then
    for field, value in pairs(options.conditions) do
      if field ~= "donation_date" then
        query = query .. " AND d." .. field .. " = ?"
        table.insert(params, value)
      end
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    query = query .. " ORDER BY d." .. options.order_by .. " " .. direction
  else
    query = query .. " ORDER BY d.donation_date DESC"
  end
  
  -- Add pagination
  if options.limit then
    query = query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset then
      query = query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return self.base:execute_query(query, params)
end

-- Find donations by category
function DonationRepository:find_by_category(category, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.category = category
  
  if not options.order_by then
    options.order_by = "donation_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find donations by payment method
function DonationRepository:find_by_payment_method(payment_method, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.payment_method = payment_method
  
  if not options.order_by then
    options.order_by = "donation_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Get total donations for a date range
function DonationRepository:get_total_by_date_range(start_date, end_date, conditions)
  conditions = conditions or {}
  
  local query = "SELECT SUM(amount) as total FROM donations WHERE donation_date >= ? AND donation_date <= ?"
  local params = {start_date, end_date}
  
  -- Add additional conditions
  for field, value in pairs(conditions) do
    if field ~= "donation_date" then
      query = query .. " AND " .. field .. " = ?"
      table.insert(params, value)
    end
  end
  
  local result, err = self.base:execute_query_one(query, params)
  if not result then
    return nil, err
  end
  
  return tonumber(result.total) or 0, nil
end

-- Get top donors for a date range
function DonationRepository:get_top_donors(start_date, end_date, limit)
  limit = limit or 10
  
  local query = [[
    SELECT d.member_id, m.first_name, m.last_name, m.email,
           SUM(d.amount) as total_donated,
           COUNT(d.id) as donation_count
    FROM donations d
    LEFT JOIN members m ON d.member_id = m.id
    WHERE d.donation_date >= ? AND d.donation_date <= ?
    AND d.member_id IS NOT NULL
    GROUP BY d.member_id, m.first_name, m.last_name, m.email
    ORDER BY total_donated DESC
    LIMIT ?
  ]]
  
  return self.base:execute_query(query, {start_date, end_date, limit})
end

-- Get donation statistics for a date range
function DonationRepository:get_stats_by_date_range(start_date, end_date)
  -- Total amount
  local total_amount, total_err = self:get_total_by_date_range(start_date, end_date)
  if not total_amount then
    return nil, total_err
  end
  
  -- Total count
  local total_count, count_err = self:count({
    donation_date = {operator = ">=", value = start_date}
  })
  if not total_count then
    return nil, count_err
  end
  
  -- Count by payment method
  local payment_stats_query = [[
    SELECT payment_method, COUNT(*) as count, SUM(amount) as total
    FROM donations 
    WHERE donation_date >= ? AND donation_date <= ?
    GROUP BY payment_method
    ORDER BY total DESC
  ]]
  
  local payment_stats, payment_err = self.base:execute_query(payment_stats_query, {start_date, end_date})
  if not payment_stats then
    return nil, payment_err
  end
  
  -- Count by category
  local category_stats_query = [[
    SELECT category, COUNT(*) as count, SUM(amount) as total
    FROM donations 
    WHERE donation_date >= ? AND donation_date <= ?
    AND category IS NOT NULL AND category != ''
    GROUP BY category
    ORDER BY total DESC
  ]]
  
  local category_stats, category_err = self.base:execute_query(category_stats_query, {start_date, end_date})
  if not category_stats then
    return nil, category_err
  end
  
  -- Average donation
  local average_donation = total_count > 0 and (total_amount / total_count) or 0
  
  return {
    total_amount = total_amount,
    total_count = total_count,
    average_donation = average_donation,
    payment_method_stats = payment_stats,
    category_stats = category_stats
  }, nil
end

-- Get monthly donation summary
function DonationRepository:get_monthly_summary(year, month)
  local start_date = string.format("%04d-%02d-01", year, month)
  local next_month = month == 12 and 1 or month + 1
  local next_year = month == 12 and year + 1 or year
  local end_date = string.format("%04d-%02d-01", next_year, next_month)
  
  return self:get_stats_by_date_range(start_date, end_date)
end

-- Get yearly donation summary
function DonationRepository:get_yearly_summary(year)
  local start_date = string.format("%04d-01-01", year)
  local end_date = string.format("%04d-12-31", year)
  
  return self:get_stats_by_date_range(start_date, end_date)
end

-- Search donations with member information
function DonationRepository:search_with_member_info(query, options)
  options = options or {}
  
  local search_query = [[
    SELECT d.*, m.first_name, m.last_name, m.email
    FROM donations d
    LEFT JOIN members m ON d.member_id = m.id
    WHERE (m.first_name LIKE ? OR m.last_name LIKE ? OR m.email LIKE ? 
           OR d.category LIKE ? OR d.notes LIKE ?)
  ]]
  
  local search_param = "%" .. query .. "%"
  local params = {search_param, search_param, search_param, search_param, search_param}
  
  -- Add additional conditions
  if options.conditions then
    for field, value in pairs(options.conditions) do
      search_query = search_query .. " AND d." .. field .. " = ?"
      table.insert(params, value)
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    search_query = search_query .. " ORDER BY d." .. options.order_by .. " " .. direction
  else
    search_query = search_query .. " ORDER BY d.donation_date DESC"
  end
  
  -- Add pagination
  if options.limit then
    search_query = search_query .. " LIMIT ?"
    table.insert(params, options.limit)
    
    if options.offset then
      search_query = search_query .. " OFFSET ?"
      table.insert(params, options.offset)
    end
  end
  
  return self.base:execute_query(search_query, params)
end

-- Alias for backward compatibility
function DonationRepository:search_with_member_details(query, options)
  return self:search_with_member_info(query, options)
end

-- Count search results for donations with member information (for pagination)
function DonationRepository:count_search_with_member_details(query, options)
  options = options or {}
  
  local count_query = [[
    SELECT COUNT(*) as count
    FROM donations d
    LEFT JOIN members m ON d.member_id = m.id
    WHERE (m.first_name LIKE ? OR m.last_name LIKE ? OR m.email LIKE ? 
           OR d.category LIKE ? OR d.notes LIKE ?)
  ]]
  
  local search_param = "%" .. query .. "%"
  local params = {search_param, search_param, search_param, search_param, search_param}
  
  -- Add additional conditions
  if options.conditions then
    for field, value in pairs(options.conditions) do
      count_query = count_query .. " AND d." .. field .. " = ?"
      table.insert(params, value)
    end
  end
  
  local result, err = self.base:execute_query_one(count_query, params)
  if not result then
    return nil, err
  end
  
  return tonumber(result.count)
end

-- Get anonymous donations
function DonationRepository:find_anonymous_donations(options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.member_id = nil  -- This might need adjustment based on how NULL is handled
  
  if not options.order_by then
    options.order_by = "donation_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

return DonationRepository
