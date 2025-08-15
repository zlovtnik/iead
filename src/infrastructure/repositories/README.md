# Repository Pattern Implementation

This directory contains the base repository implementation and specific repository classes for the Church Management System.

## Overview

The repository pattern provides a consistent interface for data access operations, abstracting away the specific database implementation details. This implementation includes:

- **BaseRepository**: Generic CRUD operations with validation, pagination, and query building
- **Specific Repositories**: Domain-specific repositories that extend BaseRepository functionality
- **Type Safety**: Schema validation and type conversion
- **Query Building**: Flexible condition building with support for complex queries

## Features

### BaseRepository Features
- ✅ Generic CRUD operations (Create, Read, Update, Delete)
- ✅ Flexible query conditions with operators (LIKE, IN, etc.)
- ✅ Pagination with count and page information
- ✅ Data validation with type checking and constraints
- ✅ Transaction support through underlying database layer
- ✅ Custom query execution for complex operations
- ✅ Counting and existence checking

### Specific Repository Features
- ✅ Domain-specific business logic
- ✅ Custom validation rules
- ✅ Specialized search and filtering
- ✅ Statistics and reporting methods
- ✅ Computed fields and data transformations

## Usage Examples

### Basic Repository Usage

```lua
local BaseRepository = require("src.infrastructure.db.base_repository")

-- Create a repository for a table
local schema = {
  name = {type = "string", required = true, max_length = 100},
  price = {type = "number", required = false},
  is_active = {type = "number", required = false}
}

local product_repo = BaseRepository.new("products", schema)

-- Create a record
local product, err = product_repo:create({
  name = "Test Product",
  price = 29.99,
  is_active = 1
})

-- Find records
local all_products = product_repo:find_all()
local active_products = product_repo:find_all({
  conditions = {is_active = 1},
  order_by = "name",
  order_direction = "ASC"
})

-- Find with complex conditions
local expensive_products = product_repo:find_all({
  conditions = {
    price = {operator = ">=", value = 50.00},
    is_active = 1
  }
})

-- Pagination
local page_result = product_repo:paginate({
  page = 1,
  per_page = 10,
  conditions = {is_active = 1},
  order_by = "name"
})

-- Update and delete
local updated_product = product_repo:update_by_id(1, {price = 39.99})
local success = product_repo:delete_by_id(1)
```

### Specific Repository Usage

```lua
local UserRepository = require("src.infrastructure.repositories.user_repository")

local user_repo = UserRepository.new()

-- Create user (password is automatically hashed)
local user, err = user_repo:create({
  username = "john_doe",
  email = "john@example.com",
  password = "SecurePass123",
  role = "Member"
})

-- Verify credentials
local authenticated_user, auth_err = user_repo:verify_credentials("john_doe", "SecurePass123")

-- Find users by role
local admins = user_repo:find_by_role("Admin")

-- Search users
local search_results = user_repo:search("john")

-- Get statistics
local stats = user_repo:get_stats()
-- Returns: {total_users, active_users, inactive_users, admin_count, pastor_count, member_count}
```

### Member Repository Usage

```lua
local MemberRepository = require("src.infrastructure.repositories.member_repository")

local member_repo = MemberRepository.new()

-- Create member
local member = member_repo:create({
  first_name = "John",
  last_name = "Doe",
  email = "john.doe@example.com",
  phone = "555-0123",
  date_of_birth = "1990-05-15"
})

-- Search members
local search_results = member_repo:search("john")

-- Find birthdays this month
local birthday_members = member_repo:find_by_birth_month(5) -- May

-- Get member statistics
local stats = member_repo:get_stats()
-- Returns: {total_members, active_members, inactive_members, new_this_month, birthdays_this_month}
```

## Creating New Repositories

To create a new repository for a domain entity:

1. **Create the repository file** in `src/infrastructure/repositories/`
2. **Define the schema** with validation rules
3. **Extend BaseRepository** functionality
4. **Add domain-specific methods**

Example:

```lua
-- src/infrastructure/repositories/event_repository.lua
local BaseRepository = require("src.infrastructure.db.base_repository")

local EventRepository = {}
EventRepository.__index = EventRepository

function EventRepository.new()
  local schema = {
    title = {type = "string", required = true, max_length = 200},
    description = {type = "string", required = false},
    start_date = {type = "string", required = true},
    end_date = {type = "string", required = false},
    location = {type = "string", required = false, max_length = 255},
    max_attendees = {type = "number", required = false}
  }
  
  local base_repo = BaseRepository.new("events", schema)
  local instance = {base = base_repo}
  setmetatable(instance, EventRepository)
  return instance
end

-- Delegate basic operations
function EventRepository:find_all(options)
  return self.base:find_all(options)
end

function EventRepository:create(data)
  return self.base:create(data)
end

-- Add domain-specific methods
function EventRepository:find_upcoming_events()
  local today = os.date("!%Y-%m-%d")
  return self.base:find_all({
    conditions = {
      start_date = {operator = ">=", value = today}
    },
    order_by = "start_date"
  })
end

function EventRepository:find_events_in_date_range(start_date, end_date)
  local query = "SELECT * FROM events WHERE start_date >= ? AND start_date <= ? ORDER BY start_date"
  return self.base:execute_query(query, {start_date, end_date})
end

return EventRepository
```

## Schema Definition

Define validation schemas for your repositories:

```lua
local schema = {
  field_name = {
    type = "string|number|boolean",  -- Data type
    required = true|false,           -- Is field required
    max_length = number,             -- Maximum string length
    min_length = number,             -- Minimum string length
    -- Add custom validation as needed
  }
}
```

## Query Conditions

The repository supports flexible query conditions:

```lua
-- Simple equality
{field = value}

-- Operators
{field = {operator = "LIKE", value = "%search%"}}
{field = {operator = ">=", value = 100}}
{field = {operator = "!=", value = "inactive"}}

-- IN conditions
{field = {in = {1, 2, 3, 4}}}

-- Multiple conditions (AND)
{
  is_active = 1,
  role = "Admin",
  created_at = {operator = ">=", value = "2023-01-01"}
}
```

## Testing

Run the repository tests:

```bash
lua src/tests/test_base_repository.lua
```

The test suite covers:
- Repository creation and configuration
- CRUD operations
- Validation
- Query building
- Pagination
- Error handling
- Domain-specific functionality

## Integration with Existing Code

To integrate repositories with your existing controllers:

```lua
-- In your controller
local UserRepository = require("src.infrastructure.repositories.user_repository")

local UserController = {}

function UserController.list_users(client, params)
  local user_repo = UserRepository.new()
  
  local page = tonumber(params.page) or 1
  local per_page = tonumber(params.per_page) or 10
  
  local result, err = user_repo:paginate({
    page = page,
    per_page = per_page,
    conditions = params.filters,
    order_by = params.sort_by or "username"
  })
  
  if not result then
    json_utils.send_json_response(client, 500, {error = err})
    return
  end
  
  json_utils.send_json_response(client, 200, result)
end

function UserController.create_user(client, params)
  local user_repo = UserRepository.new()
  
  local user, err = user_repo:create(params)
  if not user then
    json_utils.send_json_response(client, 400, {error = err})
    return
  end
  
  json_utils.send_json_response(client, 201, user)
end

return UserController
```

## Benefits

1. **Consistency**: All data access follows the same patterns
2. **Type Safety**: Schema validation prevents data corruption
3. **Maintainability**: Business logic is separated from data access
4. **Testability**: Easy to mock and test repository operations
5. **Flexibility**: Custom queries for complex operations
6. **Performance**: Built-in pagination and query optimization
7. **Validation**: Automatic data validation and sanitization

## Next Steps

1. Create repositories for remaining entities (Event, Donation, Tithe, etc.)
2. Integrate repositories into existing controllers
3. Add repository-specific unit tests
4. Consider adding caching layer for frequently accessed data
5. Implement soft delete functionality if needed
6. Add database connection monitoring and health checks
