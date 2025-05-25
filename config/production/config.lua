-- production configuration
return {
  db_file = "church_management.db",
  host = "0.0.0.0",  -- Listen on all interfaces in production
  port = 8080,
  log_level = "info",
  environment = "production"
}
