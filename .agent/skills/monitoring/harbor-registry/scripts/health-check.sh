#!/usr/bin/env bash
##
# Harbor Registry Health Check Script
#
# Performs health checks on Harbor Container Registry
# Checks API connectivity, project access, and storage quotas
#
# Usage: ./health-check.sh [options]
#   --url=URL          Harbor URL (default: from HARBOR_BASE_URL)
#   --username=USER    Harbor username (default: from HARBOR_USERNAME)
#   --password=PASS    Harbor password (default: from HARBOR_PASSWORD)
#   --project=PROJ     Check specific project
#   --skip-scan        Skip vulnerability scan check
##

set -euo pipefail

# Configuration
HARBOR_URL="${HARBOR_BASE_URL:-https://harbor.aglz.io}"
HARBOR_USERNAME="${HARBOR_USERNAME:-}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
HARBOR_TIMEOUT="${HARBOR_TIMEOUT:-30}"
CHECK_PROJECT="${CHECK_PROJECT:-}"
SKIP_SCAN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_detail() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Parse arguments
for arg in "$@"; do
    case $arg in
        --url=*)        HARBOR_URL="${arg#*=}" ;;
        --username=*)   HARBOR_USERNAME="${arg#*=}" ;;
        --password=*)   HARBOR_PASSWORD="${arg#*=}" ;;
        --project=*)    CHECK_PROJECT="${arg#*=}" ;;
        --skip-scan)    SKIP_SCAN=true ;;
    esac
done

# Validate credentials
if [[ -z "$HARBOR_USERNAME" ]] || [[ -z "$HARBOR_PASSWORD" ]]; then
    log_error "Harbor credentials not set"
    log_detail "Set HARBOR_USERNAME and HARBOR_PASSWORD environment variables"
    exit 1
fi

# API request
harbor_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"

    local url="$HARBOR_URL/api/v2.0$endpoint"

    if [[ -n "$data" ]]; then
        curl -s -X "$method" \
            --connect-timeout "$HARBOR_TIMEOUT" \
            -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url"
    else
        curl -s -X "$method" \
            --connect-timeout "$HARBOR_TIMEOUT" \
            -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" \
            -H "Content-Type: application/json" \
            "$url"
    fi
}

# Check HTTP status code
check_status() {
    local response="$1"
    local http_code=$(echo "$response" | grep -oP 'HTTP_STATUS:\K\d+' || echo "000")

    if (( http_code >= 200 && http_code < 300 )); then
        return 0
    else
        return 1
    fi
}

# Test Harbor connectivity
test_connectivity() {
    log_detail "Testing Harbor connectivity..."

    local response
    response=$(harbor_api "/systeminfo" -w "HTTP_STATUS:%{http_code}")

    if check_status "$response"; then
        local version
        version=$(echo "$response" | jq -r '.harbor_version // "unknown"')
        log_info "Harbor is accessible (v$version)"
        return 0
    else
        log_error "Cannot connect to Harbor at $HARBOR_URL"
        return 1
    fi
}

# Check project access
check_projects() {
    log_detail "Checking project access..."

    local response
    response=$(harbor_api "/projects" -w "HTTP_STATUS:%{http_code}")

    if check_status "$response"; then
        local count
        count=$(echo "$response" | jq 'length')
        log_info "Accessible projects: $count"

        # List projects
        echo "$response" | jq -r '.[].name' | while read -r project; do
            log_detail "  - $project"
        done

        return 0
    else
        log_error "Cannot list projects"
        return 1
    fi
}

# Check specific project
check_project() {
    local project_name="$1"

    log_detail "Checking project: $project_name"

    # Get project ID
    local response
    response=$(harbor_api "/projects?name=$project_name" -w "HTTP_STATUS:%{http_code}")

    if ! check_status "$response"; then
        log_error "Cannot find project: $project_name"
        return 1
    fi

    local project_id
    project_id=$(echo "$response" | jq -r '.[0].project_id // empty')

    if [[ -z "$project_id" ]]; then
        log_error "Project not found: $project_name"
        return 1
    fi

    log_info "Project ID: $project_id"

    # Check repositories
    local repos
    repos=$(harbor_api "/projects/$project_id/repositories" -w "HTTP_STATUS:%{http_code}")

    if check_status "$repos"; then
        local repo_count
        repo_count=$(echo "$repos" | jq 'length')
        log_detail "Repositories: $repo_count"
    fi

    # Check storage quota
    local project_detail
    project_detail=$(harbor_api "/projects/$project_id" -w "HTTP_STATUS:%{http_code}")

    if check_status "$project_detail"; then
        local storage_limit storage_used
        storage_limit=$(echo "$project_detail" | jq -r '.storage_limit // -1')
        storage_used=$(echo "$project_detail" | jq -r '.storage_bytes // 0')

        if [[ "$storage_limit" != "-1" ]]; then
            local usage_pct
            usage_pct=$((storage_used * 100 / storage_limit))
            log_detail "Storage: $usage_pct% ($storage_used / $storage_limit bytes)"

            if (( usage_pct > 90 )); then
                log_error "Storage usage above 90%!"
            elif (( usage_pct > 80 )); then
                log_warn "Storage usage above 80%"
            fi
        else
            log_detail "Storage: No quota set"
        fi
    fi

    return 0
}

# Check vulnerability scanner
check_scanner() {
    if [[ "$SKIP_SCAN" == true ]]; then
        log_detail "Skipping scanner check"
        return 0
    fi

    log_detail "Checking vulnerability scanner..."

    local response
    response=$(harbor_api "/scanners" -w "HTTP_STATUS:%{http_code}")

    if check_status "$response"; then
        local scanner
        scanner=$(echo "$response" | jq -r '.[0].name // "none"')
        log_info "Scanner: $scanner"
        return 0
    else
        log_warn "No scanner configured"
        return 0
    fi
}

# Check system health
check_system_health() {
    log_detail "Checking system health..."

    local response
    response=$(harbor_api "/health" -w "HTTP_STATUS:%{http_code}")

    if check_status "$response"; then
        local healthy
        healthy=$(echo "$response" | jq -r '.healthy // "false"')

        if [[ "$healthy" == "true" ]]; then
            log_info "System healthy"
        else
            log_warn "System may have issues"
        fi

        return 0
    else
        log_error "Health endpoint not accessible"
        return 1
    fi
}

# Main health check logic
main() {
    echo "======================================"
    echo "Harbor Registry Health Check"
    echo "======================================"
    echo "URL: $HARBOR_URL"
    echo "Username: $HARBOR_USERNAME"
    echo ""

    test_connectivity || exit 1
    test_connectivity
    check_system_health
    check_projects

    if [[ -n "$CHECK_PROJECT" ]]; then
        check_project "$CHECK_PROJECT"
    fi

    check_scanner

    echo ""
    echo "======================================"
    echo "Health check complete"
    echo "======================================"
}

main
