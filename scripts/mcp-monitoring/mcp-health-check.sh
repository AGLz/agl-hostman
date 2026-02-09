#!/bin/bash
##############################################################################
# MCP Server Health Check and Monitoring Script
# Part of AGL-25: MCP Server Optimization
##############################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs/mcp-monitoring"
HEALTH_FILE="${LOG_DIR}/mcp-health-status.json"
ALERT_LOG="${LOG_DIR}/mcp-alerts.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# MCP Servers to monitor
declare -A MCP_SERVERS=(
    ["claude-flow"]="npx claude-flow@alpha mcp start"
    ["ruv-swarm"]="npx ruv-swarm mcp start"
    ["flow-nexus"]="npx flow-nexus@latest mcp start"
    ["archon"]="http://192.168.0.183:8052/mcp"
    ["archon-tailscale"]="http://100.80.30.59:8051/mcp"
    ["exa"]="npx -y exa-mcp-server"
    ["agentic-payments"]="npx agentic-payments@latest mcp"
    ["zai-mcp-server"]="npx -y @z_ai/mcp-server"
)

# Create log directory
mkdir -p "${LOG_DIR}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${ALERT_LOG}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${ALERT_LOG}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${ALERT_LOG}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${ALERT_LOG}"
}

# Test HTTP MCP server
test_http_server() {
    local name="$1"
    local url="$2"

    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 5 --max-time 10 "${url}" &> /dev/null; then
            return 0
        fi
    fi
    return 1
}

# Test npx-based MCP server
test_npx_server() {
    local name="$1"
    local command="$2"

    # Check if npx is available
    if ! command -v npx &> /dev/null; then
        return 1
    fi

    # Extract package name from command using safer method
    local package=""
    # Extract the part after 'npx' and before '@' or space
    package=$(echo "$command" | sed -E 's/.*npx[[:space:]]+(-y[[:space:]]+)?([^[:space:]@]+).*/\2/' | head -1)

    if [[ -n "$package" && "$package" != "$command" ]]; then
        # Check if package is installed or can be resolved
        if npm list -g "$package" &> /dev/null; then
            return 0
        fi
        # Try to check if package exists in npm registry
        if npm view "$package" &> /dev/null; then
            return 0
        fi
    fi

    return 1
}

# Check individual MCP server health
check_server_health() {
    local name="$1"
    local config="$2"
    local status="unknown"
    local response_time=""
    local details=""

    local start_time=$(date +%s%N)

    if [[ "$config" == http* ]]; then
        # HTTP-based server
        if test_http_server "$name" "$config"; then
            status="healthy"
            details="HTTP connection successful"
        else
            status="unhealthy"
            details="HTTP connection failed"
        fi
    else
        # npx-based server
        if test_npx_server "$name" "$config"; then
            status="healthy"
            details="Package available"
        else
            status="unhealthy"
            details="Package not found or npx unavailable"
        fi
    fi

    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    response_time="${duration}ms"

    echo "{\"name\":\"$name\",\"status\":\"$status\",\"response_time\":\"$response_time\",\"details\":\"$details\"}"
}

# Main health check function
run_health_check() {
    log_info "Starting MCP server health check..."

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local overall_status="healthy"
    local results=()

    echo "[" > "${HEALTH_FILE}.tmp"

    local first=true
    for server in "${!MCP_SERVERS[@]}"; do
        local config="${MCP_SERVERS[$server]}"
        local result=$(check_server_health "$server" "$config")

        if ! $first; then
            echo "," >> "${HEALTH_FILE}.tmp"
        fi
        first=false

        echo -n "  $result" >> "${HEALTH_FILE}.tmp"
        results+=("$result")

        # Extract status from result
        local server_status=$(echo "$result" | grep -oP '"status":"[^"]+"' | cut -d'"' -f4)
        if [[ "$server_status" == "unhealthy" ]]; then
            overall_status="unhealthy"
            log_error "MCP server '$server' is unhealthy: $result"
        elif [[ "$server_status" == "healthy" ]]; then
            log_success "MCP server '$server' is healthy"
        fi
    done

    echo "" >> "${HEALTH_FILE}.tmp"
    echo "]" >> "${HEALTH_FILE}.tmp"

    # Add metadata
    cat > "${HEALTH_FILE}" << EOF
{
  "timestamp": "${timestamp}",
  "overall_status": "${overall_status}",
  "total_servers": ${#MCP_SERVERS[@]},
  "healthy_count": $(echo "${results[@]}" | grep -o '"status":"healthy"' | wc -l),
  "unhealthy_count": $(echo "${results[@]}" | grep -o '"status":"unhealthy"' | wc -l),
  "servers": $(cat "${HEALTH_FILE}.tmp")
}
EOF

    rm -f "${HEALTH_FILE}.tmp"

    log_info "Health check complete. Overall status: ${overall_status}"
    log_info "Results saved to: ${HEALTH_FILE}"

    # Return exit code based on overall status
    if [[ "$overall_status" == "healthy" ]]; then
        return 0
    else
        return 1
    fi
}

# Generate health report
generate_report() {
    log_info "Generating health report..."

    if [[ ! -f "${HEALTH_FILE}" ]]; then
        log_error "Health file not found. Run health check first."
        return 1
    fi

    echo ""
    echo "=== MCP Server Health Report ==="
    echo ""

    # Parse and display health status
    if command -v jq &> /dev/null; then
        jq -r '.servers[] | "\(.name): \(.status) (\(.response_time)) - \(.details)"' "${HEALTH_FILE}"
    else
        grep -oP '"name":"[^"]+"|"status":"[^"]+"|"response_time":"[^"]+"|"details":"[^"]+"' "${HEALTH_FILE}" | \
        paste - - - - | sed 's/"//g' | sed 's/name://g' | sed 's/status://g' | \
        sed 's/response_time://g' | sed 's/details://g'
    fi

    echo ""
}

# Restart unhealthy servers
restart_unhealthy() {
    log_info "Checking for servers to restart..."

    if [[ ! -f "${HEALTH_FILE}" ]]; then
        log_error "Health file not found. Run health check first."
        return 1
    fi

    local restarted=0

    # Get unhealthy servers
    local unhealthy_servers=()
    if command -v jq &> /dev/null; then
        mapfile -t unhealthy_servers < <(jq -r '.servers[] | select(.status == "unhealthy") | .name' "${HEALTH_FILE}")
    else
        log_warning "jq not found. Cannot parse unhealthy servers automatically."
        return 1
    fi

    for server in "${unhealthy_servers[@]}"; do
        log_warning "Attempting to restart: $server"

        case "$server" in
            claude-flow|ruv-swarm|flow-nexus|exa|agentic-payments|zai-mcp-server)
                # npx-based servers - ensure packages are installed
                local config="${MCP_SERVERS[$server]}"
                local package=$(echo "$config" | grep -oP '[^\s@]+(?=@|$)' | head -1)
                if [[ -n "$package" ]]; then
                    log_info "Installing/Updating $package..."
                    npm install -g "$package@latest" 2>&1 | tee -a "${ALERT_LOG}" || true
                    ((restarted++))
                fi
                ;;
            archon|archon-tailscale)
                # HTTP servers - log for manual intervention
                log_warning "HTTP server $server requires manual intervention"
                ;;
        esac
    done

    if [[ $restarted -gt 0 ]]; then
        log_success "Restarted $restarted server(s)"
        log_info "Running health check again..."
        sleep 5
        run_health_check
    else
        log_info "No servers were restarted (all healthy or require manual intervention)"
    fi
}

# Setup cron job for automated monitoring
setup_cron() {
    log_info "Setting up cron job for MCP health monitoring..."

    local cron_entry="*/5 * * * * ${SCRIPT_DIR}/mcp-health-check.sh check >> ${LOG_DIR}/cron.log 2>&1"

    # Check if entry already exists
    if crontab -l 2>/dev/null | grep -q "mcp-health-check"; then
        log_warning "Cron entry already exists"
        return 0
    fi

    # Add cron entry
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    log_success "Cron job added successfully"
    log_info "Health checks will run every 5 minutes"
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
    check       Run health check on all MCP servers
    report      Generate and display health report
    restart     Restart unhealthy servers
    monitor     Run continuous monitoring (with interval)
    setup-cron  Setup automated monitoring via cron
    help        Display this help message

Examples:
    $0 check              # Run health check
    $0 report             # Show health report
    $0 restart            # Restart unhealthy servers
    $0 monitor 60         # Monitor every 60 seconds

EOF
}

# Continuous monitoring
monitor_mode() {
    local interval="${1:-60}"

    log_info "Starting continuous monitoring (interval: ${interval}s)"
    log_info "Press Ctrl+C to stop"

    while true; do
        run_health_check
        generate_report
        echo ""
        log_info "Next check in ${interval} seconds..."
        sleep "$interval"
    done
}

# Main script logic
main() {
    local command="${1:-check}"

    case "$command" in
        check)
            run_health_check
            generate_report
            ;;
        report)
            generate_report
            ;;
        restart)
            restart_unhealthy
            ;;
        monitor)
            monitor_mode "${2:-60}"
            ;;
        setup-cron)
            setup_cron
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
