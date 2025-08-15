-- src/infrastructure/config/security.lua
-- Security configuration for the church management system

local security_config = {}

-- Authentication settings
security_config.auth = {
    -- Session settings
    session_timeout = tonumber(os.getenv("SESSION_TIMEOUT")) or 3600, -- 1 hour
    session_refresh_threshold = tonumber(os.getenv("SESSION_REFRESH_THRESHOLD")) or 300, -- 5 minutes
    
    -- Password policy
    password_policy = {
        min_length = tonumber(os.getenv("MIN_PASSWORD_LENGTH")) or 8,
        max_length = tonumber(os.getenv("MAX_PASSWORD_LENGTH")) or 128,
        require_uppercase = os.getenv("REQUIRE_UPPERCASE") ~= "false",
        require_lowercase = os.getenv("REQUIRE_LOWERCASE") ~= "false",
        require_digit = os.getenv("REQUIRE_DIGIT") ~= "false",
        require_special = os.getenv("REQUIRE_SPECIAL") == "true",
        prevent_reuse_count = tonumber(os.getenv("PASSWORD_HISTORY_COUNT")) or 5
    },
    
    -- Account lockout settings
    account_lockout = {
        max_failed_attempts = tonumber(os.getenv("MAX_FAILED_ATTEMPTS")) or 5,
        lockout_duration = tonumber(os.getenv("LOCKOUT_DURATION")) or 900, -- 15 minutes
        reset_failed_attempts_after = tonumber(os.getenv("RESET_ATTEMPTS_AFTER")) or 3600 -- 1 hour
    },
    
    -- Token settings
    tokens = {
        access_token_length = tonumber(os.getenv("ACCESS_TOKEN_LENGTH")) or 32,
        refresh_token_length = tonumber(os.getenv("REFRESH_TOKEN_LENGTH")) or 64,
        csrf_token_length = tonumber(os.getenv("CSRF_TOKEN_LENGTH")) or 32
    }
}

-- Rate limiting configuration
security_config.rate_limiting = {
    -- Authentication endpoints
    auth_endpoints = {
        enabled = os.getenv("AUTH_RATE_LIMIT_ENABLED") ~= "false",
        max_attempts = tonumber(os.getenv("AUTH_RATE_LIMIT_MAX")) or 5,
        window_seconds = tonumber(os.getenv("AUTH_RATE_LIMIT_WINDOW")) or 900, -- 15 minutes
        identifier_types = {"ip", "username"}
    },
    
    -- General API endpoints
    api_endpoints = {
        enabled = os.getenv("API_RATE_LIMIT_ENABLED") ~= "false",
        max_attempts = tonumber(os.getenv("API_RATE_LIMIT_MAX")) or 100,
        window_seconds = tonumber(os.getenv("API_RATE_LIMIT_WINDOW")) or 60, -- 1 minute
        identifier_types = {"ip"}
    },
    
    -- Global rate limiting
    global = {
        enabled = os.getenv("GLOBAL_RATE_LIMIT_ENABLED") ~= "false",
        max_attempts = tonumber(os.getenv("GLOBAL_RATE_LIMIT_MAX")) or 1000,
        window_seconds = tonumber(os.getenv("GLOBAL_RATE_LIMIT_WINDOW")) or 60,
        identifier_types = {"ip"}
    }
}

-- Encryption settings
security_config.encryption = {
    -- bcrypt settings
    bcrypt_rounds = tonumber(os.getenv("BCRYPT_ROUNDS")) or 12,
    
    -- Ensure minimum security standards
    min_bcrypt_rounds = 10,
    max_bcrypt_rounds = 15
}

-- Database security settings
security_config.database = {
    -- Connection settings
    max_connections = tonumber(os.getenv("DB_MAX_CONNECTIONS")) or 10,
    connection_timeout = tonumber(os.getenv("DB_CONNECTION_TIMEOUT")) or 30,
    
    -- Query settings
    max_query_time = tonumber(os.getenv("DB_MAX_QUERY_TIME")) or 30,
    enable_query_logging = os.getenv("DB_ENABLE_QUERY_LOGGING") == "true",
    
    -- Security settings
    enable_foreign_keys = os.getenv("DB_ENABLE_FOREIGN_KEYS") ~= "false",
    enable_triggers = os.getenv("DB_ENABLE_TRIGGERS") ~= "false"
}

-- Input validation settings
security_config.validation = {
    -- String sanitization
    max_input_length = tonumber(os.getenv("MAX_INPUT_LENGTH")) or 10000,
    strip_html_tags = os.getenv("STRIP_HTML_TAGS") ~= "false",
    encode_html_entities = os.getenv("ENCODE_HTML_ENTITIES") ~= "false",
    
    -- File upload restrictions (for future use)
    file_upload = {
        enabled = os.getenv("FILE_UPLOAD_ENABLED") == "true",
        max_file_size = tonumber(os.getenv("MAX_FILE_SIZE")) or 5242880, -- 5MB
        allowed_types = {".jpg", ".jpeg", ".png", ".pdf", ".doc", ".docx"},
        scan_for_malware = os.getenv("SCAN_MALWARE") == "true"
    }
}

-- HTTPS and security headers
security_config.web_security = {
    -- Force HTTPS
    force_https = os.getenv("FORCE_HTTPS") == "true",
    https_port = tonumber(os.getenv("HTTPS_PORT")) or 443,
    
    -- Security headers
    security_headers = {
        enable_hsts = os.getenv("ENABLE_HSTS") ~= "false",
        hsts_max_age = tonumber(os.getenv("HSTS_MAX_AGE")) or 31536000, -- 1 year
        enable_csp = os.getenv("ENABLE_CSP") == "true",
        csp_policy = os.getenv("CSP_POLICY") or "default-src 'self'",
        enable_xframe_options = os.getenv("ENABLE_XFRAME_OPTIONS") ~= "false",
        xframe_options = os.getenv("XFRAME_OPTIONS") or "DENY",
        enable_content_type_options = os.getenv("ENABLE_CONTENT_TYPE_OPTIONS") ~= "false",
        enable_xss_protection = os.getenv("ENABLE_XSS_PROTECTION") ~= "false"
    },
    
    -- CORS settings
    cors = {
        enabled = os.getenv("CORS_ENABLED") == "true",
        allowed_origins = os.getenv("CORS_ALLOWED_ORIGINS") or "*",
        allowed_methods = os.getenv("CORS_ALLOWED_METHODS") or "GET,POST,PUT,DELETE,OPTIONS",
        allowed_headers = os.getenv("CORS_ALLOWED_HEADERS") or "Content-Type,Authorization,X-CSRF-Token",
        max_age = tonumber(os.getenv("CORS_MAX_AGE")) or 86400 -- 24 hours
    }
}

-- Logging and monitoring
security_config.logging = {
    -- Security event logging
    log_auth_attempts = os.getenv("LOG_AUTH_ATTEMPTS") ~= "false",
    log_rate_limit_violations = os.getenv("LOG_RATE_LIMIT_VIOLATIONS") ~= "false",
    log_validation_failures = os.getenv("LOG_VALIDATION_FAILURES") ~= "false",
    log_permission_denials = os.getenv("LOG_PERMISSION_DENIALS") ~= "false",
    
    -- Log levels
    security_log_level = os.getenv("SECURITY_LOG_LEVEL") or "INFO",
    
    -- Log retention
    log_retention_days = tonumber(os.getenv("LOG_RETENTION_DAYS")) or 90,
    
    -- Alert thresholds
    alert_thresholds = {
        failed_auth_per_minute = tonumber(os.getenv("ALERT_FAILED_AUTH_PER_MIN")) or 10,
        rate_limit_violations_per_minute = tonumber(os.getenv("ALERT_RATE_LIMIT_PER_MIN")) or 5,
        permission_denials_per_minute = tonumber(os.getenv("ALERT_PERMISSION_DENIALS_PER_MIN")) or 3
    }
}

-- Environment-specific overrides
local env = os.getenv("ENVIRONMENT") or "development"

if env == "production" then
    -- Production overrides for enhanced security
    security_config.encryption.bcrypt_rounds = math.max(security_config.encryption.bcrypt_rounds, 12)
    security_config.auth.session_timeout = math.min(security_config.auth.session_timeout, 3600) -- Max 1 hour
    security_config.web_security.force_https = true
    security_config.web_security.security_headers.enable_hsts = true
    security_config.web_security.security_headers.enable_csp = true
    security_config.logging.security_log_level = "WARN"
    
elseif env == "staging" then
    -- Staging overrides
    security_config.encryption.bcrypt_rounds = math.max(security_config.encryption.bcrypt_rounds, 10)
    security_config.logging.security_log_level = "INFO"
    
elseif env == "development" then
    -- Development overrides for easier testing
    security_config.encryption.bcrypt_rounds = math.max(security_config.encryption.bcrypt_rounds, 4) -- Faster for dev
    security_config.auth.session_timeout = 7200 -- 2 hours for convenience
    security_config.logging.security_log_level = "DEBUG"
    
    -- Relax some security for development convenience
    security_config.rate_limiting.auth_endpoints.max_attempts = 10
    security_config.rate_limiting.api_endpoints.max_attempts = 200
end

-- Validation function to ensure configuration is secure
function security_config.validate()
    local errors = {}
    
    -- Validate bcrypt rounds
    if security_config.encryption.bcrypt_rounds < security_config.encryption.min_bcrypt_rounds then
        table.insert(errors, "bcrypt_rounds too low (minimum: " .. security_config.encryption.min_bcrypt_rounds .. ")")
    end
    
    if security_config.encryption.bcrypt_rounds > security_config.encryption.max_bcrypt_rounds then
        table.insert(errors, "bcrypt_rounds too high (maximum: " .. security_config.encryption.max_bcrypt_rounds .. ")")
    end
    
    -- Validate password policy
    if security_config.auth.password_policy.min_length < 8 then
        table.insert(errors, "minimum password length too low (minimum: 8)")
    end
    
    -- Validate session timeout
    if security_config.auth.session_timeout > 86400 then -- 24 hours
        table.insert(errors, "session timeout too long (maximum: 24 hours)")
    end
    
    -- In production, certain settings must be secure
    if env == "production" then
        if not security_config.web_security.force_https then
            table.insert(errors, "HTTPS must be enforced in production")
        end
        
        if security_config.encryption.bcrypt_rounds < 12 then
            table.insert(errors, "bcrypt rounds must be at least 12 in production")
        end
    end
    
    return #errors == 0, errors
end

-- Get configuration value with fallback
function security_config.get(key_path, default_value)
    local keys = {}
    for key in key_path:gmatch("[^%.]+") do
        table.insert(keys, key)
    end
    
    local value = security_config
    for _, key in ipairs(keys) do
        if type(value) == "table" and value[key] ~= nil then
            value = value[key]
        else
            return default_value
        end
    end
    
    return value
end

-- Apply configuration validation on load
local valid, errors = security_config.validate()
if not valid then
    error("Security configuration validation failed: " .. table.concat(errors, "; "))
end

return security_config
