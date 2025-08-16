#!/bin/bash

# Dependency Security and Update Script
# Checks for vulnerabilities and outdated dependencies in both frontend and backend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Church Management System - Dependency Security Check${NC}"
echo "==============================================================="

# Function to print colored output
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "church-management-1.0-1.rockspec" ]]; then
    log_error "This script must be run from the project root directory"
    exit 1
fi

# Frontend dependency checks
log_info "Checking frontend dependencies..."
cd public

# Check if package.json exists
if [[ ! -f "package.json" ]]; then
    log_error "package.json not found in public directory"
    exit 1
fi

# Install/update npm audit if needed
log_info "Running npm audit..."
if npm audit --audit-level=high; then
    log_success "No high-severity vulnerabilities found in npm dependencies"
else
    log_warning "High-severity vulnerabilities found! Run 'npm audit fix' to resolve"
    echo ""
    echo "Detailed vulnerability report:"
    npm audit --audit-level=moderate --json > ../audit-report.json 2>/dev/null || true
fi

# Check for outdated packages
log_info "Checking for outdated npm packages..."
OUTDATED_COUNT=$(npm outdated --depth=0 2>/dev/null | wc -l || echo "0")
if [[ $OUTDATED_COUNT -gt 1 ]]; then
    log_warning "$((OUTDATED_COUNT - 1)) packages are outdated"
    echo "Run 'npm outdated' to see details and 'npm update' to update"
    npm outdated --depth=0 || true
else
    log_success "All npm packages are up to date"
fi

# Check bundle size
log_info "Analyzing bundle size..."
if command -v npx &> /dev/null; then
    if [[ -d "dist" ]] || [[ -d "build" ]]; then
        log_info "Bundle analysis would require build. Skipping for now."
    else
        log_info "No build directory found. Run 'npm run build' first for bundle analysis."
    fi
fi

cd ..

# Backend dependency checks (Lua/LuaRocks)
log_info "Checking backend dependencies..."

# Check if luarocks is installed
if ! command -v luarocks &> /dev/null; then
    log_warning "luarocks not found. Install LuaRocks to check Lua dependencies"
else
    log_info "Checking LuaRocks dependencies..."
    
    # Check if rockspec file exists
    if [[ -f "church-management-1.0-1.rockspec" ]]; then
        # List installed rocks
        log_info "Installed Lua rocks:"
        luarocks list --porcelain 2>/dev/null || log_warning "Could not list installed rocks"
        
        # Check for security advisories (manual process for Lua)
        log_info "Manual security check required for Lua dependencies"
        log_info "Check https://github.com/advisories for known vulnerabilities"
    fi
fi

# Database dependency checks
log_info "Checking database dependencies..."
if command -v sqlite3 &> /dev/null; then
    SQLITE_VERSION=$(sqlite3 --version | cut -d' ' -f1)
    log_success "SQLite version: $SQLITE_VERSION"
    
    # Check if version is recent (3.35+ recommended)
    # Use proper version comparison
    if printf '%s\n' "3.35.0" "$SQLITE_VERSION" | sort -V | head -n1 | grep -q "3.35.0"; then
        log_success "SQLite version is current"
    else
        log_warning "SQLite version $SQLITE_VERSION is older. Consider upgrading to 3.35+"
    fi
    # To initialize the database, use a valid SQL file (not schema.lua)
    if [[ -f "src/db/schema.sql" ]]; then
        sqlite3 church_management.db < src/db/schema.sql
        log_success "Applied schema.sql to SQLite database."
    else
        log_warning "No schema.sql file found for SQLite initialization."
    fi
else
    log_warning "SQLite not found"
fi

# System dependency checks
log_info "Checking system dependencies..."

# Check Lua version
if command -v lua &> /dev/null; then
    LUA_VERSION=$(lua -v 2>&1 | head -n1)
    log_success "Lua: $LUA_VERSION"
else
    log_warning "Lua not found"
fi

# Check OpenResty/nginx
if command -v openresty &> /dev/null; then
    OPENRESTY_VERSION=$(openresty -v 2>&1)
    log_success "OpenResty: $OPENRESTY_VERSION"
elif command -v nginx &> /dev/null; then
    NGINX_VERSION=$(nginx -v 2>&1)
    log_success "Nginx: $NGINX_VERSION"
else
    log_warning "OpenResty/Nginx not found"
fi

# Security configuration checks
log_info "Checking security configurations..."

# Check for sensitive files
SENSITIVE_FILES=(".env" "config/database.lua" "*.key" "*.pem")
shopt -s nullglob
for pattern in "${SENSITIVE_FILES[@]}"; do
    for file in $pattern; do
        if [ -e "$file" ]; then
            log_warning "Sensitive file found: $file"
            log_info "Ensure this file is in .gitignore and properly secured"
        fi
    done
done
shopt -u nullglob

# Check .gitignore
if [[ -f ".gitignore" ]]; then
    if grep -q "node_modules\|\.env\|*.db\|\.log" .gitignore; then
        log_success ".gitignore contains common sensitive patterns"
    else
        log_warning ".gitignore may be missing sensitive file patterns"
    fi
else
    log_error ".gitignore file not found"
fi

# Generate security report
log_info "Generating security report..."
REPORT_FILE="security-report-$(date +%Y%m%d-%H%M%S).txt"

cat > "$REPORT_FILE" << EOF
Church Management System - Security Audit Report
Generated: $(date)
===============================================

FRONTEND DEPENDENCIES:
$(cd public && npm audit --audit-level=moderate 2>/dev/null || echo "Audit completed with warnings")

OUTDATED PACKAGES:
$(cd public && npm outdated 2>/dev/null || echo "All packages current")

SYSTEM INFORMATION:
- Lua: $(lua -v 2>&1 | head -n1 || echo "Not found")
- OpenResty: $(openresty -v 2>&1 || echo "Not found")  
- SQLite: $(sqlite3 --version 2>/dev/null || echo "Not found")
- Node.js: $(node --version 2>/dev/null || echo "Not found")
- npm: $(npm --version 2>/dev/null || echo "Not found")

RECOMMENDATIONS:
1. Run 'npm audit fix' to resolve any npm vulnerabilities
2. Keep all dependencies updated regularly
3. Monitor security advisories for Lua/OpenResty dependencies
4. Ensure all sensitive configuration files are properly secured
5. Regular security scans should be part of CI/CD pipeline

EOF

log_success "Security report saved to: $REPORT_FILE"

# Summary
echo ""
echo "==============================================================="
log_info "Security check completed!"
echo ""
echo "Next steps:"
echo "1. Review the generated report: $REPORT_FILE"
echo "2. Fix any high/critical vulnerabilities immediately"
echo "3. Plan updates for outdated dependencies"
echo "4. Set up automated security scanning in CI/CD"
echo ""
    # Check if there are critical vulnerabilities
   # Use jq for proper JSON parsing
   if command -v jq &> /dev/null; then
       CRITICAL_COUNT=$(jq '[.vulnerabilities[].severity | select(. == "critical")] | length' public/audit-report.json 2>/dev/null || echo "0")
   else
       # Fallback to grep if jq is not available
       CRITICAL_COUNT=$(grep -o '"severity":"critical"' public/audit-report.json 2>/dev/null | wc -l || echo "0")
   fi
    if [[ $CRITICAL_COUNT -gt 0 ]]; then
    # Check if there are critical vulnerabilities
    CRITICAL_COUNT=$(cat public/audit-report.json 2>/dev/null | grep -c '"severity":"critical"' || echo "0")
    if [[ $CRITICAL_COUNT -gt 0 ]]; then
        log_error "Critical vulnerabilities found! Address immediately."
        exit 1
    fi
fi

log_success "Security check completed successfully!"
