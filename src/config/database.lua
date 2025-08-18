-- src/config/database.lua
-- Database configuration for Church Management System

local config = {
  -- PostgreSQL configuration
  host = os.getenv("DB_HOST") or "localhost",
  port = os.getenv("DB_PORT") or "5432",
  database = os.getenv("DB_NAME") or "church_management",
  user = os.getenv("DB_USER") or "postgres",
  password = os.getenv("DB_PASSWORD") or "password",
  
  -- Application configuration
  app_host = os.getenv("APP_HOST") or "127.0.0.1",
  app_port = tonumber(os.getenv("APP_PORT")) or 8080
}

return config
