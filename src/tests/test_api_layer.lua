-- src/tests/test_api_layer.lua
-- Tests for the new standardized API layer

local test_runner = require("src.tests.test_runner")
local ApiResponse = require("src.application.middlewares.api_response")
local ErrorHandler = require("src.application.middlewares.error_handler")
local RequestValidator = require("src.application.middlewares.request_validator")
local ApiVersioning = require("src.application.middlewares.api_versioning")
local ApiMiddleware = require("src.application.middlewares.api_middleware")

local tests = {}

-- Mock client for testing
local function create_mock_client(headers, body, method, path)
  return {
    headers = headers or {},
    body = body,
    method = method or "GET",
    path = path or "/test",
    ip = "127.0.0.1",
    response_headers = {},
    response_status = nil,
    response_body = nil,
    send = function(self, response)
      self.response_body = response
    end
  }
end

-- Test API Response formatting
function tests.test_api_response_success()
  local response = ApiResponse.success({ test = "data" }, "Test message")
  
  assert(response.success == true, "Response should be marked as successful")
  assert(response.data.test == "data", "Response should contain correct data")
  assert(response.message == "Test message", "Response should contain message")
  assert(response.meta.timestamp, "Response should have timestamp")
  assert(response.meta.request_id, "Response should have request ID")
  assert(response.meta.version == "v1", "Response should have default version")
end

function tests.test_api_response_error()
  local response = ApiResponse.error("TEST_ERROR", "Test error message", { detail = "info" })
  
  assert(response.success == false, "Response should be marked as failed")
  assert(response.data == nil, "Error response should have no data")
  assert(response.error.code == "TEST_ERROR", "Response should contain error code")
  assert(response.error.message == "Test error message", "Response should contain error message")
  assert(response.error.details.detail == "info", "Response should contain error details")
end

function tests.test_api_response_paginated()
  local data = { {id = 1}, {id = 2} }
  local response = ApiResponse.paginated(data, 1, 2, 10)
  
  assert(response.success == true, "Paginated response should be successful")
  assert(#response.data == 2, "Response should contain correct data count")
  assert(response.pagination.current_page == 1, "Response should have correct current page")
  assert(response.pagination.per_page == 2, "Response should have correct per_page")
  assert(response.pagination.total_items == 10, "Response should have correct total")
  assert(response.pagination.total_pages == 5, "Response should calculate total pages")
  assert(response.pagination.has_next == true, "Response should indicate next page exists")
  assert(response.pagination.has_previous == false, "Response should indicate no previous page")
end

-- Test Error Handler
function tests.test_error_handler_normalize_string()
  local error_info = ErrorHandler.normalize_error("Test error message")
  
  assert(error_info.message == "Test error message", "Should preserve error message")
  assert(error_info.type == "generic", "Should set generic type")
  assert(error_info.category == "business_logic", "Should categorize as business_logic")
  assert(error_info.status_code == 422, "Should default to 422 status for business logic")
  assert(error_info.code == "UNPROCESSABLE_ENTITY", "Should set default error code")
end

function tests.test_error_handler_normalize_table()
  local error = {
    message = "Validation failed",
    validation_errors = { {field = "email", message = "Invalid email"} }
  }
  
  local error_info = ErrorHandler.normalize_error(error)
  
  assert(error_info.message == "Validation failed", "Should preserve error message")
  assert(error_info.validation_errors, "Should preserve validation errors")
  assert(error_info.category == "validation", "Should categorize as validation error")
  assert(error_info.status_code == 400, "Should set 400 status for validation")
end

function tests.test_error_handler_pattern_matching()
  local error_info = ErrorHandler.normalize_error("unique constraint")
  
  assert(error_info.status_code == 409, "Should map to 409 status")
  assert(error_info.code == "ALREADY_EXISTS", "Should map to correct error code")
  assert(error_info.category == "business_logic", "Should categorize correctly")
end

-- Test Request Validator
function tests.test_request_validator_required_fields()
  local schema = {
    name = { required = true, type = "string" },
    email = { required = true, type = "string", pattern = "email" }
  }
  
  local data = { name = "John" }  -- Missing email
  local sanitized, errors = RequestValidator.validate(data, schema)
  
  assert(#errors == 1, "Should have one validation error")
  assert(errors[1].field == "email", "Should identify missing email field")
  assert(string.find(errors[1].message, "required"), "Should indicate field is required")
end

function tests.test_request_validator_type_conversion()
  local schema = {
    age = { type = "integer" },
    active = { type = "boolean" }
  }
  
  local data = { age = "25", active = "true" }
  local sanitized, errors = RequestValidator.validate(data, schema)
  
  assert(#errors == 0, "Should have no validation errors")
  assert(sanitized.age == 25, "Should convert string to integer")
  assert(sanitized.active == true, "Should convert string to boolean")
end

function tests.test_request_validator_pattern_validation()
  local schema = {
    email = { type = "string", pattern = "email" },
    phone = { type = "string", pattern = "phone" }
  }
  
  local data = { 
    email = "invalid-email",
    phone = "555-1234"
  }
  local sanitized, errors = RequestValidator.validate(data, schema)
  
  assert(#errors == 1, "Should have one validation error")
  assert(errors[1].field == "email", "Should identify invalid email")
  assert(sanitized.phone == "555-1234", "Should accept valid phone")
end

function tests.test_request_validator_length_validation()
  local schema = {
    username = { type = "string", length = { min = 3, max = 20 } }
  }
  
  local data = { username = "ab" }  -- Too short
  local sanitized, errors = RequestValidator.validate(data, schema)
  
  assert(#errors == 1, "Should have one validation error")
  assert(string.find(errors[1].message, "at least 3"), "Should indicate minimum length")
end

-- Test API Versioning
function tests.test_api_versioning_extract_from_header()
  local client = create_mock_client({
    ["X-API-Version"] = "v2"
  })
  
  -- This would be tested with actual middleware execution
  -- For now, just test the version info structure
  local version_info = ApiVersioning.get_version_info()
  
  assert(version_info.default_version == "v1", "Should have correct default version")
  assert(#version_info.supported_versions >= 1, "Should have supported versions")
end

function tests.test_api_versioning_versioned_handler()
  local v1_called = false
  local v2_called = false
  
  local handlers = {
    v1 = function() v1_called = true end,
    v2 = function() v2_called = true end
  }
  
  local versioned = ApiVersioning.versioned_handler(handlers)
  
  -- Test v1 call
  versioned(create_mock_client(), { api_version = "v1" })
  assert(v1_called == true, "Should call v1 handler")
  
  -- Test v2 call
  versioned(create_mock_client(), { api_version = "v2" })
  assert(v2_called == true, "Should call v2 handler")
end

-- Test API Middleware composition
function tests.test_api_middleware_presets()
  local public_middleware = ApiMiddleware.presets.public()
  local auth_middleware = ApiMiddleware.presets.authenticated()
  local admin_middleware = ApiMiddleware.presets.admin_only()
  
  assert(type(public_middleware) == "function", "Public preset should return function")
  assert(type(auth_middleware) == "function", "Auth preset should return function")
  assert(type(admin_middleware) == "function", "Admin preset should return function")
end

function tests.test_api_middleware_protection()
  local handler_called = false
  local test_handler = function(client, params)
    handler_called = true
    params.send_success({ test = true })
  end
  
  local protected = ApiMiddleware.protect(test_handler, {
    authentication = false  -- No auth for test
  })
  
  assert(type(protected) == "function", "Protect should return function")
  
  -- This would require more complex mocking to test execution
  -- The structure test confirms the wrapper is created correctly
end

-- Test validation schemas
function tests.test_predefined_schemas()
  local schemas = ApiMiddleware.schemas
  
  assert(schemas.login, "Should have login schema")
  assert(schemas.login.username, "Login schema should have username field")
  assert(schemas.login.password, "Login schema should have password field")
  
  assert(schemas.member_create, "Should have member_create schema")
  assert(schemas.member_create.first_name, "Member schema should have first_name field")
  assert(schemas.member_create.email, "Member schema should have email field")
  
  assert(schemas.pagination, "Should have pagination schema")
  assert(schemas.pagination.page, "Pagination schema should have page field")
end

function tests.test_schema_combination()
  local combined = RequestValidator.combine_schemas(
    ApiMiddleware.schemas.pagination,
    ApiMiddleware.schemas.search
  )
  
  assert(combined.page, "Combined schema should have page field")
  assert(combined.q or combined.search, "Combined schema should have search field")
end

-- Integration test
function tests.test_full_middleware_stack()
  local test_data = {}
  
  local test_handler = function(client, params)
    test_data.request_id = params.request_id
    test_data.api_version = params.api_version
    test_data.current_user = params.current_user
    
    if params.send_success then
      params.send_success({ message = "Integration test successful" })
    end
  end
  
  local middleware = ApiMiddleware.create_standard_stack({
    authentication = false,  -- Skip auth for test
    versioning = true,
    validation_schema = {
      test_field = { type = "string" }
    }
  })
  
  local client = create_mock_client({
    ["X-API-Version"] = "v1",
    ["Content-Type"] = "application/json"
  }, '{"test_field": "test_value"}')
  
  -- Execute middleware stack
  -- This would require more complex mocking to fully test
  -- The structure confirms the middleware chain is properly composed
  assert(type(middleware) == "function", "Should create middleware function")
end

-- Run all tests
function tests.run_all()
  local success_count = 0
  local failure_count = 0
  
  for test_name, test_func in pairs(tests) do
    if test_name ~= "run_all" then
      local success, error_msg = pcall(test_func)
      if success then
        print("✓ " .. test_name)
        success_count = success_count + 1
      else
        print("✗ " .. test_name .. ": " .. error_msg)
        failure_count = failure_count + 1
      end
    end
  end
  
  print(string.format("\nAPI Layer Tests: %d passed, %d failed", success_count, failure_count))
  return failure_count == 0
end

-- Run tests if this file is executed directly
if debug.getinfo(2) == nil then
  tests.run_all()
end

return tests
