# Documentation System

This directory contains the documentation generation infrastructure for the Church Management System.

## Directory Structure

```
docs/
├── README.md                    # This file
├── generate.lua                 # Main documentation generation script
├── config/
│   └── default.json            # Default configuration
├── generator/
│   ├── doc_generator.lua       # Main generator framework
│   ├── config.lua              # Configuration management
│   ├── plugin_base.lua         # Base class for plugins
│   └── plugin_manager.lua      # Plugin management system
├── templates/
│   ├── base.html               # Base HTML template
│   ├── api.md                  # API documentation template
│   ├── setup.md                # Setup guide template
│   ├── architecture.md         # Architecture documentation template
│   └── deployment.md           # Deployment guide template
├── plugins/                    # Documentation plugins (to be created)
├── assets/                     # Static assets (CSS, JS, images)
└── site/                       # Generated documentation output
```

## Quick Start

### Generate All Documentation

```bash
lua docs/generate.lua
```

### Generate with Custom Configuration

```bash
lua docs/generate.lua --config docs/config/custom.json
```

### Generate Specific Plugin Only

```bash
lua docs/generate.lua --plugin api_docs
```

### Generate with Verbose Output

```bash
lua docs/generate.lua --verbose
```

## Configuration

The documentation system uses JSON configuration files. The default configuration is located at `docs/config/default.json`.

### Configuration Options

- `title`: Documentation site title
- `version`: Documentation version
- `base_url`: Base URL for the documentation site
- `output_dir`: Directory where generated documentation will be placed
- `templates`: Paths to template files
- `plugins`: Plugin-specific configuration
- `site`: Site-wide settings (theme, navigation, etc.)

### Environment Variables

You can override configuration values using environment variables:

- `DOC_TITLE`: Override the documentation title
- `DOC_VERSION`: Override the version
- `DOC_BASE_URL`: Override the base URL
- `DOC_OUTPUT_DIR`: Override the output directory

## Plugin Architecture

The documentation system uses a plugin-based architecture that allows for modular and extensible documentation generation.

### Creating a Plugin

1. Extend the `PluginBase` class
2. Implement the `generate(config, generator)` method
3. Register the plugin with the `PluginManager`

Example:

```lua
local PluginBase = require('docs.generator.plugin_base')

local MyPlugin = PluginBase.new("my_plugin")

function MyPlugin:generate(config, generator)
    -- Plugin implementation
    self:log("Generating documentation...")
    
    -- Generate content
    local content = "# My Documentation\n\nGenerated content here"
    
    -- Write to file
    generator:write_file(config.output_dir .. "/my-docs.md", content)
    
    return { success = true, files_generated = 1 }
end

return MyPlugin
```

### Plugin Dependencies

Plugins can declare dependencies on other plugins:

```lua
function MyPlugin:new()
    local self = PluginBase.new("my_plugin")
    self:add_dependency("api_docs")  -- This plugin depends on api_docs
    return self
end
```

## Templates

The system uses a template-based approach for generating documentation. Templates support variable substitution using `{{variable}}` syntax.

### Template Variables

Common template variables include:

- `{{title}}`: Page/section title
- `{{description}}`: Page/section description
- `{{content}}`: Main content
- `{{base_url}}`: Base URL for links
- `{{version}}`: Documentation version
- `{{timestamp}}`: Generation timestamp

## Development

### Adding New Templates

1. Create a new template file in `docs/templates/`
2. Add the template path to the configuration
3. Use the template in your plugin

### Testing

Run the documentation generator with verbose output to see detailed information:

```bash
lua docs/generate.lua --verbose
```

### Debugging

Enable verbose logging and check the output for any errors or warnings during generation.

## Next Steps

This infrastructure provides the foundation for the documentation system. The following plugins will be implemented in subsequent tasks:

1. API Documentation Plugin
2. Architecture Documentation Plugin  
3. Setup Guide Plugin
4. Deployment Documentation Plugin
5. Static Site Generator Plugin

Each plugin will leverage this infrastructure to generate specific types of documentation.