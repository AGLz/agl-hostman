#!/bin/bash
#
# Harbor CT182 Functionality Tests
# Tests: T-FUNC-001 through T-FUNC-010
# Version: 1.0.0
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CT_ID="182"
CT_IP="192.168.100.182"
HARBOR_URL="https://$CT_IP"
ADMIN_USER="admin"
ADMIN_PASS="Harbor12345"
TEST_PROJECT="test-project"
TEST_USER="testuser"
TEST_PASS="TestPass123!"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Logging
LOG_FILE="/tmp/harbor-ct182-func-tests-$(date +%Y%m%d-%H%M%S).log"
RESULTS_JSON="/tmp/harbor-ct182-func-tests-results.json"

echo '{"timestamp":"'$(date -Iseconds)'","tests":[]}' > "$RESULTS_JSON"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_WARNINGS++))
}

add_test_result() {
    jq --arg id "$1" --arg name "$2" --arg status "$3" --arg details "$4" \
       '.tests += [{id: $id, name: $name, status: $status, details: $details}]' \
       "$RESULTS_JSON" > "${RESULTS_JSON}.tmp" && mv "${RESULTS_JSON}.tmp" "$RESULTS_JSON"
}

# T-FUNC-001: Admin Login Authentication
test_admin_login() {
    log "Running T-FUNC-001: Admin Login Authentication"

    local response
    response=$(pct exec "$CT_ID" -- curl -sk -X POST \
        "$HARBOR_URL/c/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "principal=$ADMIN_USER&password=$ADMIN_PASS" \
        -w "%{http_code}" -o /dev/null 2>/dev/null || echo "000")

    if [ "$response" = "200" ] || [ "$response" = "302" ]; then
        log_success "Admin login successful (HTTP $response)"
        add_test_result "T-FUNC-001" "Admin Login" "PASS" "Login successful"
        return 0
    else
        log_error "Admin login failed (HTTP $response)"
        add_test_result "T-FUNC-001" "Admin Login" "FAIL" "HTTP $response"
        return 1
    fi
}

# T-FUNC-002: Project Creation
test_project_creation() {
    log "Running T-FUNC-002: Project Creation and Management"

    # Get session token
    local token
    token=$(pct exec "$CT_ID" -- curl -sk -X POST \
        "$HARBOR_URL/c/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "principal=$ADMIN_USER&password=$ADMIN_PASS" \
        -c /tmp/harbor-cookies.txt \
        -w "%{http_code}" 2>/dev/null | grep -oP '(?<=Set-Cookie: ).*' || echo "")

    # Create project via API
    local response
    response=$(pct exec "$CT_ID" -- curl -sk -X POST \
        "$HARBOR_URL/api/v2.0/projects" \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -H "Content-Type: application/json" \
        -d "{\"project_name\":\"$TEST_PROJECT\",\"public\":false}" \
        -w "%{http_code}" -o /dev/null 2>/dev/null || echo "000")

    if [ "$response" = "201" ] || [ "$response" = "409" ]; then
        log_success "Project creation/exists: $TEST_PROJECT (HTTP $response)"
        add_test_result "T-FUNC-002" "Project Creation" "PASS" "Project: $TEST_PROJECT"
        return 0
    else
        log_error "Project creation failed (HTTP $response)"
        add_test_result "T-FUNC-002" "Project Creation" "FAIL" "HTTP $response"
        return 1
    fi
}

# T-FUNC-004: Docker Image Push
test_image_push() {
    log "Running T-FUNC-004: Docker Image Push Operation"

    # Login to Harbor registry
    if pct exec "$CT_ID" -- docker login "$CT_IP" -u "$ADMIN_USER" -p "$ADMIN_PASS" &>/dev/null; then
        log_success "Docker login successful"
    else
        log_error "Docker login failed"
        add_test_result "T-FUNC-004" "Image Push" "FAIL" "Docker login failed"
        return 1
    fi

    # Pull test image
    log "Pulling test image (alpine:latest)..."
    if pct exec "$CT_ID" -- docker pull alpine:latest &>/dev/null; then
        log_success "Test image pulled: alpine:latest"
    else
        log_error "Failed to pull test image"
        add_test_result "T-FUNC-004" "Image Push" "FAIL" "Pull failed"
        return 1
    fi

    # Tag image for Harbor
    local harbor_tag="$CT_IP/$TEST_PROJECT/alpine:test"
    if pct exec "$CT_ID" -- docker tag alpine:latest "$harbor_tag" &>/dev/null; then
        log_success "Image tagged: $harbor_tag"
    else
        log_error "Failed to tag image"
        add_test_result "T-FUNC-004" "Image Push" "FAIL" "Tag failed"
        return 1
    fi

    # Push image to Harbor
    log "Pushing image to Harbor..."
    if pct exec "$CT_ID" -- docker push "$harbor_tag" &>/dev/null; then
        log_success "Image pushed successfully: $harbor_tag"
        add_test_result "T-FUNC-004" "Image Push" "PASS" "Image: $harbor_tag"
        return 0
    else
        log_error "Image push failed"
        add_test_result "T-FUNC-004" "Image Push" "FAIL" "Push failed"
        return 1
    fi
}

# T-FUNC-005: Docker Image Pull
test_image_pull() {
    log "Running T-FUNC-005: Docker Image Pull Operation"

    # Remove local image
    local harbor_tag="$CT_IP/$TEST_PROJECT/alpine:test"
    pct exec "$CT_ID" -- docker rmi "$harbor_tag" &>/dev/null || true
    pct exec "$CT_ID" -- docker rmi alpine:latest &>/dev/null || true

    # Pull from Harbor
    log "Pulling image from Harbor..."
    if pct exec "$CT_ID" -- docker pull "$harbor_tag" &>/dev/null; then
        log_success "Image pulled successfully: $harbor_tag"
        add_test_result "T-FUNC-005" "Image Pull" "PASS" "Image: $harbor_tag"
        return 0
    else
        log_error "Image pull failed"
        add_test_result "T-FUNC-005" "Image Pull" "FAIL" "Pull failed"
        return 1
    fi
}

# T-FUNC-010: API Endpoint Functionality
test_api_endpoints() {
    log "Running T-FUNC-010: API Endpoint Functionality"

    # Test system info endpoint
    local response
    response=$(pct exec "$CT_ID" -- curl -sk \
        "$HARBOR_URL/api/v2.0/systeminfo" \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -w "%{http_code}" 2>/dev/null || echo "000")

    if [ "$response" = "200" ]; then
        log_success "System info API accessible (HTTP 200)"
    else
        log_error "System info API failed (HTTP $response)"
        add_test_result "T-FUNC-010" "API Endpoints" "FAIL" "systeminfo: $response"
        return 1
    fi

    # Test projects endpoint
    response=$(pct exec "$CT_ID" -- curl -sk \
        "$HARBOR_URL/api/v2.0/projects" \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -w "%{http_code}" 2>/dev/null || echo "000")

    if [ "$response" = "200" ]; then
        log_success "Projects API accessible (HTTP 200)"
    else
        log_error "Projects API failed (HTTP $response)"
        add_test_result "T-FUNC-010" "API Endpoints" "FAIL" "projects: $response"
        return 1
    fi

    # Test health endpoint
    response=$(pct exec "$CT_ID" -- curl -sk \
        "$HARBOR_URL/api/v2.0/health" \
        -w "%{http_code}" 2>/dev/null || echo "000")

    if [ "$response" = "200" ]; then
        log_success "Health API accessible (HTTP 200)"
        add_test_result "T-FUNC-010" "API Endpoints" "PASS" "All endpoints functional"
        return 0
    else
        log_error "Health API failed (HTTP $response)"
        add_test_result "T-FUNC-010" "API Endpoints" "FAIL" "health: $response"
        return 1
    fi
}

# Generate summary
generate_summary() {
    log ""
    log "========================================="
    log "Functionality Tests Summary"
    log "========================================="
    log "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    log "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    log "Warnings: ${YELLOW}$TESTS_WARNINGS${NC}"
    log "========================================="

    jq --arg passed "$TESTS_PASSED" \
       --arg failed "$TESTS_FAILED" \
       --arg warnings "$TESTS_WARNINGS" \
       '.summary = {passed: ($passed|tonumber), failed: ($failed|tonumber), warnings: ($warnings|tonumber)}' \
       "$RESULTS_JSON" > "${RESULTS_JSON}.tmp" && mv "${RESULTS_JSON}.tmp" "$RESULTS_JSON"

    log ""
    log "Full log: $LOG_FILE"
    log "Results JSON: $RESULTS_JSON"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        log "${GREEN}✓ All functionality tests passed${NC}"
        return 0
    else
        log "${RED}✗ Some functionality tests failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    log "Starting Harbor CT182 Functionality Tests"
    log "Target: $HARBOR_URL"
    log ""

    test_admin_login || true
    test_project_creation || true
    test_image_push || true
    test_image_pull || true
    test_api_endpoints || true

    generate_summary
}

main "$@"
