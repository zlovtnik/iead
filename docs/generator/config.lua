-- Documentation Configuration System
-- Provides flexible configuration management for documentation generation

local json = require('cjson')

local DocConfig = {}
DocConfig.__index = DocConfig

-- Default configuration values
local DEFAULT_CONFIG = {
    version = "1.0.0",
    title = "Church Management System Documentation",
    description = "Comprehensive documentation for the church management system",
    base_url = "http://localhost:8080",
    output_dir = "docs/site",
    
    -- Authentication configuration
    auth_types = {"bearer", "session"},
    
    -- Output formats
    output_formats = {"html", "openapi", "markdown"},
    
    -- Template paths
    templates = {
        base = "docs/templates/base.html",
        api = "docs/templates/api.md",
        setup = "docs/templates/setup.md",
        architecture = "docs/templates/architecture.md",
        deployment = "docs/templates/deployment.md"
    },
    
    -- Plugin configuration
    plugins = {
        api_docs = {
            enabled = true,
            include_examples = true,
            languages = {"curl", "javascript", "python"}
        },
        architecture_docs = {
            enabled = true,
            generate_diagrams = true,
            diagram_format = "mermaid"
        },
        setup_guide = {
            enabled = true,
            include_troubleshooting = true,
            platforms = {"windows", "macos", "linux"}
        },
        deployment_docs = {
            enabled = true,
            include_monitoring = true,
            include_scaling = true
        }
    },
    
    -- Site configuration
    site = {
        theme = "default",
        search_enabled = true,
        navigation = {
            "Getting Started",
            "API Reference",
            "Architecture",
            "Deployment"
        }
    }
}

-- Create new configuration instance
function DocConfig.new(config_path)
    local self = setmetatable({}, DocConfig)
    self.config = self:deep_copy(DEFAULT_CONFIG)
    
    if config_path then
        self:load_from_file(config_path)
    end
    
    return self
end

-- Load configuration from file
function DocConfig:load_from_file(path)
    local file = io.open(path, 'r')
    if not file then
        print("Warning: Could not load config file: " .. path .. ", using defaults")
        return
    end
    
    local content = file:read('*all')
    file:close()
    
    local success, user_config = pcall(json.decode, content)
    if not success then
        error("Invalid JSON in config file: " .. path)
    end
    
    self:merge(user_config)
    print("Loaded configuration from: " .. path)
end

-- Save configuration to file
function DocConfig:save_to_file(path)
    local file = io.open(path, 'w')
    if not file then
        error("Could not write config file: " .. path)
    end
    
    local content = json.encode(self.config)
    file:write(content)
    file:close()
    
    print("Saved configuration to: " .. path)
end

-- Merge user configuration with defaults
function DocConfig:merge(user_config)
    self.config = self:deep_merge(self.config, user_config)
end

-- Get configuration value
function DocConfig:get(key)
    local keys = {}
    for k in key:gmatch("[^%.]+") do
        table.insert(keys, k)
    end
    
    local value = self.config
    for _, k in ipairs(keys) do
        if type(value) == 'table' and value[k] ~= nil then
            value = value[k]
        else
            return nil
        end
    end
    
    return value
end

-- Set configuration value
function DocConfig:set(key, value)
    local keys = {}
    for k in key:gmatch("[^%.]+") do
        table.insert(keys, k)
    end
    
    local current = self.config
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(current[k]) ~= 'table' then
            current[k] = {}
        end
        current = current[k]
    end
    
    current[keys[#keys]] = value
end

-- Get all configuration
function DocConfig:get_all()
    return self.config
end

-- Validate configuration
function DocConfig:validate()
    local errors = {}
    
    -- Check required fields
    local required = {"title", "version", "output_dir"}
    for _, field in ipairs(required) do
        if not self.config[field] then
            table.insert(errors, "Missing required field: " .. field)
        end
    end
    
    -- Validate output directory
    if self.config.output_dir and not self.config.output_dir:match("^[%w%./%-_]+$") then
        table.insert(errors, "Invalid output directory path")
    end
    
    -- Validate templates
    if self.config.templates then
        for name, path in pairs(self.config.templates) do
            if type(path) ~= 'string' or path == '' then
                table.insert(errors, "Invalid template path for: " .. name)
            end
        end
    end
    
    if #errors > 0 then
        error("Configuration validation failed:\n" .. table.concat(errors, "\n"))
    end
    
    return true
end

-- Deep copy table
function DocConfig:deep_copy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[self:deep_copy(orig_key)] = self:deep_copy(orig_value)
        end
        setmetatable(copy, self:deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Deep merge tables
function DocConfig:deep_merge(base, override)
    local result = self:deep_copy(base)
    
    for key, value in pairs(override) do
        if type(value) == 'table' and type(result[key]) == 'table' then
            result[key] = self:deep_merge(result[key], value)
        else
            result[key] = value
        end
    end
    
    return result
end

-- Create configuration from environment variables
function DocConfig:load_from_env()
    local env_config = {}
    
    -- Map environment variables to config keys
    local env_mappings = {
        DOC_TITLE = "title",
        DOC_VERSION = "version",
        DOC_BASE_URL = "base_url",
        DOC_OUTPUT_DIR = "output_dir"
    }
    
    for env_var, config_key in pairs(env_mappings) do
        local value = os.getenv(env_var)
        if value then
            env_config[config_key] = value
        end
    end
    
    if next(env_config) then
        self:merge(env_config)
        print("Loaded configuration from environment variables")
    end
end

return DocConfig