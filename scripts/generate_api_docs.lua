#!/usr/bin/env lua

-- scripts/generate_api_docs.lua
-- Script to generate API documentation

local APIDocGenerator = require("docs.generator.api_doc_generator")

-- Configuration
local config = {
  title = "Church Management System API",
  description = "Comprehensive API for church operations management including member management, events, donations, and reporting",
  version = "1.0.0",
  api_version = "v1",
  output_dir = "docs/api",
  routes_dir = "src/routes",
  base_url = "http://localhost:8080",
  generate_yaml = true,
  servers = {
    {
      url = "http://localhost:8080",
      description = "Development server"
    },
    {
      url = "https://api.church.example.com",
      description = "Production server"
    }
  }
}

-- Parse command line arguments
local args = {...}
for i, arg in ipairs(args) do
  if arg == "--output" and args[i + 1] then
    config.output_dir = args[i + 1]
  elseif arg == "--base-url" and args[i + 1] then
    config.base_url = args[i + 1]
  elseif arg == "--routes-dir" and args[i + 1] then
    config.routes_dir = args[i + 1]
  elseif arg == "--help" then
    print("Usage: lua scripts/generate_api_docs.lua [options]")
    print("")
    print("Options:")
    print("  --output DIR        Output directory (default: docs/api)")
    print("  --base-url URL      Base URL for examples (default: http://localhost:8080)")
    print("  --routes-dir DIR    Routes directory (default: src/routes)")
    print("  --help              Show this help message")
    print("")
    return
  end
end

-- Generate documentation
print("Church Management System - API Documentation Generator")
print("=" .. string.rep("=", 50))
print("")

local success = APIDocGenerator.generate(config)

if success then
  print("")
  print("Documentation generated successfully!")
  print("Output directory: " .. config.output_dir)
  print("")
  print("Files generated:")
  print("  - openapi.json      (OpenAPI 3.0 specification)")
  print("  - openapi.yaml      (OpenAPI 3.0 specification - YAML)")
  print("  - endpoint_summaries.json (Quick reference)")
  print("  - code_examples.json (Code examples)")
  print("  - metadata.json     (Generation metadata)")
  print("  - README.md         (Human-readable summary)")
  print("")
  print("Next steps:")
  print("  1. Open openapi.json in Swagger UI for interactive exploration")
  print("  2. Use code_examples.json for integration examples")
  print("  3. Review README.md for documentation overview")
else
  print("")
  print("Error: Failed to generate documentation")
  os.exit(1)
end