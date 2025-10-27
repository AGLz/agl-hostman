#!/bin/bash
################################################################################
# MySQL Backup Detection Script
# Purpose: Detect and analyze MySQL backup jobs, timing, and resource usage
# Author: Hive Mind Coder Agent
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/diagnostics"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${LOG_DIR}/mysql-backup-analysis-${TIMESTAMP}.log"
readonly MORNING_START_HOUR=9
readonly MORNING_END_HOUR=10

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

print_header() {
    local title="$1"
    echo "" | tee -a "${LOG_FILE}"
    echo "================================================================" | tee -a "${LOG_FILE}"
    echo "  ${title}" | tee -a "${LOG_FILE}"
    echo "================================================================" | tee -a "${LOG_FILE}"
}

check_requirements() {
    log_info "Checking requirements..."

    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
        log_info "Created log directory: ${LOG_DIR}"
    fi

    log_success "Requirements check completed"
}

detect_mysqldump_processes() {
    print_header "Active MySQL Backup Processes"

    local current_hour=$(date +%H | sed 's/^0//')

    log_info "Checking for running mysqldump processes..."

    if pgrep -f mysqldump > /dev/null; then
        log_warning "Active mysqldump processes detected!"

        if [[ $current_hour -ge $MORNING_START_HOUR && $current_hour -lt $MORNING_END_HOUR ]]; then
            log_error "⚠️  BACKUP RUNNING DURING MORNING PEAK (9-10am)!"
        fi

        echo "" | tee -a "${LOG_FILE}"
        ps aux | grep -i mysqldump | grep -v grep | tee -a "${LOG_FILE}"

        # Get detailed process information
        echo "" | tee -a "${LOG_FILE}"
        log_info "Detailed process information:"
        pgrep -f mysqldump | while read -r pid; do
            echo "  PID: ${pid}" | tee -a "${LOG_FILE}"
            echo "  Command: $(ps -p "$pid" -o cmd --no-headers)" | tee -a "${LOG_FILE}"
            echo "  CPU: $(ps -p "$pid" -o %cpu --no-headers)%" | tee -a "${LOG_FILE}"
            echo "  Memory: $(ps -p "$pid" -o %mem --no-headers)%" | tee -a "${LOG_FILE}"
            echo "  Elapsed: $(ps -p "$pid" -o etime --no-headers)" | tee -a "${LOG_FILE}"
            echo "" | tee -a "${LOG_FILE}"
        done
    else
        log_info "No active mysqldump processes found"
    fi
}

find_backup_scripts() {
    print_header "MySQL Backup Scripts and Configurations"

    log_info "Searching for backup scripts in common locations..."

    local search_paths=(
        "/usr/local/bin"
        "/opt"
        "/root"
        "/home"
        "/var/scripts"
        "/etc/cron.daily"
        "/etc/cron.hourly"
    )

    local backup_patterns=(
        "*mysql*backup*"
        "*db*backup*"
        "*mysqldump*"
        "*database*backup*"
    )

    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            for pattern in "${backup_patterns[@]}"; do
                find "$path" -maxdepth 3 -type f -iname "$pattern" 2>/dev/null | while IFS= read -r file; do
                    echo "  Found: ${file}" | tee -a "${LOG_FILE}"

                    if [[ -r "$file" ]]; then
                        # Check if script contains mysqldump
                        if grep -q "mysqldump" "$file" 2>/dev/null; then
                            log_warning "  ↳ Contains mysqldump command"

                            # Show the backup command
                            echo "    Backup commands:" | tee -a "${LOG_FILE}"
                            grep -n "mysqldump" "$file" | head -5 | sed 's/^/      /' | tee -a "${LOG_FILE}"
                        fi
                    fi
                    echo "" | tee -a "${LOG_FILE}"
                done
            done
        fi
    done
}

check_mysql_config() {
    print_header "MySQL Configuration Analysis"

    local mysql_configs=(
        "/etc/mysql/my.cnf"
        "/etc/my.cnf"
        "/etc/mysql/mysql.conf.d/mysqld.cnf"
    )

    for config in "${mysql_configs[@]}"; do
        if [[ -f "$config" ]]; then
            log_info "Found MySQL config: ${config}"

            # Check for backup-related settings
            if grep -i "backup" "$config" 2>/dev/null; then
                echo "  Backup-related settings:" | tee -a "${LOG_FILE}"
                grep -i "backup" "$config" | sed 's/^/    /' | tee -a "${LOG_FILE}"
            fi

            echo "" | tee -a "${LOG_FILE}"
        fi
    done

    # Check for backup directories
    log_info "Searching for backup directories..."

    local backup_dirs=(
        "/var/backups/mysql"
        "/backup/mysql"
        "/backups/mysql"
        "/var/lib/mysql/backup"
        "/opt/backups/mysql"
    )

    for dir in "${backup_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Found backup directory: ${dir}"

            local backup_count=$(find "$dir" -type f -name "*.sql*" 2>/dev/null | wc -l)
            local latest_backup=$(find "$dir" -type f -name "*.sql*" -printf '%T+ %p\n' 2>/dev/null | sort -r | head -1)

            echo "  Total backups: ${backup_count}" | tee -a "${LOG_FILE}"
            if [[ -n "$latest_backup" ]]; then
                echo "  Latest backup: ${latest_backup}" | tee -a "${LOG_FILE}"
            fi

            # Check disk usage
            local dir_size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
            echo "  Directory size: ${dir_size}" | tee -a "${LOG_FILE}"

            echo "" | tee -a "${LOG_FILE}"
        fi
    done
}

analyze_backup_schedule() {
    print_header "Backup Schedule Analysis"

    log_info "Analyzing cron jobs for MySQL backups..."

    # Check user crontabs
    if [[ $EUID -eq 0 ]]; then
        cut -f1 -d: /etc/passwd | while read -r user; do
            if crontab -u "$user" -l 2>/dev/null | grep -i "mysql\|backup\|dump"; then
                echo "  User: ${user}" | tee -a "${LOG_FILE}"
                crontab -u "$user" -l 2>/dev/null | grep -i "mysql\|backup\|dump" | while IFS= read -r line; do
                    echo "    ${line}" | tee -a "${LOG_FILE}"

                    # Check if scheduled during 9-10am
                    local hour_field=$(echo "$line" | awk '{print $2}')
                    if [[ "$hour_field" == "9" ]] || [[ "$hour_field" == "09" ]]; then
                        log_error "    ⚠️  SCHEDULED DURING MORNING PEAK!"
                    fi
                done
                echo "" | tee -a "${LOG_FILE}"
            fi
        done
    fi

    # Check system cron
    local system_cron_files=(
        "/etc/crontab"
        "/etc/cron.d/"*
    )

    for cron_file in "${system_cron_files[@]}"; do
        if [[ -f "$cron_file" ]]; then
            if grep -i "mysql\|backup\|dump" "$cron_file" 2>/dev/null; then
                echo "  File: ${cron_file}" | tee -a "${LOG_FILE}"
                grep -i "mysql\|backup\|dump" "$cron_file" | sed 's/^/    /' | tee -a "${LOG_FILE}"
                echo "" | tee -a "${LOG_FILE}"
            fi
        fi
    done
}

check_recent_backup_activity() {
    print_header "Recent Backup Activity"

    log_info "Checking system logs for recent backup activity..."

    local log_files=(
        "/var/log/syslog"
        "/var/log/cron"
        "/var/log/cron.log"
        "/var/log/mysql/error.log"
    )

    local today=$(date '+%b %d')

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_info "Checking ${log_file}..."

            # Look for backup-related entries from today between 9-10am
            grep "$today 09:" "$log_file" 2>/dev/null | grep -i "mysql\|backup\|dump" | tail -20 | while IFS= read -r line; do
                log_warning "  ${line}"
            done >> "${LOG_FILE}" 2>&1
        fi
    done
}

estimate_backup_impact() {
    print_header "Backup Resource Impact Estimation"

    log_info "Estimating backup resource requirements..."

    # Check MySQL database sizes
    if command -v mysql &> /dev/null; then
        log_info "Database sizes:"

        mysql -e "SELECT
            table_schema AS 'Database',
            ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
        FROM information_schema.tables
        GROUP BY table_schema
        ORDER BY SUM(data_length + index_length) DESC;" 2>/dev/null | tee -a "${LOG_FILE}" || log_warning "Could not query database sizes"
    else
        log_warning "MySQL client not available for size estimation"
    fi

    echo "" | tee -a "${LOG_FILE}"

    # Calculate expected backup time based on size
    log_info "Resource impact estimates:"
    echo "  - Small DB (<100MB): ~1-2 minutes, low CPU impact" | tee -a "${LOG_FILE}"
    echo "  - Medium DB (100MB-1GB): ~5-10 minutes, moderate CPU impact" | tee -a "${LOG_FILE}"
    echo "  - Large DB (>1GB): ~15+ minutes, high CPU/IO impact" | tee -a "${LOG_FILE}"
}

generate_summary() {
    print_header "Summary Report"

    log_info "Analysis completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log file saved to: ${LOG_FILE}"

    echo "" | tee -a "${LOG_FILE}"
    log_success "MySQL backup analysis complete!"

    cat << EOF | tee -a "${LOG_FILE}"

RECOMMENDATIONS:
1. Schedule backups during off-peak hours (avoid 9-10am)
2. Use incremental backups for large databases
3. Implement backup compression to reduce I/O
4. Monitor backup duration and resource usage
5. Consider using mysqlhotcopy or replication for large databases

OPTIMAL BACKUP TIMES:
- Late night: 2-4am (lowest traffic)
- Early morning: 5-7am (before business hours)
- Mid-afternoon: 2-3pm (if daily backup needed)

NEXT STEPS:
- Run: monitor-php-fpm.sh to check PHP processing impact
- Run: log-resource-usage.sh to track actual resource consumption during backups
- Run: morning-monitor.sh for comprehensive morning peak analysis
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting MySQL Backup Detector (${SCRIPT_NAME})"

    check_requirements || exit 1

    detect_mysqldump_processes
    find_backup_scripts
    check_mysql_config
    analyze_backup_schedule
    check_recent_backup_activity
    estimate_backup_impact
    generate_summary

    exit 0
}

# Run main function
main "$@"

################################################################################
# USAGE EXAMPLES
################################################################################
# Basic usage:
#   sudo ./detect-mysql-backups.sh
#
# Run during suspected backup time:
#   ./detect-mysql-backups.sh
#
# Schedule to run at 9:30am to catch morning backups:
#   30 9 * * * /path/to/detect-mysql-backups.sh
#
# Run and email results:
#   ./detect-mysql-backups.sh | mail -s "MySQL Backup Analysis" admin@example.com
################################################################################
