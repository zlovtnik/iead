-- src/tests/test_base_repository.lua
-- Unit tests for BaseRepository implementation

local BaseRepository = require("src.infrastructure.db.base_repository")
local UserRepository = require("src.infrastructure.repositories.user_repository")

-- Test configuration
local test_db_file = "test_repository.db"

-- Override database configuration for testing
package.loaded["src.config.database"] = {
  db_file = test_db_file
}

local db = require("src.infrastructure.db.connection")

local tests = {}

-- Test utilities
local function setup_test_db()
  -- Remove existing test database
  os.remove(test_db_file)
  
  -- Initialize database tables
  local env = require("luasql.sqlite3")()
  local conn = env:connect(test_db_file)
  
  -- Create test table
  conn:execute([[
    CREATE TABLE test_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      price REAL,
      is_active INTEGER DEFAULT 1,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ]])
  
  -- Create users table for UserRepository tests
  conn:execute([[
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'Member',
      member_id INTEGER,
      is_active INTEGER DEFAULT 1,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ]])
  
  conn:close()
  env:close()
end

local function cleanup_test_db()
  os.remove(test_db_file)
end

-- Test BaseRepository creation
function tests.test_create_repository()
  setup_test_db()
  
  local schema = {
    name = {type = "string", required = true, max_length = 100},
    description = {type = "string", required = false},
    price = {type = "number", required = false},
    is_active = {type = "number", required = false}
  }
  
  local repo = BaseRepository.new("test_items", schema)
  
  assert(repo ~= nil, "Repository should be created")
  assert(repo.table_name == "test_items", "Table name should be set correctly")
  assert(repo.primary_key == "id", "Default primary key should be 'id'")
  
  cleanup_test_db()
end

-- Test repository create operation
function tests.test_repository_create()
  setup_test_db()
  
  local schema = {
    name = {type = "string", required = true, max_length = 100},
    price = {type = "number", required = false}
  }
  
  local repo = BaseRepository.new("test_items", schema)
  
  -- Test successful create
  local item, err = repo:create({
    name = "Test Item",
    description = "A test item",
    price = 29.99,
    is_active = 1
  })
  
  assert(item ~= nil, "Item should be created: " .. (err or ""))
  assert(item.name == "Test Item", "Name should be set correctly")
  assert(tonumber(item.price) == 29.99, "Price should be set correctly")
  
  -- Test validation error
  local invalid_item, invalid_err = repo:create({
    description = "Missing required name field"
  })
  
  assert(invalid_item == nil, "Invalid item should not be created")
  assert(invalid_err ~= nil, "Should return validation error")
  
  cleanup_test_db()
end

-- Test repository find operations
function tests.test_repository_find()
  setup_test_db()
  
  local repo = BaseRepository.new("test_items")
  
  -- Create test data
  repo:create({name = "Item 1", price = 10.00})
  repo:create({name = "Item 2", price = 20.00})
  repo:create({name = "Item 3", price = 30.00, is_active = 0})
  
  -- Test find_all
  local all_items, err = repo:find_all()
  assert(all_items ~= nil, "Should find all items: " .. (err or ""))
  assert(#all_items == 3, "Should find 3 items")
  
  -- Test find_all with conditions
  local active_items, active_err = repo:find_all({
    conditions = {is_active = 1}
  })
  assert(active_items ~= nil, "Should find active items: " .. (active_err or ""))
  assert(#active_items == 2, "Should find 2 active items")
  
  -- Test find_one
  local item, item_err = repo:find_one({name = "Item 1"})
  assert(item ~= nil, "Should find specific item: " .. (item_err or ""))
  assert(item.name == "Item 1", "Should find correct item")
  
  -- Test find_by_id
  local item_by_id, id_err = repo:find_by_id(1)
  assert(item_by_id ~= nil, "Should find item by ID: " .. (id_err or ""))
  assert(tonumber(item_by_id.id) == 1, "Should find correct item by ID")
  
  cleanup_test_db()
end

-- Test repository update operations
function tests.test_repository_update()
  setup_test_db()
  
  local repo = BaseRepository.new("test_items")
  
  -- Create test item
  local item, create_err = repo:create({name = "Original Name", price = 10.00})
  assert(item ~= nil, "Should create item: " .. (create_err or ""))
  
  -- Test update_by_id
  local updated_item, update_err = repo:update_by_id(item.id, {
    name = "Updated Name",
    price = 15.00
  })
  
  assert(updated_item ~= nil, "Should update item: " .. (update_err or ""))
  assert(updated_item.name == "Updated Name", "Name should be updated")
  assert(tonumber(updated_item.price) == 15.00, "Price should be updated")
  
  cleanup_test_db()
end

-- Test repository delete operations
function tests.test_repository_delete()
  setup_test_db()
  
  local repo = BaseRepository.new("test_items")
  
  -- Create test items
  repo:create({name = "Item 1"})
  repo:create({name = "Item 2"})
  
  -- Test delete_by_id
  local success, err = repo:delete_by_id(1)
  assert(success == true, "Should delete item: " .. (err or ""))
  
  -- Verify item is deleted
  local deleted_item, find_err = repo:find_by_id(1)
  assert(deleted_item == nil, "Item should be deleted")
  
  -- Test delete with conditions
  local affected_rows, delete_err = repo:delete({name = "Item 2"})
  assert(affected_rows ~= nil, "Should delete by conditions: " .. (delete_err or ""))
  assert(affected_rows == 1, "Should delete 1 row")
  
  cleanup_test_db()
end

-- Test repository count and exists operations
function tests.test_repository_count_exists()
  setup_test_db()
  
  local repo = BaseRepository.new("test_items")
  
  -- Create test items
  repo:create({name = "Item 1", is_active = 1})
  repo:create({name = "Item 2", is_active = 1})
  repo:create({name = "Item 3", is_active = 0})
  
  -- Test count
  local total_count, count_err = repo:count()
  assert(total_count ~= nil, "Should count items: " .. (count_err or ""))
  assert(total_count == 3, "Should count 3 items")
  
  -- Test count with conditions
  local active_count, active_count_err = repo:count({is_active = 1})
  assert(active_count ~= nil, "Should count active items: " .. (active_count_err or ""))
  assert(active_count == 2, "Should count 2 active items")
  
  -- Test exists
  local exists, exists_err = repo:exists({name = "Item 1"})
  assert(exists == true, "Item should exist: " .. (exists_err or ""))
  
  local not_exists, not_exists_err = repo:exists({name = "Nonexistent"})
  assert(not_exists == false, "Nonexistent item should not exist")
  
  cleanup_test_db()
end

-- Test repository pagination
function tests.test_repository_pagination()
  setup_test_db()
  
  local repo = BaseRepository.new("test_items")
  
  -- Create test items
  for i = 1, 15 do
    repo:create({name = "Item " .. i, price = i * 10})
  end
  
  -- Test pagination
  local page1, page1_err = repo:paginate({
    page = 1,
    per_page = 5,
    order_by = "name"
  })
  
  assert(page1 ~= nil, "Should paginate: " .. (page1_err or ""))
  assert(#page1.records == 5, "Should return 5 items per page")
  assert(page1.total_count == 15, "Should count total items correctly")
  assert(page1.total_pages == 3, "Should calculate total pages correctly")
  assert(page1.current_page == 1, "Should set current page correctly")
  assert(page1.has_next == true, "Should indicate next page exists")
  assert(page1.has_prev == false, "Should indicate no previous page")
  
  -- Test second page
  local page2, page2_err = repo:paginate({
    page = 2,
    per_page = 5
  })
  
  assert(page2 ~= nil, "Should paginate page 2: " .. (page2_err or ""))
  assert(#page2.records == 5, "Should return 5 items for page 2")
  assert(page2.current_page == 2, "Should set current page to 2")
  assert(page2.has_next == true, "Should indicate next page exists")
  assert(page2.has_prev == true, "Should indicate previous page exists")
  
  cleanup_test_db()
end

-- Test UserRepository specific functionality
function tests.test_user_repository()
  setup_test_db()
  
  local user_repo = UserRepository.new()
  
  -- Test create user with password hashing
  local user, create_err = user_repo:create({
    username = "testuser",
    email = "test@example.com",
    password = "SecurePass123",
    role = "Member"
  })
  
  assert(user ~= nil, "Should create user: " .. (create_err or ""))
  assert(user.username == "testuser", "Username should be set")
  assert(user.password ~= "SecurePass123", "Password should be hashed")
  
  -- Test find by username
  local found_user, find_err = user_repo:find_by_username("testuser")
  assert(found_user ~= nil, "Should find user by username: " .. (find_err or ""))
  assert(found_user.email == "test@example.com", "Should find correct user")
  
  -- Test verify credentials
  local verified_user, verify_err = user_repo:verify_credentials("testuser", "SecurePass123")
  assert(verified_user ~= nil, "Should verify correct credentials: " .. (verify_err or ""))
  
  local invalid_user, invalid_err = user_repo:verify_credentials("testuser", "WrongPassword")
  assert(invalid_user == nil, "Should reject invalid credentials")
  assert(invalid_err ~= nil, "Should return error for invalid credentials")
  
  cleanup_test_db()
end

-- Run all tests
local function run_tests()
  local passed = 0
  local failed = 0
  
  for test_name, test_func in pairs(tests) do
    print("Running " .. test_name .. "...")
    local success, err = pcall(test_func)
    
    if success then
      print("✓ " .. test_name .. " passed")
      passed = passed + 1
    else
      print("✗ " .. test_name .. " failed: " .. tostring(err))
      failed = failed + 1
    end
  end
  
  print("\nTest Results:")
  print("Passed: " .. passed)
  print("Failed: " .. failed)
  print("Total: " .. (passed + failed))
  
  return failed == 0
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_base_repository%.lua$") then
  run_tests()
end

return tests
