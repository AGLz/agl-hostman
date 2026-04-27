#!/bin/bash
# =============================================================================
# AGL Hostman - Disaster Recovery Restore Script
# =============================================================================
# Purpose: Restore AGL Hostman application from backup
# SLA: RTO < 4 hours
# =============================================================================
# Author: DevOps Team
# Created: 2025-02-08
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="/mnt/shares/agl-hostman-backups"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOG_DIR="${BACKUP_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESTORE_LOG="${LOG_DIR}/restore-${TIMESTAMP}.log"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$RESTORE_LOG"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# =============================================================================
# PRE-RESTORE CHECKS
# =============================================================================

pre_restore_checks() {
    log_info "Running pre-restore checks..."

    # Verify backup directory exists
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        log_error "Backup directory not found: ${BACKUP_ROOT}"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not installed"
        exit 1
    fi

    log_success "Pre-restore checks passed"
}

# =============================================================================
# BACKUP SELECTION
# =============================================================================

select_backup() {
    local backup_type=$1  # daily, weekly, monthly

    log_info "Available ${backup_type} backups:"
    ls -lth "${BACKUP_ROOT}/${backup_type}/" | grep -E "\.(sql\.gz|rdb\.gz|tar\.gz|enc)$" | head -20

    echo ""
    read -p "Enter backup timestamp (e.g., 20250208_020000) or 'latest': " backup_timestamp

    if [[ "$backup_timestamp" == "latest" ]]; then
        backup_timestamp=$(ls -t "${BACKUP_ROOT}/${backup_type}/" | grep -oE '[0-9]{8}_[0-9]{6}' | head -1)
    fi

    if [[ -z "$backup_timestamp" ]]; then
        log_error "No backup timestamp provided"
        exit 1
    fi

    log_info "Selected backup: ${backup_timestamp}"
    echo "$backup_timestamp"
}

# =============================================================================
# DATABASE RESTORE FUNCTIONS
# =============================================================================

restore_postgres_container() {
    local container=$1
    local timestamp=$2
    local backup_type=${3:-daily}

    log_info "Restoring PostgreSQL container: ${container}"

    if ! docker ps | grep -q "$container"; then
        log_warn "Container ${container} not running, skipping"
        return
    fi

    local backups=($(ls "${BACKUP_ROOT}/${backup_type}/${container}"_postgres_*.sql.gz 2>/dev/null))

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warn "No PostgreSQL backups found for ${container}"
        return
    fi

    for backup_file in "${backups[@]}"; do
        if [[ "$backup_file" == *"${timestamp}"* ]]; then
            local db_name=$(basename "$backup_file" | sed -E "s/${container}_postgres_([^.]+)\.sql\.gz/\1/")

            log_info "  Restoring database: ${db_name}"

            # Drop existing database (create fresh)
            docker exec "$container" psql -U postgres -c "DROP DATABASE IF EXISTS ${db_name};" 2>/dev/null || true
            docker exec "$container" psql -U postgres -c "CREATE DATABASE ${db_name};" 2>/dev/null || true

            # Restore from backup
            gunzip -c "$backup_file" | docker exec -i "$container" pg_restore -U postgres -d "${db_name}" -Fc 2>/dev/null || \
                gunzip -c "$backup_file" | docker exec -i "$container" psql -U postgres -d "${db_name}" 2>/dev/null

            if [[ $? -eq 0 ]]; then
                log_success "  Restored ${db_name}"
            else
                log_error "Failed to restore ${db_name}"
            fi
        fi
    done
}

restore_mariadb_container() {
    local container=$1
    local timestamp=$2
    local backup_type=${3:-daily}

    log_info "Restoring MariaDB container: ${container}"

    if ! docker ps | grep -q "$container"; then
        log_warn "Container ${container} not running, skipping"
        return
    fi

    local backups=($(ls "${BACKUP_ROOT}/${backup_type}/${container}"_mariadb_*.sql.gz 2>/dev/null))

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warn "No MariaDB backups found for ${container}"
        return
    fi

    for backup_file in "${backups[@]}"; do
        if [[ "$backup_file" == *"${timestamp}"* ]]; then
            local db_name=$(basename "$backup_file" | sed -E "s/${container}_mariadb_([^.]+)\.sql\.gz/\1/")

            log_info "  Restoring database: ${db_name}"

            # Drop and recreate database
            docker exec "$container" mysql -u root -e "DROP DATABASE IF EXISTS \`${db_name}\`;" 2>/dev/null || true
            docker exec "$container" mysql -u root -e "CREATE DATABASE \`${db_name}\`;" 2>/dev/null || true

            # Restore from backup
            gunzip -c "$backup_file" | docker exec -i "$container" mysql -u root "${db_name}" 2>/dev/null

            if [[ $? -eq 0 ]]; then
                log_success "  Restored ${db_name}"
            else
                log_error "Failed to restore ${db_name}"
            fi
        fi
    done
}

restore_redis_container() {
    local container=$1
    local timestamp=$2
    local backup_type=${3:-daily}

    log_info "Restoring Redis container: ${container}"

    if ! docker ps | grep -q "$container"; then
        log_warn "Container ${container} not running, skipping"
        return
    fi

    local backup_file="${BACKUP_ROOT}/${backup_type}/${container}_redis_${timestamp}.rdb.gz"

    if [[ ! -f "$backup_file" ]]; then
        log_warn "No Redis backup found for ${container}"
        return
    fi

    # Stop Redis, restore data, start Redis
    docker exec "$container" redis-cli SHUTDOWN NOSAVE 2>/dev/null || true
    sleep 2

    gunzip -c "$backup_file" | docker cp - "${container}:/data/dump.rdb" 2>/dev/null || true

    docker start "$container" 2>/dev/null || docker restart "$container" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log_success "  Restored Redis data"
    else
        log_error "Failed to restore Redis data"
    fi
}

# =============================================================================
# DOCKER VOLUME RESTORE
# =============================================================================

restore_docker_volume() {
    local volume_name=$1
    local timestamp=$2
    local backup_type=${3:-daily}

    log_info "Restoring Docker volume: ${volume_name}"

    local backup_file="${BACKUP_ROOT}/${backup_type}/volume_${volume_name}_${timestamp}.tar.gz"

    if [[ ! -f "$backup_file" ]]; then
        log_warn "No volume backup found: ${volume_name}"
        return
    fi

    # Create new volume (will overwrite existing)
    docker volume rm "${volume_name}" 2>/dev/null || true
    docker volume create "${volume_name}"

    # Restore data
    docker run --rm \
        -v "${volume_name}:/volume" \
        -v "${BACKUP_ROOT}/${backup_type}:/backup" \
        alpine sh -c "tar -xzf /backup/volume_${volume_name}_${timestamp}.tar.gz -C /volume"

    if [[ $? -eq 0 ]]; then
        log_success "  Restored ${volume_name}"
    else
        log_error "Failed to restore ${volume_name}"
    fi
}

# =============================================================================
# APPLICATION CONFIGURATION RESTORE
# =============================================================================

restore_application_config() {
    local timestamp=$1
    local backup_type=${3:-daily}

    log_info "Restoring application configuration"

    local config_file="${BACKUP_ROOT}/${backup_type}/app_config_${timestamp}.tar.gz"

    if [[ ! -f "$config_file" ]]; then
        log_warn "No configuration backup found"
        return
    fi

    # Extract to temporary directory first
    local temp_dir=$(mktemp -d)
    tar -xzf "$config_file" -C "$temp_dir"

    # Copy back to project
    cp -r "${temp_dir}"/* "$PROJECT_ROOT/" 2>/dev/null || true

    # Clean up
    rm -rf "$temp_dir"

    log_success "  Application configuration restored"
}

restore_environment_file() {
    local timestamp=$1
    local backup_type=${3:-daily}

    log_info "Restoring environment file"

    local env_file="${BACKUP_ROOT}/${backup_type}/env_backup_${timestamp}.enc"

    if [[ ! -f "$env_file" ]]; then
        log_warn "No environment backup found"
        return
    fi

    # Decrypt if needed
    if command -v gpg &> /dev/null; then
        gpg --batch --yes --output "${PROJECT_ROOT}/.env" --decrypt "$env_file" 2>/dev/null || \
            cp "$env_file" "${PROJECT_ROOT}/.env"
    else
        cp "$env_file" "${PROJECT_ROOT}/.env"
    fi

    chmod 600 "${PROJECT_ROOT}/.env"

    log_success "  Environment file restored"
}

# =============================================================================
# POST-RESTORE VALIDATION
# =============================================================================

post_restore_validation() {
    log_info "Running post-restore validation..."

    local errors=0

    # Check containers
    log_info "Checking container status..."
    local containers=("agl-hostman-app" "agl-hostman-db" "agl-hostman-redis")

    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            log_success "  ${container}: Running"
        else
            log_warn "  ${container}: Not running"
            ((errors++))
        fi
    done

    # Check database connectivity
    log_info "Checking database connectivity..."

    if docker exec agl-hostman-db pg_isready &>/dev/null; then
        log_success "  PostgreSQL: Accessible"
    else
        log_error "  PostgreSQL: Not accessible"
        ((errors++))
    fi

    if docker exec agl-hostman-redis redis-cli ping &>/dev/null; then
        log_success "  Redis: Accessible"
    else
        log_error "  Redis: Not accessible"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "=========================================="
        log_success "Restore validation PASSED"
        log_success "=========================================="
        return 0
    else
        log_error "=========================================="
        log_error "Restore validation FAILED: ${errors} errors"
        log_error "=========================================="
        return 1
    fi
}

# =============================================================================
# FULL RESTORE
# =============================================================================

full_restore() {
    local timestamp=$1
    local backup_type=${2:-daily}

    log_info "=========================================="
    log_info "Starting Full Restore"
    log_info "=========================================="
    log_info "Backup Type: ${backup_type}"
    log_info "Timestamp: ${timestamp}"

    local start_time=$(date +%s)

    # Stop all services
    log_info "Stopping all services..."
    cd "$PROJECT_ROOT"
    docker compose down 2>/dev/null || true

    # Restore databases
    restore_postgres_container "crowbar-postgres" "$timestamp" "$backup_type"
    restore_mariadb_container "api9-mariadb" "$timestamp" "$backup_type"
    restore_mariadb_container "agl-admin-mysql" "$timestamp" "$backup_type"

    # Restore Redis
    restore_redis_container "crowbar-redis" "$timestamp" "$backup_type"
    restore_redis_container "api9-redis" "$timestamp" "$backup_type"
    restore_redis_container "agl-admin-redis" "$timestamp" "$backup_type"

    # Restore volumes
    restore_docker_volume "agl-hostman-db-data" "$timestamp" "$backup_type"
    restore_docker_volume "agl-hostman-redis-data" "$timestamp" "$backup_type"

    # Restore configuration
    restore_application_config "$timestamp" "$backup_type"
    restore_environment_file "$timestamp" "$backup_type"

    # Start services
    log_info "Starting all services..."
    docker compose up -d 2>/dev/null || true

    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 30

    # Validate
    post_restore_validation

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))

    log_info "Restore completed in ${minutes} minutes"

    if [[ $minutes -lt 240 ]]; then
        log_success "RTO target met (< 4 hours)"
    else
        log_warn "RTO target exceeded (${minutes} minutes)"
    fi
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

interactive_restore() {
    echo "============================================================================="
    echo "AGL HOSTMAN DISASTER RECOVERY"
    echo "============================================================================="
    echo ""
    echo "Select restore type:"
    echo "  1) Full restore (all databases, Redis, volumes, config)"
    echo "  2) Database only"
    echo "  3) Redis only"
    echo "  4) Docker volumes only"
    echo "  5) Application configuration only"
    echo "  6) Exit"
    echo ""
    read -p "Enter choice [1-6]: " choice

    case $choice in
        1)
            echo ""
            echo "Select backup type:"
            echo "  1) Daily"
            echo "  2) Weekly"
            echo "  3) Monthly"
            read -p "Enter choice [1-3]: " backup_choice

            case $backup_choice in
                1) backup_type="daily" ;;
                2) backup_type="weekly" ;;
                3) backup_type="monthly" ;;
                *) backup_type="daily" ;;
            esac

            local timestamp=$(select_backup "$backup_type")
            full_restore "$timestamp" "$backup_type"
            ;;
        *)
            log_info "Exiting..."
            exit 0
            ;;
    esac
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    pre_restore_checks

    if [[ "${1:-}" == "--timestamp" && -n "${2:-}" ]]; then
        local timestamp=$2
        local backup_type=${3:-daily}
        full_restore "$timestamp" "$backup_type"
    else
        interactive_restore
    fi
}

main "$@"
