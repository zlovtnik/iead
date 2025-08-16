#!/usr/bin/env lua

-- Main Documentation Generation Script
-- Provides command-line interface for generating documentation

local DocGenerator = require('docs.generator.doc_generator')
local DocConfig = require('docs.generator.config')
local PluginManager = require('docs.generator.plugin_manager')

-- Parse command line arguments
local function parse_args(args)
    local options = {
        config_file = "docs/config/default.json",
        output_dir = nil,
        plugins = {},
        verbose = false,
        help = false
    }
    
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "--config" or arg == "-c" then
            i = i + 1
            options.config_file = args[i]
        elseif arg == "--output" or arg == "-o" then
            i = i + 1
            options.output_dir = args[i]
        elseif arg == "--plugin" or arg == "-p" then
            i = i + 1
            table.insert(options.plugins, args[i])
        elseif arg == "--verbose" or arg == "-v" then
            options.verbose = true
        elseif arg == "--help" or arg == "-h" then
            options.help = true
        else
            print("Unknown option: " .. arg)
            options.help = true
        end
        
        i = i + 1
    end
    
    return options
end

-- Print help message
local function print_help()
    print([[
Documentation Generator

Usage: lua docs/generate.lua [OPTIONS]

Options:
  -c, --config FILE     Configuration file (default: docs/config/default.json)
  -o, --output DIR      Output directory (overrides config)
  -p, --plugin NAME     Run specific plugin only (can be used multiple times)
  -v, --verbose         Enable verbose output
  -h, --help            Show this help message

Examples:
  lua docs/generate.lua                           # Generate all documentation
  lua docs/generate.lua -c custom.json           # Use custom config
  lua docs/generate.lua -p api_docs               # Generate only API docs
  lua docs/generate.lua -o /tmp/docs -v           # Custom output with verbose
]])
end

-- Main function
local function main(args)
    local options = parse_args(args)
    
    if options.help then
        print_help()
        return 0
    end
    
    -- Load configuration
    local config = DocConfig.new(options.config_file)
    
    -- Override output directory if specified
    if options.output_dir then
        config:set("output_dir", options.output_dir)
    end
    
    -- Load environment variables
    config:load_from_env()
    
    -- Validate configuration
    local success, error_msg = pcall(config.validate, config)
    if not success then
        print("Configuration validation failed: " .. error_msg)
        return 1
    end
    
    -- Create documentation generator
    local generator = DocGenerator.new(config:get_all())
    local plugin_manager = PluginManager.new()
    
    -- Load templates
    generator:load_template("api", "docs/templates/api.md")
    
    -- Load built-in plugins (these will be implemented in subsequent tasks)
    -- TODO: Load actual documentation plugins:
    -- - API Documentation Plugin
    -- - Architecture Documentation Plugin  
    -- - Setup Guide Plugin
    -- - Deployment Documentation Plugin
    -- - Static Site Generator Plugin
    
    -- For now, no plugins are loaded - they will be added in subsequent tasks
    
    -- Execute plugins
    local results
    if #options.plugins > 0 then
        -- Execute specific plugins only
        results = {}
        for _, plugin_name in ipairs(options.plugins) do
            print("Executing plugin: " .. plugin_name)
            local result = plugin_manager:execute_plugin(plugin_name, config:get_all(), generator)
            results[plugin_name] = result
        end
    else
        -- Execute all plugins
        results = plugin_manager:execute_all(config:get_all(), generator)
    end
    
    -- Print results
    print("\nDocumentation Generation Results:")
    print("================================")
    
    local total_success = 0
    local total_failed = 0
    local total_skipped = 0
    
    for plugin_name, result in pairs(results) do
        local status
        if result.skipped then
            status = "SKIPPED"
            total_skipped = total_skipped + 1
        elseif result.success then
            status = "SUCCESS"
            total_success = total_success + 1
        else
            status = "FAILED"
            total_failed = total_failed + 1
        end
        
        print(string.format("  %-20s: %s", plugin_name, status))
        
        if options.verbose and result.error then
            print("    Error: " .. result.error)
        end
        
        if options.verbose and result.files_generated then
            print("    Files generated: " .. result.files_generated)
        end
    end
    
    print("\nSummary:")
    print("  Success: " .. total_success)
    print("  Failed:  " .. total_failed)
    print("  Skipped: " .. total_skipped)
    
    if total_failed > 0 then
        print("\nSome plugins failed. Check the output above for details.")
        return 1
    end
    
    print("\nDocumentation generated successfully!")
    print("Output directory: " .. config:get("output_dir"))
    
    return 0
end

-- Run main function if script is executed directly
if arg and arg[0] and arg[0]:match("generate%.lua$") then
    local exit_code = main(arg)
    os.exit(exit_code)
end

-- Export for testing
return {
    main = main,
    parse_args = parse_args,
    print_help = print_help
}