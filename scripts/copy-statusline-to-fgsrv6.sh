#!/bin/bash

# Secure Statusline Copy Script - FGSRV6 Deployment
# Target: root@186.202.57.120 (or 10.6.0.5 via Tailscale)
# Mission: Copy statusline-command.sh with backup and validation

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"
SOURCE_FILE="$PROJECT_ROOT/.claude/statusline-command.sh"
TARGET_HOST="${FGSRV6_HOST:-186.202.57.120}"
TARGET_USER="${FGSRV6_USER:-root}"
TARGET_DIR="/root/.claude"
IDENTITY_FILE="$HOME/.ssh/fg_srv.pem"
LOG_FILE="/tmp/statusline-copy-$(date +%Y%m%d_%H%M%S).log"

# Helper functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

print_usage() {
    cat << 'EOF'
Secure Statusline Copy Script - FGSRV6 Deployment

Usage: copy-statusline-to-fgsrv6.sh [OPTIONS]

Options:
    --help              Show this help message
    --tailscale         Use Tailscale IP (10.6.0.5) instead of external IP
    --dry-run           Show what would be done without making changes
    --no-backup         Skip backup step (not recommended)

Environment Variables:
    FGSRV6_HOST         Override target host (default: 186.202.57.120)
    FGSRV6_USER         Override target user (default: root)

Examples:
    # Standard deployment to external IP
    ./copy-statusline-to-fgsrv6.sh

    # Deploy via Tailscale
    ./copy-statusline-to-fgsrv6.sh --tailscale

    # Dry run to test
    ./copy-statusline-to-fgsrv6.sh --dry-run

EOF
}

# Parse arguments
DRY_RUN=false
NO_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            print_usage
            exit 0
            ;;
        --tailscale)
            TARGET_HOST="100.83.51.9"
            log "Using Tailscale IP: $TARGET_HOST"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            log_warn "DRY RUN MODE - no changes will be made"
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            log_warn "Backup disabled - existing files will be overwritten"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validation
validate_source() {
    log "Validating source file..."

    if [ ! -f "$SOURCE_FILE" ]; then
        log_error "Source file not found: $SOURCE_FILE"
        exit 1
    fi

    if [ ! -r "$SOURCE_FILE" ]; then
        log_error "Source file not readable: $SOURCE_FILE"
        exit 1
    fi

    local size=$(stat -c%s "$SOURCE_FILE" 2>/dev/null || stat -f%z "$SOURCE_FILE" 2>/dev/null)
    log_success "Source file validated: $SOURCE_FILE ($size bytes)"
}

# Test SSH connection
test_connection() {
    log "Testing SSH connection to $TARGET_USER@$TARGET_HOST..."

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN: Skipping connection test"
        return 0
    fi

    if ssh -i "$IDENTITY_FILE" -o ConnectTimeout=10 -o BatchMode=yes "$TARGET_USER@$TARGET_HOST" "echo 'Connection OK'" > /dev/null 2>&1; then
        log_success "SSH connection successful"
        return 0
    else
        log_error "Cannot connect to $TARGET_USER@$TARGET_HOST"
        log "Please check:"
        log "  1. Host is reachable: ping $TARGET_HOST"
        log "  2. SSH key is configured"
        log "  3. User has access: $TARGET_USER"
        log "  4. Try Tailscale option: --tailscale"
        exit 1
    fi
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)

    if [ "$NO_BACKUP" = true ]; then
        log_warn "Backup skipped (--no-backup flag)"
        return 0
    fi

    log "Creating backup on $TARGET_HOST..."

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN: Would create backup with timestamp: $timestamp"
        return 0
    fi

    ssh -i "$IDENTITY_FILE" "$TARGET_USER@$TARGET_HOST" "
        # Create .claude directory if it doesn't exist
        mkdir -p $TARGET_DIR

        # Backup statusline script if exists
        if [ -f $TARGET_DIR/statusline-command.sh ]; then
            cp $TARGET_DIR/statusline-command.sh $TARGET_DIR/statusline-command.sh.backup.$timestamp
            echo 'Backup created: statusline-command.sh.backup.$timestamp'
        else
            echo 'No existing statusline script to backup'
        fi

        # List backups
        echo 'Current backups:'
        ls -lh $TARGET_DIR/*.backup.* 2>/dev/null || echo 'No backups found'
    " | tee -a "$LOG_FILE"

    log_success "Backup completed"
}

# Transfer file
transfer_file() {
    log "Transferring statusline-command.sh to $TARGET_HOST..."

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN: Would transfer $SOURCE_FILE to $TARGET_USER@$TARGET_HOST:$TARGET_DIR/statusline-command.sh"
        return 0
    fi

    if scp -i "$IDENTITY_FILE" -q "$SOURCE_FILE" "$TARGET_USER@$TARGET_HOST:$TARGET_DIR/statusline-command.sh"; then
        log_success "File transferred successfully"
    else
        log_error "File transfer failed"
        exit 1
    fi
}

# Set permissions
set_permissions() {
    log "Setting executable permissions..."

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN: Would execute: chmod +x $TARGET_DIR/statusline-command.sh"
        return 0
    fi

    ssh -i "$IDENTITY_FILE" "$TARGET_USER@$TARGET_HOST" "chmod +x $TARGET_DIR/statusline-command.sh"
    log_success "Permissions set: executable"
}

# Validate deployment
validate_deployment() {
    log "Validating deployment..."

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN: Skipping validation"
        return 0
    fi

    local validation_result
    validation_result=$(ssh -i "$IDENTITY_FILE" "$TARGET_USER@$TARGET_HOST" "
        echo '=== Validation Checks ==='

        # Check file exists
        if [ -f $TARGET_DIR/statusline-command.sh ]; then
            echo '✓ File exists'
        else
            echo '✗ File not found'
            exit 1
        fi

        # Check executable
        if [ -x $TARGET_DIR/statusline-command.sh ]; then
            echo '✓ File is executable'
        else
            echo '✗ File not executable'
            exit 1
        fi

        # Check file size
        SIZE=\$(stat -c%s $TARGET_DIR/statusline-command.sh 2>/dev/null || stat -f%z $TARGET_DIR/statusline-command.sh 2>/dev/null)
        echo \"✓ File size: \$SIZE bytes\"

        # Test execution with sample input
        echo '✓ Testing execution with sample input:'
        echo '{\"model\": {\"display_name\": \"Claude Sonnet 4.5\"}, \"workspace\": {\"current_dir\": \"/root\"}}' | $TARGET_DIR/statusline-command.sh

        echo '=== Validation Complete ==='
    " 2>&1)

    echo "$validation_result" | tee -a "$LOG_FILE"

    if echo "$validation_result" | grep -q "✗"; then
        log_error "Validation failed"
        return 1
    else
        log_success "Validation passed"
        return 0
    fi
}

# Rollback function
rollback() {
    log_error "Deployment failed. Attempting rollback..."

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN: Would perform rollback"
        exit 1
    fi

    ssh -i "$IDENTITY_FILE" "$TARGET_USER@$TARGET_HOST" "
        LATEST_BACKUP=\$(ls -t $TARGET_DIR/statusline-command.sh.backup.* 2>/dev/null | head -1)
        if [ -n \"\$LATEST_BACKUP\" ]; then
            cp \"\$LATEST_BACKUP\" $TARGET_DIR/statusline-command.sh
            echo \"Rolled back to: \$LATEST_BACKUP\"
        else
            echo 'No backup available for rollback'
        fi
    "

    exit 1
}

# Main execution
main() {
    log "========================================="
    log "  Statusline Deployment to FGSRV6"
    log "========================================="
    log ""
    log "Target: $TARGET_USER@$TARGET_HOST:$TARGET_DIR"
    log "Source: $SOURCE_FILE"
    log "Log: $LOG_FILE"
    log ""

    # Execute deployment steps
    validate_source
    test_connection
    create_backup
    transfer_file
    set_permissions

    if validate_deployment; then
        log ""
        log "========================================="
        log_success "  Deployment Complete!"
        log "========================================="
        log ""
        log "Next steps:"
        log "  1. Restart Claude Code on FGSRV6 to see the statusline"
        log "  2. Test with: ssh $TARGET_USER@$TARGET_HOST '$TARGET_DIR/statusline-command.sh'"
        log "  3. Check settings.json has statusline configuration"
        log ""
        log "Rollback if needed:"
        log "  ssh $TARGET_USER@$TARGET_HOST 'ls -t $TARGET_DIR/*.backup.* | head -1 | xargs -I {} cp {} $TARGET_DIR/statusline-command.sh'"
        log ""
    else
        rollback
    fi
}

# Run main with error handling
if ! main; then
    log_error "Deployment failed"
    exit 1
fi
