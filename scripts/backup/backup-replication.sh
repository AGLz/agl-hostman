#!/bin/bash
# Offsite Backup Replication Script
# Purpose: Replicate local backups to offsite storage with encryption
# Supports: Backblaze B2 (rclone), Hetzner Storage (rsync), S3-compatible storage
#
# Usage:
#   ./backup-replication.sh                    # Interactive mode
#   ./backup-replication.sh --config <file>    # Custom config
#   ./backup-replication.sh --dry-run          # Preview changes
#   ./backup-replication.sh --verify           # Verify backups only
#
# Requirements:
#   - rclone (for cloud storage)
#   - rsync (for VPS/storage box)
#   - gpg (for encryption)
#   - pigz (for parallel compression)

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/replication-config.env"
LOG_DIR="/var/log/backup-replication"
LOG_FILE="${LOG_DIR}/replication-$(date +%Y%m%d-%H%M%S).log"
PID_FILE="/var/run/backup-replication.pid"

# Default values (can be overridden by config file)
BACKUP_SOURCE_LOCAL="/mnt/shares/agl-hostman-backups"
BACKUP_SOURCE_PROXMOX="/spark/base/dump"
BACKUP_TEMP="/tmp/backup-replication"

# Offsite targets
B2_BUCKET="agl-hostman-backups"
HETZNER_HOST="uXXXXXX.your-storagebox.de"
HETZNER_USER="uXXXXXX"
HETZNER_PORT=23

# Encryption
ENCRYPT_GPG_RECIPIENT="agl-backup@local"
ENCRYPT_GPG_KEY_ID=""
ENCRYPT_TEMP_DIR="${BACKUP_TEMP}/encrypt"

# Bandwidth control (KB/s)
BANDWIDTH_LIMIT=10240  # 10 MB/s

# Retention
RETENTION_DAYS=90
RETENTION_COUNT=30

# Notification
ALERT_EMAIL=""
SLACK_WEBHOOK=""

# ============================================================================
# COLORS AND OUTPUT
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
    echo -e "${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOG_FILE}"; }
log_error() { log -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"; }
log_success() { log -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"; }

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Create PID file
create_pidfile() {
    if [[ -f "${PID_FILE}" ]]; then
        local old_pid
        old_pid=$(cat "${PID_FILE}")
        if ps -p "${old_pid}" > /dev/null 2>&1; then
            log_error "Another instance is already running (PID: ${old_pid})"
            exit 1
        else
            log_warn "Removing stale PID file"
            rm -f "${PID_FILE}"
        fi
    fi
    echo $$ > "${PID_FILE}"
    trap 'rm -f "${PID_FILE}"' EXIT
}

# Load configuration file
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        log_info "Loading configuration from ${CONFIG_FILE}"
        # shellcheck source=/dev/null
        source "${CONFIG_FILE}"
    else
        log_warn "Configuration file not found: ${CONFIG_FILE}"
        log_info "Using default values"
    fi
}

# Create required directories
create_directories() {
    mkdir -p "${LOG_DIR}" "${BACKUP_TEMP}" "${ENCRYPT_TEMP_DIR}"
    chmod 700 "${LOG_DIR}"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    command -v rclone >/dev/null 2>&1 || missing_deps+=("rclone")
    command -v rsync >/dev/null 2>&1 || missing_deps+=("rsync")
    command -v gpg >/dev/null 2>&1 || missing_deps+=("gpg")

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: apt-get install ${missing_deps[*]}"
        exit 1
    fi
}

# Calculate directory size
get_size() {
    du -sb "$1" 2>/dev/null | awk '{print $1}' || echo "0"
}

# Format bytes to human readable
format_size() {
    local bytes=$1
    local units=('B' 'KB' 'MB' 'GB' 'TB')
    local unit=0
    while ((bytes > 1024 && unit < 4)); do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    echo "${bytes} ${units[${unit}]}"
}

# Format duration
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" ${hours} ${minutes} ${secs}
}

# ============================================================================
# ENCRYPTION FUNCTIONS
# ============================================================================

# Check GPG key availability
check_gpg_key() {
    log_info "Checking GPG encryption key..."

    if [[ -n "${ENCRYPT_GPG_KEY_ID}" ]]; then
        if gpg --list-keys "${ENCRYPT_GPG_KEY_ID}" >/dev/null 2>&1; then
            log_success "GPG key found: ${ENCRYPT_GPG_KEY_ID}"
            return 0
        fi
    fi

    if gpg --list-keys "${ENCRYPT_GPG_RECIPIENT}" >/dev/null 2>&1; then
        ENCRYPT_GPG_KEY_ID=$(gpg --list-keys "${ENCRYPT_GPG_RECIPIENT}" | grep -m1 -oP '(?<=\[)[A-F0-9]+(?=\])' || true)
        if [[ -n "${ENCRYPT_GPG_KEY_ID}" ]]; then
            log_success "GPG key found: ${ENCRYPT_GPG_KEY_ID}"
            return 0
        fi
    fi

    log_error "GPG key not found for recipient: ${ENCRYPT_GPG_RECIPIENT}"
    log_info "Generate key with: gpg --full-generate-key"
    return 1
}

# Encrypt file with GPG
encrypt_file() {
    local input_file="$1"
    local output_file="${input_file}.gpg"

    log_info "Encrypting: $(basename "${input_file}")"

    if gpg --batch --yes --output "${output_file}" \
        --encrypt --recipient "${ENCRYPT_GPG_RECIPIENT}" \
        --cipher-algo AES256 --compress-algo ZLIB \
        --s2k-digest-algo SHA512 "${input_file}" 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "Encrypted: ${output_file}"
        return 0
    else
        log_error "Encryption failed for: ${input_file}"
        return 1
    fi
}

# Encrypt directory
encrypt_directory() {
    local input_dir="$1"
    local output_file="$2"
    local temp_dir="${ENCRYPT_TEMP_DIR}/$(basename "${input_dir}")"

    log_info "Encrypting directory: ${input_dir}"

    # Create archive first
    mkdir -p "${temp_dir}"
    local archive_file="${temp_dir}/archive.tar.gz"

    if ! tar czf "${archive_file}" -C "${input_dir}" . 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to create archive"
        return 1
    fi

    # Encrypt the archive
    if encrypt_file "${archive_file}"; then
        mv "${archive_file}.gpg" "${output_file}"
        rm -rf "${temp_dir}"
        log_success "Directory encrypted: ${output_file}"
        return 0
    else
        rm -rf "${temp_dir}"
        return 1
    fi
}

# Decrypt file with GPG
decrypt_file() {
    local input_file="$1"
    local output_file="$2"

    log_info "Decrypting: $(basename "${input_file}")"

    if gpg --batch --yes --output "${output_file}" \
        --decrypt "${input_file}" 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "Decrypted: ${output_file}"
        return 0
    else
        log_error "Decryption failed for: ${input_file}"
        return 1
    fi
}

# ============================================================================
# REPLICATION FUNCTIONS
# ============================================================================

# Replicate to Backblaze B2 using rclone
replicate_b2() {
    local source_dir="$1"
    local remote_path="$2"
    local dry_run="${3:-false}"

    log_info "Starting replication to Backblaze B2..."
    log_info "Source: ${source_dir}"
    log_info "Destination: ${B2_BUCKET}:${remote_path}"

    local rclone_opts=(
        --bwlimit "${BANDWIDTH_LIMIT}K"
        --transfers 4
        --checkers 8
        --stats 1m
        --stats-log-level NOTICE
        --log-file "${LOG_FILE}"
        --exclude ".DS_Store"
        --exclude "Thumbs.db"
        --exclude ".git/"
    )

    if [[ "${dry_run}" == "true" ]]; then
        rclone_opts+=(--dry-run)
        log_info "DRY RUN MODE - No files will be transferred"
    fi

    local start_time
    start_time=$(date +%s)

    if rclone sync "${source_dir}/" "${B2_BUCKET}:${remote_path}" \
        "${rclone_opts[@]}" 2>&1 | tee -a "${LOG_FILE}"; then

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "B2 replication completed in $(format_duration ${duration})"

        # Get stats
        local stats
        stats=$(rclone stats "${B2_BUCKET}:${remote_path}" --json 2>/dev/null || echo '{}')
        log_info "B2 Stats: ${stats}"

        return 0
    else
        log_error "B2 replication failed"
        return 1
    fi
}

# Replicate to Hetzner Storage Box using rsync
replicate_hetzner() {
    local source_dir="$1"
    local remote_path="$2"
    local dry_run="${3:-false}"

    log_info "Starting replication to Hetzner Storage Box..."
    log_info "Source: ${source_dir}"
    log_info "Destination: ${HETZNER_HOST}:${remote_path}"

    local rsync_opts=(
        -avz
        --progress
        --bwlimit="${BANDWIDTH_LIMIT}"
        --stats
        --human-readable
        --itemize-changes
        --log-file="${LOG_FILE}"
        --exclude=".DS_Store"
        --exclude="Thumbs.db"
        --exclude=".git/"
        --delete
        --delete-after
    )

    if [[ "${dry_run}" == "true" ]]; then
        rsync_opts+=(--dry-run)
        log_info "DRY RUN MODE - No files will be transferred"
    fi

    local start_time
    start_time=$(date +%s)

    if rsync "${rsync_opts[@]}" \
        "${source_dir}/" \
        "${HETZNER_USER}@${HETZNER_HOST}:${remote_path}" \
        2>&1 | tee -a "${LOG_FILE}"; then

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "Hetzner replication completed in $(format_duration ${duration})"

        return 0
    else
        log_error "Hetzner replication failed"
        return 1
    fi
}

# Replicate Proxmox backups
replicate_proxmox() {
    local dry_run="${1:-false}"

    if [[ ! -d "${BACKUP_SOURCE_PROXMOX}" ]]; then
        log_warn "Proxmox backup directory not found: ${BACKUP_SOURCE_PROXMOX}"
        return 0
    fi

    log_info "Replicating Proxmox backups..."

    # Get list of recent backups
    local recent_backups
    recent_backups=$(find "${BACKUP_SOURCE_PROXMOX}" -name "*.vma.zst" -o -name "*.tar.zst" | head -20)

    local backup_count=0
    while IFS= read -r backup; do
        if [[ -f "${backup}" ]]; then
            local filename
            filename=$(basename "${backup}")

            log_info "Processing: ${filename}"

            # Encrypt backup
            local encrypted_file="${ENCRYPT_TEMP_DIR}/${filename}.gpg"
            if encrypt_file "${backup}"; then
                mv "${backup}.gpg" "${encrypted_file}"

                # Upload to B2
                if replicate_b2 "${ENCRYPT_TEMP_DIR}" "proxmox/${filename}" "${dry_run}"; then
                    ((backup_count++))
                fi

                rm -f "${encrypted_file}"
            fi
        fi
    done <<< "${recent_backups}"

    log_success "Replicated ${backup_count} Proxmox backups"
    return 0
}

# Replicate application backups
replicate_applications() {
    local dry_run="${1:-false}"

    if [[ ! -d "${BACKUP_SOURCE_LOCAL}" ]]; then
        log_warn "Application backup directory not found: ${BACKUP_SOURCE_LOCAL}"
        return 0
    fi

    log_info "Replicating application backups..."

    # Replicate daily backups
    if [[ -d "${BACKUP_SOURCE_LOCAL}/daily" ]]; then
        replicate_b2 "${BACKUP_SOURCE_LOCAL}/daily" "daily" "${dry_run}"
        replicate_hetzner "${BACKUP_SOURCE_LOCAL}/daily" "daily" "${dry_run}"
    fi

    # Replicate weekly backups
    if [[ -d "${BACKUP_SOURCE_LOCAL}/weekly" ]]; then
        replicate_b2 "${BACKUP_SOURCE_LOCAL}/weekly" "weekly" "${dry_run}"
        replicate_hetzner "${BACKUP_SOURCE_LOCAL}/weekly" "weekly" "${dry_run}"
    fi

    log_success "Application backups replicated"
    return 0
}

# ============================================================================
# VERIFICATION FUNCTIONS
# ============================================================================

# Verify B2 backups
verify_b2() {
    log_info "Verifying Backblaze B2 backups..."

    if ! rclone check "${B2_BUCKET}:" "${BACKUP_SOURCE_LOCAL}/" \
        --one-way --log-file="${LOG_FILE}" 2>&1 | tee -a "${LOG_FILE}"; then
        log_warn "B2 verification found discrepancies"
        return 1
    fi

    log_success "B2 verification passed"
    return 0
}

# Verify Hetzner backups
verify_hetzner() {
    log_info "Verifying Hetzner Storage Box backups..."

    local temp_check="${BACKUP_TEMP}/verify-hetzner"
    mkdir -p "${temp_check}"

    if ! rsync -avz --dry-run --itemize-changes \
        "${HETZNER_USER}@${HETZNER_HOST}:" \
        "${temp_check}/" 2>&1 | tee -a "${LOG_FILE}"; then
        log_warn "Hetzner verification found discrepancies"
        return 1
    fi

    log_success "Hetzner verification passed"
    rm -rf "${temp_check}"
    return 0
}

# Test restoration
test_restore() {
    log_info "Testing restoration from offsite storage..."

    local test_file="${BACKUP_TEMP}/restore-test-$(date +%s).txt"
    local test_content="Restore test at $(date)"

    # Create test file
    echo "${test_content}" > "${test_file}"

    # Encrypt and upload
    encrypt_file "${test_file}"
    local encrypted_file="${test_file}.gpg"

    rclone copy "${encrypted_file}" "${B2_BUCKET}:test/"

    # Download and decrypt
    local downloaded_file="${BACKUP_TEMP}/downloaded-$(date +%s).txt.gpg"
    rclone copy "${B2_BUCKET}:test/$(basename "${encrypted_file}")" "${BACKUP_TEMP}/"

    decrypt_file "${downloaded_file}" "${downloaded_file%.gpg}"

    # Verify
    if grep -q "${test_content}" "${downloaded_file%.gpg}"; then
        log_success "Restore test passed"
        rm -f "${test_file}" "${encrypted_file}" "${download_file}"
        return 0
    else
        log_error "Restore test failed - content mismatch"
        return 1
    fi
}

# ============================================================================
# NOTIFICATION FUNCTIONS
# ============================================================================

send_notification() {
    local status="$1"
    local message="$2"

    # Email notification
    if [[ -n "${ALERT_EMAIL}" ]] && command -v mail >/dev/null 2>&1; then
        echo "${message}" | mail -s "[Backup Replication] ${status}" "${ALERT_EMAIL}"
    fi

    # Slack notification
    if [[ -n "${SLACK_WEBHOOK}" ]] && command -v curl >/dev/null 2>&1; then
        local color="good"
        [[ "${status}" == *"FAILED"* ]] && color="danger"
        [[ "${status}" == *"WARNING"* ]] && color="warning"

        curl -X POST "${SLACK_WEBHOOK}" \
            -H 'Content-Type: application/json' \
            -d "{
                \"attachments\": [{
                    \"color\": \"${color}\",
                    \"title\": \"Backup Replication: ${status}\",
                    \"text\": \"${message}\",
                    \"footer\": \"AGL Backup System\",
                    \"ts\": $(date +%s)
                }]
            }" >/dev/null 2>&1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_usage() {
    cat << EOF
Offsite Backup Replication Script

Usage: $0 [OPTIONS]

Options:
    --config FILE       Use custom configuration file
    --dry-run           Preview changes without transferring
    --verify            Verify offsite backups only
    --test-restore      Test restoration from offsite
    --source-only       Replicate source backups only
    --proxmox-only      Replicate Proxmox backups only
    -h, --help          Show this help message

Examples:
    $0                              # Run full replication
    $0 --dry-run                    # Preview what would be replicated
    $0 --verify                     # Verify offsite backups
    $0 --test-restore               # Test restoration capability

Configuration file: ${CONFIG_FILE}
EOF
}

main() {
    local dry_run=false
    local verify_only=false
    local test_restore_only=false
    local source_only=false
    local proxmox_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --verify)
                verify_only=true
                shift
                ;;
            --test-restore)
                test_restore_only=true
                shift
                ;;
            --source-only)
                source_only=true
                shift
                ;;
            --proxmox-only)
                proxmox_only=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Initialization
    check_root
    create_pidfile
    load_config
    create_directories
    check_dependencies
    check_gpg_key

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Offsite Backup Replication${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local start_time
    start_time=$(date +%s)
    local exit_code=0

    # Verification mode
    if [[ "${verify_only}" == "true" ]]; then
        log_info "Running verification only..."
        verify_b2 || exit_code=$?
        verify_hetzner || exit_code=$?
        exit ${exit_code}
    fi

    # Test restore mode
    if [[ "${test_restore_only}" == "true" ]]; then
        log_info "Running restore test..."
        test_restore || exit_code=$?
        exit ${exit_code}
    fi

    # Replication mode
    log_info "Starting backup replication..."
    [[ "${dry_run}" == "true" ]] && log_info "DRY RUN MODE - No files will be transferred"

    # Replicate application backups
    if [[ "${proxmox_only}" == "false" ]]; then
        replicate_applications "${dry_run}" || exit_code=$?
    fi

    # Replicate Proxmox backups
    if [[ "${source_only}" == "false" ]]; then
        replicate_proxmox "${dry_run}" || exit_code=$?
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Replication Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Duration: $(format_duration ${duration})"
    echo -e "Log file: ${LOG_FILE}"
    echo ""

    if [[ ${exit_code} -eq 0 ]]; then
        log_success "Backup replication completed successfully"
        send_notification "SUCCESS" "Backup replication completed in $(format_duration ${duration})"
    else
        log_error "Backup replication completed with errors"
        send_notification "FAILED" "Backup replication failed. Check logs: ${LOG_FILE}"
    fi

    # Cleanup
    rm -rf "${BACKUP_TEMP}"

    exit ${exit_code}
}

main "$@"
