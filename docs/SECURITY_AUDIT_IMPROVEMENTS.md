# Security Audit Improvements in Quality Tracker

## Problem Addressed

The original security audit implementation in `scripts/quality_tracker.lua` (lines 179-197) had several security and reliability issues:

1. **No prerequisite validation** - Blindly attempted to run `npm audit` without checking if npm or the project directory existed
2. **No error handling** - Did not capture or validate the `os.execute` return code before processing results
3. **Unsafe file operations** - Opened and read `/tmp/audit_output.json` without validating the command succeeded
4. **Fragile JSON parsing** - Could crash or report misleading numbers if JSON parsing failed or file was empty
5. **Path injection vulnerability** - Used unescaped paths in shell commands

## Security Improvements Implemented

### 1. Prerequisite Validation

**Before:**
```lua
local audit_result = os.execute("cd " .. self.project_root .. "/public && npm audit --json > /tmp/audit_output.json 2>/dev/null")
```

**After:**
```lua
-- 1. Check if public directory exists and is accessible
local public_dir = self.project_root .. "/public"
local public_dir_file = io.open(public_dir .. "/package.json", "r")
if not public_dir_file then
    print("[quality_tracker] Warning: No package.json found in public directory, skipping npm audit")
    return security
end
public_dir_file:close()

-- 2. Check if npm is available by testing it directly
local npm_check_result = os.execute("npm --version > /dev/null 2>&1")
if npm_check_result ~= 0 and npm_check_result ~= true then
    print("[quality_tracker] Warning: npm not found or not working, skipping security audit")
    return security
end
```

### 2. Command Execution Hardening

**Before:**
```lua
local audit_result = os.execute("cd " .. self.project_root .. "/public && npm audit --json > /tmp/audit_output.json 2>/dev/null")
```

**After:**
```lua
-- 3. Run security audit with proper error handling and path escaping
local audit_output_file = "/tmp/audit_output.json"
local audit_command = string.format("cd '%s' && npm audit --json > '%s' 2>/dev/null", 
    public_dir:gsub("'", "'\\''"), audit_output_file:gsub("'", "'\\''"))

local audit_result = os.execute(audit_command)
```

**Security improvements:**
- **Path escaping**: Properly escapes single quotes in paths to prevent shell injection
- **Explicit file paths**: Uses absolute paths for temporary files
- **Command validation**: Constructs commands safely using `string.format`

### 3. Return Code Validation

**Before:**
```lua
local audit_file = io.open("/tmp/audit_output.json", "r")
if audit_file then
    -- Process file regardless of command success
```

**After:**
```lua
-- 4. Only process results if the command succeeded or returned expected npm audit codes
local audit_success = (audit_result == 0 or audit_result == true or 
                      audit_result == 256 or audit_result == 512) -- 0, 1, 2 exit codes
if audit_success then
    local audit_file = io.open(audit_output_file, "r")
    -- Only process if command succeeded
```

**Improvements:**
- **Exit code validation**: Only processes results if npm audit succeeded
- **Lua version compatibility**: Handles both Lua 5.1 (returns true/false) and newer versions (returns exit codes)
- **Expected failure handling**: Recognizes that npm audit returns non-zero codes when vulnerabilities are found

### 4. File Content Validation

**Before:**
```lua
local content = audit_file:read("*all")
audit_file:close()

local success, audit_data = pcall(json.decode, content)
```

**After:**
```lua
local content = audit_file:read("*all")
audit_file:close()

-- 5. Validate file content before parsing
if content and content:len() > 0 and content:match("%S") then -- Non-empty and has non-whitespace
    local success, audit_data = pcall(json.decode, content)
    if success and audit_data then
        -- Process valid JSON data
    else
        print("[quality_tracker] Warning: Failed to parse npm audit JSON output, using default security values")
    end
else
    print("[quality_tracker] Warning: npm audit output file is empty or invalid, using default security values")
end
```

**Improvements:**
- **Content validation**: Checks that file is non-empty and contains non-whitespace content
- **JSON parsing safety**: Already used `pcall` but now has better error handling
- **Graceful degradation**: Uses default values when parsing fails instead of crashing

### 5. Enhanced Error Handling and Logging

**Before:**
```lua
-- No error logging or fallback handling
```

**After:**
```lua
-- Comprehensive error handling with informative messages
if not audit_success then
    print(string.format("[quality_tracker] Warning: npm audit command failed with exit code %s, using default security values", tostring(audit_result)))
end

-- Handle different npm audit output formats
local vulnerabilities = nil
if audit_data.metadata and audit_data.metadata.vulnerabilities then
    vulnerabilities = audit_data.metadata.vulnerabilities  -- npm 7+
elseif audit_data.vulnerabilities then
    vulnerabilities = audit_data.vulnerabilities  -- npm 6
end

if vulnerabilities then
    print(string.format("[quality_tracker] Security audit completed: %d high, %d medium, %d low vulnerabilities", 
        security.vulnerabilities_high, security.vulnerabilities_medium, security.vulnerabilities_low))
else
    print("[quality_tracker] Warning: npm audit output format not recognized, using default security values")
end
```

**Improvements:**
- **Detailed logging**: Provides specific error messages for different failure scenarios
- **Format compatibility**: Handles different npm audit output formats (npm 6 vs 7+)
- **Success reporting**: Logs successful audit results for visibility

### 6. Resource Cleanup

**Before:**
```lua
-- No cleanup of temporary files
```

**After:**
```lua
-- Clean up temporary file
os.remove(audit_output_file)
```

**Improvement:**
- **Resource cleanup**: Always removes temporary files, even on failure

## Testing Results

The improved security audit function now handles various scenarios correctly:

### Scenario 1: npm not available
```
[quality_tracker] Warning: npm not found or not working, skipping security audit
```

### Scenario 2: No package.json in public directory
```
[quality_tracker] Warning: No package.json found in public directory, skipping npm audit
```

### Scenario 3: npm audit command fails
```
[quality_tracker] Warning: npm audit command failed with exit code nil, using default security values
```

### Scenario 4: Successful audit with no vulnerabilities
```
[quality_tracker] Security audit completed: 0 high, 0 medium, 0 low vulnerabilities
```

## Security Benefits

1. **Prevents Command Injection**: Proper path escaping prevents malicious paths from executing arbitrary commands
2. **Avoids File System Attacks**: Validates file existence and content before processing
3. **Handles Missing Dependencies**: Gracefully handles missing npm or project files
4. **Prevents Crashes**: Robust error handling prevents the quality tracker from crashing on invalid input
5. **Provides Visibility**: Detailed logging helps with debugging and monitoring
6. **Resource Safety**: Proper cleanup prevents temporary file accumulation

## Compatibility

The implementation is compatible with:
- **Lua 5.1** (used in OpenResty) and newer versions
- **npm 6** and **npm 7+** (different JSON output formats)
- **Various operating systems** (macOS, Linux, Windows with appropriate shell)
- **Missing dependencies** (graceful degradation when npm is not available)

## Future Enhancements

Potential future improvements:
1. **Timeout handling**: Add timeouts for long-running npm audit commands
2. **Retry logic**: Implement retry mechanism for transient failures
3. **Caching**: Cache audit results to avoid repeated expensive operations
4. **Alternative tools**: Support for other security audit tools (yarn audit, etc.)
5. **Detailed reporting**: Parse and report specific vulnerability details

## Conclusion

The security audit improvements transform a fragile, potentially unsafe implementation into a robust, secure, and reliable system that:
- Validates all prerequisites before execution
- Safely handles shell commands and file operations
- Provides comprehensive error handling and logging
- Maintains compatibility across different environments
- Fails safely without compromising the overall quality tracking system

These improvements ensure that the quality tracker can safely run in production environments without security risks or reliability issues.