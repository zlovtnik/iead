#!/bin/sh
# Start the Church Management System in production mode

# Set default environment variables if not already set
: ${PORT:=8080}
: ${HOST:=0.0.0.0}
: ${DB_PATH:=/data/church_management.db}
: ${APP_ENV:=production}

# Export environment variables
export PORT
export HOST
export DB_PATH
export APP_ENV

# Make the app executable
chmod +x app.lua

# Ensure database directory exists
mkdir -p "$(dirname "$DB_PATH")"

# Print startup information
echo "Starting Church Management System in $APP_ENV mode"
echo "Listening on $HOST:$PORT"
echo "Database path: $DB_PATH"

# Run the app
exec lua app.lua
