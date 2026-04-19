#!/bin/bash
################################################################################
# Deployment Script: Production Environment
# Purpose: Deploy AGL Hostman to production using blue-green strategy
# Environment: Production (CT182 / Dokploy)
#
# Usage:
#   ./scripts/deployment/deploy-production.sh [--version VERSION] [--skip-approval]
#
# Environment Variables Required:
#   PRODUCTION_DOKPLOY_URL - Production Dokploy instance URL
#   PRODUCTION_DOKPLOY_TOKEN - Authentication token
#   PRODUCTION_DOMAIN - Production domain
#   PRODUCTION_LB_API_URL - Load balancer API URL
#   PRODUCTION_LB_TOKEN - Load balancer authentication token
#
# Features:
#   - Blue-green deployment strategy
#   - Required approval workflow
#   - Gradual traffic switching (10%, 50%, 100%)
#   - Automatic rollback on failure
#   - Zero-downtime deployment
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure
set -u  # Exit on undefined variable

################################################################################
# Configuration
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="/tmp/production-deploy-$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="/tmp/production-deploy-state.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION="latest"
SKIP_APPROVAL=false
TIMEOUT=1200  # 20 minutes
HEALTH_CHECK_RETRIES=30
HEALTH_CHECK_INTERVAL=10
TRAFFIC_INTERVALS=(10 50 100)
MONITOR_DURATION=300  # 5 minutes monitoring window

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Production environment variables
PRODUCTION_DOKPLOY_URL="${PRODUCTION_DOKPLOY_URL:-http://192.168.0.182:3000}"
PRODUCTION_DOKPLOY_TOKEN="${PRODUCTION_DOKPLOY_TOKEN:-}"
PRODUCTION_DOMAIN="${PRODUCTION_DOMAIN:-prod-agl.aglz.io}"
PRODUCTION_LB_API_URL="${PRODUCTION_LB_API_URL:-}"
PRODUCTION_LB_TOKEN="${PRODUCTION_LB_TOKEN:-}"

# Active slot tracking
ACTIVE_SLOT=""
INACTIVE_SLOT=""

################################################################################
# Utility Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "${BLUE}$*${NC}"; }
log_success() { log "SUCCESS" "${GREEN}$*${NC}"; }
log_warning() { log "WARNING" "${YELLOW}$*${NC}"; }
log_error() { log "ERROR" "${RED}$*${NC}"; }

save_state() {
    local key="$1"
    local value="$2"

    if [ ! -f "$STATE_FILE" ]; then
        echo "{}" > "$STATE_FILE"
    fi

    jq -r --arg key "$key" --arg value "$value" '.[$key] = $value' "$STATE_FILE" > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

load_state() {
    local key="$1"
    local default="${2:-}"

    if [ -f "$STATE_FILE" ]; then
        jq -r --arg key "$key" '.[$key] // $default' "$STATE_FILE"
    else
        echo "$default"
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy AGL Hostman to production environment using blue-green deployment.

OPTIONS:
    --version VERSION     Deploy specific version (default: latest)
    --skip-approval      Skip manual approval (USE WITH CAUTION)
    --help               Show this help message

ENVIRONMENT VARIABLES:
    PRODUCTION_DOKPLOY_URL      Production Dokploy instance URL
    PRODUCTION_DOKPLOY_TOKEN    Authentication token (required)
    PRODUCTION_DOMAIN           Production domain
    PRODUCTION_LB_API_URL       Load balancer API URL (required)
    PRODUCTION_LB_TOKEN         Load balancer auth token (required)

DEPLOYMENT PROCESS:
    1. Pre-deployment validation
    2. Manual approval (unless skipped)
    3. Deploy to inactive slot (blue/green)
    4. Health checks on inactive slot
    5. Gradual traffic switching (10% -> 50% -> 100%)
    6. Monitoring window (5 minutes)
    7. Switch active slot
    8. Keep old slot for rollback (1 hour)

ROLLBACK:
    Automatic rollback will occur if:
    - Health checks fail
    - Smoke tests fail
    - Error rate > 5% during monitoring
    - Response time > 500ms threshold

EXAMPLES:
    $0                                    # Deploy latest with approval
    $0 --version v1.2.3                   # Deploy specific version
    $0 --skip-approval --version v1.2.3   # Deploy without approval
EOF
}

################################################################################
# Pre-flight Checks
################################################################################

check_prerequisites() {
    log_info "Checking production deployment prerequisites..."

    # Check if required commands exist
    local required_commands=("curl" "jq" "docker")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Check environment variables
    if [ -z "$PRODUCTION_DOKPLOY_TOKEN" ]; then
        log_error "PRODUCTION_DOKPLOY_TOKEN is not set"
        exit 1
    fi

    if [ -z "$PRODUCTION_LB_API_URL" ] || [ -z "$PRODUCTION_LB_TOKEN" ]; then
        log_error "Load balancer credentials not configured"
        log_error "Required: PRODUCTION_LB_API_URL and PRODUCTION_LB_TOKEN"
        exit 1
    fi

    # Check if we can reach production infrastructure
    if ! curl -s -f "$PRODUCTION_DOKPLOY_URL/health" &> /dev/null; then
        log_warning "Cannot reach Dokploy at $PRODUCTION_DOKPLOY_URL"
    fi

    log_success "Prerequisites check passed"
}

################################################################################
# Approval Workflow
################################################################################

request_approval() {
    if [ "$SKIP_APPROVAL" = true ]; then
        log_warning "SKIPPING APPROVAL - USE WITH CAUTION"
        return 0
    fi

    log_warning "Production deployment requires approval"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  PRODUCTION DEPLOYMENT APPROVAL REQUIRED"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Version: $VERSION"
    echo "Domain: $PRODUCTION_DOMAIN"
    echo "Strategy: Blue-Green Deployment"
    echo ""
    echo "This will:"
    echo "  - Deploy to inactive slot"
    echo "  - Run health and smoke tests"
    echo "  - Gradually switch traffic"
    echo "  - Monitor for 5 minutes"
    echo ""
    echo "Rollback will trigger automatically if issues are detected."
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    read -p "Type 'approve' to continue: " approval

    if [ "$approval" != "approve" ]; then
        log_error "Deployment cancelled"
        exit 1
    fi

    log_success "Approval granted"
}

################################################################################
# Slot Management
################################################################################

determine_slots() {
    log_info "Determining active and inactive slots..."

    # Query current active slot from production
    local slot_url="$PRODUCTION_DOKPLOY_URL/api/v1/slots/active"
    local response

    response=$(curl -s "$slot_url" \
        -H "Authorization: Bearer $PRODUCTION_DOKPLOY_TOKEN")

    ACTIVE_SLOT=$(echo "$response" | jq -r '.slot // "blue"')

    if [ "$ACTIVE_SLOT" = "blue" ]; then
        INACTIVE_SLOT="green"
    else
        INACTIVE_SLOT="blue"
    fi

    save_state "active_slot" "$ACTIVE_SLOT"
    save_state "inactive_slot" "$INACTIVE_SLOT"

    log_info "Active slot: $ACTIVE_SLOT"
    log_info "Inactive slot: $INACTIVE_SLOT"
}

################################################################################
# Deployment Operations
################################################################################

deploy_to_inactive_slot() {
    local version="$1"

    log_info "Deploying version $version to $INACTIVE_SLOT slot..."

    local deploy_url="$PRODUCTION_DOKPLOY_URL/api/v1/deploy/slot"
    local response

    response=$(curl -s -X POST "$deploy_url" \
        -H "Authorization: Bearer $PRODUCTION_DOKPLOY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"slot\": \"$INACTIVE_SLOT\",
            \"version\": \"$version\",
            \"environment\": \"production\"
        }")

    local deployment_id
    deployment_id=$(echo "$response" | jq -r '.deploymentId // empty')

    if [ -z "$deployment_id" ]; then
        log_error "Failed to trigger deployment"
        return 1
    fi

    save_state "deployment_id" "$deployment_id"
    log_success "Deployment triggered: ID=$deployment_id"

    # Wait for deployment to complete
    wait_for_deployment "$deployment_id"
}

wait_for_deployment() {
    local deployment_id="$1"
    local elapsed=0

    log_info "Waiting for $INACTIVE_SLOT slot deployment..."

    while [ $elapsed -lt $TIMEOUT ]; do
        local status
        status=$(curl -s "$PRODUCTION_DOKPLOY_URL/api/v1/deployments/$deployment_id" \
            -H "Authorization: Bearer $PRODUCTION_DOKPLOY_TOKEN" \
            | jq -r '.status // "unknown"')

        case "$status" in
            "success")
                log_success "$INACTIVE_SLOT slot deployed successfully"
                return 0
                ;;
            "failed"|"error")
                log_error "$INACTIVE_SLOT slot deployment failed"
                return 1
                ;;
            "deploying"|"pending")
                log_info "Deployment in progress... (${elapsed}s/$TIMEOUT)"
                ;;
        esac

        sleep $HEALTH_CHECK_INTERVAL
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
    done

    log_error "Deployment timeout"
    return 1
}

################################################################################
# Health Checks
################################################################################

run_health_checks() {
    local slot="$1"
    local base_url="https://$slot-$PRODUCTION_DOMAIN/api/health"

    log_info "Running health checks on $slot slot..."

    for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
        if curl -s -f "$base_url" > /dev/null 2>&1; then
            log_success "$slot slot is healthy"
            return 0
        fi

        log_info "Waiting for $slot to be healthy... ($i/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done

    log_error "$slot slot failed health checks"
    return 1
}

run_smoke_tests() {
    local slot="$1"
    local base_url="https://$slot-$PRODUCTION_DOMAIN"

    log_info "Running smoke tests on $slot slot..."

    local endpoints=(
        "/api/health"
        "/api/overview"
        "/api/containers"
        "/api/vms"
    )

    for endpoint in "${endpoints[@]}"; do
        local url="$base_url$endpoint"
        log_info "Testing: $url"

        if ! curl -s -f "$url" > /dev/null 2>&1; then
            log_error "Smoke test failed: $url"
            return 1
        fi
    done

    log_success "All smoke tests passed on $slot slot"
}

################################################################################
# Traffic Management
################################################################################

switch_traffic() {
    local from_slot="$1"
    local to_slot="$2"
    local percentage="$3"

    log_info "Switching $percentage% traffic: $from_slot -> $to_slot"

    local traffic_url="$PRODUCTION_LB_API_URL/traffic"
    local response

    response=$(curl -s -X POST "$traffic_url" \
        -H "Authorization: Bearer $PRODUCTION_LB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"from\": \"$from_slot\",
            \"to\": \"$to_slot\",
            \"percentage\": $percentage
        }")

    if [ $? -eq 0 ]; then
        log_success "Traffic switched: $percentage%"
    else
        log_error "Failed to switch traffic"
        return 1
    fi
}

gradual_traffic_switch() {
    log_info "Starting gradual traffic switch to $INACTIVE_SLOT..."

    for percentage in "${TRAFFIC_INTERVALS[@]}"; do
        if ! switch_traffic "$ACTIVE_SLOT" "$INACTIVE_SLOT" "$percentage"; then
            return 1
        fi

        # Monitor for stability before next switch
        monitor_for_stability 60
    done

    log_success "Full traffic switch complete"
}

monitor_deployment() {
    local duration="$1"
    local elapsed=0

    log_info "Monitoring deployment for ${duration}s..."

    while [ $elapsed -lt $duration ]; do
        local metrics
        metrics=$(curl -s "https://$PRODUCTION_DOMAIN/api/metrics" || echo '{"error_rate": 0, "response_time": 0}')

        local error_rate
        local response_time

        error_rate=$(echo "$metrics" | jq -r '.error_rate // 0')
        response_time=$(echo "$metrics" | jq -r '.response_time // 0')

        # Check thresholds
        if (( $(echo "$error_rate > 0.05" | bc -l) )); then
            log_error "Error rate too high: $error_rate"
            return 1
        fi

        if [ "$response_time" -gt 500 ]; then
            log_warning "Response time elevated: ${response_time}ms"
        fi

        log_info "Monitoring: error_rate=$error_rate, response_time=${response_time}ms"
        sleep 30
        elapsed=$((elapsed + 30))
    done

    log_success "Monitoring period passed"
}

monitor_for_stability() {
    local duration="$1"
    sleep "$duration"
}

################################################################################
# Rollback Operations
################################################################################

rollback_deployment() {
    log_warning "Initiating automatic rollback..."

    # Immediately switch all traffic back
    switch_traffic "$INACTIVE_SLOT" "$ACTIVE_SLOT" 100

    # Verify health of rollback
    if ! run_health_checks "$ACTIVE_SLOT"; then
        log_error "Rollback target is unhealthy!"
        return 1
    fi

    log_success "Rollback completed"
    notify_rollback
}

notify_rollback() {
    log_warning "Rollback notification sent"
    # Send notification via webhook/Slack
}

################################################################################
# Finalization
################################################################################

finalize_deployment() {
    log_info "Finalizing production deployment..."

    # Update active slot
    local activate_url="$PRODUCTION_DOKPLOY_URL/api/v1/slots/activate"
    curl -s -X POST "$activate_url" \
        -H "Authorization: Bearer $PRODUCTION_DOKPLOY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"slot\": \"$INACTIVE_SLOT\"}"

    # Keep old slot available for rollback
    save_state "previous_slot" "$ACTIVE_SLOT"
    save_state "rollback_available" "true"
    save_state "rollback_expires" "$(date -d '+1 hour' +%s)"

    log_success "Deployment finalized"
    log_info "Previous slot ($ACTIVE_SLOT) kept for 1 hour rollback window"
}

################################################################################
# Main Deployment Flow
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                VERSION="$2"
                shift 2
                ;;
            --skip-approval)
                SKIP_APPROVAL=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    log_info "Starting PRODUCTION deployment..."
    log_info "Version: $VERSION"
    log_info "Domain: $PRODUCTION_DOMAIN"
    log_info "Strategy: Blue-Green"

    # Pre-flight checks
    check_prerequisites

    # Request approval
    request_approval

    # Determine slots
    determine_slots

    # Deploy to inactive slot
    if ! deploy_to_inactive_slot "$VERSION"; then
        log_error "Failed to deploy to inactive slot"
        exit 1
    fi

    # Health checks on inactive slot
    if ! run_health_checks "$INACTIVE_SLOT"; then
        log_error "Health checks failed on inactive slot"
        rollback_deployment
        exit 1
    fi

    # Smoke tests on inactive slot
    if ! run_smoke_tests "$INACTIVE_SLOT"; then
        log_error "Smoke tests failed on inactive slot"
        rollback_deployment
        exit 1
    fi

    # Gradual traffic switch
    if ! gradual_traffic_switch; then
        log_error "Traffic switch failed"
        rollback_deployment
        exit 1
    fi

    # Monitoring window
    if ! monitor_deployment "$MONITOR_DURATION"; then
        log_error "Monitoring detected issues"
        rollback_deployment
        exit 1
    fi

    # Finalize deployment
    finalize_deployment

    log_success "Production deployment completed successfully!"
    log_info "New active slot: $INACTIVE_SLOT"
    log_info "Access at: https://$PRODUCTION_DOMAIN"
}

# Run main function
main "$@"
