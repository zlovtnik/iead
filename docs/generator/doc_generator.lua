-- Documentation Generator Framework
-- Provides a plugin-based architecture for generating comprehensive documentation

local json = require('cjson')
local lfs = require('lfs')

local DocGenerator = {}
DocGenerator.__index = DocGenerator

-- Create new documentation generator instance
function DocGenerator.new(config)
    local self = setmetatable({}, DocGenerator)
    self.config = config or {}
    self.plugins = {}
    self.templates = {}
    return self
end

-- Register a documentation plugin
function DocGenerator:register_plugin(name, plugin)
    if type(plugin.generate) ~= 'function' then
        error("Plugin must have a 'generate' function")
    end
    
    self.plugins[name] = plugin
    print("Registered documentation plugin: " .. name)
end

-- Load template from file
function DocGenerator:load_template(name, path)
    local file = io.open(path, 'r')
    if not file then
        error("Could not load template: " .. path)
    end
    
    local content = file:read('*all')
    file:close()
    
    self.templates[name] = content
    return content
end

-- Process template with variables
function DocGenerator:process_template(template_name, variables)
    local template = self.templates[template_name]
    if not template then
        error("Template not found: " .. template_name)
    end
    
    local result = template
    for key, value in pairs(variables or {}) do
        local pattern = "{{" .. key .. "}}"
        result = result:gsub(pattern, tostring(value))
    end
    
    return result
end

-- Generate documentation using all registered plugins
function DocGenerator:generate_all()
    local results = {}
    
    print("Starting documentation generation...")
    
    -- Ensure output directory exists
    self:ensure_directory(self.config.output_dir or "docs/site")
    
    -- Run each plugin
    for name, plugin in pairs(self.plugins) do
        print("Running plugin: " .. name)
        
        local success, result = pcall(plugin.generate, plugin, self.config, self)
        
        if success then
            results[name] = result
            print("Plugin " .. name .. " completed successfully")
        else
            print("Plugin " .. name .. " failed: " .. tostring(result))
            results[name] = { success = false, error = result }
        end
    end
    
    print("Documentation generation completed")
    return results
end

-- Generate specific documentation type
function DocGenerator:generate(plugin_name, options)
    local plugin = self.plugins[plugin_name]
    if not plugin then
        error("Plugin not found: " .. plugin_name)
    end
    
    local config = self:merge_config(self.config, options or {})
    return plugin:generate(config, self)
end

-- Merge configuration objects
function DocGenerator:merge_config(base, override)
    local result = {}
    
    -- Copy base config
    for k, v in pairs(base) do
        result[k] = v
    end
    
    -- Override with new values
    for k, v in pairs(override) do
        result[k] = v
    end
    
    return result
end

-- Ensure directory exists
function DocGenerator:ensure_directory(path)
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

-- Write content to file
function DocGenerator:write_file(path, content)
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
    
    print("Written file: " .. path)
end

-- Read file content
function DocGenerator:read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return nil, "Could not read file: " .. path
    end
    
    local content = file:read('*all')
    file:close()
    
    return content
end

-- Validate configuration
function DocGenerator:validate_config()
    local required_fields = {
        'title',
        'version',
        'output_dir'
    }
    
    for _, field in ipairs(required_fields) do
        if not self.config[field] then
            error("Missing required configuration field: " .. field)
        end
    end
    
    return true
end

return DocGenerator