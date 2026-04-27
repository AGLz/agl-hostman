#!/bin/bash

# Integration Test Setup Verification Script
# Verifies all dependencies and configurations are correct

set -e

echo "🔍 Verifying Integration Test Setup..."
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=1
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

FAILED=0

# 1. Check Node.js version
echo "📦 Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -ge 18 ]; then
        check_pass "Node.js $(node -v) installed"
    else
        check_fail "Node.js version must be 18 or higher (found $(node -v))"
    fi
else
    check_fail "Node.js is not installed"
fi

# 2. Check npm
echo ""
echo "📦 Checking npm..."
if command -v npm &> /dev/null; then
    check_pass "npm $(npm -v) installed"
else
    check_fail "npm is not installed"
fi

# 3. Check Docker (optional but recommended)
echo ""
echo "🐳 Checking Docker..."
if command -v docker &> /dev/null; then
    if docker ps &> /dev/null; then
        check_pass "Docker is installed and running"
    else
        check_warn "Docker is installed but not running (some tests will be skipped)"
    fi
else
    check_warn "Docker is not installed (Docker tests will be skipped)"
fi

# 4. Check dependencies
echo ""
echo "📚 Checking dependencies..."
if [ -f "package.json" ]; then
    check_pass "package.json found"

    if [ -d "node_modules" ]; then
        check_pass "node_modules directory exists"

        # Check critical dependencies
        DEPS=("jest" "supertest" "nock" "dockerode")
        for dep in "${DEPS[@]}"; do
            if [ -d "node_modules/$dep" ]; then
                check_pass "$dep installed"
            else
                check_fail "$dep not installed (run: npm install)"
            fi
        done
    else
        check_fail "node_modules not found (run: npm install)"
    fi
else
    check_fail "package.json not found"
fi

# 5. Check test files
echo ""
echo "🧪 Checking test files..."
TEST_FILES=(
    "tests/integration/api.test.js"
    "tests/integration/docker.test.js"
    "tests/integration/network.test.js"
    "tests/integration/health.test.js"
)

for file in "${TEST_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$(basename $file) exists"
    else
        check_fail "$(basename $file) not found"
    fi
done

# 6. Check mock files
echo ""
echo "🎭 Checking mock files..."
MOCK_FILES=(
    "tests/integration/mocks/proxmox-mock.js"
    "tests/integration/mocks/network-mock.js"
)

for file in "${MOCK_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$(basename $file) exists"
    else
        check_fail "$(basename $file) not found"
    fi
done

# 7. Check configuration files
echo ""
echo "⚙️  Checking configuration..."
CONFIG_FILES=(
    "tests/integration/jest.config.js"
    "tests/integration/setup.js"
    "tests/integration/teardown.js"
    "tests/integration/helpers/test-setup.js"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$(basename $file) exists"
    else
        check_fail "$(basename $file) not found"
    fi
done

# 8. Check documentation
echo ""
echo "📖 Checking documentation..."
DOC_FILES=(
    "tests/integration/README.md"
    "tests/integration/CI-CD-INTEGRATION.md"
    "tests/integration/MOCK-DATA.md"
    "tests/integration/PHASE-2-DELIVERABLES.md"
)

for file in "${DOC_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$(basename $file) exists"
    else
        check_fail "$(basename $file) not found"
    fi
done

# 9. Test environment variables
echo ""
echo "🔐 Checking environment..."
if [ "$NODE_ENV" = "test" ]; then
    check_pass "NODE_ENV is set to 'test'"
else
    check_warn "NODE_ENV not set to 'test' (will be set automatically)"
fi

# 10. Check test scripts in package.json
echo ""
echo "🚀 Checking test scripts..."
if grep -q "test:integration" package.json 2>/dev/null; then
    check_pass "test:integration script found in package.json"
else
    check_fail "test:integration script not found in package.json"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "You can now run the integration tests:"
    echo "  npm run test:integration"
    echo ""
    echo "Or run with coverage:"
    echo "  npm run test:integration -- --coverage"
    exit 0
else
    echo -e "${RED}❌ Some checks failed!${NC}"
    echo ""
    echo "Please fix the issues above before running tests."
    echo ""
    echo "To install dependencies:"
    echo "  npm install"
    echo ""
    echo "To start Docker:"
    echo "  sudo systemctl start docker"
    exit 1
fi
