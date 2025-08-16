-- Plugin Manager for Documentation Generator
-- Handles plugin registration, dependency resolution, and execution order

local PluginManager = {}
PluginManager.__index = PluginManager

-- Create new plugin manager
function PluginManager.new()
    local self = setmetatable({}, PluginManager)
    self.plugins = {}
    self.execution_order = {}
    return self
end

-- Register a plugin
function PluginManager:register(plugin)
    if not plugin.get_name then
        error("Plugin must have get_name() method")
    end
    
    local name = plugin:get_name()
    if self.plugins[name] then
        error("Plugin already registered: " .. name)
    end
    
    self.plugins[name] = plugin
    self:log("Registered plugin: " .. name)
    
    -- Recalculate execution order
    self:calculate_execution_order()
end

-- Unregister a plugin
function PluginManager:unregister(name)
    if not self.plugins[name] then
        error("Plugin not found: " .. name)
    end
    
    self.plugins[name] = nil
    self:log("Unregistered plugin: " .. name)
    
    -- Recalculate execution order
    self:calculate_execution_order()
end

-- Get plugin by name
function PluginManager:get_plugin(name)
    return self.plugins[name]
end

-- Get all registered plugins
function PluginManager:get_all_plugins()
    return self.plugins
end

-- Calculate execution order based on dependencies
function PluginManager:calculate_execution_order()
    local order = {}
    local visited = {}
    local visiting = {}
    
    -- Topological sort with cycle detection
    local function visit(name)
        if visiting[name] then
            error("Circular dependency detected involving plugin: " .. name)
        end
        
        if visited[name] then
            return
        end
        
        visiting[name] = true
        
        local plugin = self.plugins[name]
        if plugin and plugin.get_dependencies then
            for _, dep_name in ipairs(plugin:get_dependencies()) do
                if not self.plugins[dep_name] then
                    error("Plugin dependency not found: " .. dep_name .. " (required by " .. name .. ")")
                end
                visit(dep_name)
            end
        end
        
        visiting[name] = nil
        visited[name] = true
        table.insert(order, name)
    end
    
    -- Visit all plugins
    for name, _ in pairs(self.plugins) do
        visit(name)
    end
    
    self.execution_order = order
    self:log("Calculated execution order: " .. table.concat(order, " -> "))
end

-- Execute all plugins in dependency order
function PluginManager:execute_all(config, generator)
    local results = {}
    
    self:log("Starting plugin execution...")
    
    for _, name in ipairs(self.execution_order) do
        local plugin = self.plugins[name]
        
        -- Check if plugin is enabled
        if not plugin:is_enabled(config) then
            self:log("Skipping disabled plugin: " .. name)
            results[name] = { success = true, skipped = true }
        else
            self:log("Executing plugin: " .. name)
            
            -- Validate plugin configuration
            local success, validation_error = pcall(plugin.validate_config, plugin, config)
            if not success then
                self:log("Plugin configuration validation failed: " .. name .. " - " .. validation_error, "ERROR")
                results[name] = { success = false, error = validation_error }
            else
                -- Execute plugin
                local exec_success, result = pcall(plugin.generate, plugin, config, generator)
                
                if exec_success then
                    results[name] = result or { success = true }
                    self:log("Plugin completed successfully: " .. name)
                else
                    self:log("Plugin execution failed: " .. name .. " - " .. tostring(result), "ERROR")
                    results[name] = { success = false, error = result }
                end
            end
        end
    end
    
    self:log("Plugin execution completed")
    return results
end

-- Execute specific plugin
function PluginManager:execute_plugin(name, config, generator)
    local plugin = self.plugins[name]
    if not plugin then
        error("Plugin not found: " .. name)
    end
    
    if not plugin:is_enabled(config) then
        return { success = true, skipped = true }
    end
    
    -- Validate configuration
    local success, validation_error = pcall(plugin.validate_config, plugin, config)
    if not success then
        error("Plugin configuration validation failed: " .. validation_error)
    end
    
    -- Execute plugin
    return plugin:generate(config, generator)
end

-- Get execution order
function PluginManager:get_execution_order()
    return self.execution_order
end

-- Validate all plugin dependencies
function PluginManager:validate_dependencies()
    local errors = {}
    
    for name, plugin in pairs(self.plugins) do
        if plugin.get_dependencies then
            for _, dep_name in ipairs(plugin:get_dependencies()) do
                if not self.plugins[dep_name] then
                    table.insert(errors, "Plugin '" .. name .. "' depends on missing plugin: " .. dep_name)
                end
            end
        end
    end
    
    if #errors > 0 then
        error("Dependency validation failed:\n" .. table.concat(errors, "\n"))
    end
    
    return true
end

-- Get plugin statistics
function PluginManager:get_stats()
    local stats = {
        total_plugins = 0,
        enabled_plugins = 0,
        disabled_plugins = 0,
        plugins_with_dependencies = 0
    }
    
    for name, plugin in pairs(self.plugins) do
        stats.total_plugins = stats.total_plugins + 1
        
        if plugin.get_dependencies and #plugin:get_dependencies() > 0 then
            stats.plugins_with_dependencies = stats.plugins_with_dependencies + 1
        end
    end
    
    return stats
end

-- Log message
function PluginManager:log(message, level)
    level = level or "INFO"
    print("[" .. level .. "] PluginManager: " .. message)
end

return PluginManager