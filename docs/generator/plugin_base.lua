-- Base Plugin Class for Documentation Generators
-- Provides common functionality and interface for documentation plugins

local PluginBase = {}
PluginBase.__index = PluginBase

-- Create new plugin instance
function PluginBase.new(name, options)
    local self = setmetatable({}, PluginBase)
    self.name = name or "unnamed_plugin"
    self.options = options or {}
    self.dependencies = {}
    return self
end

-- Plugin interface - must be implemented by subclasses
function PluginBase:generate(config, generator)
    error("Plugin must implement generate() method")
end

-- Get plugin name
function PluginBase:get_name()
    return self.name
end

-- Add dependency on another plugin
function PluginBase:add_dependency(plugin_name)
    table.insert(self.dependencies, plugin_name)
end

-- Get plugin dependencies
function PluginBase:get_dependencies()
    return self.dependencies
end

-- Validate plugin configuration
function PluginBase:validate_config(config)
    -- Override in subclasses for specific validation
    return true
end

-- Log plugin message
function PluginBase:log(message, level)
    level = level or "INFO"
    print("[" .. level .. "] " .. self.name .. ": " .. message)
end

-- Check if plugin is enabled in configuration
function PluginBase:is_enabled(config)
    local plugin_config = config.plugins and config.plugins[self.name]
    if plugin_config then
        return plugin_config.enabled ~= false
    end
    return true -- Default to enabled
end

-- Get plugin-specific configuration
function PluginBase:get_plugin_config(config)
    return config.plugins and config.plugins[self.name] or {}
end

-- Utility: Ensure directory exists
function PluginBase:ensure_directory(path)
    local lfs = require('lfs')
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    local current_path = ""
    for _, part in ipairs(parts) do
        current_path = current_path .. part .. "/"
        lfs.mkdir(current_path)
    end
end

-- Utility: Write file with directory creation
function PluginBase:write_file(path, content)
    -- Ensure directory exists
    local dir = path:match("(.*/)")
    if dir then
        self:ensure_directory(dir)
    end
    
    local file = io.open(path, 'w')
    if not file then
        error("Could not write file: " .. path)
    end
    
    file:write(content)
    file:close()
    
    self:log("Written file: " .. path)
end

-- Utility: Read file content
function PluginBase:read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return nil, "Could not read file: " .. path
    end
    
    local content = file:read('*all')
    file:close()
    
    return content
end

-- Utility: Process template with variables
function PluginBase:process_template(template, variables)
    local result = template
    for key, value in pairs(variables or {}) do
        local pattern = "{{" .. key .. "}}"
        result = result:gsub(pattern, tostring(value))
    end
    return result
end

-- Utility: Generate timestamp
function PluginBase:get_timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Utility: Sanitize filename
function PluginBase:sanitize_filename(filename)
    return filename:gsub("[^%w%.-]", "_")
end

-- Utility: Get file extension
function PluginBase:get_file_extension(filename)
    return filename:match("%.([^%.]+)$")
end

-- Utility: Join paths
function PluginBase:join_paths(...)
    local parts = {...}
    local path = table.concat(parts, "/")
    return path:gsub("//+", "/")
end

return PluginBase