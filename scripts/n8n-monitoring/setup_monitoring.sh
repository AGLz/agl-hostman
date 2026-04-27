#!/bin/bash

################################################################################
# N8N Monitoring System Setup Script
# Purpose: Install and configure the complete monitoring system
# Author: Hive Mind Coder Agent
################################################################################

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/n8n-monitoring"
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly CRON_DIR="/etc/cron.d"

# Color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_header() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}▶${NC} $*"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_error() {
    echo -e "${RED}✗${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

check_requirements() {
    print_header "Checking Requirements"

    local missing_deps=()

    # Check for Docker
    if ! command -v docker &>/dev/null; then
        missing_deps+=("docker")
    else
        print_success "Docker installed"
    fi

    # Check for curl
    if ! command -v curl &>/dev/null; then
        missing_deps+=("curl")
    else
        print_success "curl installed"
    fi

    # Check for bash version
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        print_error "Bash 4.0 or higher required (found ${BASH_VERSION})"
        missing_deps+=("bash>=4.0")
    else
        print_success "Bash ${BASH_VERSION}"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing requirements: ${missing_deps[*]}"
        echo
        echo "Please install missing dependencies and try again."
        exit 1
    fi

    echo
}

setup_directories() {
    print_header "Setting Up Directories"

    print_step "Creating log directories..."
    mkdir -p "${LOG_DIR}"/{diagnostics,reports,recovery_state}
    print_success "Log directories created"

    print_step "Setting permissions..."
    chmod 755 "${LOG_DIR}"
    chmod 755 "${LOG_DIR}"/{diagnostics,reports,recovery_state}
    print_success "Permissions set"

    echo
}

install_scripts() {
    print_header "Installing Monitoring Scripts"

    local scripts=(
        "check_n8n_health.sh"
        "n8n_auto_recovery.sh"
        "collect_diagnostics.sh"
        "aggregate_logs.sh"
    )

    for script in "${scripts[@]}"; do
        print_step "Installing ${script}..."

        if [[ -f "${SCRIPT_DIR}/${script}" ]]; then
            chmod +x "${SCRIPT_DIR}/${script}"
            print_success "${script} installed"
        else
            print_error "${script} not found"
            exit 1
        fi
    done

    echo
}

load_config() {
    if [[ -f "${SCRIPT_DIR}/n8n_monitor.conf" ]]; then
        print_step "Loading configuration..."
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/n8n_monitor.conf"
        print_success "Configuration loaded"
    else
        print_warning "Configuration file not found, using defaults"
    fi
}

setup_cron_jobs() {
    print_header "Setting Up Scheduled Tasks"

    local cron_file="${CRON_DIR}/n8n-monitoring"

    print_step "Creating cron configuration..."

    cat > "${cron_file}" <<EOF
# N8N Monitoring System Cron Jobs
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Health check every 5 minutes
*/5 * * * * root ${SCRIPT_DIR}/check_n8n_health.sh >> ${LOG_DIR}/cron.log 2>&1

# Check if recovery is needed every minute (script handles safety limits)
* * * * * root ${SCRIPT_DIR}/n8n_auto_recovery.sh >> ${LOG_DIR}/cron.log 2>&1 || true

# Daily log aggregation at 02:00
0 2 * * * root ${SCRIPT_DIR}/aggregate_logs.sh >> ${LOG_DIR}/cron.log 2>&1

# Weekly full diagnostics on Sunday at 03:00
0 3 * * 0 root ${SCRIPT_DIR}/collect_diagnostics.sh >> ${LOG_DIR}/cron.log 2>&1

EOF

    chmod 644 "${cron_file}"
    print_success "Cron jobs configured"

    echo
    print_warning "Note: Cron jobs require cron daemon to be running"
    echo "         If using systemd timers instead, see documentation"
    echo
}

setup_systemd_timer() {
    print_header "Setting Up Systemd Timers (Optional)"

    if [[ ! -d "${SYSTEMD_DIR}" ]]; then
        print_warning "Systemd not available, skipping timer setup"
        return
    fi

    print_step "Creating systemd service unit..."

    cat > "${SYSTEMD_DIR}/n8n-health-check.service" <<EOF
[Unit]
Description=N8N Health Check
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=${SCRIPT_DIR}/check_n8n_health.sh
StandardOutput=append:${LOG_DIR}/health_check.log
StandardError=append:${LOG_DIR}/health_check.log

[Install]
WantedBy=multi-user.target
EOF

    cat > "${SYSTEMD_DIR}/n8n-health-check.timer" <<EOF
[Unit]
Description=N8N Health Check Timer
Requires=n8n-health-check.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=n8n-health-check.service

[Install]
WantedBy=timers.target
EOF

    print_step "Creating recovery service unit..."

    cat > "${SYSTEMD_DIR}/n8n-auto-recovery.service" <<EOF
[Unit]
Description=N8N Auto Recovery
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=${SCRIPT_DIR}/n8n_auto_recovery.sh
StandardOutput=append:${LOG_DIR}/auto_recovery.log
StandardError=append:${LOG_DIR}/auto_recovery.log

[Install]
WantedBy=multi-user.target
EOF

    cat > "${SYSTEMD_DIR}/n8n-auto-recovery.timer" <<EOF
[Unit]
Description=N8N Auto Recovery Timer
Requires=n8n-auto-recovery.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
Unit=n8n-auto-recovery.service

[Install]
WantedBy=timers.target
EOF

    print_success "Systemd units created"

    print_step "Reloading systemd daemon..."
    systemctl daemon-reload 2>/dev/null || print_warning "Could not reload systemd daemon"

    echo
    print_warning "To enable systemd timers, run:"
    echo "  systemctl enable --now n8n-health-check.timer"
    echo "  systemctl enable --now n8n-auto-recovery.timer"
    echo
}

run_initial_tests() {
    print_header "Running Initial Tests"

    print_step "Testing health check script..."
    if "${SCRIPT_DIR}/check_n8n_health.sh" 2>&1 | head -20; then
        print_success "Health check script working"
    else
        print_warning "Health check returned non-zero exit code (this may be normal if container is unhealthy)"
    fi

    echo
    print_step "Checking log directory..."
    if [[ -d "${LOG_DIR}" ]] && [[ -w "${LOG_DIR}" ]]; then
        print_success "Log directory is writable"
    else
        print_error "Log directory not writable"
    fi

    echo
}

display_summary() {
    print_header "Installation Complete"

    cat <<EOF
${GREEN}✓${NC} N8N Monitoring System has been installed successfully!

${BLUE}Installed Components:${NC}
  • Health Check Script: ${SCRIPT_DIR}/check_n8n_health.sh
  • Auto Recovery Script: ${SCRIPT_DIR}/n8n_auto_recovery.sh
  • Diagnostics Collection: ${SCRIPT_DIR}/collect_diagnostics.sh
  • Log Aggregation: ${SCRIPT_DIR}/aggregate_logs.sh

${BLUE}Log Location:${NC}
  ${LOG_DIR}

${BLUE}Configuration File:${NC}
  ${SCRIPT_DIR}/n8n_monitor.conf

${BLUE}Quick Start Commands:${NC}

  ${YELLOW}# Check n8n health manually${NC}
  ${SCRIPT_DIR}/check_n8n_health.sh

  ${YELLOW}# Trigger recovery if needed${NC}
  ${SCRIPT_DIR}/n8n_auto_recovery.sh

  ${YELLOW}# Collect full diagnostics${NC}
  ${SCRIPT_DIR}/collect_diagnostics.sh

  ${YELLOW}# Generate log report${NC}
  ${SCRIPT_DIR}/aggregate_logs.sh

  ${YELLOW}# View recovery system status${NC}
  ${SCRIPT_DIR}/n8n_auto_recovery.sh --status

  ${YELLOW}# Reset circuit breaker${NC}
  ${SCRIPT_DIR}/n8n_auto_recovery.sh --reset-circuit-breaker

${BLUE}Scheduled Tasks:${NC}
  • Health checks: Every 5 minutes
  • Auto recovery: Every minute (with safety limits)
  • Log aggregation: Daily at 02:00
  • Full diagnostics: Weekly on Sunday at 03:00

${BLUE}Monitoring Logs:${NC}
  • Health checks: ${LOG_DIR}/health_check.log
  • Auto recovery: ${LOG_DIR}/auto_recovery.log
  • Incidents: ${LOG_DIR}/incidents.log
  • Cron output: ${LOG_DIR}/cron.log

${BLUE}Next Steps:${NC}
  1. Review and customize ${SCRIPT_DIR}/n8n_monitor.conf
  2. Test the health check: ${SCRIPT_DIR}/check_n8n_health.sh
  3. Monitor logs in ${LOG_DIR}
  4. Optionally enable systemd timers instead of cron

${BLUE}Documentation:${NC}
  Each script includes --help option for detailed usage information.

EOF
}

main() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi

    print_header "N8N Monitoring System Setup"

    echo "This script will install and configure the complete n8n monitoring system."
    echo
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    check_requirements
    setup_directories
    install_scripts
    load_config
    setup_cron_jobs

    # Optionally setup systemd timers
    read -p "Setup systemd timers? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_systemd_timer
    fi

    run_initial_tests
    display_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
