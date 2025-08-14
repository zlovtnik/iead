#!/usr/bin/env lua

-- Test the assert_true behavior

local test_runner = require("src.tests.test_runner")

print("🧪 Testing assert_true behavior with match results")
print("================================================")

local password = "TestPassword123"

-- Test what match returns
local lower_match = password:match("%l")
local upper_match = password:match("%u")
local digit_match = password:match("%d")

print("Lower match result: " .. tostring(lower_match) .. " (type: " .. type(lower_match) .. ")")
print("Upper match result: " .. tostring(upper_match) .. " (type: " .. type(upper_match) .. ")")
print("Digit match result: " .. tostring(digit_match) .. " (type: " .. type(digit_match) .. ")")

print("\nTesting truthiness:")
print("Lower match is truthy: " .. tostring(not not lower_match))
print("Lower match == true: " .. tostring(lower_match == true))

print("\nTesting with assert_true:")
local success1, error1 = pcall(test_runner.assert_true, lower_match, "Lower match should be true")
print("assert_true(lower_match): " .. (success1 and "PASS" or "FAIL: " .. error1))

local success2, error2 = pcall(test_runner.assert_true, not not lower_match, "Lower match converted to boolean should be true")
print("assert_true(not not lower_match): " .. (success2 and "PASS" or "FAIL: " .. error2))
