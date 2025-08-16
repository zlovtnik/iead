-- src/controllers/example_standardized_controller.lua
-- Example controller demonstrating the new standardized API layer

local ApiMiddleware = require("src.application.middlewares.api_middleware")
local MemberRepository = require("src.infrastructure.repositories.member_repository")
local log = require("src.utils.log")

-- Helper function to get table keys
local function get_table_keys(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

local ExampleController = {}

-- Create repository instance
local member_repo = MemberRepository.new()

-- Get all members with standardized response format
-- GET /api/v1/members
function ExampleController.index(client, params)
  local request_id = params.request_id
  
  log.info("Fetching members list", {
    request_id = request_id,
    user_id = params.current_user and params.current_user.id,
    api_version = params.api_version
  })
  
  -- Extract pagination parameters (already validated by middleware)
  local page = params.page or 1
  local per_page = params.per_page or 20
  local order_by = params.order_by or "last_name"
  local order_direction = params.order_direction or "ASC"
  
  local options = {
    page = page,
    per_page = per_page,
    order_by = order_by,
    order_direction = order_direction
  }
  
  -- Handle search if provided
  if params.search and params.search ~= "" then
    local members, err = member_repo:search(params.search, options)
    
    if not members then
      return params.handle_error({
        message = "Failed to search members: " .. (err or "Unknown error"),
        code = "SEARCH_FAILED",
        status_code = 500
      })
    end
    
    -- Get total count for search results
    local total_count, count_err = member_repo:count_search(params.search, {conditions = options.conditions})
    if not total_count then
      -- Fallback to result count if search count fails
      total_count = #members
    end
    
    return params.send_success(members, "Members search completed successfully", nil, {
      page = page,
      per_page = per_page,
      total_count = total_count
    })
  end
  
  -- Regular paginated listing
  local result, err = member_repo:paginate(options)
  
  if not result then
    return params.handle_error({
      message = "Failed to fetch members: " .. (err or "Unknown error"),
      code = "FETCH_FAILED", 
      status_code = 500
    })
  end
  
  return params.send_success(result.data, "Members retrieved successfully", nil, {
    page = page,
    per_page = per_page,
    total_count = result.total_count
  })
end

-- Get a single member by ID
-- GET /api/v1/members/:id
function ExampleController.show(client, params)
  local member_id = params.id
  
  if not member_id then
    return params.send_error(400, "BAD_REQUEST", "Member ID is required")
  end
  
  log.info("Fetching member details", {
    request_id = params.request_id,
    member_id = member_id,
    user_id = params.current_user and params.current_user.id
  })
  
  local member, err = member_repo:find_by_id(tonumber(member_id))
  
  if not member then
    if err and type(err) == "string" and string.find(err:lower(), "not found") then
      return params.send_not_found("Member")
    else
      return params.handle_error({
        message = "Failed to fetch member: " .. (err or "Unknown error"),
        code = "FETCH_FAILED",
        status_code = 500
      })
    end
  end
  
  return params.send_success(member, "Member retrieved successfully")
end

-- Create a new member
-- POST /api/v1/members
function ExampleController.create(client, params)
  log.info("Creating new member", {
    request_id = params.request_id,
    user_id = params.current_user and params.current_user.id,
    member_data = {
      first_name = params.first_name,
      last_name = params.last_name,
      email = params.email
    }
  })
  
  -- Data is already validated by middleware
  local member_data = {
    first_name = params.first_name,
    last_name = params.last_name,
    email = params.email,
    phone = params.phone,
    address = params.address,
    birth_date = params.birth_date,
    join_date = params.join_date or os.date("%Y-%m-%d"),
    status = params.status or "Active"
  }
  
  local member, err = member_repo:create(member_data)
  
  if not member then
    -- Check for common errors
    if err and type(err) == "string" and string.find(err:lower(), "unique constraint") then
      return params.handle_error({
        message = "A member with this email already exists",
        code = "EMAIL_ALREADY_EXISTS",
        status_code = 409
      })
    else
      return params.handle_error({
        message = "Failed to create member: " .. (err or "Unknown error"),
        code = "CREATION_FAILED",
        status_code = 500
      })
    end
  end
  
  log.info("Member created successfully", {
    request_id = params.request_id,
    member_id = member.id,
    user_id = params.current_user and params.current_user.id
  })
  
  return params.send_created(member, "Member created successfully")
end

-- Update an existing member
-- PUT /api/v1/members/:id
function ExampleController.update(client, params)
  local member_id = params.id
  
  if not member_id then
    return params.send_error(400, "BAD_REQUEST", "Member ID is required")
  end
  
  log.info("Updating member", {
    request_id = params.request_id,
    member_id = member_id,
    user_id = params.current_user and params.current_user.id
  })
  
  -- Check if member exists
  local existing_member, _ = member_repo:find_by_id(tonumber(member_id))
  if not existing_member then
    return params.send_not_found("Member")
  end
  
  -- Build update data from validated params
  local update_data = {}
  local updatable_fields = {
    "first_name", "last_name", "email", "phone", 
    "address", "birth_date", "join_date", "status"
  }
  
  for _, field in ipairs(updatable_fields) do
    if params[field] ~= nil then
      update_data[field] = params[field]
    end
  end
  
  if next(update_data) == nil then
    return params.send_error(400, "BAD_REQUEST", "No valid fields provided for update")
  end
  
  local updated_member, err = member_repo:update(tonumber(member_id), update_data)
  
  if not updated_member then
    if err and type(err) == "string" and string.find(err:lower(), "unique constraint") then
      return params.handle_error({
        message = "A member with this email already exists",
        code = "EMAIL_ALREADY_EXISTS",
        status_code = 409
      })
    else
      return params.handle_error({
        message = "Failed to update member: " .. (err or "Unknown error"),
        code = "UPDATE_FAILED",
        status_code = 500
      })
    end
  end
  
  log.info("Member updated successfully", {
    request_id = params.request_id,
    member_id = member_id,
    user_id = params.current_user and params.current_user.id,
    updated_fields = get_table_keys(update_data)
  })
  
  return params.send_success(updated_member, "Member updated successfully")
end

-- Delete a member (soft delete)
-- DELETE /api/v1/members/:id  
function ExampleController.destroy(client, params)
  local member_id = params.id
  
  if not member_id then
    return params.send_error(400, "BAD_REQUEST", "Member ID is required")
  end
  
  log.info("Deleting member", {
    request_id = params.request_id,
    member_id = member_id,
    user_id = params.current_user and params.current_user.id
  })
  
  -- Check if member exists
  local existing_member, _ = member_repo:find_by_id(tonumber(member_id))
  if not existing_member then
    return params.send_not_found("Member")
  end
  
  local success, err = member_repo:delete(tonumber(member_id))
  
  if not success then
    return params.handle_error({
      message = "Failed to delete member: " .. (err or "Unknown error"),
      code = "DELETION_FAILED",
      status_code = 500
    })
  end
  
  log.info("Member deleted successfully", {
    request_id = params.request_id,
    member_id = member_id,
    user_id = params.current_user and params.current_user.id
  })
  
  return params.send_success(nil, "Member deleted successfully")
end

-- Create middleware configurations for each endpoint
ExampleController.middleware = {
  -- List members - Pastor+ required, with pagination validation
  index = ApiMiddleware.presets.pastor_only({
    validation_schema = ApiMiddleware.RequestValidator.combine_schemas(
      ApiMiddleware.schemas.pagination,
      ApiMiddleware.schemas.search
    ),
    endpoint = "members.index"
  }),
  
  -- Show member - Member+ required (with member access control in auth middleware)
  show = ApiMiddleware.presets.authenticated({
    endpoint = "members.show"
  }),
  
  -- Create member - Pastor+ required, with full validation
  create = ApiMiddleware.presets.pastor_only({
    validation_schema = ApiMiddleware.schemas.member_create,
    endpoint = "members.create"
  }),
  
  -- Update member - Pastor+ required, with update validation
  update = ApiMiddleware.presets.pastor_only({
    validation_schema = ApiMiddleware.schemas.member_update,
    endpoint = "members.update"
  }),
  
  -- Delete member - Admin only
  destroy = ApiMiddleware.presets.admin_only({
    endpoint = "members.destroy"
  })
}

return ExampleController
