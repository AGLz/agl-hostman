#!/bin/bash
################################################################################
# Deployment Script: Staging Environment
# Purpose: Deploy AGL Hostman to staging environment
# Environment: Staging (CT181 / Dokploy)
#
# Usage:
#   ./scripts/deployment/deploy-staging.sh [--skip-tests] [--version VERSION]
#
# Environment Variables Required:
#   STAGING_DOKPLOY_URL - Dokploy instance URL
#   STAGING_DOKPLOY_TOKEN - Authentication token
#   STAGING_DOMAIN - Staging domain
#
# Features:
#   - Pre-deployment health checks
#   - Optional test execution
#   - Container orchestration via Dokploy
#   - Post-deployment verification
#   - Rollback on failure
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure
set -u  # Exit on undefined variable

################################################################################
# Configuration
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="/tmp/staging-deploy-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SKIP_TESTS=false
VERSION="latest"
TIMEOUT=600  # 10 minutes
HEALTH_CHECK_RETRIES=30
HEALTH_CHECK_INTERVAL=10

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Required environment variables
STAGING_DOKPLOY_URL="${STAGING_DOKPLOY_URL:-http://192.168.0.180:3000}"
STAGING_DOKPLOY_TOKEN="${STAGING_DOKPLOY_TOKEN:-}"
STAGING_DOMAIN="${STAGING_DOMAIN:-staging-agl.aglz.io}"

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

Deploy AGL Hostman to staging environment.

OPTIONS:
    --skip-tests      Skip pre-deployment tests
    --version VERSION Deploy specific version (default: latest)
    --help            Show this help message

ENVIRONMENT VARIABLES:
    STAGING_DOKPLOY_URL      Dokploy instance URL (default: http://192.168.0.180:3000)
    STAGING_DOKPLOY_TOKEN    Authentication token (required)
    STAGING_DOMAIN           Staging domain (default: staging-agl.aglz.io)

EXAMPLES:
    $0                                    # Deploy latest version
    $0 --version v1.2.3                   # Deploy specific version
    $0 --skip-tests                       # Deploy without running tests
EOF
}

################################################################################
# Pre-flight Checks
################################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if required commands exist
    local required_commands=("curl" "jq" "docker")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        exit 1
    fi

    # Check environment variables
    if [ -z "$STAGING_DOKPLOY_TOKEN" ]; then
        log_error "STAGING_DOKPLOY_TOKEN is not set"
        exit 1
    fi

    # Check if we can reach Dokploy
    if ! curl -s -f "$STAGING_DOKPLOY_URL/health" &> /dev/null; then
        log_warning "Cannot reach Dokploy at $STAGING_DOKPLOY_URL"
    fi

    log_success "Prerequisites check passed"
}

################################################################################
# Pre-deployment Tests
################################################################################

run_pre_deployment_tests() {
    if [ "$SKIP_TESTS" = true ]; then
        log_warning "Skipping pre-deployment tests"
        return 0
    fi

    log_info "Running pre-deployment tests..."

    cd "$PROJECT_ROOT/src"

    # Run Pest tests
    log_info "Running PHP tests..."
    if ! php artisan test --parallel --no-coverage; then
        log_error "PHP tests failed"
        return 1
    fi

    # Run JavaScript tests if present
    if [ -f "$PROJECT_ROOT/package.json" ]; then
        log_info "Running JavaScript tests..."
        cd "$PROJECT_ROOT"
        if ! npm test -- --run --no-coverage; then
            log_error "JavaScript tests failed"
            return 1
        fi
    fi

    log_success "All pre-deployment tests passed"
}

################################################################################
# Docker Image Operations
################################################################################

build_or_pull_image() {
    local version="$1"

    log_info "Preparing Docker image: $version"

    # Check if image exists locally
    if docker images | grep -q "agl-hostman.*$version"; then
        log_info "Image found locally"
        return 0
    fi

    # Try to pull from registry
    local registry="harbor.aglz.io:5000"
    if docker pull "$registry/agl-hostman:$version" 2>/dev/null; then
        log_success "Pulled image from registry"
        return 0
    fi

    # Build image if not found
    log_info "Building Docker image..."
    if ! docker build -t "agl-hostman:$version" -f "$PROJECT_ROOT/src/Dockerfile" "$PROJECT_ROOT/src"; then
        log_error "Failed to build Docker image"
        return 1
    fi

    log_success "Docker image ready"
}

################################################################################
# Deployment Operations
################################################################################

trigger_dokploy_deployment() {
    local version="$1"

    log_info "Triggering Dokploy deployment..."

    local deploy_url="$STAGING_DOKPLOY_URL/api/v1/deploy"
    local response

    response=$(curl -s -X POST "$deploy_url" \
        -H "Authorization: Bearer $STAGING_DOKPLOY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"version\": \"$version\",
            \"environment\": \"staging\",
            \"project\": \"agl-hostman\"
        }")

    if [ $? -ne 0 ]; then
        log_error "Failed to trigger deployment"
        return 1
    fi

    # Parse response
    local deployment_id
    deployment_id=$(echo "$response" | jq -r '.deploymentId // empty')

    if [ -z "$deployment_id" ]; then
        log_error "Invalid response from Dokploy"
        return 1
    fi

    log_success "Deployment triggered: ID=$deployment_id"
    echo "$deployment_id"
}

wait_for_deployment() {
    local deployment_id="$1"
    local elapsed=0

    log_info "Waiting for deployment to complete..."

    while [ $elapsed -lt $TIMEOUT ]; do
        local status
        status=$(curl -s "$STAGING_DOKPLOY_URL/api/v1/deployments/$deployment_id" \
            -H "Authorization: Bearer $STAGING_DOKPLOY_TOKEN" \
            | jq -r '.status // "unknown"')

        case "$status" in
            "success")
                log_success "Deployment completed successfully"
                return 0
                ;;
            "failed"|"error")
                log_error "Deployment failed"
                return 1
                ;;
            "deploying"|"pending")
                log_info "Deployment in progress... (${elapsed}s/$TIMEOUT)"
                ;;
            *)
                log_warning "Unknown status: $status"
                ;;
        esac

        sleep $HEALTH_CHECK_INTERVAL
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
    done

    log_error "Deployment timeout after ${TIMEOUT}s"
    return 1
}

################################################################################
# Health Checks
################################################################################

run_health_checks() {
    log_info "Running post-deployment health checks..."

    local health_url="https://$STAGING_DOMAIN/api/health"
    local attempts=0

    while [ $attempts -lt $HEALTH_CHECK_RETRIES ]; do
        if curl -s -f "$health_url" > /dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi

        attempts=$((attempts + 1))
        log_info "Waiting for service to be healthy... ($attempts/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done

    log_error "Health check failed after $attempts attempts"
    return 1
}

run_smoke_tests() {
    log_info "Running smoke tests..."

    local base_url="https://$STAGING_DOMAIN"
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

    log_success "All smoke tests passed"
}

################################################################################
# Rollback Operations
################################################################################

rollback_deployment() {
    log_warning "Initiating rollback..."

    local rollback_url="$STAGING_DOKPLOY_URL/api/v1/rollback"

    if curl -s -X POST "$rollback_url" \
        -H "Authorization: Bearer $STAGING_DOKPLOY_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"environment": "staging"}'; then
        log_success "Rollback triggered"
    else
        log_error "Rollback failed"
    fi
}

################################################################################
# Main Deployment Flow
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --version)
                VERSION="$2"
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

    log_info "Starting staging deployment..."
    log_info "Version: $VERSION"
    log_info "Domain: $STAGING_DOMAIN"
    log_info "Skip tests: $SKIP_TESTS"

    # Pre-flight checks
    check_prerequisites

    # Run tests
    if ! run_pre_deployment_tests; then
        log_error "Pre-deployment tests failed, aborting"
        exit 1
    fi

    # Prepare image
    if ! build_or_pull_image "$VERSION"; then
        log_error "Failed to prepare image"
        exit 1
    fi

    # Trigger deployment
    local deployment_id
    if ! deployment_id=$(trigger_dokploy_deployment "$VERSION"); then
        log_error "Failed to trigger deployment"
        exit 1
    fi

    # Wait for deployment
    if ! wait_for_deployment "$deployment_id"; then
        log_error "Deployment failed"
        rollback_deployment
        exit 1
    fi

    # Health checks
    if ! run_health_checks; then
        log_error "Health checks failed"
        rollback_deployment
        exit 1
    fi

    # Smoke tests
    if ! run_smoke_tests; then
        log_error "Smoke tests failed"
        rollback_deployment
        exit 1
    fi

    log_success "Staging deployment completed successfully!"
    log_info "Access at: https://$STAGING_DOMAIN"
}

# Run main function
main "$@"
