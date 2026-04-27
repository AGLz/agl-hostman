#!/bin/bash
# Docker Health Check Script
# Check all container health, logs, and metrics
#
# Usage:
#   ./docker-health-check.sh check [container-name]
#   ./docker-health-check.sh all
#   ./docker-health-check.sh watch [container-name]
#   ./docker-health-check.sh report

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"
LOG_LINES="${LOG_LINES:-50}"
METRICS_INTERVAL="${METRICS_INTERVAL:-5}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if container exists
container_exists() {
    local container="$1"
    docker inspect "$container" &> /dev/null
}

# Get container health status
get_health_status() {
    local container="$1"

    if ! container_exists "$container"; then
        echo "not_found"
        return
    fi

    local status
    status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)

    if [[ "$status" == "running" ]]; then
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no_healthcheck")
        echo "$health_status"
    else
        echo "$status"
    fi
}

# Format health status with color
format_status() {
    local status="$1"

    case "$status" in
        healthy|running)
            echo -e "${GREEN}$status${NC}"
            ;;
        unhealthy|exited|dead)
            echo -e "${RED}$status${NC}"
            ;;
        starting|created|restarting|paused)
            echo -e "${YELLOW}$status${NC}"
            ;;
        no_healthcheck)
            echo -e "${CYAN}$status${NC}"
            ;;
        *)
            echo -e "${NC}$status${NC}"
            ;;
    esac
}

# Check single container health
check_container() {
    local container="$1"
    local verbose="${2:-false}"

    if ! container_exists "$container"; then
        log_error "Container not found: $container"
        return 1
    fi

    local status
    status=$(get_health_status "$container")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Container: $container"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Status
    echo -n "Status: "
    format_status "$status"

    # Container details
    local image
    image=$(docker inspect --format='{{.Config.Image}}' "$container")
    echo "Image: $image"

    local uptime
    uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container" | xargs date -d 2>/dev/null | xargs -I{} dateutils.ddiff {} now -f "%dd %Hh %Mm" 2>/dev/null || echo "unknown")
    echo "Uptime: $uptime"

    # Health check details
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "")

    if [[ -n "$health_status" ]] && [[ "$health_status" != "no_healthcheck" ]]; then
        echo ""
        echo "Health Check:"
        local health_log
        health_log=$(docker inspect --format='{{range .State.Health.Log}}{{.Start}} - {{.ExitCode}} - {{.Output}}{{"\n"}}{{end}}' "$container" | tail -1)
        echo "  Last check: $health_log"
    fi

    # Resource usage
    echo ""
    echo "Resources:"
    local stats
    stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" "$container" | tail -1)
    echo "  CPU: $(echo "$stats" | awk '{print $1}')"
    echo "  Memory: $(echo "$stats" | awk '{print $2}')"
    echo "  Network: $(echo "$stats" | awk '{print $3}')"
    echo "  Disk: $(echo "$stats" | awk '{print $4}')"

    # Recent logs if unhealthy or verbose
    if [[ "$status" == "unhealthy" ]] || [[ "$verbose" == "true" ]]; then
        echo ""
        echo "Recent logs (last $LOG_LINES lines):"
        docker logs --tail "$LOG_LINES" "$container" 2>&1 | sed 's/^/  /'
    fi

    # Return code based on health
    if [[ "$status" == "healthy" ]] || [[ "$status" == "running" && "$health_status" == "no_healthcheck" ]]; then
        return 0
    else
        return 1
    fi
}

# Check all containers
check_all_containers() {
    log_info "Checking all containers..."

    local containers
    containers=$(docker ps -a --format "{{.Names}}")

    local healthy=0
    local unhealthy=0
    local no_healthcheck=0
    local not_running=0

    for container in $containers; do
        local status
        status=$(get_health_status "$container")

        case "$status" in
            healthy)
                ((healthy++))
                ;;
            unhealthy)
                ((unhealthy++))
                check_container "$container" "false"
                ;;
            no_healthcheck)
                ((no_healthcheck++))
                ;;
            *)
                ((not_running++))
                check_container "$container" "false"
                ;;
        esac
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Healthy:       ${GREEN}$healthy${NC}"
    echo -e "Unhealthy:     ${RED}$unhealthy${NC}"
    echo -e "No Healthcheck: ${CYAN}$no_healthcheck${NC}"
    echo -e "Not Running:   ${YELLOW}$not_running${NC}"
    echo ""

    if [[ $unhealthy -gt 0 ]] || [[ $not_running -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Watch container health continuously
watch_container() {
    local container="${1:-}"

    log_info "Watching container health... (Press Ctrl+C to stop)"

    while true; do
        clear
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "Last update: $timestamp"
        echo ""

        if [[ -n "$container" ]]; then
            check_container "$container" "true"
        else
            check_all_containers
        fi

        sleep "$METRICS_INTERVAL"
    done
}

# Generate health report
generate_report() {
    local report_file="docker-health-report-$(date +%Y%m%d_%H%M%S).txt"

    log_info "Generating health report: $report_file"

    {
        echo "Docker Container Health Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "================================"
        echo ""

        echo "Container Overview:"
        echo "-------------------"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | sed 's/^/  /'
        echo ""

        echo "Health Status:"
        echo "--------------"
        local containers
        containers=$(docker ps -a --format "{{.Names}}")

        for container in $containers; do
            local status
            status=$(get_health_status "$container")
            echo -n "$container: "
            format_status "$status"

            # Add health check details if available
            local health_status
            health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "")

            if [[ -n "$health_status" ]] && [[ "$health_status" != "no_healthcheck" ]]; then
                local last_check
                last_check=$(docker inspect --format='{{json .State.Health}}' "$container" | jq -r '.Log[-1] // empty')
                if [[ -n "$last_check" ]]; then
                    echo "  Last check: $(echo "$last_check" | jq -r '.Start') - Exit code: $(echo "$last_check" | jq -r '.ExitCode')"
                fi
            fi
        done

        echo ""
        echo "Resource Usage:"
        echo "---------------"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | sed 's/^/  /'
        echo ""

        echo "Volume Usage:"
        echo "-------------"
        docker system df -v --format "table {{.Type}}\t{{.Name}}\t{{.Size}}" | grep volume | sed 's/^/  /'
        echo ""

        echo "Network Statistics:"
        echo "-------------------"
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | sed 's/^/  /'
        echo ""

    } | tee "$report_file"

    log_success "Report saved to: $report_file"
}

# Check specific service endpoint
check_endpoint() {
    local url="$1"
    local expected_code="${2:-200}"

    log_info "Checking endpoint: $url"

    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time "$HEALTH_CHECK_TIMEOUT")

    if [[ "$response_code" == "$expected_code" ]]; then
        log_success "Endpoint healthy: HTTP $response_code"
        return 0
    else
        log_error "Endpoint unhealthy: HTTP $response_code (expected $expected_code)"
        return 1
    fi
}

# Run comprehensive health check
run_comprehensive_check() {
    log_info "Running comprehensive health check..."

    local issues=0

    # Check all containers
    echo ""
    echo "Checking containers..."
    if ! check_all_containers; then
        ((issues++))
    fi

    # Check disk space
    echo ""
    echo "Checking disk space..."
    local disk_usage
    disk_usage=$(df -h /var/lib/docker | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        log_warning "Docker disk usage is high: ${disk_usage}%"
        ((issues++))
    else
        log_success "Docker disk usage: ${disk_usage}%"
    fi

    # Check Docker daemon
    echo ""
    echo "Checking Docker daemon..."
    if docker info &> /dev/null; then
        log_success "Docker daemon is running"
    else
        log_error "Docker daemon is not responding"
        ((issues++))
    fi

    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $issues -eq 0 ]]; then
        log_success "All health checks passed!"
        return 0
    else
        log_error "$issues health check(s) failed"
        return 1
    fi
}

# Display usage
usage() {
    cat << EOF
Docker Health Check Script

Usage:
  $0 check <container-name>           Check specific container health
  $0 all                              Check all containers
  $0 watch [container-name]           Watch health continuously
  $0 report                           Generate health report
  $0 endpoint <url> [expected-code]   Check HTTP endpoint
  $0 comprehensive                    Run comprehensive health check

Examples:
  $0 check myapp-app
  $0 all
  $0 watch
  $0 watch myapp-db
  $0 report
  $0 endpoint http://localhost:8080/health
  $0 comprehensive

Environment Variables:
  HEALTH_CHECK_TIMEOUT    Timeout for endpoint checks (default: 30)
  LOG_LINES               Number of log lines to display (default: 50)
  METRICS_INTERVAL        Interval for watch mode (default: 5)
EOF
}

# Main
case "${1:-}" in
    check)
        check_container "$2" "${3:-false}"
        ;;
    all)
        check_all_containers
        ;;
    watch)
        watch_container "${2:-}"
        ;;
    report)
        generate_report
        ;;
    endpoint)
        check_endpoint "$2" "${3:-200}"
        ;;
    comprehensive)
        run_comprehensive_check
        ;;
    *)
        usage
        exit 1
        ;;
esac
