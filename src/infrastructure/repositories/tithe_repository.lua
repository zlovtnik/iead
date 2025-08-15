-- src/infrastructure/repositories/tithe_repository.lua
-- Tithe repository implementation using BaseRepository

local BaseRepository = require("src.infrastructure.db.base_repository")

local TitheRepository = {}
TitheRepository.__index = TitheRepository

-- Create a new TitheRepository instance
function TitheRepository.new()
  local schema = {
    member_id = {
      type = "number",
      required = true
    },
    amount = {
      type = "number",
      required = true
    },
    tithe_date = {
      type = "string",
      required = true
    },
    payment_method = {
      type = "string",
      required = true,
      max_length = 50
    },
    is_paid = {
      type = "number",
      required = false
    },
    notes = {
      type = "string",
      required = false
    }
  }
  
  local base_repo = BaseRepository.new("tithes", schema)
  local instance = {
    base = base_repo
  }
  setmetatable(instance, TitheRepository)
  return instance
end

-- Delegate to base repository methods
function TitheRepository:find_all(options)
  return self.base:find_all(options)
end

function TitheRepository:find_one(conditions)
  return self.base:find_one(conditions)
end

function TitheRepository:find_by_id(id)
  return self.base:find_by_id(id)
end

function TitheRepository:update_by_id(id, data)
  return self.base:update_by_id(id, data)
end

function TitheRepository:delete_by_id(id)
  return self.base:delete_by_id(id)
end

function TitheRepository:count(conditions)
  return self.base:count(conditions)
end

function TitheRepository:exists(conditions)
  return self.base:exists(conditions)
end

function TitheRepository:paginate(options)
  return self.base:paginate(options)
end

-- Custom create method with default values
function TitheRepository:create(data)
  -- Set default tithe date to today if not provided
  if not data.tithe_date then
    data.tithe_date = os.date("%Y-%m-%d")
  end
  
  -- Set default payment method if not provided
  if not data.payment_method then
    data.payment_method = "Cash"
  end
  
  -- Set default paid status
  if data.is_paid == nil then
    data.is_paid = 1  -- Default to paid
  end
  
  return self.base:create(data)
end

-- Custom update method (delegates to base)
function TitheRepository:update(conditions, data)
  return self.base:update(conditions, data)
end

-- Find tithes by member
function TitheRepository:find_by_member(member_id, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.member_id = member_id
  
  if not options.order_by then
    options.order_by = "tithe_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find tithes by date range
function TitheRepository:find_by_date_range(start_date, end_date, options)
  options = options or {}
  
  local query = [[
    SELECT t.*, m.first_name, m.last_name, m.email
    FROM tithes t
    JOIN members m ON t.member_id = m.id
    WHERE t.tithe_date >= ? AND t.tithe_date <= ?
  ]]
  
  local params = {start_date, end_date}
  
  -- Add additional conditions
  if options.conditions then
    for field, value in pairs(options.conditions) do
      if field ~= "tithe_date" then
        query = query .. " AND t." .. field .. " = ?"
        table.insert(params, value)
      end
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    query = query .. " ORDER BY t." .. options.order_by .. " " .. direction
  else
    query = query .. " ORDER BY t.tithe_date DESC"
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

-- Find paid/unpaid tithes
function TitheRepository:find_by_payment_status(is_paid, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.is_paid = is_paid and 1 or 0
  
  if not options.order_by then
    options.order_by = "tithe_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Find tithes by payment method
function TitheRepository:find_by_payment_method(payment_method, options)
  options = options or {}
  options.conditions = options.conditions or {}
  options.conditions.payment_method = payment_method
  
  if not options.order_by then
    options.order_by = "tithe_date"
    options.order_direction = "DESC"
  end
  
  return self:find_all(options)
end

-- Get total tithes for a date range
function TitheRepository:get_total_by_date_range(start_date, end_date, conditions)
  conditions = conditions or {}
  
  local query = "SELECT SUM(amount) as total FROM tithes WHERE tithe_date >= ? AND tithe_date <= ?"
  local params = {start_date, end_date}
  
  -- Add additional conditions
  for field, value in pairs(conditions) do
    if field ~= "tithe_date" then
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

-- Get member tithe summary for a date range
function TitheRepository:get_member_tithe_summary(member_id, start_date, end_date)
  local query = [[
    SELECT 
      COUNT(*) as tithe_count,
      SUM(amount) as total_amount,
      AVG(amount) as average_amount,
      COUNT(CASE WHEN is_paid = 1 THEN 1 END) as paid_count,
      COUNT(CASE WHEN is_paid = 0 THEN 1 END) as unpaid_count,
      SUM(CASE WHEN is_paid = 1 THEN amount ELSE 0 END) as paid_amount,
      SUM(CASE WHEN is_paid = 0 THEN amount ELSE 0 END) as unpaid_amount
    FROM tithes 
    WHERE member_id = ? AND tithe_date >= ? AND tithe_date <= ?
  ]]
  
  return self.base:execute_query_one(query, {member_id, start_date, end_date})
end

-- Get top tithe contributors for a date range
function TitheRepository:get_top_contributors(start_date, end_date, limit)
  limit = limit or 10
  
  local query = [[
    SELECT t.member_id, m.first_name, m.last_name, m.email,
           SUM(t.amount) as total_tithed,
           COUNT(t.id) as tithe_count,
           AVG(t.amount) as average_tithe
    FROM tithes t
    JOIN members m ON t.member_id = m.id
    WHERE t.tithe_date >= ? AND t.tithe_date <= ?
    AND t.is_paid = 1
    GROUP BY t.member_id, m.first_name, m.last_name, m.email
    ORDER BY total_tithed DESC
    LIMIT ?
  ]]
  
  return self.base:execute_query(query, {start_date, end_date, limit})
end

-- Get tithe statistics for a date range
function TitheRepository:get_stats_by_date_range(start_date, end_date)
  -- Total amount (all tithes)
  local total_amount, total_err = self:get_total_by_date_range(start_date, end_date)
  if not total_amount then
    return nil, total_err
  end
  
  -- Paid amount
  local paid_amount, paid_err = self:get_total_by_date_range(start_date, end_date, {is_paid = 1})
  if not paid_amount then
    return nil, paid_err
  end
  
  -- Unpaid amount
  local unpaid_amount = total_amount - paid_amount
  
  -- Total count
  local total_count, count_err = self:count({
    tithe_date = {operator = ">=", value = start_date}
  })
  if not total_count then
    return nil, count_err
  end
  
  -- Paid count
  local paid_count, paid_count_err = self:count({
    tithe_date = {operator = ">=", value = start_date},
    is_paid = 1
  })
  if not paid_count then
    return nil, paid_count_err
  end
  
  -- Unpaid count
  local unpaid_count = total_count - paid_count
  
  -- Payment method breakdown
  local payment_stats_query = [[
    SELECT payment_method, COUNT(*) as count, SUM(amount) as total
    FROM tithes 
    WHERE tithe_date >= ? AND tithe_date <= ?
    GROUP BY payment_method
    ORDER BY total DESC
  ]]
  
  local payment_stats, payment_err = self.base:execute_query(payment_stats_query, {start_date, end_date})
  if not payment_stats then
    return nil, payment_err
  end
  
  -- Average tithe
  local average_tithe = total_count > 0 and (total_amount / total_count) or 0
  
  return {
    total_amount = total_amount,
    paid_amount = paid_amount,
    unpaid_amount = unpaid_amount,
    total_count = total_count,
    paid_count = paid_count,
    unpaid_count = unpaid_count,
    average_tithe = average_tithe,
    payment_collection_rate = total_count > 0 and (paid_count / total_count * 100) or 0,
    payment_method_stats = payment_stats
  }, nil
end

-- Get monthly tithe summary
function TitheRepository:get_monthly_summary(year, month)
  local start_date = string.format("%04d-%02d-01", year, month)
  local next_month = month == 12 and 1 or month + 1
  local next_year = month == 12 and year + 1 or year
  local end_date = string.format("%04d-%02d-01", next_year, next_month)
  
  return self:get_stats_by_date_range(start_date, end_date)
end

-- Get yearly tithe summary
function TitheRepository:get_yearly_summary(year)
  local start_date = string.format("%04d-01-01", year)
  local end_date = string.format("%04d-12-31", year)
  
  return self:get_stats_by_date_range(start_date, end_date)
end

-- Mark tithe as paid/unpaid
function TitheRepository:set_payment_status(tithe_id, is_paid)
  return self:update_by_id(tithe_id, {is_paid = is_paid and 1 or 0})
end

-- Search tithes with member information
function TitheRepository:search_with_member_info(query, options)
  options = options or {}
  
  local search_query = [[
    SELECT t.*, m.first_name, m.last_name, m.email
    FROM tithes t
    JOIN members m ON t.member_id = m.id
    WHERE (m.first_name LIKE ? OR m.last_name LIKE ? OR m.email LIKE ? 
           OR t.notes LIKE ?)
  ]]
  
  local search_param = "%" .. query .. "%"
  local params = {search_param, search_param, search_param, search_param}
  
  -- Add additional conditions
  if options.conditions then
    for field, value in pairs(options.conditions) do
      search_query = search_query .. " AND t." .. field .. " = ?"
      table.insert(params, value)
    end
  end
  
  -- Add ordering
  if options.order_by then
    local direction = options.order_direction or "ASC"
    search_query = search_query .. " ORDER BY t." .. options.order_by .. " " .. direction
  else
    search_query = search_query .. " ORDER BY t.tithe_date DESC"
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

-- Get tithe trend for a member over time
function TitheRepository:get_member_tithe_trend(member_id, months_back)
  months_back = months_back or 12
  
  local query = [[
    SELECT 
      strftime('%Y-%m', tithe_date) as month,
      COUNT(*) as tithe_count,
      SUM(amount) as total_amount,
      AVG(amount) as average_amount,
      COUNT(CASE WHEN is_paid = 1 THEN 1 END) as paid_count,
      SUM(CASE WHEN is_paid = 1 THEN amount ELSE 0 END) as paid_amount
    FROM tithes
    WHERE member_id = ?
    AND tithe_date >= date('now', '-' || ? || ' months')
    GROUP BY strftime('%Y-%m', tithe_date)
    ORDER BY month DESC
  ]]
  
  return self.base:execute_query(query, {member_id, months_back})
end

-- Get unpaid tithes for follow-up
function TitheRepository:get_unpaid_tithes_for_followup(days_overdue)
  days_overdue = days_overdue or 30
  
  local cutoff_date = os.date("%Y-%m-%d", os.time() - (days_overdue * 24 * 60 * 60))
  
  local query = [[
    SELECT t.*, m.first_name, m.last_name, m.email, m.phone
    FROM tithes t
    JOIN members m ON t.member_id = m.id
    WHERE t.is_paid = 0 
    AND t.tithe_date <= ?
    AND m.is_active = 1
    ORDER BY t.tithe_date ASC, m.last_name ASC
  ]]
  
  return self.base:execute_query(query, {cutoff_date})
end

return TitheRepository
