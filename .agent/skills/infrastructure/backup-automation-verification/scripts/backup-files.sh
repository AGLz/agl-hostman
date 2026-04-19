#!/bin/bash
################################################################################
# Automated File Backup Script
# Backs up critical files and directories
# Usage: ./backup-files.sh [--config backup-config.conf]
################################################################################

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/files}"
COMPRESS="${COMPRESS:-true}"
ENCRYPT="${ENCRYPT:-false}"
UPLOAD_S3="${UPLOAD_S3:-false}"
S3_BUCKET="${S3_BUCKET:-}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
CONFIG_FILE="${CONFIG_FILE:-}"

# Default paths to backup (can be overridden by config file)
DEFAULT_PATHS=(
    "/var/www/html/storage/app"
    "/var/www/html/storage/framework"
    "/var/www/html/storage/logs"
    "/var/www/html/.env"
    "/var/www/html/public/uploads"
    "/var/www/html/config"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load configuration from file
load_config() {
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from: $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Create backup directory
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
}

# Generate timestamp
generate_timestamp() {
    echo "$(date +"%Y%m%d_%H%M%S")"
}

# Backup files using tar
backup_files() {
    local timestamp=$(generate_timestamp)
    local backup_file="backup_files_${timestamp}.tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_file}"

    log_info "Starting file backup..."
    log_info "Timestamp: $timestamp"

    # Use default paths or custom paths from config
    local paths=("${BACKUP_PATHS[@]:-${DEFAULT_PATHS[@]}}")

    # Validate paths exist
    local valid_paths=()
    for path in "${paths[@]}"; do
        if [[ -e "$path" ]]; then
            valid_paths+=("$path")
        else
            log_warn "Path not found, skipping: $path"
        fi
    done

    if [[ ${#valid_paths[@]} -eq 0 ]]; then
        log_error "No valid paths to backup"
        return 1
    fi

    # Create tar archive
    log_info "Creating archive with ${#valid_paths[@]} paths..."

    if [[ "$COMPRESS" == "true" ]]; then
        tar -czf "$backup_path" "${valid_paths[@]}" 2>/dev/null
    else
        tar -cf "$backup_path" "${valid_paths[@]}" 2>/dev/null
    fi

    if [[ -f "$backup_path" ]]; then
        log_info "File backup created: $backup_file"
        echo "$backup_path"
        return 0
    else
        log_error "Failed to create backup archive"
        return 1
    fi
}

# Backup using rsync (incremental)
backup_rsync() {
    local timestamp=$(generate_timestamp)
    local backup_path="${BACKUP_DIR}/rsync_${timestamp}"
    local link_dest="${BACKUP_DIR}/rsync_latest"

    log_info "Starting rsync incremental backup..."

    local paths=("${BACKUP_PATHS[@]:-${DEFAULT_PATHS[@]}}")

    # Create rsync command with hard-linking
    local rsync_cmd=(
        "rsync"
        "-av"
        "--delete"
        "--link-dest=$link_dest"
    )

    # Add paths
    for path in "${paths[@]}"; do
        if [[ -e "$path" ]]; then
            rsync_cmd+=("$path")
        fi
    done

    rsync_cmd+=("$backup_path/")

    # Execute rsync
    "${rsync_cmd[@]}"

    # Update latest link
    rm -f "$link_dest"
    ln -s "$backup_path" "$link_dest"

    log_info "Rsync backup created: $backup_path"
    echo "$backup_path"
}

# Backup to Docker volume
backup_docker_volumes() {
    local timestamp=$(generate_timestamp)
    local backup_file="backup_docker_volumes_${timestamp}.tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_file}"

    log_info "Starting Docker volume backup..."

    # Get volumes to backup
    local volumes=("${DOCKER_VOLUMES[@]}")

    if [[ ${#volumes[@]} -eq 0 ]]; then
        log_warn "No Docker volumes specified"
        return 0
    fi

    # Create temporary container for backup
    local temp_container="backup_temp_$(date +%s)"

    # Run backup container
    docker run --rm \
        -v "${backup_path}:/backup.tar.gz" \
        -v /var/lib/docker/volumes:/data:ro \
        alpine tar -czf /backup.tar.gz "${volumes[@]/#/data/}"

    if [[ -f "$backup_path" ]]; then
        log_info "Docker volumes backup created: $backup_file"
        echo "$backup_path"
        return 0
    else
        log_error "Failed to backup Docker volumes"
        return 1
    fi
}

# Encrypt backup
encrypt_backup() {
    local backup_path="$1"

    if [[ "$ENCRYPT" != "true" ]]; then
        return 0
    fi

    if [[ -z "$ENCRYPT_KEY" ]]; then
        log_warn "Encryption enabled but ENCRYPT_KEY not set"
        return 0
    fi

    log_info "Encrypting backup..."

    local encrypted_path="${backup_path}.enc"
    openssl enc -aes-256-cbc -salt -in "$backup_path" \
        -out "$encrypted_path" -k "$ENCRYPT_KEY"

    if [[ -f "$encrypted_path" ]]; then
        rm "$backup_path"
        log_info "Backup encrypted successfully"
        echo "$encrypted_path"
        return 0
    else
        log_error "Backup encryption failed"
        return 1
    fi
}

# Upload to S3
upload_to_s3() {
    local backup_path="$1"

    if [[ "$UPLOAD_S3" != "true" ]]; then
        return 0
    fi

    if [[ -z "$S3_BUCKET" ]]; then
        log_warn "S3 upload enabled but S3_BUCKET not set"
        return 0
    fi

    log_info "Uploading backup to S3..."

    local s3_path="s3://${S3_BUCKET}/files/$(basename "$backup_path")"

    if aws s3 cp "$backup_path" "$s3_path"; then
        log_info "Backup uploaded to S3: $s3_path"

        if [[ "${DELETE_LOCAL_AFTER_UPLOAD:-false}" == "true" ]]; then
            rm "$backup_path"
            log_info "Local copy removed"
        fi
        return 0
    else
        log_error "S3 upload failed"
        return 1
    fi
}

# Generate checksum
generate_checksum() {
    local backup_path="$1"

    log_info "Generating checksum..."

    local checksum_file="${backup_path}.sha256"
    sha256sum "$backup_path" > "$checksum_file"

    log_info "Checksum saved to: $checksum_file"
}

# Display backup info
display_info() {
    local backup_path="$1"

    local file_size=$(du -h "$backup_path" | cut -f1)
    local file_name=$(basename "$backup_path")

    log_info "Backup Details:"
    echo "  File: $file_name"
    echo "  Size: $file_size"
    echo "  Path: $backup_path"
}

# Main execution
main() {
    log_info "=== File Backup Started ==="

    # Load configuration
    load_config

    # Create backup directory
    create_backup_dir

    # Determine backup type
    local backup_type="${BACKUP_TYPE:-tar}"

    # Perform backup
    local backup_path=""

    case "$backup_type" in
        tar)
            backup_path=$(backup_files)
            ;;
        rsync)
            backup_path=$(backup_rsync)
            ;;
        docker)
            backup_path=$(backup_docker_volumes)
            ;;
        *)
            log_error "Unknown backup type: $backup_type"
            exit 1
            ;;
    esac

    # Check if backup was created
    if [[ ! -f "$backup_path" && ! -d "$backup_path" ]]; then
        log_error "Backup was not created"
        exit 1
    fi

    # Encrypt backup (skip for rsync directories)
    if [[ "$backup_type" != "rsync" ]]; then
        local encrypted_path
        encrypted_path=$(encrypt_backup "$backup_path")
        if [[ -n "$encrypted_path" ]]; then
            backup_path="$encrypted_path"
        fi
    fi

    # Generate checksum (skip for rsync directories)
    if [[ "$backup_type" != "rsync" ]]; then
        generate_checksum "$backup_path"
    fi

    # Upload to S3 (skip for rsync directories)
    if [[ "$backup_type" != "rsync" ]]; then
        upload_to_s3 "$backup_path"
    fi

    # Display info
    if [[ -f "$backup_path" ]]; then
        display_info "$backup_path"
    fi

    log_info "=== File Backup Completed Successfully ==="

    exit 0
}

# Run main function
main "$@"
