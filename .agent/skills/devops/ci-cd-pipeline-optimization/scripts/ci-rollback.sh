#!/bin/bash
# CI Rollback Script
# Performs immediate rollback to previous deployment version
#
# Usage: ./ci-rollback.sh [options]
#   --environment ENV         Target environment: production, staging (default: production)
#   --version VERSION         Specific version to rollback to (default: previous)
#   --workflow WORKFLOW       Deployment workflow (default: cd.yml)
#   --dry-run                 Show what would be done without executing
#   --force                   Skip confirmation prompt
#   --notify                  Send rollback notification
#   --help                    Show this help

set -euo pipefail

# Default values
ENVIRONMENT="${ENVIRONMENT:-production}"
VERSION=""
WORKFLOW="${WORKFLOW:-deploy-production.yml}"
DRY_RUN=false
FORCE=false
NOTIFY=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }
log_dry() { echo -e "${CYAN}[DRY-RUN]${NC} $1"; }

# Get environment URL
get_env_url() {
    local env=$1
    case "$env" in
        production) echo "${PRODUCTION_URL:-https://prod-agl.aglz.io}" ;;
        staging) echo "${STAGING_URL:-https://staging-agl.aglz.io}" ;;
        *) echo "" ;;
    esac
}

# Get current active slot
get_active_slot() {
    local url=$1
    curl -s "$url/api/deployment/slot" 2>/dev/null || echo "blue"
}

# Rollback to previous version
rollback_deployment() {
    local env=$1
    local target_version=$2
    local url=$(get_env_url "$env")

    log_info "Initiating rollback for $env environment"

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Would rollback $env to version: $target_version"
        log_dry "Would switch traffic via load balancer"
        log_dry "Would verify health at $url"
        return 0
    fi

    # Get active slot
    ACTIVE_SLOT=$(get_active_slot "$url")
    TARGET_SLOT=$([ "$ACTIVE_SLOT" = "blue" ] && echo "green" || echo "blue")

    log_info "Current active slot: $ACTIVE_SLOT"
    log_info "Target slot: $TARGET_SLOT"

    # If target version specified, deploy that version to target slot
    if [[ -n "$target_version" && "$target_version" != "previous" ]]; then
        log_info "Deploying specific version: $target_version"

        # Trigger deployment via webhook
        WEBHOOK_URL="${env}_DOKPLOY_WEBHOOK_URL"
        if [[ -n "${!WEBHOOK_URL:-}" ]]; then
            curl -X POST "${!WEBHOOK_URL}" \
                -H "Content-Type: application/json" \
                -d "{
                    \"slot\": \"$TARGET_SLOT\",
                    \"version\": \"$target_version\",
                    \"rollback\": true
                }" 2>/dev/null || log_warn "Webhook call failed"
        fi

        # Wait for deployment
        log_info "Waiting for deployment to complete..."
        sleep 60
    else
        log_info "Using existing deployment in $TARGET_SLOT slot"
    fi

    # Switch traffic
    log_info "Switching traffic to $TARGET_SLOT slot..."

    LB_API_URL="${env}_LB_API_URL"
    LB_API_TOKEN="${env}_LB_API_TOKEN"

    if [[ -n "${!LB_API_URL:-}" && -n "${!LB_API_TOKEN:-}" ]]; then
        curl -X POST "${!LB_API_URL}/traffic/switch" \
            -H "Authorization: Bearer ${!LB_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"target\": \"$TARGET_SLOT\", \"percentage\": 100}" \
            2>/dev/null || log_error "Failed to switch traffic"
    else
        log_warn "Load balancer API not configured, manual traffic switch required"
    fi

    # Verify rollback
    log_info "Verifying rollback..."

    for i in {1..20}; do
        HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$url/health" 2>/dev/null || echo "000")

        if [[ "$HEALTH_CHECK" == "200" ]]; then
            log_info "Rollback verified - health check passed"
            return 0
        fi

        log_warn "Health check failed ($i/20): HTTP $HEALTH_CHECK"
        sleep 10
    done

    log_error "Rollback verification failed after 20 attempts"
    return 1
}

# Send notification
send_notification() {
    local env=$1
    local status=$2
    local message=$3

    if [[ "$NOTIFY" == false ]]; then
        return 0
    fi

    log_info "Sending rollback notification..."

    # Slack notification
    SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"text\": \"Rollback $status - $env\",
                \"blocks\": [
                    {
                        \"type\": \"header\",
                        \"text\": {
                            \"type\": \"plain_text\",
                            \"text\": \"🔄 Rollback $status\"
                        }
                    },
                    {
                        \"type\": \"section\",
                        \"fields\": [
                            {
                                \"type\": \"mrkdwn\",
                                \"text\": \"*Environment:*\\n$env\"
                            },
                            {
                                \"type\": \"mrkdwn\",
                                \"text\": \"*Status:*\\n$status\"
                            },
                            {
                                \"type\": \"mrkdwn\",
                                \"text\": \"*Triggered by:*\\n${USER:-unknown}\"
                            },
                            {
                                \"type\": \"mrkdwn\",
                                \"text\": \"*Timestamp:*\\n$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
                            }
                        ]
                    },
                    {
                        \"type\": \"section\",
                        \"text\": {
                            \"type\": \"mrkdwn\",
                            \"text\": \"$message\"
                        }
                    }
                ]
            }" 2>/dev/null || log_warn "Slack notification failed"
    fi

    # Email notification
    if command -v mail &> /dev/null && [[ -n "${DEPLOYMENT_EMAIL:-}" ]]; then
        echo "$message" | mail -s "Rollback $status - $env" "$DEPLOYMENT_EMAIL" 2>/dev/null || true
    fi
}

# Usage
usage() {
    grep '^#' "$0" | sed 's/^#/ /' | sed '1d; $d'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment) ENVIRONMENT="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --workflow) WORKFLOW="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        --notify) NOTIFY=true; shift ;;
        --help) usage ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(production|staging)$ ]]; then
    fatal "Invalid environment: $ENVIRONMENT (use: production, staging)"
fi

# Check dependencies
if ! command -v curl &> /dev/null; then
    fatal "curl not found"
fi

# Main rollback flow
log_info "CI Rollback Script"
log_info "Environment: $ENVIRONMENT"
log_info "Target version: ${VERSION:-previous}"
log_info "Workflow: $WORKFLOW"

# Get current state
ENV_URL=$(get_env_url "$ENVIRONMENT")

if [[ -z "$ENV_URL" ]]; then
    fatal "Could not determine URL for environment: $ENVIRONMENT"
fi

log_info "Environment URL: $ENV_URL"

# Check current health
CURRENT_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$ENV_URL/health" 2>/dev/null || echo "000")
log_info "Current health status: HTTP $CURRENT_HEALTH"

# Get available versions
log_info "Fetching available versions..."

if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
    RUNS=$(gh run list --workflow="$WORKFLOW" --limit 10 --json databaseId,conclusion,displayTitle,createdAt 2>/dev/null || echo "[]")

    if [[ "$RUNS" != "[]" ]]; then
        echo ""
        echo "Recent deployments:"
        echo "$RUNS" | jq -r '.[] | select(.conclusion == "success") | "  #\(.databaseId) | \(.displayTitle) | \(.createdAt)"' | head -5
        echo ""
    fi
fi

# Confirm rollback
if [[ "$FORCE" == false ]]; then
    echo ""
    echo -e "${YELLOW}This will rollback $ENVIRONMENT to ${VERSION:-previous version}${NC}"
    echo ""
    read -p "Continue with rollback? (yes/no): " -r
    echo

    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_info "Rollback cancelled"
        exit 0
    fi
fi

# Perform rollback
if rollback_deployment "$ENVIRONMENT" "$VERSION"; then
    log_info "Rollback completed successfully"
    send_notification "$ENVIRONMENT" "Success" "Rollback to ${VERSION:-previous} completed successfully for $ENVIRONMENT environment."
    exit 0
else
    log_error "Rollback failed"
    send_notification "$ENVIRONMENT" "Failed" "Rollback to ${VERSION:-previous} FAILED for $ENVIRONMENT environment. Manual intervention required."

    echo ""
    echo -e "${RED}Rollback failed!${NC}"
    echo "Manual steps:"
    echo "  1. Verify environment status: $ENV_URL/health"
    echo "  2. Check load balancer configuration"
    echo "  3. Review application logs"
    echo "  4. Contact on-call engineer"
    echo ""

    exit 1
fi
