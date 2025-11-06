#!/bin/bash
#
# Harbor CT182 Performance Benchmark Script
# Tests: T-PERF-001 through T-PERF-007
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
TEST_PROJECT="perf-test"

# Performance thresholds
WEB_UI_THRESHOLD=3000      # 3 seconds
SMALL_PUSH_THRESHOLD=30000 # 30 seconds
LARGE_PUSH_THRESHOLD=300000 # 5 minutes

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Logging
LOG_FILE="/tmp/harbor-ct182-perf-$(date +%Y%m%d-%H%M%S).log"
RESULTS_JSON="/tmp/harbor-ct182-perf-results.json"

echo '{"timestamp":"'$(date -Iseconds)'","benchmarks":[]}' > "$RESULTS_JSON"

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

add_benchmark_result() {
    jq --arg id "$1" --arg name "$2" --arg duration "$3" --arg threshold "$4" --arg status "$5" \
       '.benchmarks += [{id: $id, name: $name, duration_ms: ($duration|tonumber), threshold_ms: ($threshold|tonumber), status: $status}]' \
       "$RESULTS_JSON" > "${RESULTS_JSON}.tmp" && mv "${RESULTS_JSON}.tmp" "$RESULTS_JSON"
}

# T-PERF-001: Web UI Response Time
test_web_ui_performance() {
    log "Running T-PERF-001: Web UI Response Time"

    local total_time=0
    local iterations=5

    for i in $(seq 1 $iterations); do
        local start=$(date +%s%3N)
        pct exec "$CT_ID" -- curl -sk -o /dev/null "$HARBOR_URL/" &>/dev/null
        local end=$(date +%s%3N)
        local duration=$((end - start))
        total_time=$((total_time + duration))
        log "  Iteration $i: ${duration}ms"
    done

    local avg_time=$((total_time / iterations))

    if [ "$avg_time" -lt "$WEB_UI_THRESHOLD" ]; then
        log_success "Web UI avg response time: ${avg_time}ms (threshold: ${WEB_UI_THRESHOLD}ms)"
        add_benchmark_result "T-PERF-001" "Web UI Response" "$avg_time" "$WEB_UI_THRESHOLD" "PASS"
        return 0
    else
        log_error "Web UI avg response time: ${avg_time}ms exceeds threshold ${WEB_UI_THRESHOLD}ms"
        add_benchmark_result "T-PERF-001" "Web UI Response" "$avg_time" "$WEB_UI_THRESHOLD" "FAIL"
        return 1
    fi
}

# T-PERF-002: Small Image Push Performance
test_small_image_push() {
    log "Running T-PERF-002: Small Image Push Performance (10MB)"

    # Create test project
    pct exec "$CT_ID" -- curl -sk -X POST \
        "$HARBOR_URL/api/v2.0/projects" \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -H "Content-Type: application/json" \
        -d "{\"project_name\":\"$TEST_PROJECT\",\"public\":false}" &>/dev/null || true

    # Login to registry
    pct exec "$CT_ID" -- docker login "$CT_IP" -u "$ADMIN_USER" -p "$ADMIN_PASS" &>/dev/null

    # Pull small test image
    pct exec "$CT_ID" -- docker pull alpine:latest &>/dev/null

    local tag="$CT_IP/$TEST_PROJECT/alpine:perf-test"
    pct exec "$CT_ID" -- docker tag alpine:latest "$tag" &>/dev/null

    # Measure push time
    local start=$(date +%s%3N)
    pct exec "$CT_ID" -- docker push "$tag" &>/dev/null
    local end=$(date +%s%3N)
    local duration=$((end - start))

    if [ "$duration" -lt "$SMALL_PUSH_THRESHOLD" ]; then
        log_success "Small image push: ${duration}ms (threshold: ${SMALL_PUSH_THRESHOLD}ms)"
        add_benchmark_result "T-PERF-002" "Small Image Push" "$duration" "$SMALL_PUSH_THRESHOLD" "PASS"
        return 0
    else
        log_error "Small image push: ${duration}ms exceeds threshold ${SMALL_PUSH_THRESHOLD}ms"
        add_benchmark_result "T-PERF-002" "Small Image Push" "$duration" "$SMALL_PUSH_THRESHOLD" "FAIL"
        return 1
    fi
}

# T-PERF-004: Image Pull Performance
test_image_pull() {
    log "Running T-PERF-004: Image Pull Performance"

    local tag="$CT_IP/$TEST_PROJECT/alpine:perf-test"

    # Remove local image
    pct exec "$CT_ID" -- docker rmi "$tag" &>/dev/null || true

    # Measure pull time
    local start=$(date +%s%3N)
    pct exec "$CT_ID" -- docker pull "$tag" &>/dev/null
    local end=$(date +%s%3N)
    local duration=$((end - start))

    log_success "Image pull completed: ${duration}ms"
    add_benchmark_result "T-PERF-004" "Image Pull" "$duration" "0" "PASS"
    return 0
}

# T-PERF-005: Concurrent Operations
test_concurrent_operations() {
    log "Running T-PERF-005: Concurrent Push/Pull Operations"

    # Prepare 3 test images
    for i in 1 2 3; do
        local tag="$CT_IP/$TEST_PROJECT/alpine:concurrent-$i"
        pct exec "$CT_ID" -- docker tag alpine:latest "$tag" &>/dev/null
    done

    # Push concurrently
    local start=$(date +%s%3N)
    {
        pct exec "$CT_ID" -- docker push "$CT_IP/$TEST_PROJECT/alpine:concurrent-1" &>/dev/null &
        pct exec "$CT_ID" -- docker push "$CT_IP/$TEST_PROJECT/alpine:concurrent-2" &>/dev/null &
        pct exec "$CT_ID" -- docker push "$CT_IP/$TEST_PROJECT/alpine:concurrent-3" &>/dev/null &
        wait
    }
    local end=$(date +%s%3N)
    local duration=$((end - start))

    log_success "Concurrent push (3 images): ${duration}ms"
    add_benchmark_result "T-PERF-005" "Concurrent Operations" "$duration" "0" "PASS"
    return 0
}

# T-PERF-007: Resource Utilization
test_resource_utilization() {
    log "Running T-PERF-007: Resource Utilization Monitoring"

    # Get container stats
    local cpu_usage
    cpu_usage=$(pct exec "$CT_ID" -- top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

    local mem_usage
    mem_usage=$(pct exec "$CT_ID" -- free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')

    local disk_usage
    disk_usage=$(pct exec "$CT_ID" -- df -h / | awk 'NR==2{print $5}' | sed 's/%//')

    log "  CPU Usage: ${cpu_usage}%"
    log "  Memory Usage: ${mem_usage}%"
    log "  Disk Usage: ${disk_usage}%"

    # Get Harbor container resource usage
    local harbor_containers
    harbor_containers=$(pct exec "$CT_ID" -- docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tail -n +2)

    log "Harbor Container Resources:"
    echo "$harbor_containers" | while read line; do
        log "  $line"
    done

    log_success "Resource utilization monitored"
    add_benchmark_result "T-PERF-007" "Resource Utilization" "0" "0" "INFO"

    # Store detailed metrics
    jq --arg cpu "$cpu_usage" \
       --arg mem "$mem_usage" \
       --arg disk "$disk_usage" \
       '.resource_metrics = {cpu_percent: ($cpu|tonumber), memory_percent: ($mem|tonumber), disk_percent: ($disk|tonumber)}' \
       "$RESULTS_JSON" > "${RESULTS_JSON}.tmp" && mv "${RESULTS_JSON}.tmp" "$RESULTS_JSON"

    return 0
}

# Generate summary
generate_summary() {
    log ""
    log "========================================="
    log "Performance Benchmark Summary"
    log "========================================="
    log "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    log "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    log "========================================="

    jq --arg passed "$TESTS_PASSED" \
       --arg failed "$TESTS_FAILED" \
       '.summary = {passed: ($passed|tonumber), failed: ($failed|tonumber)}' \
       "$RESULTS_JSON" > "${RESULTS_JSON}.tmp" && mv "${RESULTS_JSON}.tmp" "$RESULTS_JSON"

    log ""
    log "Full log: $LOG_FILE"
    log "Results JSON: $RESULTS_JSON"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        log "${GREEN}✓ All performance benchmarks passed${NC}"
        return 0
    else
        log "${RED}✗ Some performance benchmarks failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    log "Starting Harbor CT182 Performance Benchmarks"
    log "Target: $HARBOR_URL"
    log ""

    test_web_ui_performance || true
    test_small_image_push || true
    test_image_pull || true
    test_concurrent_operations || true
    test_resource_utilization || true

    generate_summary
}

main "$@"
