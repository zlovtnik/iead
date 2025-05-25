-- Production configuration for Church Management System
return {
  db_file = "church_management.db",
  host = "0.0.0.0",  -- Listen on all interfaces in production
  port = 8080,
  log_level = "info",
  environment = "production",
  max_connections = 100,
  timeout = 60,
  enable_cache = true,
  cache_ttl = 3600,  -- 1 hour in seconds
  ssl = false,       -- Set to true if using SSL/TLS
  debug = false
}
