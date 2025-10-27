#!/bin/bash
#
# Harbor CT182 Installation Verification Script
# Tests: T-INST-001 through T-INST-006
# Version: 1.0.0
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CT_ID="182"
CT_IP="192.168.100.182"
HARBOR_VERSION="v2.9.0"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Logging
LOG_FILE="/tmp/harbor-ct182-install-verification-$(date +%Y%m%d-%H%M%S).log"
RESULTS_JSON="/tmp/harbor-ct182-install-verification-results.json"

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
    local test_id="$1"
    local test_name="$2"
    local status="$3"
    local details="$4"

    jq --arg id "$test_id" \
       --arg name "$test_name" \
       --arg status "$status" \
       --arg details "$details" \
       '.tests += [{id: $id, name: $name, status: $status, details: $details}]' \
       "$RESULTS_JSON" > "${RESULTS_JSON}.tmp" && mv "${RESULTS_JSON}.tmp" "$RESULTS_JSON"
}

# T-INST-001: Docker Engine Installation
test_docker_installation() {
    log "Running T-INST-001: Docker Engine Installation"

    # Check if Docker is installed
    if pct exec "$CT_ID" -- which docker &>/dev/null; then
        local docker_version
        docker_version=$(pct exec "$CT_ID" -- docker --version | awk '{print $3}' | sed 's/,//')
        log_success "Docker installed: $docker_version"
    else
        log_error "Docker not installed"
        add_test_result "T-INST-001" "Docker Engine Installation" "FAIL" "Docker not found"
        return 1
    fi

    # Check Docker daemon status
    if pct exec "$CT_ID" -- systemctl is-active docker &>/dev/null; then
        log_success "Docker daemon running"
    else
        log_error "Docker daemon not running"
        add_test_result "T-INST-001" "Docker Engine Installation" "FAIL" "Docker daemon not running"
        return 1
    fi

    # Test Docker functionality
    if pct exec "$CT_ID" -- docker run --rm hello-world &>/dev/null; then
        log_success "Docker hello-world test passed"
    else
        log_error "Docker hello-world test failed"
        add_test_result "T-INST-001" "Docker Engine Installation" "FAIL" "hello-world test failed"
        return 1
    fi

    add_test_result "T-INST-001" "Docker Engine Installation" "PASS" "Docker $docker_version functional"
    return 0
}

# T-INST-002: Docker Compose Installation
test_docker_compose_installation() {
    log "Running T-INST-002: Docker Compose Installation"

    # Check if Docker Compose is installed
    if pct exec "$CT_ID" -- which docker-compose &>/dev/null; then
        local compose_version
        compose_version=$(pct exec "$CT_ID" -- docker-compose --version | awk '{print $4}' | sed 's/,//')
        log_success "Docker Compose installed: $compose_version"
    else
        log_error "Docker Compose not installed"
        add_test_result "T-INST-002" "Docker Compose Installation" "FAIL" "Docker Compose not found"
        return 1
    fi

    # Verify version compatibility
    local major_version
    major_version=$(pct exec "$CT_ID" -- docker-compose --version | grep -oP '(?<=version )\d+' | head -1)
    if [ "$major_version" -ge 2 ]; then
        log_success "Docker Compose version compatible: v$major_version"
    else
        log_warning "Docker Compose version may be outdated: v$major_version"
    fi

    add_test_result "T-INST-002" "Docker Compose Installation" "PASS" "Docker Compose $compose_version functional"
    return 0
}

# T-INST-003: Harbor Download and Extraction
test_harbor_download() {
    log "Running T-INST-003: Harbor Download and Extraction"

    # Check if Harbor directory exists
    if pct exec "$CT_ID" -- test -d /opt/harbor; then
        log_success "Harbor directory exists: /opt/harbor"
    else
        log_error "Harbor directory not found: /opt/harbor"
        add_test_result "T-INST-003" "Harbor Download and Extraction" "FAIL" "Harbor directory missing"
        return 1
    fi

    # Check for key Harbor files
    local required_files=("harbor.yml" "install.sh" "prepare" "docker-compose.yml")
    local missing_files=0

    for file in "${required_files[@]}"; do
        if pct exec "$CT_ID" -- test -f "/opt/harbor/$file"; then
            log_success "Found: $file"
        else
            log_error "Missing: $file"
            ((missing_files++))
        fi
    done

    if [ "$missing_files" -gt 0 ]; then
        add_test_result "T-INST-003" "Harbor Download and Extraction" "FAIL" "$missing_files files missing"
        return 1
    fi

    add_test_result "T-INST-003" "Harbor Download and Extraction" "PASS" "All Harbor files present"
    return 0
}

# T-INST-004: Harbor Configuration Validation
test_harbor_configuration() {
    log "Running T-INST-004: Harbor Configuration Validation"

    # Check if harbor.yml exists
    if ! pct exec "$CT_ID" -- test -f /opt/harbor/harbor.yml; then
        log_error "harbor.yml not found"
        add_test_result "T-INST-004" "Harbor Configuration Validation" "FAIL" "harbor.yml missing"
        return 1
    fi

    # Validate hostname configuration
    local hostname
    hostname=$(pct exec "$CT_ID" -- grep -oP '(?<=^hostname: ).*' /opt/harbor/harbor.yml | tr -d ' ')
    if [ -n "$hostname" ]; then
        log_success "Hostname configured: $hostname"
    else
        log_error "Hostname not configured in harbor.yml"
        add_test_result "T-INST-004" "Harbor Configuration Validation" "FAIL" "Hostname not set"
        return 1
    fi

    # Validate HTTPS configuration
    if pct exec "$CT_ID" -- grep -q "^https:" /opt/harbor/harbor.yml; then
        log_success "HTTPS configuration found"

        # Check certificate paths
        local cert_path
        cert_path=$(pct exec "$CT_ID" -- grep -A2 "^https:" /opt/harbor/harbor.yml | grep certificate | awk '{print $2}')
        if pct exec "$CT_ID" -- test -f "$cert_path" 2>/dev/null; then
            log_success "SSL certificate exists: $cert_path"
        else
            log_warning "SSL certificate not found: $cert_path"
        fi
    else
        log_warning "HTTPS not configured (HTTP only)"
    fi

    # Check admin password
    if pct exec "$CT_ID" -- grep -q "^harbor_admin_password:" /opt/harbor/harbor.yml; then
        log_success "Admin password configured"
    else
        log_warning "Admin password using default"
    fi

    add_test_result "T-INST-004" "Harbor Configuration Validation" "PASS" "Configuration valid, hostname: $hostname"
    return 0
}

# T-INST-005: Harbor Service Startup
test_harbor_services() {
    log "Running T-INST-005: Harbor Service Startup"

    # Check if Harbor services are running
    local running_containers
    running_containers=$(pct exec "$CT_ID" -- docker-compose -f /opt/harbor/docker-compose.yml ps --services --filter "status=running" 2>/dev/null | wc -l || echo "0")

    if [ "$running_containers" -gt 0 ]; then
        log_success "Harbor containers running: $running_containers"
    else
        log_error "No Harbor containers running"
        add_test_result "T-INST-005" "Harbor Service Startup" "FAIL" "No containers running"
        return 1
    fi

    # Check core services
    local core_services=("harbor-core" "harbor-portal" "harbor-db" "registry" "registryctl" "harbor-jobservice")
    local missing_services=0

    for service in "${core_services[@]}"; do
        if pct exec "$CT_ID" -- docker ps | grep -q "$service"; then
            log_success "Service running: $service"
        else
            log_error "Service not running: $service"
            ((missing_services++))
        fi
    done

    if [ "$missing_services" -gt 0 ]; then
        add_test_result "T-INST-005" "Harbor Service Startup" "FAIL" "$missing_services services not running"
        return 1
    fi

    add_test_result "T-INST-005" "Harbor Service Startup" "PASS" "All core services running"
    return 0
}

# T-INST-006: Harbor Component Health Check
test_harbor_health() {
    log "Running T-INST-006: Harbor Component Health Check"

    # Wait for services to be ready
    log "Waiting for Harbor to be ready (30s)..."
    sleep 30

    # Check Harbor API health
    local health_status
    health_status=$(pct exec "$CT_ID" -- curl -sk "https://$CT_IP/api/v2.0/health" 2>/dev/null | grep -oP '(?<="status":")[^"]*' || echo "unknown")

    if [ "$health_status" = "healthy" ]; then
        log_success "Harbor API health: $health_status"
    else
        log_error "Harbor API health: $health_status"
        add_test_result "T-INST-006" "Harbor Component Health Check" "FAIL" "API health: $health_status"
        return 1
    fi

    # Check web UI accessibility
    if pct exec "$CT_ID" -- curl -sk -o /dev/null -w "%{http_code}" "https://$CT_IP/" | grep -q "200"; then
        log_success "Harbor Web UI accessible (HTTP 200)"
    else
        log_error "Harbor Web UI not accessible"
        add_test_result "T-INST-006" "Harbor Component Health Check" "FAIL" "Web UI not accessible"
        return 1
    fi

    # Check registry endpoint
    if pct exec "$CT_ID" -- curl -sk -o /dev/null -w "%{http_code}" "https://$CT_IP/v2/" | grep -q "401"; then
        log_success "Registry API accessible (HTTP 401 - auth required)"
    else
        log_warning "Registry API response unexpected"
    fi

    add_test_result "T-INST-006" "Harbor Component Health Check" "PASS" "All components healthy"
    return 0
}

# Generate summary report
generate_summary() {
    log ""
    log "========================================="
    log "Installation Verification Summary"
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
        log "${GREEN}✓ Harbor installation verified successfully${NC}"
        return 0
    else
        log "${RED}✗ Harbor installation verification failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    log "Starting Harbor CT182 Installation Verification"
    log "Target: Container $CT_ID ($CT_IP)"
    log ""

    test_docker_installation || true
    test_docker_compose_installation || true
    test_harbor_download || true
    test_harbor_configuration || true
    test_harbor_services || true
    test_harbor_health || true

    generate_summary
}

main "$@"
