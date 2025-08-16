-- src/utils/functional_new.lua
-- Functional programming utilities for Lua using luafun
-- This module serves as the main functional programming interface

-- Import luafun adapter
local luafun_adapter = require("src.utils.luafun_adapter")

-- Re-export all luafun_adapter functions
local functional = {}

-- Core functional operations
functional.each = luafun_adapter.each
functional.map = luafun_adapter.map
functional.filter = luafun_adapter.filter
functional.reduce = luafun_adapter.reduce
functional.range = luafun_adapter.range
functional.zip = luafun_adapter.zip
functional.chain = luafun_adapter.chain
functional.take = luafun_adapter.take
functional.drop = luafun_adapter.drop
functional.head = luafun_adapter.head
functional.tail = luafun_adapter.tail
functional.reverse = luafun_adapter.reverse
functional.duplicate = luafun_adapter.duplicate
functional.enumerate = luafun_adapter.enumerate
functional.partition = luafun_adapter.partition
functional.group_by = luafun_adapter.group_by
functional.length = luafun_adapter.length
functional.all = luafun_adapter.all
functional.any = luafun_adapter.any
functional.min = luafun_adapter.min
functional.max = luafun_adapter.max
functional.sum = luafun_adapter.sum

-- Table-specific operations
functional.map_table = luafun_adapter.map_table
functional.filter_table = luafun_adapter.filter_table
functional.reduce_table = luafun_adapter.reduce_table
functional.pluck = luafun_adapter.pluck
functional.unique = luafun_adapter.unique
functional.from_pairs = luafun_adapter.from_pairs
functional.from_table = luafun_adapter.from_table
functional.average = luafun_adapter.average
functional.omit_keys = luafun_adapter.omit_keys
functional.group_by_func = luafun_adapter.group_by_func

-- Advanced functional operations
functional.compose = luafun_adapter.compose
functional.pipe = luafun_adapter.pipe
functional.curry = luafun_adapter.curry
functional.maybe = luafun_adapter.maybe

return functional
