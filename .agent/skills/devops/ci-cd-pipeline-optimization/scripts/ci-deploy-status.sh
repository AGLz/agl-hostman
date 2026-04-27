#!/bin/bash
# CI Deployment Status Checker
# Checks deployment status across all environments and verifies health
#
# Usage: ./ci-deploy-status.sh [options]
#   --environment ENV         Target environment: all, staging, production (default: all)
#   --workflow WORKFLOW       Workflow to check (default: cd.yml)
#   --verbose                 Show detailed health check results
#   --watch                   Continuously monitor status
#   --interval SECONDS        Watch interval in seconds (default: 30)
#   --json                    Output JSON format
#   --help                    Show this help

set -euo pipefail

# Default values
ENVIRONMENT="${ENVIRONMENT:-all}"
WORKFLOW="${WORKFLOW:-cd.yml}"
VERBOSE=false
WATCH=false
INTERVAL=30
OUTPUT_JSON=false

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

# Health check function
check_health() {
    local url=$1
    local timeout=${2:-5}

    if command -v curl &> /dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
        RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time "$timeout" "$url" 2>/dev/null || echo "0")

        if [[ "$HTTP_CODE" == "200" ]]; then
            echo "healthy|$RESPONSE_TIME"
        elif [[ "$HTTP_CODE" == "000" ]]; then
            echo "unreachable|0"
        else
            echo "unhealthy|$HTTP_CODE"
        fi
    else
        echo "unknown|0"
    fi
}

# Get deployment info from workflow
get_deployment_info() {
    local env=$1
    local env_upper=$(echo "$env" | tr '[:lower:]' '[:upper:]')

    # Try to get URL from environment variables or config
    case "$env" in
        staging)
            echo "${STAGING_URL:-https://staging-agl.aglz.io}"
            ;;
        production)
            echo "${PRODUCTION_URL:-https://prod-agl.aglz.io}"
            ;;
        uat)
            echo "${UAT_URL:-https://uat-agl.aglz.io}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Format status
format_status() {
    local status=$1
    case "$status" in
        healthy) echo -e "${GREEN}HEALTHY${NC}" ;;
        unhealthy) echo -e "${RED}UNHEALTHY${NC}" ;;
        unreachable) echo -e "${RED}UNREACHABLE${NC}" ;;
        deploying) echo -e "${YELLOW}DEPLOYING${NC}" ;;
        failed) echo -e "${RED}FAILED${NC}" ;;
        *) echo -e "${CYAN}UNKNOWN${NC}" ;;
    esac
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
        --workflow) WORKFLOW="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --watch) WATCH=true; shift ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --json) OUTPUT_JSON=true; shift ;;
        --help) usage ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Check dependencies
if ! command -v gh &> /dev/null; then
    fatal "gh CLI not found. Install: https://cli.github.com/"
fi

if ! command -v curl &> /dev/null; then
    fatal "curl not found"
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    fatal "Not authenticated with GitHub. Run: gh auth login"
fi

# Environments to check
if [[ "$ENVIRONMENT" == "all" ]]; then
    ENVIRONMENTS=(staging production)
else
    ENVIRONMENTS=("$ENVIRONMENT")
fi

# Main loop for watch mode
while true; do
    clear 2>/dev/null || true

    # Output JSON
    if [[ "$OUTPUT_JSON" == true ]]; then
        JSON_OUTPUT="{"
        JSON_OUTPUT+="\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        JSON_OUTPUT+="\"environments\":["

        FIRST=true
        for env in "${ENVIRONMENTS[@]}"; do
            if [[ "$FIRST" == false ]]; then
                JSON_OUTPUT+=","
            fi
            FIRST=false

            URL=$(get_deployment_info "$env")
            if [[ -n "$URL" ]]; then
                HEALTH_RESULT=$(check_health "$URL")
                STATUS=$(echo "$HEALTH_RESULT" | cut -d'|' -f1)
                METRIC=$(echo "$HEALTH_RESULT" | cut -d'|' -f2)

                JSON_OUTPUT+="{"
                JSON_OUTPUT+="\"name\":\"$env\","
                JSON_OUTPUT+="\"url\":\"$URL\","
                JSON_OUTPUT+="\"status\":\"$STATUS\","
                JSON_OUTPUT+="\"response_time\":$METRIC"
                JSON_OUTPUT+="}"
            fi
        done

        JSON_OUTPUT+="]}"
        echo "$JSON_OUTPUT"

        if [[ "$WATCH" == false ]]; then
            exit 0
        fi

        sleep "$INTERVAL"
        continue
    fi

    # Table output
    echo -e "${BOLD}Deployment Status - $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""

    printf "${BOLD}%-15s %-40s %-15s %-15s${NC}\n" "Environment" "URL" "Status" "Response"
    printf "%s\n" "────────────────────────────────────────────────────────────────────────"

    for env in "${ENVIRONMENTS[@]}"; do
        URL=$(get_deployment_info "$env")

        if [[ -z "$URL" ]]; then
            printf "%-15s %-40s %-15s\n" "$env" "Not configured" "${YELLOW}N/A${NC}"
            continue
        fi

        HEALTH_RESULT=$(check_health "$URL")
        STATUS=$(echo "$HEALTH_RESULT" | cut -d'|' -f1)
        METRIC=$(echo "$HEALTH_RESULT" | cut -d'|' -f2)

        # Format response time/HTTP code
        if [[ "$STATUS" == "healthy" ]]; then
            RESPONSE="${METRIC}s"
        else
            RESPONSE="HTTP $METRIC"
        fi

        printf "%-15s %-40s %-15s %-15s\n" \
            "$env" \
            "$URL" \
            "$(format_status "$STATUS")" \
            "$RESPONSE"

        # Verbose output
        if [[ "$VERBOSE" == true ]]; then
            echo ""
            echo "  Details for $env:"

            # Get recent deployment runs
            RUN_INFO=$(gh run list --workflow="$WORKFLOW" --limit 5 --json databaseId,conclusion,createdAt,displayTitle 2>/dev/null || echo "[]")

            if [[ -n "$RUN_INFO" && "$RUN_INFO" != "[]" ]]; then
                echo "  Recent deployments:"
                echo "$RUN_INFO" | jq -r '.[] | "    • \(.displayTitle) - \(.conclusion // "running") (\(.createdAt))"' | head -3
            fi

            # Get version info if healthy
            if [[ "$STATUS" == "healthy" ]]; then
                VERSION=$(curl -s "$URL/api/version" 2>/dev/null || echo "unknown")
                if [[ "$VERSION" != "unknown" ]]; then
                    echo "  Version: $VERSION"
                fi
            fi

            echo ""
        fi
    done

    echo ""
    echo "Legend: $(format_status healthy) = 200 OK, $(format_status unhealthy) = Non-200, $(format_status unreachable) = Connection failed"

    # Check workflow status
    echo ""
    echo -e "${BOLD}Recent Workflow Activity:${NC}"

    # Get recent deployments
    RUNS=$(gh run list --workflow="$WORKFLOW" --limit 3 --json databaseId,conclusion,createdAt,event,displayTitle 2>/dev/null || echo "[]")

    if [[ "$RUNS" != "[]" ]]; then
        echo "$RUNS" | jq -r '.[] | "  #\(.databaseId) | \(.displayTitle) | \(.conclusion // "running") | \(.createdAt)"' 2>/dev/null || \
        echo "$RUNS" | jq -r '.[] | "#\(.databaseId) | \(.displayTitle) | \(.conclusion // "running")"' 2>/dev/null
    fi

    # Exit if not watching
    if [[ "$WATCH" == false ]]; then
        exit 0
    fi

    echo ""
    echo "Refreshing every ${INTERVAL}s... (Ctrl+C to exit)"
    sleep "$INTERVAL"
done
