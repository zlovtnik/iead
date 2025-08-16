#!/usr/bin/env luajit

-- Performance testing script for Church Management System
-- Tests critical API endpoints for response time and throughput

local socket = require("socket")
local http = require("socket.http")
local json = require("cjson")

local PerformanceTest = {}

-- Configuration
local config = {
  base_url = "http://localhost:8080",
  concurrent_users = 10,
  test_duration = 30, -- seconds
  endpoints = {
    {
      name = "Members List",
      method = "GET",
      path = "/api/v1/members",
      expected_status = 200,
      max_response_time = 100 -- milliseconds
    },
    {
      name = "Member Search",
      method = "GET", 
      path = "/api/v1/members?search=John",
      expected_status = 200,
      max_response_time = 200
    },
    {
      name = "Donations List",
      method = "GET",
      path = "/api/v1/donations",
      expected_status = 200,
      max_response_time = 150
    },
    {
      name = "Events List",
      method = "GET",
      path = "/api/v1/events",
      expected_status = 200,
      max_response_time = 100
    },
    {
      name = "Member Statistics",
      method = "GET",
      path = "/api/v1/members/1/stats",
      expected_status = 200,
      max_response_time = 300
    }
  }
}

-- Test results storage
local results = {
  total_requests = 0,
  successful_requests = 0,
  failed_requests = 0,
  response_times = {},
  endpoints = {}
}

-- Helper function to make HTTP request with timing
local function time_request(endpoint)
  local start_time = socket.gettime()
  
  local response_body, status_code, response_headers, status_line = http.request(config.base_url .. endpoint.path)
  local code_num = tonumber(status_code) or 0

  local end_time = socket.gettime()
  local response_time = (end_time - start_time) * 1000 -- Convert to milliseconds

  return {
    status_code   = code_num,
    response_time = response_time,
    body          = response_body,
    success       = code_num == endpoint.expected_status
  }
end

-- Run performance test for a single endpoint
function PerformanceTest.test_endpoint(endpoint, duration)
  print(string.format("Testing %s for %d seconds...", endpoint.name, duration))
  
  local start_time = socket.gettime()
  local endpoint_results = {
    name = endpoint.name,
    total_requests = 0,
    successful_requests = 0,
    failed_requests = 0,
    response_times = {},
    min_time = math.huge,
    max_time = 0,
    avg_time = 0,
    p95_time = 0,
    errors = {}
  }
  
  while (socket.gettime() - start_time) < duration do
    local result = time_request(endpoint)
    
    endpoint_results.total_requests = endpoint_results.total_requests + 1
    results.total_requests = results.total_requests + 1
    
    if result.success then
      endpoint_results.successful_requests = endpoint_results.successful_requests + 1
      results.successful_requests = results.successful_requests + 1
      
      table.insert(endpoint_results.response_times, result.response_time)
      table.insert(results.response_times, result.response_time)
      
      -- Update min/max
      if result.response_time < endpoint_results.min_time then
        endpoint_results.min_time = result.response_time
      end
      if result.response_time > endpoint_results.max_time then
        endpoint_results.max_time = result.response_time
      end
      
    else
      endpoint_results.failed_requests = endpoint_results.failed_requests + 1
      results.failed_requests = results.failed_requests + 1
      table.insert(endpoint_results.errors, result.status_code)
    end
    
    -- Small delay to avoid overwhelming the server
    socket.sleep(0.01)
  end
  
  -- Calculate statistics
  if #endpoint_results.response_times > 0 then
    local sum = 0
    for _, time in ipairs(endpoint_results.response_times) do
      sum = sum + time
    end
    endpoint_results.avg_time = sum / #endpoint_results.response_times
    
    -- Calculate 95th percentile
    table.sort(endpoint_results.response_times)
    local p95_index = math.ceil(#endpoint_results.response_times * 0.95)
    endpoint_results.p95_time = endpoint_results.response_times[p95_index] or 0
  end
  
  table.insert(results.endpoints, endpoint_results)
  return endpoint_results
end

-- Run all performance tests
function PerformanceTest.run_all_tests()
  print("🚀 Starting Performance Tests")
  print("=" .. string.rep("=", 50))
  print(string.format("Test Duration: %d seconds per endpoint", config.test_duration))
  print(string.format("Base URL: %s", config.base_url))
  print()
  
  local overall_start = socket.gettime()
  
  for _, endpoint in ipairs(config.endpoints) do
    local endpoint_result = PerformanceTest.test_endpoint(endpoint, config.test_duration)
    
    -- Print immediate results
    print(string.format("✓ %s: %d requests, %.2fms avg, %.2fms p95", 
      endpoint_result.name,
      endpoint_result.total_requests,
      endpoint_result.avg_time,
      endpoint_result.p95_time
    ))
    
    -- Check if response time meets requirements
    if endpoint_result.avg_time > endpoint.max_response_time then
      print(string.format("⚠️  Warning: Average response time (%.2fms) exceeds target (%.2fms)",
        endpoint_result.avg_time, endpoint.max_response_time))
    end
    
    print()
  end
  
  local overall_end = socket.gettime()
  local total_duration = overall_end - overall_start
  
  PerformanceTest.print_summary(total_duration)
end

-- Print comprehensive test summary
function PerformanceTest.print_summary(duration)
  print("📊 Performance Test Summary")
  print("=" .. string.rep("=", 50))
  print(string.format("Total Test Duration: %.2f seconds", duration))
  print(string.format("Total Requests: %d", results.total_requests))
  print(string.format("Successful Requests: %d (%.1f%%)", 
    results.successful_requests, 
    results.total_requests > 0 and (results.successful_requests / results.total_requests) * 100 or 0
  ))

  print(string.format("Failed Requests: %d (%.1f%%)",
    results.failed_requests,
    results.total_requests > 0 and (results.failed_requests / results.total_requests) * 100 or 0
  ))
  
  if #results.response_times > 0 then
    local sum = 0
    for _, time in ipairs(results.response_times) do
      sum = sum + time
    end
    local overall_avg = sum / #results.response_times
    
    table.sort(results.response_times)
    local overall_p95 = results.response_times[math.ceil(#results.response_times * 0.95)] or 0
    local overall_min = results.response_times[1] or 0
    local overall_max = results.response_times[#results.response_times] or 0
    
    print(string.format("Response Time - Min: %.2fms, Max: %.2fms, Avg: %.2fms, P95: %.2fms",
      overall_min, overall_max, overall_avg, overall_p95
    ))
    
    print(string.format("Throughput: %.2f requests/second", 
      results.total_requests / duration
    ))
  end
  
  print()
  print("📋 Individual Endpoint Results:")
  print("-" .. string.rep("-", 80))
  
  for _, endpoint in ipairs(results.endpoints) do
    print(string.format("%-20s | %6d reqs | %7.2fms avg | %7.2fms p95 | %6.1f%% success",
      endpoint.name,
      endpoint.total_requests,
      endpoint.avg_time,
      endpoint.p95_time,
      endpoint.total_requests > 0 and (endpoint.successful_requests / endpoint.total_requests) * 100 or 0
    ))
  end
  
  print()
  
  -- Performance recommendations
  -- Performance recommendations
  print("🎯 Performance Recommendations:")
  for _, endpoint in ipairs(results.endpoints) do
    if endpoint.avg_time > 200 then
      print(string.format("• Optimize %s - average response time is %.2fms", 
        endpoint.name, endpoint.avg_time))
    end
    if endpoint.p95_time > 500 then
      print(string.format("• Investigate %s - 95th percentile is %.2fms", 
        endpoint.name, endpoint.p95_time))
    end
    if endpoint.total_requests > 0 and (endpoint.successful_requests / endpoint.total_requests) < 0.99 then
      print(string.format("• Fix reliability issues in %s - %.1f%% success rate", 
        endpoint.name, (endpoint.successful_requests / endpoint.total_requests) * 100))
    end
  end
end

-- Run tests if this file is executed directly
if debug.getinfo(2) == nil then
  -- Check if server is running
  local response, code = http.request(config.base_url .. "/health")
  local code_num = tonumber(code)
  if not response or code_num ~= 200 then
    print("❌ Error: Server not responding at " .. config.base_url)
    print("   Response: " .. tostring(response or "nil"))
    print("   Status code: " .. tostring(code) .. " (expected 200)")
    print("Please start the server before running performance tests.")
    os.exit(1)
  end
  
  PerformanceTest.run_all_tests()
end

return PerformanceTest
