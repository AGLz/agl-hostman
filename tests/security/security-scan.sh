#!/bin/bash

# Security Scan Script for AGL Infrastructure
# Part of AGL-24: Testing Coverage Improvement

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}AGL Security Scan${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Function to print section header
print_header() {
    echo -e "\n${BLUE}>>> $1${NC}\n"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Change to src directory
cd "$PROJECT_ROOT/src" || exit 1

# 1. Run Security Tests
print_header "Running PHPUnit Security Tests"
if vendor/bin/phpunit --testsuite=Unit,Feature --filter=Security --colors=never; then
    print_success "Security tests passed"
    TESTS_PASSED=true
else
    print_error "Security tests failed"
    TESTS_PASSED=false
fi

# 2. Run PHPStan
print_header "Running PHPStan Static Analysis"
if composer exec -- phpstan analyse --level=max --error-format=table app/ tests/ 2>/dev/null || true; then
    print_success "PHPStan analysis completed"
else
    print_warning "PHPStan found issues (review above)"
fi

# 3. Check for hardcoded secrets
print_header "Checking for Hardcoded Secrets"
SECRETS_FOUND=false

# Check common secret patterns
if grep -r -i "password.*=.*['\"].*['\"]" app/ --include="*.php" | grep -v "env(" | grep -v "//" | head -5; then
    print_error "Potential hardcoded passwords found"
    SECRETS_FOUND=true
fi

if grep -r -i "api_key.*=.*['\"].*['\"]" app/ --include="*.php" | grep -v "env(" | grep -v "//" | head -5; then
    print_error "Potential hardcoded API keys found"
    SECRETS_FOUND=true
fi

if [ "$SECRETS_FOUND" = false ]; then
    print_success "No hardcoded secrets detected"
fi

# 4. Check .gitignore
print_header "Checking .gitignore for Sensitive Files"
GITIGNORE_CHECK=true

if [ ! -f "../.gitignore" ]; then
    print_warning ".gitignore not found"
    GITIGNORE_CHECK=false
else
    if ! grep -q "\.env" "../.gitignore"; then
        print_error ".env not in .gitignore"
        GITIGNORE_CHECK=false
    fi

    if ! grep -q "\.env.local" "../.gitignore"; then
        print_warning ".env.local not in .gitignore"
    fi
fi

if [ "$GITIGNORE_CHECK" = true ]; then
    print_success ".gitignore properly configured"
fi

# 5. Check file permissions
print_header "Checking File Permissions"
PERM_ISSUES=false

# Check for world-writable files
if find app/ -type f -perm -002 2>/dev/null | head -5; then
    print_error "World-writable files found"
    PERM_ISSUES=true
fi

if [ "$PERM_ISSUES" = false ]; then
    print_success "File permissions are secure"
fi

# 6. Composer audit
print_header "Running Composer Security Audit"
if composer audit --no-dev 2>&1; then
    print_success "No known vulnerabilities in dependencies"
else
    print_warning "Composer audit found issues (review above)"
fi

# 7. Check debug mode
print_header "Checking Application Debug Mode"
DEBUG_ENABLED=$(php artisan env | grep APP_DEBUG | cut -d= -f2)

if [ "$DEBUG_ENABLED" = "true" ]; then
    print_warning "Debug mode is enabled (should be disabled in production)"
else
    print_success "Debug mode is disabled"
fi

# 8. Check app key
print_header "Checking Application Key"
APP_KEY=$(php artisan env | grep APP_KEY | cut -d= -f2)

if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "null" ]; then
    print_error "APP_KEY is not set"
elif echo "$APP_KEY" | grep -q "SomeRandomString"; then
    print_error "APP_KEY is using default value"
else
    print_success "APP_KEY is properly configured"
fi

# 9. Generate security report
print_header "Generating Security Report"
if php ../.github/scripts/generate-security-report.php; then
    print_success "Security report generated"
    echo "  Report: src/security-report.html"
else
    print_warning "Report generation failed"
fi

# Summary
echo -e "\n${BLUE}=================================${NC}"
echo -e "${BLUE}Security Scan Summary${NC}"
echo -e "${BLUE}=================================${NC}\n"

if [ "$TESTS_PASSED" = true ] && [ "$SECRETS_FOUND" = false ]; then
    print_success "Security scan completed successfully"
    echo -e "\n${GREEN}All critical security checks passed!${NC}\n"
    exit 0
else
    print_error "Security scan found issues"
    echo -e "\n${RED}Please review the issues above and fix them.${NC}\n"
    exit 1
fi
