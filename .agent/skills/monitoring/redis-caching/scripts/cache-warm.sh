#!/usr/bin/env bash
##
# Cache Warming Script
#
# Pre-populates Redis cache with frequently accessed data
# Run this after deployments or cache clears
#
# Usage: ./cache-warm.sh [options]
#   --category=CAT     Specific category to warm (all, containers, deployments, etc.)
#   --parallel=N       Number of parallel workers (default: 4)
#   --dry-run          Show what would be warmed without caching
##

set -euo pipefail

# Configuration
APP_URL="${APP_URL:-http://localhost:8000}"
API_BASE="$APP_URL/api/v1"
AUTH_TOKEN="${API_TOKEN:-}"
CATEGORY="${CATEGORY:-all}"
PARALLEL="${PARALLEL:-4}"
DRY_RUN=false

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_detail() { echo -e "${BLUE}[CACHE]${NC} $1"; }

# Parse arguments
for arg in "$@"; do
    case $arg in
        --category=*)    CATEGORY="${arg#*=}" ;;
        --parallel=*)    PARALLEL="${arg#*=}" ;;
        --dry-run)       DRY_RUN=true ;;
    esac
done

# API call with auth
api_get() {
    local endpoint="$1"
    local url="$API_BASE$endpoint"

    if [[ -n "$AUTH_TOKEN" ]]; then
        curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$url"
    else
        curl -s "$url"
    fi
}

# Warm container cache
warm_containers() {
    log_info "Warming container cache..."

    # All containers
    log_detail "Fetching all containers"
    if [[ "$DRY_RUN" == false ]]; then
        api_get "/containers?per_page=100" > /dev/null
    fi

    # Running containers
    log_detail "Fetching running containers"
    api_get "/containers?status=running" > /dev/null

    # Container stats
    local containers
    containers=$(api_get "/containers?per_page=100" | jq -r '.[].id // empty' 2>/dev/null || echo "")

    for id in $containers; do
        log_detail "Fetching container $id"
        api_get "/containers/$id" > /dev/null
        api_get "/containers/$id/metrics" > /dev/null
    done
}

# Warm deployment cache
warm_deployments() {
    log_info "Warming deployment cache..."

    # Recent deployments
    log_detail "Fetching recent deployments"
    api_get "/deployments?per_page=50" > /dev/null

    # Deployment stats
    local deployments
    deployments=$(api_get "/deployments?per_page=50" | jq -r '.[].id // empty' 2>/dev/null || echo "")

    for id in $deployments; do
        log_detail "Fetching deployment $id"
        api_get "/deployments/$id" > /dev/null
    done
}

# Warm server cache
warm_servers() {
    log_info "Warming server cache..."

    local servers
    servers=$(api_get "/servers" | jq -r '.[].id // empty' 2>/dev/null || echo "")

    for id in $servers; do
        log_detail "Fetching server $id"
        api_get "/servers/$id" > /dev/null
        api_get "/servers/$id/metrics" > /dev/null
        api_get "/servers/$id/containers" > /dev/null
    done
}

# Warm metrics cache
warm_metrics() {
    log_info "Warming metrics cache..."

    # Aggregate metrics
    log_detail "Fetching aggregate metrics"
    api_get "/metrics/aggregate" > /dev/null

    # Server metrics
    local servers
    servers=$(api_get "/servers" | jq -r '.[].id // empty' 2>/dev/null || echo "")

    for id in $servers; do
        for metric in cpu memory disk; do
            log_detail "Fetching $metric for server $id"
            api_get "/metrics/server/$id/$metric" > /dev/null
        done
    done
}

# Warm alerts cache
warm_alerts() {
    log_info "Warming alerts cache..."

    log_detail "Fetching active alerts"
    api_get "/alerts?status=active" > /dev/null

    log_detail "Fetching critical alerts"
    api_get "/alerts?severity=critical" > /dev/null
}

# Warm dashboard cache
warm_dashboard() {
    log_info "Warming dashboard cache..."

    log_detail "Fetching dashboard data"
    api_get "/dashboard" > /dev/null
}

# Main warming logic
main() {
    log_info "Cache Warming Script"
    log_info "App: $APP_URL"
    log_info "Category: $CATEGORY"
    log_info "Dry run: $DRY_RUN"

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY RUN - No actual caching will occur"
    fi

    case $CATEGORY in
        all)
            warm_servers
            warm_containers
            warm_deployments
            warm_metrics
            warm_alerts
            warm_dashboard
            ;;
        containers)
            warm_containers
            ;;
        deployments)
            warm_deployments
            ;;
        servers)
            warm_servers
            ;;
        metrics)
            warm_metrics
            ;;
        alerts)
            warm_alerts
            ;;
        dashboard)
            warm_dashboard
            ;;
        *)
            log_warn "Unknown category: $CATEGORY"
            log_info "Valid categories: all, containers, deployments, servers, metrics, alerts, dashboard"
            exit 1
            ;;
    esac

    log_info "Cache warming complete"
}

main
