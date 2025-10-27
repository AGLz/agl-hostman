#!/bin/bash

#############################################################################
# Local Diagnostic Check - Pre-Deployment Validation
#############################################################################
#
# Purpose: Check current system state before deploying to VPS hosts
# Usage: ./local-diagnostic-check.sh
#
# This script performs quick checks that can be run locally to understand
# the baseline configuration and identify obvious issues.
#
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/tmp/vps-diagnostic-${TIMESTAMP}"
mkdir -p "${REPORT_DIR}"

#############################################################################
# Output Functions
#############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

#############################################################################
# Diagnostic Functions
#############################################################################

check_vps_connectivity() {
    print_section "VPS Connectivity Check"

    local hosts="fgsrv3 fgsrv4 fgsrv5"

    for host in ${hosts}; do
        if timeout 5 ping -c 1 "${host}" &>/dev/null; then
            print_success "${host}: Ping successful"
        else
            print_error "${host}: Ping failed"
        fi

        if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "${host}" "echo 'SSH OK'" &>/dev/null; then
            print_success "${host}: SSH connection successful"
        else
            print_warning "${host}: SSH connection failed (may require password)"
        fi
    done
}

check_documentation_files() {
    print_section "Documentation Files Check"

    local base_dir="/mnt/overpower/apps/dev/agl/agl-hostman"
    local files=(
        "docs/research/morning-timeout-analysis.md"
        "docs/analysis/diagnostic-framework.md"
        "scripts/diagnostics/morning-monitor.sh"
        "tests/vps-timeout-testing/QUICK-START.md"
        "docs/HIVE-MIND-EXECUTIVE-SUMMARY.md"
    )

    for file in "${files[@]}"; do
        local full_path="${base_dir}/${file}"
        if [ -f "${full_path}" ]; then
            local size=$(du -h "${full_path}" | cut -f1)
            print_success "${file} (${size})"
        else
            print_error "${file} - NOT FOUND"
        fi
    done
}

check_diagnostic_scripts() {
    print_section "Diagnostic Scripts Check"

    local script_dir="/mnt/overpower/apps/dev/agl/agl-hostman/scripts/diagnostics"

    if [ -d "${script_dir}" ]; then
        print_info "Script directory exists: ${script_dir}"

        local scripts=(
            "check-cron-jobs.sh"
            "detect-mysql-backups.sh"
            "monitor-php-fpm.sh"
            "analyze-nginx-connections.sh"
            "log-resource-usage.sh"
            "morning-monitor.sh"
        )

        for script in "${scripts[@]}"; do
            local full_path="${script_dir}/${script}"
            if [ -f "${full_path}" ]; then
                if [ -x "${full_path}" ]; then
                    local size=$(du -h "${full_path}" | cut -f1)
                    print_success "${script} (${size}, executable)"
                else
                    print_warning "${script} exists but not executable"
                fi
            else
                print_error "${script} - NOT FOUND"
            fi
        done
    else
        print_error "Script directory not found: ${script_dir}"
    fi
}

analyze_current_time() {
    print_section "Current Time Analysis"

    local current_hour=$(date +%H)
    local current_minute=$(date +%M)
    local current_time="${current_hour}:${current_minute}"

    print_info "Current time: ${current_time}"

    if [ "${current_hour}" -eq 9 ] || [ "${current_hour}" -eq 10 ]; then
        print_warning "WARNING: Currently in the 9-10am problem window!"
        print_warning "This is the optimal time to collect diagnostic data"
    else
        print_info "Not in the 9-10am problem window"
        print_info "Next occurrence: Tomorrow at 09:00"
    fi
}

check_required_tools() {
    print_section "Required Tools Check"

    local tools=(
        "ssh"
        "scp"
        "ping"
        "tar"
        "mysql"
        "curl"
    )

    for tool in "${tools[@]}"; do
        if command -v "${tool}" &>/dev/null; then
            local version=$(${tool} --version 2>&1 | head -n 1 || echo "version unknown")
            print_success "${tool} is installed"
        else
            print_warning "${tool} is NOT installed"
        fi
    done
}

generate_deployment_checklist() {
    print_section "Deployment Checklist"

    local checklist_file="${REPORT_DIR}/deployment-checklist.txt"

    cat > "${checklist_file}" <<'EOF'
=============================================================================
VPS Timeout Troubleshooting - Deployment Checklist
=============================================================================

□ Phase 1: Pre-Deployment Verification
  □ Review Hive Mind Executive Summary
  □ Verify SSH access to all 3 hosts (fgsrv3, fgsrv4, fgsrv5)
  □ Confirm backup windows and schedules
  □ Review current cron jobs on all hosts
  □ Document current performance baselines

□ Phase 2: Script Deployment
  □ Deploy diagnostic scripts to fgsrv3 (MySQL)
  □ Deploy diagnostic scripts to fgsrv4 (nginx/PHP5)
  □ Deploy diagnostic scripts to fgsrv5 (nginx/Laravel)
  □ Verify script permissions (chmod +x)
  □ Create log directories (/var/log/diagnostics)
  □ Test scripts manually on each host

□ Phase 3: Monitoring Setup
  □ Schedule morning-monitor.sh for 9:00 AM daily
  □ Enable MySQL slow query logging (fgsrv3)
  □ Configure syslog forwarding (optional)
  □ Set up alerting for critical thresholds
  □ Test monitoring during off-peak hours

□ Phase 4: Data Collection (Day 1-2)
  □ Collect baseline metrics (8:30-8:55 AM)
  □ Monitor during problem window (9:00-10:10 AM)
  □ Review diagnostic logs immediately after 10:30 AM
  □ Compare against Hive Mind hypotheses
  □ Document observed patterns

□ Phase 5: Root Cause Validation (Day 2-3)
  □ Analyze cron job execution times
  □ Review MySQL backup processes and locks
  □ Examine PHP-FPM worker pool exhaustion
  □ Check Laravel queue worker memory usage
  □ Investigate nginx connection timeouts
  □ Validate primary hypothesis (70% backup-related)

□ Phase 6: Remediation Implementation (Day 3-5)
  □ Reschedule MySQL backups to 2-4 AM window
  □ Stagger cron jobs (9:05, 9:15, 9:25)
  □ Configure PHP-FPM worker recycling
  □ Add nginx burst handling (burst=20 nodelay)
  □ Implement Laravel queue worker restarts
  □ Apply MySQL optimization configurations

□ Phase 7: Post-Fix Validation (Week 2)
  □ Monitor for 14 consecutive days
  □ Compare post-fix metrics with baseline
  □ Run stress tests during peak hours
  □ Validate 99.9% uptime target
  □ Document lessons learned

□ Phase 8: Long-Term Monitoring (Ongoing)
  □ Deploy Prometheus/Grafana stack
  □ Set up MySQL replication for backups
  □ Implement capacity planning process
  □ Create runbooks for common issues
  □ Schedule quarterly performance reviews

=============================================================================
Priority Actions (Today)
=============================================================================

1. [ ] Deploy scripts to all 3 hosts (use deploy-to-hosts.sh)
2. [ ] Audit current cron jobs: ssh [host] "crontab -l > /tmp/crontab-audit.txt"
3. [ ] Enable MySQL slow query log: mysql -e "SET GLOBAL slow_query_log = 'ON';"
4. [ ] Schedule tomorrow's 9am monitoring
5. [ ] Review Hive Mind analysis documents

=============================================================================
Critical Commands Reference
=============================================================================

# Deploy scripts to all hosts
./scripts/diagnostics/deploy-to-hosts.sh fgsrv3 fgsrv4 fgsrv5

# Run manual diagnostic (during problem window)
ssh [host] "sudo /opt/scripts/diagnostics/morning-monitor.sh"

# Check logs
ssh [host] "cat /var/log/diagnostics/morning-monitor-$(date +%Y%m%d).log"

# Audit cron jobs
ssh [host] "sudo crontab -l; sudo cat /etc/crontab; sudo ls -la /etc/cron.d/"

# Check MySQL processes
ssh fgsrv3 "mysql -e 'SHOW PROCESSLIST;'"

# Monitor PHP-FPM
ssh fgsrv4 "sudo systemctl status php-fpm; ps aux | grep php-fpm"

# Check nginx connections
ssh fgsrv4 "sudo netstat -anp | grep :80 | wc -l"

=============================================================================
EOF

    print_success "Deployment checklist created: ${checklist_file}"
    cat "${checklist_file}"
}

create_quick_reference() {
    print_section "Quick Reference Guide"

    local ref_file="${REPORT_DIR}/quick-reference.txt"

    cat > "${ref_file}" <<'EOF'
=============================================================================
VPS Timeout Troubleshooting - Quick Reference
=============================================================================

HOSTS
-----
fgsrv3 - MySQL server
fgsrv4 - nginx/PHP5 (https://falg.com.br)
fgsrv5 - nginx/Laravel (https://api.falg.com.br)

PROBLEM WINDOW
--------------
Daily: 9:00 AM - 10:00 AM (Brazil time)
Pattern: Timeouts during this window, normal after 10:00 AM

TOP HYPOTHESES (From Hive Mind Analysis)
-----------------------------------------
1. MySQL backups at 9:00 AM (70% probability)
   - Table locks during mysqldump
   - Connection pool exhaustion
   - Solution: Move to 2-4 AM, use --single-transaction

2. Cron job clustering (50% probability)
   - Multiple tasks at :00 minute marks
   - Resource contention
   - Solution: Stagger execution times

3. PHP-FPM memory leaks (30% probability)
   - Queue workers accumulate memory overnight
   - Critical levels by morning
   - Solution: Worker recycling, hourly restarts

4. Locaweb infrastructure (20% probability)
   - Known connectivity issues (Feb 2024)
   - Business hours limitations
   - Solution: Contact support, monitoring

DIAGNOSTIC SCRIPTS (Location: /opt/scripts/diagnostics/)
---------------------------------------------------------
morning-monitor.sh         - Unified orchestrator (run this first)
check-cron-jobs.sh         - Cron analysis
detect-mysql-backups.sh    - Backup detection
monitor-php-fpm.sh         - PHP-FPM monitoring
analyze-nginx-connections.sh - Connection tracking
log-resource-usage.sh      - Resource logging

IMMEDIATE ACTIONS
-----------------
1. Deploy scripts: ./scripts/diagnostics/deploy-to-hosts.sh
2. Enable monitoring: Schedule morning-monitor.sh for 9:00 AM
3. Enable MySQL logging: SET GLOBAL slow_query_log = 'ON';
4. Audit cron jobs: crontab -l on all hosts

DOCUMENTATION LOCATIONS
-----------------------
/docs/HIVE-MIND-EXECUTIVE-SUMMARY.md - Complete overview
/docs/research/morning-timeout-analysis.md - Root cause analysis
/docs/analysis/diagnostic-framework.md - Investigation methodology
/tests/vps-timeout-testing/QUICK-START.md - Testing guide

KEY METRICS TO MONITOR
----------------------
- MySQL connection pool usage (target: <70%)
- PHP-FPM worker pool usage (target: <70%)
- Response time (target: <500ms)
- CPU usage (target: <70%)
- Memory usage (target: <80%)
- 5xx error rate (target: 0%)

CONFIGURATION CHANGES (After Validation)
-----------------------------------------
1. Reschedule backups: 9:00 AM → 2:00 AM
2. PHP-FPM recycling: pm.max_requests = 1000
3. nginx burst: burst=20 nodelay
4. Cron staggering: 9:05, 9:15, 9:25 instead of 9:00

EMERGENCY CONTACTS
------------------
- Locaweb Support: [Contact information needed]
- Database Admin: [Contact information needed]
- DevOps Team: [Contact information needed]

=============================================================================
EOF

    print_success "Quick reference created: ${ref_file}"
}

#############################################################################
# Main Execution
#############################################################################

main() {
    print_header "VPS Timeout Diagnostic - Pre-Deployment Check"

    check_vps_connectivity
    check_documentation_files
    check_diagnostic_scripts
    check_required_tools
    analyze_current_time
    generate_deployment_checklist
    create_quick_reference

    print_header "Pre-Deployment Check Complete"

    print_info "Report directory: ${REPORT_DIR}"
    print_info ""
    print_info "Next steps:"
    print_info "1. Review: ${REPORT_DIR}/deployment-checklist.txt"
    print_info "2. Deploy: ./scripts/diagnostics/deploy-to-hosts.sh"
    print_info "3. Monitor: Wait for tomorrow's 9-10am window"

    echo ""
}

main
