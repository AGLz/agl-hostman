#!/bin/bash
##############################################################################
# MCP Server Auto-Restart Service
# Part of AGL-25: MCP Server Optimization
##############################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs/mcp-monitoring"
PID_FILE="${LOG_DIR}/mcp-auto-restart.pid"
STATE_FILE="${LOG_DIR}/auto-restart-state.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create log directory
mkdir -p "${LOG_DIR}"

# Logging functions
log() {
    local level="$1"
    shift
    local msg="*"
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} [$level] $msg" | tee -a "${LOG_DIR}/auto-restart.log"
}

log_info() { log "INFO" "$*"; }
log_success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} [SUCCESS] $*" | tee -a "${LOG_DIR}/auto-restart.log"; }
log_warning() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} [WARNING] $*" | tee -a "${LOG_DIR}/auto-restart.log"; }
log_error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} [ERROR] $*" | tee -a "${LOG_DIR}/auto-restart.log"; }

# Restart attempt tracking
declare -A RESTART_COUNT
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=300  # 5 minutes in seconds

# Load state from previous runs
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
    fi
}

# Save state
save_state() {
    {
        echo "# Auto-restart state"
        echo "LAST_RESTART=$(date +%s)"
        for server in "${!RESTART_COUNT[@]}"; do
            echo "RESTART_COUNT[$server]=${RESTART_COUNT[$server]}"
        done
    } > "$STATE_FILE"
}

# Restart individual MCP server
restart_server() {
    local server_name="$1"
    local server_config="$2"

    log_info "Attempting to restart: $server_name"

    # Check restart count
    local attempts="${RESTART_COUNT[$server_name]:-0}"
    if [[ $attempts -ge $MAX_RESTART_ATTEMPTS ]]; then
        log_error "$server_name has reached maximum restart attempts ($MAX_RESTART_ATTEMPTS). Manual intervention required."
        return 1
    fi

    # Increment restart count
    RESTART_COUNT[$server_name]=$((attempts + 1))

    case "$server_name" in
        claude-flow)
            log_info "Reinstalling claude-flow@alpha..."
            if npm install -g claude-flow@alpha &>> "${LOG_DIR}/${server_name}-restart.log"; then
                log_success "$server_name restarted successfully"
                RESTART_COUNT[$server_name]=0
                return 0
            else
                log_error "Failed to restart $server_name"
                return 1
            fi
            ;;
        ruv-swarm)
            log_info "Reinstalling ruv-swarm@latest..."
            if npm install -g ruv-swarm@latest &>> "${LOG_DIR}/${server_name}-restart.log"; then
                log_success "$server_name restarted successfully"
                RESTART_COUNT[$server_name]=0
                return 0
            else
                log_error "Failed to restart $server_name"
                return 1
            fi
            ;;
        flow-nexus)
            log_info "Reinstalling flow-nexus@latest..."
            if npm install -g flow-nexus@latest &>> "${LOG_DIR}/${server_name}-restart.log"; then
                log_success "$server_name restarted successfully"
                RESTART_COUNT[$server_name]=0
                return 0
            else
                log_error "Failed to restart $server_name"
                return 1
            fi
            ;;
        exa)
            log_info "Updating exa-mcp-server..."
            if npm install -g exa-mcp-server@latest &>> "${LOG_DIR}/${server_name}-restart.log"; then
                log_success "$server_name updated successfully"
                RESTART_COUNT[$server_name]=0
                return 0
            else
                log_error "Failed to update $server_name"
                return 1
            fi
            ;;
        agentic-payments)
            log_info "Updating agentic-payments..."
            if npm install -g agentic-payments@latest &>> "${LOG_DIR}/${server_name}-restart.log"; then
                log_success "$server_name updated successfully"
                RESTART_COUNT[$server_name]=0
                return 0
            else
                log_error "Failed to update $server_name"
                return 1
            fi
            ;;
        archon)
            log_warning "$server_name is an HTTP server. Cannot auto-restart."
            log_info "Please check the server at: $server_config"
            log_info "Common fixes:"
            log_info "  1. Ensure the archon service is running"
            log_info "  2. Check firewall rules"
            log_info "  3. Verify network connectivity"
            return 2
            ;;
        archon-tailscale)
            log_warning "$server_name is an HTTP server. Cannot auto-restart."
            log_info "Please check the server at: $server_config"
            log_info "Common fixes:"
            log_info "  1. Ensure Tailscale is connected"
            log_info "  2. Check the archon service is running"
            log_info "  3. Verify IP address: 100.80.30.59"
            return 2
            ;;
        *)
            log_error "Unknown server: $server_name"
            return 1
            ;;
    esac
}

# Monitor and auto-restart
monitor_and_restart() {
    local check_interval="${1:-300}"  # Default 5 minutes

    log_info "Starting MCP auto-restart service (interval: ${check_interval}s)"
    log_info "Max restart attempts per server: $MAX_RESTART_ATTEMPTS"

    while true; do
        # Run health check
        local health_output=$("${SCRIPT_DIR}/mcp-health-check.sh" check 2>&1)
        local health_status=$?

        # Parse health check results
        if [[ $health_status -ne 0 ]]; then
            log_warning "Health check detected issues"

            # Try to extract unhealthy servers
            local unhealthy_servers=()
            if command -v jq &> /dev/null; then
                mapfile -t unhealthy_servers < <(jq -r '.servers[] | select(.status == "unhealthy") | .name' "${LOG_DIR}/mcp-health-status.json" 2>/dev/null || echo "")
            fi

            for server in "${unhealthy_servers[@]}"; do
                # Get server config
                local server_config=""
                case "$server" in
                    claude-flow) server_config="npx claude-flow@alpha mcp start" ;;
                    ruv-swarm) server_config="npx ruv-swarm mcp start" ;;
                    flow-nexus) server_config="npx flow-nexus@latest mcp start" ;;
                    exa) server_config="npx -y exa-mcp-server" ;;
                    agentic-payments) server_config="npx agentic-payments@latest mcp" ;;
                    archon) server_config="http://192.168.0.183:8052/mcp" ;;
                    archon-tailscale) server_config="http://100.80.30.59:8051/mcp" ;;
                esac

                if [[ -n "$server_config" ]]; then
                    restart_server "$server" "$server_config"
                fi
            done
        else
            log_success "All MCP servers are healthy"
        fi

        # Save state
        save_state

        # Wait for next check
        log_info "Next check in ${check_interval} seconds..."
        sleep "$check_interval"
    done
}

# Create systemd service
create_systemd_service() {
    local service_file="/etc/systemd/system/mcp-auto-restart.service"

    log_info "Creating systemd service: $service_file"

    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=MCP Server Auto-Restart Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_ROOT}
ExecStart=${SCRIPT_DIR}/mcp-auto-restart.sh daemon
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    log_info "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    log_success "Systemd service created"
    log_info "To enable and start:"
    log_info "  sudo systemctl enable mcp-auto-restart"
    log_info "  sudo systemctl start mcp-auto-restart"
    log_info "To view logs:"
    log_info "  sudo journalctl -u mcp-auto-restart -f"
}

# Run as daemon
daemon_mode() {
    log_info "Running in daemon mode..."

    # Write PID file
    echo $$ > "$PID_FILE"

    # Trap signals
    trap 'rm -f "$PID_FILE"; log_info "Shutting down..."; exit 0' SIGTERM SIGINT

    # Run monitoring
    monitor_and_restart 300
}

# Status check
status_check() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_success "Auto-restart service is running (PID: $pid)"
            return 0
        else
            log_warning "PID file exists but process is not running"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        log_info "Auto-restart service is not running"
        return 1
    fi
}

# Stop service
stop_service() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_info "Stopping auto-restart service (PID: $pid)..."
            kill "$pid"
            rm -f "$PID_FILE"
            log_success "Service stopped"
        else
            log_warning "Service was not running"
            rm -f "$PID_FILE"
        fi
    else
        log_info "Service is not running"
    fi
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
    monitor [INTERVAL]   Run monitoring mode (default: 300s)
    daemon               Run as daemon (background)
    start                Start as daemon
    stop                 Stop daemon
    status               Check service status
    systemd              Create systemd service
    help                 Display this help

Examples:
    $0 monitor 300       # Monitor every 5 minutes
    $0 daemon            # Run in background
    $0 start             # Start daemon
    $0 status            # Check if running
    $0 systemd           # Install as systemd service

EOF
}

# Main
main() {
    local command="${1:-monitor}"

    case "$command" in
        monitor)
            load_state
            monitor_and_restart "${2:-300}"
            ;;
        daemon)
            load_state
            daemon_mode
            ;;
        start)
            if status_check &>/dev/null; then
                log_warning "Service is already running"
                exit 1
            fi
            load_state
            daemon_mode &
            log_success "Service started in background"
            ;;
        stop)
            stop_service
            ;;
        status)
            status_check
            ;;
        systemd)
            create_systemd_service
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

main "$@"
