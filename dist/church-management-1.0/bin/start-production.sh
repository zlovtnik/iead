#!/bin/sh
# Start the Church Management System in production

# Set environment variables
export APP_ENV=${APP_ENV:-production}
export PORT=${PORT:-8080}
export HOST=${HOST:-0.0.0.0}
export DB_PATH=${DB_PATH:-/data/church_management.db}

# Create data directory if it doesn't exist
mkdir -p /data

# Make the app executable
chmod +x bin/church-management

# Print environment information
echo "Starting Church Management System"
echo "Environment: $APP_ENV"
echo "Host: $HOST"
echo "Port: $PORT"
echo "Database path: $DB_PATH"

# Run the app with environment variables passed to the process
exec env APP_ENV="$APP_ENV" PORT="$PORT" HOST="$HOST" DB_PATH="$DB_PATH" bin/church-management
