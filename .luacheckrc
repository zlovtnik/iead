-- Global objects
globals = {
    -- Lua standard libraries that might be used
    "io",
    "os",
    "table",
    "string",
    "math",
    "coroutine",
    "package",
    
    -- Application globals
    "require",
    "print",
    "pairs",
    "ipairs",
    "tonumber",
    "tostring",
    "type",
    "setmetatable",
    "getmetatable",
    "assert",
    "error",
    "pcall",
    "xpcall"
}

-- Ignore unused self parameter in methods
self = false

-- Files to exclude from linting
exclude_files = {
    "lua_modules/**",
    ".luarocks/**",
    "dist/**",
    "bin/**"
}

-- Ignore specific warnings
ignore = {
    "212", -- Unused argument
    "213", -- Unused loop variable
    "311", -- Value assigned to a local variable is unused
    "542", -- Empty if branch
}

-- Maximum line length
max_line_length = 120

-- Maximum cyclomatic complexity for functions
max_cyclomatic_complexity = 15
