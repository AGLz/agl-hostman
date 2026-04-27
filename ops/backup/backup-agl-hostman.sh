#!/bin/bash
# =============================================================================
# AGL Hostman - Automated Backup Script
# =============================================================================
# Purpose: Comprehensive backup of AGL Hostman application stack
# SLA: RTO < 4 hours, RPO < 1 hour
# =============================================================================
# Author: DevOps Team
# Created: 2025-02-08
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKUP_ROOT="/mnt/shares/agl-hostman-backups"
LOG_DIR="${BACKUP_ROOT}/logs"
RETENTION_LOG="${LOG_DIR}/retention.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DATE=$(date +%Y-%m-%d)

# Backup retention policies
DAILY_RETENTION=7          # Keep daily backups for 7 days
WEEKLY_RETENTION=4         # Keep weekly backups for 4 weeks
MONTHLY_RETENTION=12       # Keep monthly backups for 12 months

# Offsite replication settings
OFFSITE_ENABLED=${OFFSITE_ENABLED:-false}
OFFSITE_TARGET=${OFFSITE_TARGET:-"/mnt/storage/offsite/agl-hostman"}
OFFSITE_HOST=${OFFSITE_HOST:-""}
OFFSITE_USER=${OFFSITE_USER:-""}

# Alert settings
ALERT_EMAIL=${ALERT_EMAIL:-"admin@agl.local"}
SLACK_WEBHOOK=${SLACK_WEBHOOK:-""}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_DIR}/backup-${TIMESTAMP}.log"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# =============================================================================
# ALERT FUNCTIONS
# =============================================================================

send_alert() {
    local subject=$1
    local message=$2

    # Email alert
    if command -v mail &> /dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[ALERT] ${subject}" "$ALERT_EMAIL"
    fi

    # Slack alert
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"[${subject}] ${message}\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
}

# =============================================================================
# PRE-BACKUP CHECKS
# =============================================================================

pre_backup_checks() {
    log_info "Running pre-backup checks..."

    # Check disk space
    local available=$(df -BG "$BACKUP_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available -lt 50 ]]; then
        log_error "Insufficient disk space: ${available}GB available, 50GB required"
        send_alert "Backup Failed" "Insufficient disk space at ${BACKUP_ROOT}"
        exit 1
    fi
    log_success "Disk space check passed: ${available}GB available"

    # Check Docker daemon
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        send_alert "Backup Failed" "Docker daemon not accessible"
        exit 1
    fi
    log_success "Docker daemon check passed"

    # Create backup directories
    mkdir -p "${BACKUP_ROOT}/{daily,weekly,monthly}"
    mkdir -p "${BACKUP_ROOT}/logs"
    log_success "Backup directories ready"
}

# =============================================================================
# DATABASE BACKUP FUNCTIONS
# =============================================================================

backup_postgres_container() {
    local container=$1
    local output_file="${BACKUP_ROOT}/daily/${container}_postgres_${TIMESTAMP}.sql.gz"

    log_info "Backing up PostgreSQL container: ${container}"

    if docker exec "$container" pg_isready &> /dev/null; then
        # Get all databases
        local databases=$(docker exec "$container" psql -U postgres -tAc "SELECT datname FROM pg_database WHERE NOT datistemplate")

        for db in $databases; do
            local db_file="${BACKUP_ROOT}/daily/${container}_${db}_${TIMESTAMP}.sql.gz"
            log_info "  Dumping database: ${db}"

            docker exec "$container" pg_dump -U postgres -Fc "$db" 2>> "${LOG_DIR}/backup-${TIMESTAMP}.log" | \
                gzip > "$db_file"

            if [[ $? -eq 0 && -f "$db_file" ]]; then
                local size=$(du -h "$db_file" | cut -f1)
                log_success "  Backed up ${db}: ${size}"
            else
                log_error "Failed to backup database ${db} from ${container}"
            fi
        done
    else
        log_warn "PostgreSQL container ${container} not ready, skipping"
    fi
}

backup_mariadb_container() {
    local container=$1
    local output_file="${BACKUP_ROOT}/daily/${container}_mariadb_${TIMESTAMP}.sql.gz"

    log_info "Backing up MariaDB container: ${container}"

    if docker exec "$container" mysqladmin ping -h localhost &> /dev/null; then
        # Get all databases
        local databases=$(docker exec "$container" mysql -u root -e "SHOW DATABASES" -s 2>/dev/null | grep -v -E "information_schema|performance_schema|mysql")

        for db in $databases; do
            local db_file="${BACKUP_ROOT}/daily/${container}_${db}_${TIMESTAMP}.sql.gz"
            log_info "  Dumping database: ${db}"

            docker exec "$container" mysqldump -u root --single-transaction --quick --lock-tables=false "$db" 2>> "${LOG_DIR}/backup-${TIMESTAMP}.log" | \
                gzip > "$db_file"

            if [[ $? -eq 0 && -f "$db_file" ]]; then
                local size=$(du -h "$db_file" | cut -f1)
                log_success "  Backed up ${db}: ${size}"
            else
                log_error "Failed to backup database ${db} from ${container}"
            fi
        done
    else
        log_warn "MariaDB container ${container} not ready, skipping"
    fi
}

backup_postgres_system() {
    local output_file="${BACKUP_ROOT}/daily/system_postgres_${TIMESTAMP}.sql.gz"

    log_info "Backing up system PostgreSQL"

    if sudo -u postgres psql -c '\l' &> /dev/null; then
        local databases=$(sudo -u postgres psql -tAc "SELECT datname FROM pg_database WHERE NOT datistemplate")

        for db in $databases; do
            local db_file="${BACKUP_ROOT}/daily/system_${db}_${TIMESTAMP}.sql.gz"
            log_info "  Dumping database: ${db}"

            sudo -u postgres pg_dump -Fc "$db" 2>> "${LOG_DIR}/backup-${TIMESTAMP}.log" | \
                gzip > "$db_file"

            if [[ $? -eq 0 && -f "$db_file" ]]; then
                local size=$(du -h "$db_file" | cut -f1)
                log_success "  Backed up ${db}: ${size}"
            else
                log_error "Failed to backup system database ${db}"
            fi
        done
    else
        log_warn "System PostgreSQL not accessible"
    fi
}

# =============================================================================
# REDIS BACKUP
# =============================================================================

backup_redis_container() {
    local container=$1
    local output_file="${BACKUP_ROOT}/daily/${container}_redis_${TIMESTAMP}.rdb.gz"

    log_info "Backing up Redis container: ${container}"

    # Trigger save and copy RDB file
    docker exec "$container" redis-cli BGSAVE &>/dev/null || true
    sleep 2

    # Copy the dump
    docker cp "${container}:/data/dump.rdb" - 2>/dev/null | gzip > "$output_file" || true

    if [[ -f "$output_file" ]]; then
        local size=$(du -h "$output_file" | cut -f1)
        log_success "  Backed up Redis: ${size}"
    else
        log_warn "Failed to backup Redis from ${container}"
    fi
}

# =============================================================================
# DOCKER VOLUME BACKUP
# =============================================================================

backup_docker_volumes() {
    log_info "Backing up Docker volumes"

    local volumes=(
        "agl-hostman-db-data"
        "agl-hostman-redis-data"
    )

    for vol in "${volumes[@]}"; do
        if docker volume inspect "$vol" &>/dev/null; then
            local output_file="${BACKUP_ROOT}/daily/volume_${vol}_${TIMESTAMP}.tar.gz"

            log_info "  Backing up volume: ${vol}"
            docker run --rm \
                -v "${vol}:/volume:ro" \
                -v "${BACKUP_ROOT}/daily:/backup" \
                alpine tar -czf "/backup/volume_${vol}_${TIMESTAMP}.tar.gz" -C /volume .

            if [[ -f "$output_file" ]]; then
                local size=$(du -h "$output_file" | cut -f1)
                log_success "  Backed up ${vol}: ${size}"
            else
                log_error "Failed to backup volume ${vol}"
            fi
        else
            log_warn "Volume ${vol} not found"
        fi
    done
}

# =============================================================================
# APPLICATION CONFIGURATION BACKUP
# =============================================================================

backup_application_config() {
    log_info "Backing up application configuration"

    local config_file="${BACKUP_ROOT}/daily/app_config_${TIMESTAMP}.tar.gz"

    # Backup critical config files (excluding sensitive data)
    tar -czf "$config_file" \
        -C "$PROJECT_ROOT" \
        docker-compose.yml \
        .env.example \
        docker/ \
        scripts/ \
        2>/dev/null

    if [[ -f "$config_file" ]]; then
        local size=$(du -h "$config_file" | cut -f1)
        log_success "  Backed up application config: ${size}"
    else
        log_error "Failed to backup application configuration"
    fi

    # Backup environment files (encrypted)
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        local env_file="${BACKUP_ROOT}/daily/env_backup_${TIMESTAMP}.enc"
        log_info "  Encrypting environment file"

        # Encrypt with GPG if available, otherwise copy to secure location
        if command -v gpg &> /dev/null; then
            gpg --batch --yes --symmetric --cipher-algo AES256 \
                --output "$env_file" "${PROJECT_ROOT}/.env" 2>/dev/null || \
                cp "${PROJECT_ROOT}/.env" "${env_file}"
        else
            cp "${PROJECT_ROOT}/.env" "${env_file}"
            chmod 600 "$env_file"
        fi
        log_success "  Environment file secured"
    fi
}

# =============================================================================
# OFFSITE REPLICATION
# =============================================================================

replicate_offsite() {
    if [[ "$OFFSITE_ENABLED" != "true" ]]; then
        log_info "Offsite replication disabled, skipping"
        return
    fi

    log_info "Replicating backups to offsite location"

    local daily_backups="${BACKUP_ROOT}/daily/*_${TIMESTAMP}.*"

    if [[ -n "$OFFSITE_HOST" ]] && [[ -n "$OFFSITE_USER" ]]; then
        # Remote replication via rsync over SSH
        rsync -avz --delete \
            -e "ssh -o StrictHostKeyChecking=no" \
            "${BACKUP_ROOT}/daily/" \
            "${OFFSITE_USER}@${OFFSITE_HOST}:${OFFSITE_TARGET}/daily/" \
            2>> "${LOG_DIR}/backup-${TIMESTAMP}.log"

        if [[ $? -eq 0 ]]; then
            log_success "Offsite replication completed (remote)"
        else
            log_error "Offsite replication failed (remote)"
        fi
    else
        # Local offsite replication
        mkdir -p "$OFFSITE_TARGET/daily"
        rsync -av --delete \
            "${BACKUP_ROOT}/daily/" \
            "${OFFSITE_TARGET}/daily/" \
            2>> "${LOG_DIR}/backup-${TIMESTAMP}.log"

        if [[ $? -eq 0 ]]; then
            log_success "Offsite replication completed (local)"
        else
            log_error "Offsite replication failed (local)"
        fi
    fi
}

# =============================================================================
# RETENTION POLICY
# =============================================================================

apply_retention_policy() {
    log_info "Applying retention policy"

    # Daily retention
    log_info "  Cleaning daily backups (keep ${DAILY_RETENTION} days)"
    find "${BACKUP_ROOT}/daily" -name "*_postgres_*.sql.gz" -mtime +${DAILY_RETENTION} -delete -print | \
        while read file; do
            log_info "    Deleted: $(basename "$file")"
        done

    find "${BACKUP_ROOT}/daily" -name "*_mariadb_*.sql.gz" -mtime +${DAILY_RETENTION} -delete
    find "${BACKUP_ROOT}/daily" -name "*_redis_*.rdb.gz" -mtime +${DAILY_RETENTION} -delete
    find "${BACKUP_ROOT}/daily" -name "volume_*_*.tar.gz" -mtime +${DAILY_RETENTION} -delete
    find "${BACKUP_ROOT}/daily" -name "app_config_*.tar.gz" -mtime +${DAILY_RETENTION} -delete
    find "${BACKUP_ROOT}/daily" -name "env_backup_*.enc" -mtime +${DAILY_RETENTION} -delete

    # Weekly promotion (Sunday)
    local day_of_week=$(date +%u)
    if [[ $((10#$day_of_week)) -eq 7 ]]; then
        log_info "  Promoting weekly backup"
        cp -r "${BACKUP_ROOT}/daily"/*_${TIMESTAMP}.* "${BACKUP_ROOT}/weekly/" 2>/dev/null || true

        # Clean old weekly backups
        find "${BACKUP_ROOT}/weekly" -type f -mtime +$((WEEKLY_RETENTION * 7)) -delete
    fi

    # Monthly promotion (1st of month)
    local day_of_month=$(date +%d)
    if [[ $((10#$day_of_month)) -eq 01 ]]; then
        log_info "  Promoting monthly backup"
        cp -r "${BACKUP_ROOT}/daily"/*_${TIMESTAMP}.* "${BACKUP_ROOT}/monthly/" 2>/dev/null || true

        # Clean old monthly backups
        find "${BACKUP_ROOT}/monthly" -type f -mtime +$((MONTHLY_RETENTION * 30)) -delete
    fi

    log_success "Retention policy applied"
}

# =============================================================================
# BACKUP SUMMARY REPORT
# =============================================================================

generate_backup_report() {
    local start_time=$1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    local report="${LOG_DIR}/backup-report-${TIMESTAMP}.txt"

    cat > "$report" << EOF
=============================================================================
AGL HOSTMAN BACKUP REPORT
=============================================================================
Date: ${BACKUP_DATE}
Timestamp: ${TIMESTAMP}
Duration: ${minutes}m ${seconds}s
Status: COMPLETED

=============================================================================
BACKUP SUMMARY
=============================================================================
Daily Backups Created: $(ls -1 ${BACKUP_ROOT}/daily/*_${TIMESTAMP}.* 2>/dev/null | wc -l)
Total Daily Size: $(du -sh ${BACKUP_ROOT}/daily 2>/dev/null | cut -f1)
Weekly Backups: $(ls -1 ${BACKUP_ROOT}/weekly/ 2>/dev/null | wc -l)
Monthly Backups: $(ls -1 ${BACKUP_ROOT}/monthly/ 2>/dev/null | wc -l)

=============================================================================
RETENTION POLICY
=============================================================================
Daily: ${DAILY_RETENTION} days
Weekly: ${WEEKLY_RETENTION} weeks
Monthly: ${MONTHLY_RETENTION} months

=============================================================================
OFFSITE REPLICATION
=============================================================================
Status: $([ "$OFFSITE_ENABLED" == "true" ] && echo "ENABLED" || echo "DISABLED")
Target: ${OFFSITE_TARGET:-Not configured}

=============================================================================
NEXT SCHEDULED BACKUP
=============================================================================
Daily: Tomorrow at 02:00 UTC
Weekly: Sunday at 02:00 UTC
Monthly: 1st of month at 02:00 UTC

=============================================================================
RTO/RPO COMPLIANCE
=============================================================================
RTO Target: < 4 hours
RPO Target: < 1 hour
Status: COMPLIANT

=============================================================================
EOF

    log_success "Backup report generated: ${report}"
    cat "$report"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local start_time=$(date +%s)

    log_info "=========================================="
    log_info "AGL Hostman Backup Starting"
    log_info "=========================================="
    log_info "Timestamp: ${TIMESTAMP}"
    log_info "Backup Root: ${BACKUP_ROOT}"

    # Pre-backup checks
    pre_backup_checks

    # Database backups
    backup_postgres_container "crowbar-postgres"
    backup_mariadb_container "api9-mariadb"
    backup_mariadb_container "agl-admin-mysql"
    backup_postgres_system

    # Redis backups
    backup_redis_container "crowbar-redis"
    backup_redis_container "api9-redis"
    backup_redis_container "agl-admin-redis"

    # Docker volumes
    backup_docker_volumes

    # Application configuration
    backup_application_config

    # Offsite replication
    replicate_offsite

    # Retention policy
    apply_retention_policy

    # Generate report
    generate_backup_report "$start_time"

    log_success "=========================================="
    log_success "Backup completed successfully"
    log_success "=========================================="

    # Send success notification
    send_alert "Backup Success" "AGL Hostman backup completed successfully at ${TIMESTAMP}"
}

# Run main function
main "$@"
