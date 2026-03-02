#!/bin/bash

#############################################################################
# VPS Diagnostic Scripts - Deployment Automation
#############################################################################
#
# Purpose: Deploy diagnostic scripts to fgsrv3, fgsrv4, fgsrv5
# Usage: ./deploy-to-hosts.sh [host1] [host2] [host3]
#
# Features:
# - Parallel deployment to multiple hosts
# - Creates necessary directories
# - Sets proper permissions
# - Validates deployment
# - Generates deployment report
#
#############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="/opt/scripts/diagnostics"
LOG_DIR="/var/log/diagnostics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEPLOY_LOG="/tmp/deployment-${TIMESTAMP}.log"

# Default hosts (can be overridden via command line)
HOSTS="${@:-fgsrv3 fgsrv4 fgsrv5}"

#############################################################################
# Functions
#############################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
    esac
}

check_ssh_connection() {
    local host=$1
    log INFO "Testing SSH connection to ${host}..."

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "${host}" "echo 'SSH OK'" &>/dev/null; then
        log SUCCESS "SSH connection to ${host} successful"
        return 0
    else
        log ERROR "Cannot connect to ${host} via SSH"
        return 1
    fi
}

create_remote_directories() {
    local host=$1
    log INFO "Creating remote directories on ${host}..."

    ssh "${host}" "sudo mkdir -p ${REMOTE_DIR} ${LOG_DIR} && \
                   sudo chmod 755 ${REMOTE_DIR} ${LOG_DIR}" &>/dev/null

    if [ $? -eq 0 ]; then
        log SUCCESS "Directories created on ${host}"
        return 0
    else
        log ERROR "Failed to create directories on ${host}"
        return 1
    fi
}

deploy_scripts() {
    local host=$1
    log INFO "Deploying scripts to ${host}..."

    # Create tarball of scripts
    local tarball="/tmp/diagnostics-${TIMESTAMP}.tar.gz"
    tar -czf "${tarball}" -C "${SCRIPT_DIR}" . 2>/dev/null

    # Copy tarball to host
    if scp -q "${tarball}" "${host}:/tmp/" &>/dev/null; then
        # Extract on remote host
        ssh "${host}" "cd /tmp && \
                       sudo tar -xzf diagnostics-${TIMESTAMP}.tar.gz -C ${REMOTE_DIR} && \
                       sudo chmod +x ${REMOTE_DIR}/*.sh && \
                       rm -f /tmp/diagnostics-${TIMESTAMP}.tar.gz" &>/dev/null

        if [ $? -eq 0 ]; then
            log SUCCESS "Scripts deployed to ${host}"
            rm -f "${tarball}"
            return 0
        else
            log ERROR "Failed to extract scripts on ${host}"
            rm -f "${tarball}"
            return 1
        fi
    else
        log ERROR "Failed to copy scripts to ${host}"
        rm -f "${tarball}"
        return 1
    fi
}

verify_deployment() {
    local host=$1
    log INFO "Verifying deployment on ${host}..."

    local script_count=$(ssh "${host}" "ls ${REMOTE_DIR}/*.sh 2>/dev/null | wc -l" 2>/dev/null)

    if [ "${script_count}" -ge 6 ]; then
        log SUCCESS "Deployment verified on ${host} (${script_count} scripts found)"
        return 0
    else
        log WARNING "Deployment verification failed on ${host} (only ${script_count} scripts found)"
        return 1
    fi
}

deploy_to_host() {
    local host=$1

    echo ""
    log INFO "=========================================="
    log INFO "Deploying to ${host}"
    log INFO "=========================================="

    # Check SSH connection
    if ! check_ssh_connection "${host}"; then
        return 1
    fi

    # Create directories
    if ! create_remote_directories "${host}"; then
        return 1
    fi

    # Deploy scripts
    if ! deploy_scripts "${host}"; then
        return 1
    fi

    # Verify deployment
    if ! verify_deployment "${host}"; then
        return 1
    fi

    log SUCCESS "Deployment to ${host} completed successfully"
    return 0
}

generate_deployment_report() {
    local report_file="${SCRIPT_DIR}/deployment-report-${TIMESTAMP}.txt"

    cat > "${report_file}" <<EOF
=============================================================================
VPS Diagnostic Scripts - Deployment Report
=============================================================================

Deployment Date: $(date)
Hosts Deployed: ${HOSTS}

-----------------------------------------------------------------------------
Deployment Summary
-----------------------------------------------------------------------------

EOF

    for host in ${HOSTS}; do
        echo "Host: ${host}" >> "${report_file}"

        if ssh "${host}" "test -d ${REMOTE_DIR}" &>/dev/null; then
            echo "  Status: SUCCESS" >> "${report_file}"
            echo "  Scripts:" >> "${report_file}"
            ssh "${host}" "ls -lh ${REMOTE_DIR}/*.sh 2>/dev/null" >> "${report_file}" 2>/dev/null || true
        else
            echo "  Status: FAILED" >> "${report_file}"
        fi

        echo "" >> "${report_file}"
    done

    cat >> "${report_file}" <<EOF
-----------------------------------------------------------------------------
Next Steps
-----------------------------------------------------------------------------

1. Test scripts on each host:
   ssh [host] "sudo ${REMOTE_DIR}/morning-monitor.sh"

2. Schedule morning monitoring (9:00 AM daily):
   ssh [host] 'echo "0 9 * * * ${REMOTE_DIR}/morning-monitor.sh" | crontab -'

3. Enable MySQL slow query logging (fgsrv3 only):
   ssh fgsrv3 'mysql -e "SET GLOBAL slow_query_log = '\''ON'\''; SET GLOBAL long_query_time = 2;"'

4. Review logs:
   ssh [host] "cat ${LOG_DIR}/morning-monitor-\$(date +%Y%m%d).log"

=============================================================================
EOF

    log SUCCESS "Deployment report generated: ${report_file}"
    cat "${report_file}"
}

#############################################################################
# Main Execution
#############################################################################

main() {
    log INFO "VPS Diagnostic Scripts Deployment"
    log INFO "Deployment log: ${DEPLOY_LOG}"
    echo ""

    # Deployment counters
    local success_count=0
    local fail_count=0

    # Deploy to each host
    for host in ${HOSTS}; do
        if deploy_to_host "${host}"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    # Summary
    echo ""
    log INFO "=========================================="
    log INFO "Deployment Summary"
    log INFO "=========================================="
    log SUCCESS "Successful deployments: ${success_count}"

    if [ ${fail_count} -gt 0 ]; then
        log ERROR "Failed deployments: ${fail_count}"
    fi

    # Generate report
    echo ""
    generate_deployment_report

    # Exit status
    if [ ${fail_count} -eq 0 ]; then
        log SUCCESS "All deployments completed successfully!"
        return 0
    else
        log WARNING "Some deployments failed. Review the log for details."
        return 1
    fi
}

# Run main function
main
