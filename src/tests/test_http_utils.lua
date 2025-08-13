-- src/tests/test_http_utils.lua
-- Tests for HTTP utilities

local test_runner = require("src.tests.test_runner")
local http_utils = require("src.utils.http")

local tests = {}

function tests.test_parse_query_params()
  local path, params = http_utils.parse_query_params("/members?name=John&email=john@example.com")
  
  test_runner.assert_equal(path, "/members", "Path should be extracted correctly")
  test_runner.assert_equal(params.name, "John", "Name parameter should be parsed")
  test_runner.assert_equal(params.email, "john@example.com", "Email parameter should be parsed")
end

function tests.test_parse_query_params_no_query()
  local path, params = http_utils.parse_query_params("/members")
  
  test_runner.assert_equal(path, "/members", "Path should be extracted correctly")
  test_runner.assert_equal(next(params), nil, "Params should be empty")
end

function tests.test_parse_form_data()
  local body = "name=John+Doe&email=john%40example.com&age=30"
  local params = http_utils.parse_form_data(body)
  
  test_runner.assert_equal(params.name, "John Doe", "Name should be URL decoded")
  test_runner.assert_equal(params.email, "john@example.com", "Email should be URL decoded")
  test_runner.assert_equal(params.age, "30", "Age should be parsed")
end

function tests.test_parse_form_data_empty()
  local params = http_utils.parse_form_data(nil)
  
  test_runner.assert_equal(next(params), nil, "Params should be empty for nil body")
end

function tests.test_parse_form_data_empty_string()
  local params = http_utils.parse_form_data("")
  
  test_runner.assert_equal(next(params), nil, "Params should be empty for empty body")
end

return tests
