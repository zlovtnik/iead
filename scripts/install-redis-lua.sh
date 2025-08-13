#!/bin/bash
# scripts/install-redis-lua.sh
# Script to install Redis Lua client for production environments

set -e

echo "Installing Redis Lua client..."

# Check if LuaRocks is available
if ! command -v luarocks &> /dev/null; then
    echo "LuaRocks not found. Installing LuaRocks..."
    
    # Install LuaRocks based on OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        apt-get update && apt-get install -y luarocks
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install luarocks
        else
            echo "Please install Homebrew first, then run: brew install luarocks"
            exit 1
        fi
    else
        echo "Unsupported OS. Please install LuaRocks manually."
        exit 1
    fi
fi

# Install Redis Lua client
echo "Installing redis-lua package..."
luarocks install redis-lua

echo "Redis Lua client installed successfully!"
echo "You can now enable Redis in your configuration with REDIS_ENABLED=true"
