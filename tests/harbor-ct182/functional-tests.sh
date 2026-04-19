#!/bin/bash
#
# Harbor CT182 Functional Testing Script
# Tests core Harbor registry features and operations
#
# Usage: ./functional-tests.sh --harbor-ip 192.168.1.182 --admin-password [PASSWORD] [--json]
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HARBOR_IP="192.168.1.182"
ADMIN_USER="admin"
ADMIN_PASSWORD=""
JSON_OUTPUT=false
TEST_RESULTS=()
FAILED_TESTS=()
PASSED_TESTS=()
TEST_PROJECT="test-project-$$"
TEST_IMAGE="alpine:latest"
CLEANUP=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --harbor-ip)
            HARBOR_IP="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --harbor-ip IP --admin-password PASS [--json] [--no-cleanup]"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}ERROR: --admin-password is required${NC}"
    exit 1
fi

HARBOR_URL="https://$HARBOR_IP"

# Test result tracking
log_test() {
    local test_id="$1"
    local test_name="$2"
    local result="$3"
    local message="$4"

    TEST_RESULTS+=("{\"id\":\"$test_id\",\"name\":\"$test_name\",\"result\":\"$result\",\"message\":\"$(echo "$message" | sed 's/"/\\"/g')\"}")

    if [ "$result" = "PASS" ]; then
        PASSED_TESTS+=("$test_id")
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓ $test_id: $test_name - PASS${NC}"
            [ -n "$message" ] && echo -e "  ${BLUE}→ $message${NC}"
        fi
    else
        FAILED_TESTS+=("$test_id")
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗ $test_id: $test_name - FAIL${NC}"
            echo -e "  ${RED}→ $message${NC}"
        fi
    fi
}

# Cleanup function
cleanup() {
    if [ "$CLEANUP" = true ]; then
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "\n${YELLOW}Cleaning up test resources...${NC}"
        fi

        # Delete test project
        curl -k -s -X DELETE "$HARBOR_URL/api/v2.0/projects/$TEST_PROJECT" \
            -u "$ADMIN_USER:$ADMIN_PASSWORD" &>/dev/null || true

        # Logout from Docker
        docker logout "$HARBOR_IP" &>/dev/null || true
    fi
}

trap cleanup EXIT

# Start functional tests
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}Harbor CT182 Functional Testing${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "Harbor URL: ${GREEN}$HARBOR_URL${NC}"
    echo -e "Test Project: ${GREEN}$TEST_PROJECT${NC}"
    echo -e "Timestamp: ${GREEN}$(date -u +"%Y-%m-%dT%H:%M:%SZ")${NC}"
    echo -e "${BLUE}================================================${NC}"
fi

# T-FUNC-001: Admin Login Authentication
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}=== Phase 1: Authentication ===${NC}\n"
fi

# Test API authentication
AUTH_RESPONSE=$(curl -k -s -o /dev/null -w '%{http_code}' -X POST \
    "$HARBOR_URL/api/v2.0/users/current" \
    -u "$ADMIN_USER:$ADMIN_PASSWORD" 2>/dev/null || echo "000")

if [ "$AUTH_RESPONSE" = "200" ]; then
    log_test "T-FUNC-001a" "Admin API authentication" "PASS" "Successfully authenticated via API"
else
    log_test "T-FUNC-001a" "Admin API authentication" "FAIL" "Authentication failed (HTTP $AUTH_RESPONSE)"
fi

# Test web UI login (check login page accessibility)
UI_RESPONSE=$(curl -k -s -o /dev/null -w '%{http_code}' "$HARBOR_URL/c/login" 2>/dev/null || echo "000")
if [ "$UI_RESPONSE" = "200" ]; then
    log_test "T-FUNC-001b" "Web UI login page" "PASS" "Login page accessible"
else
    log_test "T-FUNC-001b" "Web UI login page" "FAIL" "Login page not accessible (HTTP $UI_RESPONSE)"
fi

# T-FUNC-002: Project Creation and Management
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}=== Phase 2: Project Management ===${NC}\n"
fi

# Create test project
CREATE_RESPONSE=$(curl -k -s -o /dev/null -w '%{http_code}' -X POST \
    "$HARBOR_URL/api/v2.0/projects" \
    -u "$ADMIN_USER:$ADMIN_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{\"project_name\":\"$TEST_PROJECT\",\"public\":false}" 2>/dev/null || echo "000")

if [ "$CREATE_RESPONSE" = "201" ]; then
    log_test "T-FUNC-002a" "Create project" "PASS" "Project '$TEST_PROJECT' created successfully"
elif [ "$CREATE_RESPONSE" = "409" ]; then
    log_test "T-FUNC-002a" "Create project" "PASS" "Project already exists (acceptable)"
else
    log_test "T-FUNC-002a" "Create project" "FAIL" "Failed to create project (HTTP $CREATE_RESPONSE)"
fi

# List projects
PROJECT_LIST=$(curl -k -s "$HARBOR_URL/api/v2.0/projects?name=$TEST_PROJECT" \
    -u "$ADMIN_USER:$ADMIN_PASSWORD" 2>/dev/null || echo "[]")

if echo "$PROJECT_LIST" | jq -e '. | length > 0' &>/dev/null; then
    log_test "T-FUNC-002b" "List projects" "PASS" "Successfully retrieved project list"
else
    log_test "T-FUNC-002b" "List projects" "FAIL" "Failed to retrieve projects"
fi

# Get project details
PROJECT_DETAILS=$(curl -k -s "$HARBOR_URL/api/v2.0/projects/$TEST_PROJECT" \
    -u "$ADMIN_USER:$ADMIN_PASSWORD" 2>/dev/null || echo "{}")

if echo "$PROJECT_DETAILS" | jq -e '.name' &>/dev/null; then
    log_test "T-FUNC-002c" "Get project details" "PASS" "Retrieved project details"
else
    log_test "T-FUNC-002c" "Get project details" "FAIL" "Failed to get project details"
fi

# T-FUNC-004: Docker Image Push Operation
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}=== Phase 3: Image Push Operations ===${NC}\n"
fi

# Pull test image from Docker Hub
if docker pull "$TEST_IMAGE" &>/dev/null; then
    log_test "T-FUNC-004a" "Pull test image" "PASS" "Successfully pulled $TEST_IMAGE from Docker Hub"
else
    log_test "T-FUNC-004a" "Pull test image" "FAIL" "Failed to pull $TEST_IMAGE"
fi

# Tag image for Harbor
HARBOR_IMAGE="$HARBOR_IP/$TEST_PROJECT/alpine:test"
if docker tag "$TEST_IMAGE" "$HARBOR_IMAGE" &>/dev/null; then
    log_test "T-FUNC-004b" "Tag image for Harbor" "PASS" "Tagged image as $HARBOR_IMAGE"
else
    log_test "T-FUNC-004b" "Tag image for Harbor" "FAIL" "Failed to tag image"
fi

# Docker login to Harbor
if echo "$ADMIN_PASSWORD" | docker login "$HARBOR_IP" -u "$ADMIN_USER" --password-stdin &>/dev/null; then
    log_test "T-FUNC-004c" "Docker login to Harbor" "PASS" "Successfully logged in via Docker CLI"
else
    log_test "T-FUNC-004c" "Docker login to Harbor" "FAIL" "Docker login failed"
fi

# Push image to Harbor
if docker push "$HARBOR_IMAGE" &>/dev/null; then
    log_test "T-FUNC-004d" "Push image to Harbor" "PASS" "Successfully pushed image to Harbor"
else
    log_test "T-FUNC-004d" "Push image to Harbor" "FAIL" "Failed to push image"
fi

# Verify image in Harbor via API
sleep 2  # Wait for Harbor to index the image
REPO_LIST=$(curl -k -s "$HARBOR_URL/api/v2.0/projects/$TEST_PROJECT/repositories" \
    -u "$ADMIN_USER:$ADMIN_PASSWORD" 2>/dev/null || echo "[]")

if echo "$REPO_LIST" | jq -e '. | length > 0' &>/dev/null; then
    log_test "T-FUNC-004e" "Verify image in UI" "PASS" "Image visible in Harbor repository list"
else
    log_test "T-FUNC-004e" "Verify image in UI" "FAIL" "Image not found in repository list"
fi

# T-FUNC-005: Docker Image Pull Operation
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}=== Phase 4: Image Pull Operations ===${NC}\n"
fi

# Remove local image
docker rmi "$HARBOR_IMAGE" &>/dev/null || true

# Pull image from Harbor
if docker pull "$HARBOR_IMAGE" &>/dev/null; then
    log_test "T-FUNC-005a" "Pull image from Harbor" "PASS" "Successfully pulled image from Harbor"
else
    log_test "T-FUNC-005a" "Pull image from Harbor" "FAIL" "Failed to pull image from Harbor"
fi

# Verify pulled image
if docker images "$HARBOR_IMAGE" | grep -q "test"; then
    log_test "T-FUNC-005b" "Verify pulled image" "PASS" "Image available locally after pull"
else
    log_test "T-FUNC-005b" "Verify pulled image" "FAIL" "Image not found after pull"
fi

# T-FUNC-006: Image Scanning Functionality
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}=== Phase 5: Vulnerability Scanning ===${NC}\n"
fi

# Trigger scan
SCAN_RESPONSE=$(curl -k -s -o /dev/null -w '%{http_code}' -X POST \
    "$HARBOR_URL/api/v2.0/projects/$TEST_PROJECT/repositories/alpine/artifacts/test/scan" \
    -u "$ADMIN_USER:$ADMIN_PASSWORD" 2>/dev/null || echo "000")

if [ "$SCAN_RESPONSE" = "202" ] || [ "$SCAN_RESPONSE" = "201" ]; then
    log_test "T-FUNC-006a" "Trigger vulnerability scan" "PASS" "Scan initiated successfully"
else
    log_test "T-FUNC-006a" "Trigger vulnerability scan" "FAIL" "Failed to trigger scan (HTTP $SCAN_RESPONSE)"
fi

# Wait for scan to complete (max 30 seconds)
SCAN_COMPLETE=false
for i in {1..30}; do
    SCAN_STATUS=$(curl -k -s "$HARBOR_URL/api/v2.0/projects/$TEST_PROJECT/repositories/alpine/artifacts/test" \
        -u "$ADMIN_USER:$ADMIN_PASSWORD" 2>/dev/null || echo "{}")

    if echo "$SCAN_STATUS" | jq -e '.scan_overview' &>/dev/null; then
        SCAN_COMPLETE=true
        break
    fi
    sleep 1
done

if [ "$SCAN_COMPLETE" = true ]; then
    log_test "T-FUNC-006b" "Scan completion" "PASS" "Vulnerability scan completed"
else
    log_test "T-FUNC-006b" "Scan completion" "FAIL" "Scan did not complete within 30 seconds"
fi

# T-FUNC-010: API Endpoint Functionality
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}=== Phase 6: API Endpoints ===${NC}\n"
fi

# Test system info endpoint
SYSINFO_RESPONSE=$(curl -k -s -o /dev/null -w '%{http_code}' \
    "$HARBOR_URL/api/v2.0/systeminfo" 2>/dev/null || echo "000")

if [ "$SYSINFO_RESPONSE" = "200" ]; then
    log_test "T-FUNC-010a" "System info API" "PASS" "System info endpoint accessible"
else
    log_test "T-FUNC-010a" "System info API" "FAIL" "System info endpoint failed (HTTP $SYSINFO_RESPONSE)"
fi

# Test statistics endpoint
STATS_RESPONSE=$(curl -k -s -o /dev/null -w '%{http_code}' \
    "$HARBOR_URL/api/v2.0/statistics" \
    -u "$ADMIN_USER:$ADMIN_PASSWORD" 2>/dev/null || echo "000")

if [ "$STATS_RESPONSE" = "200" ]; then
    log_test "T-FUNC-010b" "Statistics API" "PASS" "Statistics endpoint accessible"
else
    log_test "T-FUNC-010b" "Statistics API" "FAIL" "Statistics endpoint failed (HTTP $STATS_RESPONSE)"
fi

# Generate summary
TOTAL_TESTS=${#TEST_RESULTS[@]}
PASSED_COUNT=${#PASSED_TESTS[@]}
FAILED_COUNT=${#FAILED_TESTS[@]}

if [ "$JSON_OUTPUT" = true ]; then
    # JSON output
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"harbor_url\": \"$HARBOR_URL\","
    echo "  \"test_project\": \"$TEST_PROJECT\","
    echo "  \"total_tests\": $TOTAL_TESTS,"
    echo "  \"passed\": $PASSED_COUNT,"
    echo "  \"failed\": $FAILED_COUNT,"
    echo "  \"pass_rate\": \"$((PASSED_COUNT * 100 / TOTAL_TESTS))%\","
    echo "  \"overall_result\": \"$([ $FAILED_COUNT -eq 0 ] && echo 'PASS' || echo 'FAIL')\","
    echo "  \"tests\": ["
    for i in "${!TEST_RESULTS[@]}"; do
        echo "    ${TEST_RESULTS[$i]}$([ $i -lt $((${#TEST_RESULTS[@]} - 1)) ] && echo ',')"
    done
    echo "  ]"
    echo "}"
else
    # Human-readable output
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}Functional Testing Summary${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_COUNT${NC}"
    echo -e "Failed: ${RED}$FAILED_COUNT${NC}"
    echo -e "Pass Rate: ${BLUE}$((PASSED_COUNT * 100 / TOTAL_TESTS))%${NC}"

    if [ $FAILED_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}✓ All functional tests PASSED${NC}"
        echo -e "${GREEN}Harbor is fully functional and ready for use${NC}"
        EXIT_CODE=0
    else
        echo -e "\n${RED}✗ Some functional tests FAILED${NC}"
        echo -e "${YELLOW}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}• $test${NC}"
        done
        EXIT_CODE=1
    fi
    echo -e "${BLUE}================================================${NC}"
fi

exit ${EXIT_CODE:-0}
