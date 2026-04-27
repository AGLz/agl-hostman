#!/bin/bash
################################################################################
# Automated Restore Testing Script
# Restores backups to staging environment for validation
# Usage: ./backup-restore-test.sh [--backup /path/to/backup] [--type database|files]
################################################################################

set -euo pipefail

# Configuration
BACKUP_PATH="${BACKUP_PATH:-}"
BACKUP_TYPE="${BACKUP_TYPE:-auto}"
STAGING_HOST="${STAGING_HOST:-localhost}"
STAGING_DB_PREFIX="${STAGING_DB_PREFIX:-test_}"
STAGING_DIR="${STAGING_DIR:-/tmp/restore_test}"
CLEANUP_AFTER_TEST="${CLEANUP_AFTER_TEST:-true}"
VALIDATION_QUERIES="${VALIDATION_QUERIES:-}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
        log_info "Cleaning up test environment..."

        # Clean up test database
        if [[ -n "$TEST_DB_NAME" ]]; then
            case "${DB_CONNECTION:-mysql}" in
                mysql|mariadb)
                    mysql -h "${STAGING_HOST}" \
                          -u "${DB_USERNAME:-root}" \
                          -p"${DB_PASSWORD:-}" \
                          -e "DROP DATABASE IF EXISTS \`${TEST_DB_NAME}\`;" 2>/dev/null || true
                    ;;
                postgres|postgresql)
                    dropdb -h "${STAGING_HOST}" \
                           -U "${DB_USERNAME:-postgres}" \
                           "$TEST_DB_NAME" 2>/dev/null || true
                    ;;
            esac
        fi

        # Clean up test directory
        if [[ -d "$STAGING_DIR" ]]; then
            rm -rf "$STAGING_DIR"
        fi

        log_info "Cleanup completed"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Generate unique test identifier
generate_test_id() {
    echo "test_$(date +%s)_$RANDOM"
}

# Auto-detect backup type
auto_detect_type() {
    local file="$1"

    if [[ "$file" =~ \.sql(\.gz)?$ ]]; then
        echo "database"
    elif [[ "$file" =~ \.tar(\.gz)?$ ]]; then
        echo "files"
    else
        echo "unknown"
    fi
}

# Test database restore
test_database_restore() {
    local backup_file="$1"
    local test_id=$(generate_test_id)
    TEST_DB_NAME="${STAGING_DB_PREFIX}${test_id}"

    log_info "=== Testing Database Restore ==="
    log_info "Backup: $backup_file"
    log_info "Test Database: $TEST_DB_NAME"

    # Create test database
    log_info "Creating test database..."
    case "${DB_CONNECTION:-mysql}" in
        mysql|mariadb)
            mysql -h "${STAGING_HOST}" \
                  -u "${DB_USERNAME:-root}" \
                  -p"${DB_PASSWORD:-}" \
                  -e "CREATE DATABASE \`${TEST_DB_NAME}\`;" || {
                log_error "Failed to create test database"
                return 1
            }
            ;;
        postgres|postgresql)
            createdb -h "${STAGING_HOST}" \
                     -U "${DB_USERNAME:-postgres}" \
                     "$TEST_DB_NAME" || {
                log_error "Failed to create test database"
                return 1
            }
            ;;
        sqlite)
            # SQLite doesn't need database creation
            ;;
    esac

    # Restore backup
    log_info "Restoring backup to test database..."
    case "${DB_CONNECTION:-mysql}" in
        mysql|mariadb)
            if [[ "$backup_file" =~ \.gz$ ]]; then
                gunzip -c "$backup_file" | \
                mysql -h "${STAGING_HOST}" \
                      -u "${DB_USERNAME:-root}" \
                      -p"${DB_PASSWORD:-}" \
                      "$TEST_DB_NAME" || {
                    log_error "Restore failed"
                    return 1
                }
            else
                mysql -h "${STAGING_HOST}" \
                      -u "${DB_USERNAME:-root}" \
                      -p"${DB_PASSWORD:-}" \
                      "$TEST_DB_NAME" < "$backup_file" || {
                    log_error "Restore failed"
                    return 1
                }
            fi
            ;;
        postgres|postgresql)
            if [[ "$backup_file" =~ \.gz$ ]]; then
                gunzip -c "$backup_file" | \
                psql -h "${STAGING_HOST}" \
                     -U "${DB_USERNAME:-postgres}" \
                     "$TEST_DB_NAME" || {
                    log_error "Restore failed"
                    return 1
                }
            else
                psql -h "${STAGING_HOST}" \
                     -U "${DB_USERNAME:-postgres}" \
                     "$TEST_DB_NAME" < "$backup_file" || {
                    log_error "Restore failed"
                    return 1
                }
            fi
            ;;
        sqlite)
            local test_db_path="${STAGING_DIR}/${TEST_DB_NAME}.db"
            mkdir -p "$STAGING_DIR"
            cp "$backup_file" "$test_db_path"
            ;;
    esac

    log_info "Restore completed successfully"

    # Run validation queries
    if [[ -n "$VALIDATION_QUERIES" ]]; then
        validate_database
    else
        # Default validation: check table count
        validate_database_default
    fi

    ((TESTS_PASSED++))
    log_info "Database restore test PASSED"

    return 0
}

# Validate database with custom queries
validate_database() {
    log_info "Running validation queries..."

    IFS=';' read -ra queries <<< "$VALIDATION_QUERIES"

    for query in "${queries[@]}"; do
        [[ -z "$query" ]] && continue

        log_debug "Executing: $query"

        case "${DB_CONNECTION:-mysql}" in
            mysql|mariadb)
                mysql -h "${STAGING_HOST}" \
                      -u "${DB_USERNAME:-root}" \
                      -p"${DB_PASSWORD:-}" \
                      "$TEST_DB_NAME" \
                      -e "$query" || {
                    log_error "Validation query failed: $query"
                    ((TESTS_FAILED++))
                    return 1
                }
                ;;
            postgres|postgresql)
                psql -h "${STAGING_HOST}" \
                     -U "${DB_USERNAME:-postgres}" \
                     "$TEST_DB_NAME" \
                     -c "$query" || {
                    log_error "Validation query failed: $query"
                    ((TESTS_FAILED++))
                    return 1
                }
                ;;
        esac
    done

    log_info "Validation queries passed"
}

# Validate database with default checks
validate_database_default() {
    log_info "Running default validation..."

    local table_count=0

    case "${DB_CONNECTION:-mysql}" in
        mysql|mariadb)
            table_count=$(mysql -h "${STAGING_HOST}" \
                               -u "${DB_USERNAME:-root}" \
                               -p"${DB_PASSWORD:-}" \
                               "$TEST_DB_NAME" \
                               -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$TEST_DB_NAME';")

            if [[ $table_count -lt 1 ]]; then
                log_error "No tables found in restored database"
                ((TESTS_FAILED++))
                return 1
            fi
            ;;
        postgres|postgresql)
            table_count=$(psql -h "${STAGING_HOST}" \
                              -U "${DB_USERNAME:-postgres}" \
                              "$TEST_DB_NAME" \
                              -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")

            if [[ $table_count -lt 1 ]]; then
                log_error "No tables found in restored database"
                ((TESTS_FAILED++))
                return 1
            fi
            ;;
        sqlite)
            table_count=$(sqlite3 "$test_db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")

            if [[ $table_count -lt 1 ]]; then
                log_error "No tables found in restored database"
                ((TESTS_FAILED++))
                return 1
            fi
            ;;
    esac

    log_info "Validation passed: Found $table_count tables"
}

# Test file restore
test_file_restore() {
    local backup_file="$1"
    local test_id=$(generate_test_id)
    local test_dir="${STAGING_DIR}/${test_id}"

    log_info "=== Testing File Restore ==="
    log_info "Backup: $backup_file"
    log_info "Test Directory: $test_dir"

    # Create test directory
    mkdir -p "$test_dir"

    # Extract backup
    log_info "Extracting backup..."
    if [[ "$backup_file" =~ \.tar\.gz$ ]]; then
        tar -xzf "$backup_file" -C "$test_dir" || {
            log_error "Failed to extract backup"
            return 1
        }
    elif [[ "$backup_file" =~ \.tar$ ]]; then
        tar -xf "$backup_file" -C "$test_dir" || {
            log_error "Failed to extract backup"
            return 1
        }
    else
        log_error "Unknown backup format"
        return 1
    fi

    # Check if files were extracted
    local file_count=$(find "$test_dir" -type f | wc -l)

    if [[ $file_count -lt 1 ]]; then
        log_error "No files extracted from backup"
        ((TESTS_FAILED++))
        return 1
    fi

    log_info "Extraction completed: $file_count files restored"

    # Validate file structure
    validate_file_structure "$test_dir"

    ((TESTS_PASSED++))
    log_info "File restore test PASSED"

    return 0
}

# Validate file structure
validate_file_structure() {
    local test_dir="$1"

    log_info "Validating file structure..."

    # Check for common Laravel directories
    local expected_dirs=("app" "config" "storage")
    local found_dirs=0

    for dir in "${expected_dirs[@]}"; do
        if [[ -d "${test_dir}/${dir}" ]] || find "$test_dir" -type d -name "$dir" | grep -q .; then
            ((found_dirs++))
            log_debug "Found expected directory: $dir"
        fi
    done

    # Check for .env file
    if find "$test_dir" -name ".env" | grep -q .; then
        log_info "Found .env file in backup"
    fi

    log_info "File structure validation: $found_dirs/${#expected_dirs[@]} expected directories found"
}

# Find latest backup
find_latest_backup() {
    local backup_type="$1"
    local backup_dir="${BACKUP_DIR:-/var/backups}"

    case "$backup_type" in
        database)
            local pattern="*.sql.gz"
            local search_dir="${backup_dir}/database"
            ;;
        files)
            local pattern="*.tar.gz"
            local search_dir="${backup_dir}/files"
            ;;
        *)
            log_error "Unknown backup type: $backup_type"
            return 1
            ;;
    esac

    if [[ ! -d "$search_dir" ]]; then
        log_error "Backup directory not found: $search_dir"
        return 1
    fi

    # Find most recent backup
    local latest=$(find "$search_dir" -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest" ]]; then
        log_error "No backups found in: $search_dir"
        return 1
    fi

    echo "$latest"
}

# Generate test report
generate_report() {
    log_info "=== Restore Test Report ==="
    echo "  Tests Passed: $TESTS_PASSED"
    echo "  Tests Failed: $TESTS_FAILED"
    echo "  Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo "  Success Rate: $(( TESTS_PASSED * 100 / (TESTS_PASSED + TESTS_FAILED) ))%"
    echo "  ======================"
}

# Main execution
main() {
    log_info "=== Automated Restore Testing Started ==="

    # Determine backup to test
    local backup_to_test=""

    if [[ -n "$BACKUP_PATH" ]]; then
        backup_to_test="$BACKUP_PATH"
    else
        # Find latest backup
        local type="$BACKUP_TYPE"
        [[ "$type" == "auto" ]] && type="database"

        backup_to_test=$(find_latest_backup "$type") || {
            log_error "Could not find backup to test"
            exit 1
        }
    fi

    # Verify backup exists
    if [[ ! -f "$backup_to_test" ]]; then
        log_error "Backup not found: $backup_to_test"
        exit 1
    fi

    # Determine type
    local test_type="$BACKUP_TYPE"
    if [[ "$test_type" == "auto" ]]; then
        test_type=$(auto_detect_type "$backup_to_test")
    fi

    # Run appropriate test
    case "$test_type" in
        database)
            test_database_restore "$backup_to_test" || {
                log_error "Database restore test FAILED"
                generate_report
                exit 1
            }
            ;;
        files)
            test_file_restore "$backup_to_test" || {
                log_error "File restore test FAILED"
                generate_report
                exit 1
            }
            ;;
        *)
            log_error "Unknown backup type: $test_type"
            exit 1
            ;;
    esac

    # Generate report
    generate_report

    log_info "All restore tests PASSED"
    exit 0
}

# Run main function
main "$@"
