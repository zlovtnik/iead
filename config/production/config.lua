-- production configuration
return {
  db_file = "church_management.db",
  host = "0.0.0.0",  -- Listen on all interfaces in production
  port = 8080,
  log_level = "info",
  environment = "production",
  
  -- Rate limiting configuration
  rate_limiting = {
    enabled = true,
    max_attempts = 5,
    window_seconds = 15 * 60, -- 15 minutes
    
    -- Redis configuration for production rate limiting
    redis = {
      enabled = true,
      host = os.getenv("REDIS_HOST") or "redis",
      port = tonumber(os.getenv("REDIS_PORT")) or 6379,
      timeout = 1000,
      pool_size = 10
    }
  }
}
