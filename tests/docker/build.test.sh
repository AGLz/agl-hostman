#!/bin/bash
# Docker Build Tests
# Tests for Docker image builds and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Change to project root
cd "$(dirname "$0")/../.."

echo "=========================================="
echo "Docker Build Tests"
echo "=========================================="
echo ""

# Test 1: Check Dockerfile exists
info "Test 1: Checking if production Dockerfile exists..."
if [ -f "docker/production/Dockerfile" ]; then
    pass "Production Dockerfile exists"
else
    fail "Production Dockerfile not found"
fi

# Test 2: Check dev Dockerfile exists
info "Test 2: Checking if development Dockerfile exists..."
if [ -f "docker/development/Dockerfile.dev" ]; then
    pass "Development Dockerfile exists"
else
    fail "Development Dockerfile not found"
fi

# Test 3: Check docker-compose.yml exists
info "Test 3: Checking if docker-compose.yml exists..."
if [ -f "docker-compose.yml" ]; then
    pass "docker-compose.yml exists"
else
    fail "docker-compose.yml not found"
fi

# Test 4: Check .dockerignore exists
info "Test 4: Checking if .dockerignore exists..."
if [ -f ".dockerignore" ]; then
    pass ".dockerignore exists"
else
    fail ".dockerignore not found"
fi

# Test 5: Validate docker-compose syntax
info "Test 5: Validating docker-compose.yml syntax..."
if docker-compose config > /dev/null 2>&1; then
    pass "docker-compose.yml syntax is valid"
else
    fail "docker-compose.yml syntax validation failed"
fi

# Test 6: Check if production Dockerfile uses multi-stage build
info "Test 6: Checking multi-stage build in production Dockerfile..."
if grep -q "FROM.*AS builder" docker/production/Dockerfile && \
   grep -q "FROM.*AS production" docker/production/Dockerfile; then
    pass "Production Dockerfile uses multi-stage build"
else
    fail "Production Dockerfile missing multi-stage build"
fi

# Test 7: Check if production Dockerfile creates non-root user
info "Test 7: Checking non-root user in production Dockerfile..."
if grep -q "adduser" docker/production/Dockerfile && \
   grep -q "USER appuser" docker/production/Dockerfile; then
    pass "Production Dockerfile creates non-root user"
else
    fail "Production Dockerfile missing non-root user"
fi

# Test 8: Check if health check is defined
info "Test 8: Checking health check in production Dockerfile..."
if grep -q "HEALTHCHECK" docker/production/Dockerfile; then
    pass "Production Dockerfile includes health check"
else
    fail "Production Dockerfile missing health check"
fi

# Test 9: Check if package.json exists
info "Test 9: Checking if package.json exists..."
if [ -f "package.json" ]; then
    pass "package.json exists"
else
    fail "package.json not found"
fi

# Test 10: Check if config directory exists
info "Test 10: Checking if config directory exists..."
if [ -d "config" ]; then
    pass "config directory exists"
else
    fail "config directory not found"
fi

# Test 11: Try building production image (dry run)
info "Test 11: Testing production Docker build (dry run)..."
if docker build -f docker/production/Dockerfile --target builder -t agl-hostman:test-builder . > /dev/null 2>&1; then
    pass "Production Docker build succeeded (builder stage)"
    # Clean up test image
    docker rmi agl-hostman:test-builder > /dev/null 2>&1 || true
else
    fail "Production Docker build failed (builder stage)"
fi

# Test 12: Check if .env.example exists
info "Test 12: Checking if .env.example exists..."
if [ -f ".env.example" ]; then
    pass ".env.example exists"
else
    fail ".env.example not found"
fi

# Test 13: Check if required environment variables are documented
info "Test 13: Checking required environment variables in .env.example..."
REQUIRED_VARS=("NODE_ENV" "PORT" "PROXMOX_HOST" "PROXMOX_TOKEN_ID")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^$var=" .env.example; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -eq 0 ]; then
    pass "All required environment variables documented"
else
    fail "Missing environment variables: ${MISSING_VARS[*]}"
fi

# Test 14: Check if documentation exists
info "Test 14: Checking if Docker deployment documentation exists..."
if [ -f "docs/DOCKER-DEPLOYMENT.md" ]; then
    pass "Docker deployment documentation exists"
else
    fail "Docker deployment documentation not found"
fi

# Test 15: Check if Dokploy config exists
info "Test 15: Checking if Dokploy configuration exists..."
if [ -f "config/dokploy.json" ]; then
    pass "Dokploy configuration exists"
else
    fail "Dokploy configuration not found"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
