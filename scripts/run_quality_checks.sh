#!/bin/bash

# Comprehensive Quality Assurance Test Runner
# Part of Phase 4: Testing & Quality implementation
# Integrates all testing tools with unified reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_DIR="${PROJECT_ROOT}/quality-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="${REPORTS_DIR}/${TIMESTAMP}"

# Test result tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Church Management Quality Checks   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Timestamp: $(date)"
echo -e "Report Directory: ${REPORT_DIR}"
echo ""

# Create reports directory
mkdir -p "${REPORT_DIR}"

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local critical="$3"  # true/false - whether failure should stop execution
    
    echo -e "${BLUE}Running: ${test_name}${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local log_file="${REPORT_DIR}/${test_name//[[:space:]]/_}.log"
    
    if eval "$test_command" > "$log_file" 2>&1; then
        echo -e "${GREEN}✅ PASSED: ${test_name}${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        local exit_code=$?
        echo -e "${RED}❌ FAILED: ${test_name}${NC}"
        echo -e "${YELLOW}   Log: ${log_file}${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        
        if [ "$critical" = "true" ]; then
            echo -e "${RED}Critical test failed. Stopping execution.${NC}"
            exit $exit_code
        fi
        return $exit_code
    fi
}

# Function to run a warning-only check
run_warning_check() {
    local check_name="$1"
    local check_command="$2"
    
    echo -e "${BLUE}Checking: ${check_name}${NC}"
    local log_file="${REPORT_DIR}/${check_name//[[:space:]]/_}.log"
    
    if eval "$check_command" > "$log_file" 2>&1; then
        echo -e "${GREEN}✅ OK: ${check_name}${NC}"
    else
        echo -e "${YELLOW}⚠️  WARNING: ${check_name}${NC}"
        echo -e "${YELLOW}   Log: ${log_file}${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# 1. Backend Lua Tests
echo -e "\n${YELLOW}=== Backend Testing ===${NC}"

cd "$PROJECT_ROOT"

run_test "Lua Unit Tests" "lua scripts/run_tests.lua" true
run_test "Lua Security Tests" "lua scripts/simple_security_test.lua" true
run_test "Lua Performance Tests" "lua scripts/performance_test.lua" false

# 2. Frontend Tests  
echo -e "\n${YELLOW}=== Frontend Testing ===${NC}"

cd "${PROJECT_ROOT}/public"

# Check if frontend dependencies are installed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing frontend dependencies...${NC}"
    npm install
fi

run_test "Frontend Unit Tests" "npm run test" true
run_test "Frontend Type Checking" "npx tsc --noEmit" false
run_test "Frontend Linting" "npm run lint" false

# 3. Code Quality Checks
echo -e "\n${YELLOW}=== Code Quality ===${NC}"

cd "$PROJECT_ROOT"

run_test "Lua Static Analysis" "luacheck src/ --no-color" false
run_warning_check "Backend Code Complexity" "find src/ -name '*.lua' -exec wc -l {} + | sort -nr | head -20"

cd "${PROJECT_ROOT}/public"
run_warning_check "Frontend Bundle Analysis" "node ../scripts/bundle_analyzer.mjs"

# 4. Security Audits
echo -e "\n${YELLOW}=== Security Audits ===${NC}"

cd "$PROJECT_ROOT"

run_test "Backend Security Audit" "bash scripts/security_audit.sh" false

cd "${PROJECT_ROOT}/public"
run_test "Frontend Dependency Audit" "npm audit --audit-level=moderate" false

# 5. Performance Benchmarks
echo -e "\n${YELLOW}=== Performance Benchmarks ===${NC}"

cd "$PROJECT_ROOT"

# Only run performance tests if server is available
if pgrep -f "openresty" > /dev/null 2>&1; then
    run_warning_check "API Performance Benchmark" "lua scripts/performance_demo.lua"
else
    echo -e "${YELLOW}⚠️  Server not running - skipping API performance tests${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 6. Database Health Check
echo -e "\n${YELLOW}=== Database Health ===${NC}"

run_warning_check "Database Schema Validation" "sqlite3 church_management.db '.schema' | wc -l"
run_warning_check "Database Integrity Check" "sqlite3 church_management.db 'PRAGMA integrity_check;'"

# 7. Generate Summary Report
echo -e "\n${YELLOW}=== Generating Summary Report ===${NC}"

SUMMARY_FILE="${REPORT_DIR}/quality_summary.md"

cat > "$SUMMARY_FILE" << EOF
# Quality Assurance Report

**Generated:** $(date)  
**Project:** Church Management System  
**Report ID:** ${TIMESTAMP}

## Summary

- **Total Tests:** ${TOTAL_TESTS}
- **Passed:** ${PASSED_TESTS}
- **Failed:** ${FAILED_TESTS}
- **Warnings:** ${WARNINGS}

## Test Results

### Backend Tests
- Unit Tests: $([ -f "${REPORT_DIR}/Lua_Unit_Tests.log" ] && echo "✅ PASSED" || echo "❌ FAILED")
- Security Tests: $([ -f "${REPORT_DIR}/Lua_Security_Tests.log" ] && echo "✅ PASSED" || echo "❌ FAILED")
- Performance Tests: $([ -f "${REPORT_DIR}/Lua_Performance_Tests.log" ] && echo "✅ PASSED" || echo "❌ FAILED")

### Frontend Tests
- Unit Tests: $([ -f "${REPORT_DIR}/Frontend_Unit_Tests.log" ] && echo "✅ PASSED" || echo "❌ FAILED")
- Type Checking: $([ -f "${REPORT_DIR}/Frontend_Type_Checking.log" ] && echo "✅ PASSED" || echo "❌ FAILED")
- Linting: $([ -f "${REPORT_DIR}/Frontend_Linting.log" ] && echo "✅ PASSED" || echo "❌ FAILED")

### Quality Checks
- Static Analysis: $([ -f "${REPORT_DIR}/Lua_Static_Analysis.log" ] && echo "✅ PASSED" || echo "❌ FAILED")
- Bundle Analysis: $([ -f "${REPORT_DIR}/Frontend_Bundle_Analysis.log" ] && echo "✅ PASSED" || echo "❌ FAILED")

### Security Audits
- Backend Security: $([ -f "${REPORT_DIR}/Backend_Security_Audit.log" ] && echo "✅ PASSED" || echo "❌ FAILED")
- Frontend Dependencies: $([ -f "${REPORT_DIR}/Frontend_Dependency_Audit.log" ] && echo "✅ PASSED" || echo "❌ FAILED")

## Detailed Logs

All detailed logs are available in: \`${REPORT_DIR}\`

## Recommendations

EOF

# Add recommendations based on results
if [ $FAILED_TESTS -gt 0 ]; then
    echo "- 🔴 **Critical:** $FAILED_TESTS test(s) failed - review logs immediately" >> "$SUMMARY_FILE"
fi

if [ $WARNINGS -gt 0 ]; then
    echo "- 🟡 **Warning:** $WARNINGS check(s) produced warnings - review when possible" >> "$SUMMARY_FILE"
fi

if [ $FAILED_TESTS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "- 🟢 **Excellent:** All tests passed with no warnings!" >> "$SUMMARY_FILE"
fi

echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "*Generated by Church Management QA Pipeline*" >> "$SUMMARY_FILE"

# 8. Final Results
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}         QUALITY CHECK RESULTS          ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Tests Run: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
echo -e "${YELLOW}Warnings: ${WARNINGS}${NC}"
echo ""
echo -e "📄 Summary Report: ${SUMMARY_FILE}"
echo -e "📁 All Logs: ${REPORT_DIR}"

# Set exit code based on results
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "\n${RED}❌ Quality checks completed with failures${NC}"
    exit 1
else
    echo -e "\n${GREEN}✅ Quality checks completed successfully${NC}"
    exit 0
fi
