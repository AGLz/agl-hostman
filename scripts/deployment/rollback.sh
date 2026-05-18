#!/bin/bash
################################################################################
# Rollback Script: Production/Staging Environments
# Purpose: Rollback deployment to previous version
# Supports: Blue-green rollback and standard version rollback
#
# Usage:
#   ./scripts/deployment/rollback.sh [--environment ENV] [--target VERSION]
#
# Environment Variables Required:
#   PRODUCTION_DOKPLOY_URL - Production Dokploy instance URL
#   PRODUCTION_DOKPLOY_TOKEN - Authentication token
#   PRODUCTION_LB_API_URL - Load balancer API URL
#   PRODUCTION_LB_TOKEN - Load balancer authentication token
#
# Features:
#   - Instant traffic switchback
#   - Health verification after rollback
#   - Rollback state tracking
#   - Notification on completion
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure
set -u  # Exit on undefined variable

################################################################################
# Configuration
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="/tmp/rollback-$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="/tmp/production-deploy-state.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="production"
TARGET_VERSION=""
HEALTH_CHECK_RETRIES=20
HEALTH_CHECK_INTERVAL=5

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Environment-specific configuration
case "$ENVIRONMENT" in
    "production")
        DOKPLOY_URL="${PRODUCTION_DOKPLOY_URL:-http://192.168.0.182:3000}"
        DOKPLOY_TOKEN="${PRODUCTION_DOKPLOY_TOKEN:-}"
        DOMAIN="${PRODUCTION_DOMAIN:-prod-agl.aglz.io}"
        LB_API_URL="${PRODUCTION_LB_API_URL:-}"
        LB_TOKEN="${PRODUCTION_LB_TOKEN:-}"
        ;;
    "staging")
        DOKPLOY_URL="${STAGING_DOKPLOY_URL:-http://192.168.0.180:3000}"
        DOKPLOY_TOKEN="${STAGING_DOKPLOY_TOKEN:-}"
        DOMAIN="${STAGING_DOMAIN:-staging-agl.aglz.io}"
        LB_API_URL=""
        LB_TOKEN=""
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

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

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Rollback deployment to previous version.

OPTIONS:
    --environment ENV   Target environment (production|staging, default: production)
    --target VERSION    Specific version to rollback to (default: previous)
    --help              Show this help message

ENVIRONMENT VARIABLES:
    For Production:
        PRODUCTION_DOKPLOY_URL      Production Dokploy instance URL
        PRODUCTION_DOKPLOY_TOKEN    Authentication token (required)
        PRODUCTION_DOMAIN           Production domain
        PRODUCTION_LB_API_URL       Load balancer API URL (required)
        PRODUCTION_LB_TOKEN         Load balancer auth token (required)

    For Staging:
        STAGING_DOKPLOY_URL         Staging Dokploy instance URL
        STAGING_DOKPLOY_TOKEN       Authentication token (required)
        STAGING_DOMAIN              Staging domain

ROLLBACK PROCESS:
    1. Verify rollback target health
    2. Switch traffic to previous version
    3. Run health checks
    4. Update deployment state
    5. Send notification

EXAMPLES:
    $0                                    # Rollback production to previous
    $0 --environment staging              # Rollback staging
    $0 --target v1.2.3 --environment prod # Rollback to specific version
EOF
}

################################################################################
# State Management
################################################################################

load_deployment_state() {
    if [ ! -f "$STATE_FILE" ]; then
        log_error "No deployment state found"
        return 1
    fi

    ACTIVE_SLOT=$(jq -r '.active_slot // "blue"' "$STATE_FILE")
    ROLLBACK_SLOT=$(jq -r '.previous_slot // "green"' "$STATE_FILE")
    ROLLBACK_AVAILABLE=$(jq -r '.rollback_available // "false"' "$STATE_FILE")

    log_info "Current active slot: $ACTIVE_SLOT"
    log_info "Rollback target: $ROLLBACK_SLOT"
    log_info "Rollback available: $ROLLBACK_AVAILABLE"
}

################################################################################
# Rollback Operations
################################################################################

verify_rollback_target() {
    local target_slot="$1"

    log_info "Verifying rollback target: $target_slot"

    local health_url="https://$target_slot-$DOMAIN/api/health"

    # Quick health check
    if ! curl -s -f "$health_url" > /dev/null 2>&1; then
        log_error "Rollback target is unhealthy"
        return 1
    fi

    log_success "Rollback target is healthy"
}

switch_traffic_to_rollback() {
    local from_slot="$1"
    local to_slot="$2"

    log_warning "Switching traffic: $from_slot -> $to_slot"

    # For production with load balancer
    if [ -n "$LB_API_URL" ] && [ -n "$LB_TOKEN" ]; then
        local traffic_url="$LB_API_URL/traffic"

        if curl -s -X POST "$traffic_url" \
            -H "Authorization: Bearer $LB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"from\": \"$from_slot\",
                \"to\": \"$to_slot\",
                \"percentage\": 100
            }"; then
            log_success "Traffic switched via load balancer"
        else
            log_error "Failed to switch traffic"
            return 1
        fi
    else
        # For staging, just restart services
        log_info "Restarting services on $to_slot slot"
        local restart_url="$DOKPLOY_URL/api/v1/slots/restart"

        curl -s -X POST "$restart_url" \
            -H "Authorization: Bearer $DOKPLOY_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"slot\": \"$to_slot\"}"

        log_success "Services restarted"
    fi
}

activate_rollback_slot() {
    local slot="$1"

    log_info "Activating $slot slot as primary"

    local activate_url="$DOKPLOY_URL/api/v1/slots/activate"

    curl -s -X POST "$activate_url" \
        -H "Authorization: Bearer $DOKPLOY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"slot\": \"$slot\"}"

    log_success "$slot slot activated"
}

################################################################################
# Health Checks
################################################################################

verify_rollback_health() {
    local base_url="https://$DOMAIN/api/health"

    log_info "Verifying rollback health..."

    for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
        if curl -s -f "$base_url" > /dev/null 2>&1; then
            log_success "Rollback verification passed"
            return 0
        fi

        log_info "Waiting for service... ($i/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done

    log_error "Rollback health check failed"
    return 1
}

run_smoke_tests() {
    local base_url="https://$DOMAIN"

    log_info "Running post-rollback smoke tests..."

    local endpoints=(
        "/api/health"
        "/api/overview"
    )

    for endpoint in "${endpoints[@]}"; do
        local url="$base_url$endpoint"
        if ! curl -s -f "$url" > /dev/null 2>&1; then
            log_error "Smoke test failed: $url"
            return 1
        fi
    done

    log_success "Smoke tests passed"
}

################################################################################
# Version Rollback (Alternative)
################################################################################

rollback_to_version() {
    local target_version="$1"

    log_info "Rolling back to version: $target_version"

    local deploy_url="$DOKPLOY_URL/api/v1/deploy/rollback"

    local response
    response=$(curl -s -X POST "$deploy_url" \
        -H "Authorization: Bearer $DOKPLOY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"version\": \"$target_version\",
            \"environment\": \"$ENVIRONMENT\"
        }")

    if [ $? -eq 0 ]; then
        log_success "Version rollback triggered"
    else
        log_error "Failed to rollback to version"
        return 1
    fi
}

################################################################################
# Notification
################################################################################

notify_rollback_complete() {
    local slot="$1"

    log_success "Rollback completed: $slot slot is now active"
    log_info "Access at: https://$DOMAIN"

    # Send notification via webhook/Slack if configured
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    if [ -n "$webhook_url" ]; then
        curl -s -X POST "$webhook_url" \
            -H "Content-Type: application/json" \
            -d "{
                \"text\": \"Rollback Completed: $ENVIRONMENT\",
                \"blocks\": [
                    {
                        \"type\": \"section\",
                        \"text\": {
                            \"type\": \"mrkdwn\",
                            \"text\": \"Rollback to $slot slot completed\"
                        }
                    }
                ]
            }" > /dev/null
    fi
}

################################################################################
# Main Rollback Flow
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --target)
                TARGET_VERSION="$2"
                shift 2
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

    log_warning "Starting ROLLBACK for $ENVIRONMENT..."

    # Check if version rollback requested
    if [ -n "$TARGET_VERSION" ]; then
        if ! rollback_to_version "$TARGET_VERSION"; then
            log_error "Version rollback failed"
            exit 1
        fi

        if ! verify_rollback_health; then
            log_error "Rollback health check failed"
            exit 1
        fi

        notify_rollback_complete "version-$TARGET_VERSION"
        exit 0
    fi

    # Load deployment state
    if ! load_deployment_state; then
        log_error "Cannot proceed with rollback without state"
        exit 1
    fi

    # Verify rollback target
    if ! verify_rollback_target "$ROLLBACK_SLOT"; then
        log_error "Cannot rollback: target unhealthy"
        exit 1
    fi

    # Switch traffic
    if ! switch_traffic_to_rollback "$ACTIVE_SLOT" "$ROLLBACK_SLOT"; then
        log_error "Traffic switch failed"
        exit 1
    fi

    # Activate rollback slot
    activate_rollback_slot "$ROLLBACK_SLOT"

    # Verify health
    if ! verify_rollback_health; then
        log_error "Rollback verification failed"
        exit 1
    fi

    # Run smoke tests
    if ! run_smoke_tests; then
        log_warning "Smoke tests failed, but rollback is active"
    fi

    # Notify completion
    notify_rollback_complete "$ROLLBACK_SLOT"
}

# Run main function
main "$@"
