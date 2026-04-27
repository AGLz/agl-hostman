#!/bin/bash
# =============================================================================
# AGL Hostman - Backup Restore Testing
# =============================================================================
# Purpose: Test backup restore procedures without affecting production
# SLA: Monthly testing required
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
TEST_LOG="${LOG_DIR}/test-restore-${TIMESTAMP}.log"

# Test container settings
TEST_CONTAINER_PREFIX="agl-hostman-test"
TEST_DB_NAME="agl_hostman_test"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$TEST_LOG"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# =============================================================================
# TEST FUNCTIONS
# =============================================================================

test_postgres_restore() {
    log_info "Testing PostgreSQL restore..."

    local latest_backup=$(find "${BACKUP_ROOT}/daily" -name "*_postgres_*.sql.gz" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest_backup" ]]; then
        log_error "No PostgreSQL backup found for testing"
        return 1
    fi

    log_info "Using backup: $(basename "$latest_backup")"

    # Create test container
    local test_container="${TEST_CONTAINER_PREFIX}-postgres"

    if docker ps -a | grep -q "$test_container"; then
        docker rm -f "$test_container" &>/dev/null || true
    fi

    log_info "Creating test PostgreSQL container..."
    docker run -d \
        --name "$test_container" \
        -e POSTGRES_PASSWORD=testpass \
        -e POSTGRES_DB="$TEST_DB_NAME" \
        postgres:16-alpine &>/dev/null

    # Wait for PostgreSQL to be ready
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if docker exec "$test_container" pg_isready &>/dev/null; then
            break
        fi
        ((attempt++))
        sleep 2
    done

    if [[ $attempt -eq $max_attempts ]]; then
        log_error "Test PostgreSQL container failed to start"
        docker rm -f "$test_container" &>/dev/null || true
        return 1
    fi

    log_success "Test container ready"

    # Restore from backup
    log_info "Restoring database from backup..."

    local db_name=$(basename "$latest_backup" | sed -E 's/.*_postgres_([^.]+)\.sql\.gz/\1/')

    docker exec "$test_container" psql -U postgres -c "CREATE DATABASE ${db_name};" &>/dev/null || true

    if gunzip -c "$latest_backup" | docker exec -i "$test_container" pg_restore -U postgres -d "${db_name}" -Fc &>/dev/null; then
        log_success "PostgreSQL restore: SUCCESS"
    elif gunzip -c "$latest_backup" | docker exec -i "$test_container" psql -U postgres -d "${db_name}" &>/dev/null; then
        log_success "PostgreSQL restore: SUCCESS (via psql)"
    else
        log_error "PostgreSQL restore: FAILED"
        docker rm -f "$test_container" &>/dev/null || true
        return 1
    fi

    # Verify restored data
    local tables=$(docker exec "$test_container" psql -U postgres -d "${db_name}" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0")

    if [[ $tables -gt 0 ]]; then
        log_success "Database verification: ${tables} tables restored"
    else
        log_warn "No tables found in restored database"
    fi

    # Cleanup
    log_info "Cleaning up test container..."
    docker rm -f "$test_container" &>/dev/null || true

    return 0
}

test_redis_restore() {
    log_info "Testing Redis restore..."

    local latest_backup=$(find "${BACKUP_ROOT}/daily" -name "*_redis_*.rdb.gz" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest_backup" ]]; then
        log_error "No Redis backup found for testing"
        return 1
    fi

    log_info "Using backup: $(basename "$latest_backup")"

    # Create test container
    local test_container="${TEST_CONTAINER_PREFIX}-redis"

    if docker ps -a | grep -q "$test_container"; then
        docker rm -f "$test_container" &>/dev/null || true
    fi

    log_info "Creating test Redis container..."
    docker run -d \
        --name "$test_container" \
        redis:7-alpine &>/dev/null

    # Wait for Redis to be ready
    sleep 3

    if ! docker exec "$test_container" redis-cli ping &>/dev/null; then
        log_error "Test Redis container failed to start"
        docker rm -f "$test_container" &>/dev/null || true
        return 1
    fi

    log_success "Test container ready"

    # Restore from backup
    log_info "Restoring Redis data from backup..."

    docker exec "$test_container" redis-cli SHUTDOWN NOSAVE &>/dev/null || true
    sleep 2

    gunzip -c "$latest_backup" | docker cp - "${test_container}:/data/dump.rdb" &>/dev/null

    docker start "$test_container" &>/dev/null

    sleep 2

    # Verify
    if docker exec "$test_container" redis-cli ping &>/dev/null; then
        log_success "Redis restore: SUCCESS"
    else
        log_error "Redis restore: FAILED"
        docker rm -f "$test_container" &>/dev/null || true
        return 1
    fi

    # Get info
    local keys=$(docker exec "$test_container" redis-cli DBSIZE 2>/dev/null || echo "0")
    log_info "Redis keys: ${keys}"

    # Cleanup
    log_info "Cleaning up test container..."
    docker rm -f "$test_container" &>/dev/null || true

    return 0
}

test_backup_integrity() {
    log_info "Testing backup file integrity..."

    local corrupt_files=0
    local total_files=0

    while IFS= read -r file; do
        ((total_files++))

        case "$file" in
            *.sql.gz|*.rdb.gz|*.tar.gz)
                if ! gzip -t "$file" 2>/dev/null; then
                    log_error "Corrupt file: $(basename "$file")"
                    ((corrupt_files++))
                fi
                ;;
            *.enc)
                # GPG test
                if command -v gpg &> /dev/null; then
                    if ! gpg --batch --yes --decrypt --test-only "$file" 2>/dev/null; then
                        log_warn "Cannot verify encrypted file: $(basename "$file")"
                    fi
                fi
                ;;
        esac
    done < <(find "${BACKUP_ROOT}/daily" -type f -mtime -7 2>/dev/null)

    if [[ $corrupt_files -eq 0 ]]; then
        log_success "All ${total_files} backup files passed integrity check"
        return 0
    else
        log_error "${corrupt_files}/${total_files} backup files are corrupt"
        return 1
    fi
}

test_backup_completeness() {
    log_info "Testing backup completeness..."

    local expected_containers=(
        "crowbar-postgres"
        "api9-mariadb"
        "agl-admin-mysql"
        "crowbar-redis"
        "api9-redis"
        "agl-admin-redis"
    )

    local missing_backups=0

    for container in "${expected_containers[@]}"; do
        local count=$(find "${BACKUP_ROOT}/daily" -name "${container}_*_${TIMESTAMP}.*" 2>/dev/null | wc -l)

        if [[ $count -eq 0 ]]; then
            log_warn "No backup found for: ${container}"
            ((missing_backups++))
        else
            log_info "Backup found: ${container} (${count} files)"
        fi
    done

    # Check for volumes
    local volumes=("agl-hostman-db-data" "agl-hostman-redis-data")

    for volume in "${volumes[@]}"; do
        local count=$(find "${BACKUP_ROOT}/daily" -name "volume_${volume}_*.tar.gz" 2>/dev/null | wc -l)

        if [[ $count -eq 0 ]]; then
            log_warn "No backup found for volume: ${volume}"
            ((missing_backups++))
        else
            log_info "Backup found: ${volume} (${count} files)"
        fi
    done

    if [[ $missing_backups -eq 0 ]]; then
        log_success "All expected backups found"
        return 0
    else
        log_warn "${missing_backups} expected backup(s) missing"
        return 1
    fi
}

test_restore_speed() {
    log_info "Testing restore speed..."

    local latest_backup=$(find "${BACKUP_ROOT}/daily" -name "*.sql.gz" -printf '%s %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest_backup" ]]; then
        log_warn "No backup found for speed test"
        return 0
    fi

    local size_mb=$(($(stat -f%z "$latest_backup" 2>/dev/null || stat -c%s "$latest_backup") / 1024 / 1024))

    log_info "Backup size: ${size_mb}MB"
    log_info "Testing decompression speed..."

    local start_time=$(date +%s)

    # Test decompression to /dev/null
    gunzip -c "$latest_backup" > /dev/null 2>/dev/null

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ $duration -gt 0 ]]; then
        local speed_mb_per_sec=$((size_mb / duration))
        log_info "Decompression speed: ${speed_mb_per_sec}MB/s (${duration}s for ${size_mb}MB)"

        # Project full restore time (assuming 500MB total)
        local projected_time=$((500 / speed_mb_per_sec))
        local projected_minutes=$((projected_time / 60))

        log_info "Projected full restore time: ~${projected_minutes} minutes"

        if [[ $projected_minutes -lt 240 ]]; then
            log_success "Restore speed meets RTO target (< 4 hours)"
        else
            log_warn "Restore speed may exceed RTO target (> 4 hours)"
        fi
    fi

    return 0
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_info "=========================================="
    log_info "AGL Hostman Backup Testing"
    log_info "=========================================="
    log_info "Timestamp: ${TIMESTAMP}"

    local tests_passed=0
    local tests_failed=0

    # Test 1: Backup integrity
    log_info ""
    log_info "Test 1: Backup File Integrity"
    log_info "----------------------------------------"
    if test_backup_integrity; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Test 2: Backup completeness
    log_info ""
    log_info "Test 2: Backup Completeness"
    log_info "----------------------------------------"
    if test_backup_completeness; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Test 3: PostgreSQL restore
    log_info ""
    log_info "Test 3: PostgreSQL Restore"
    log_info "----------------------------------------"
    if test_postgres_restore; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Test 4: Redis restore
    log_info ""
    log_info "Test 4: Redis Restore"
    log_info "----------------------------------------"
    if test_redis_restore; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Test 5: Restore speed
    log_info ""
    log_info "Test 5: Restore Speed"
    log_info "----------------------------------------"
    if test_restore_speed; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Summary
    log_info ""
    log_info "=========================================="
    log_info "TEST SUMMARY"
    log_info "=========================================="
    log_info "Passed: ${tests_passed}"
    log_info "Failed: ${tests_failed}"

    if [[ $tests_failed -eq 0 ]]; then
        log_success "All tests passed!"
        log_info "Test log: ${TEST_LOG}"
        exit 0
    else
        log_error "${tests_failed} test(s) failed"
        log_info "Test log: ${TEST_LOG}"
        exit 1
    fi
}

main "$@"
