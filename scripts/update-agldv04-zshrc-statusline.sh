#!/bin/bash

# ===============================================
# Update agldv04 (CT180) with fgsrv6 configs
# Copies .zshrc and statusline from fgsrv6
# ===============================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FGSRV6_HOST="100.83.51.9"  # Tailscale IP
AGLDV04_CONTAINER="180"    # CT180 (dokploy/agldv04)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_DIR="/tmp/agldv04_update_$TIMESTAMP"

# Helper functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running on Proxmox host
check_proxmox() {
    log "Checking if running on Proxmox host..."

    if ! command -v pct &> /dev/null; then
        log_error "pct command not found. This script must run on a Proxmox host."
        log "If agldv04 is a remote host, use SSH instead."
        exit 1
    fi

    log_success "Proxmox detected"
}

# Check if CT180 exists
check_container() {
    log "Checking if CT180 (agldv04) exists..."

    if ! pct list | grep -q "^$AGLDV04_CONTAINER "; then
        log_error "Container CT180 not found"
        log "Available containers:"
        pct list | tail -n +2
        exit 1
    fi

    # Check if container is running
    if pct status $AGLDV04_CONTAINER | grep -q "status: stopped"; then
        log_warn "Container CT180 is stopped. Starting it..."
        pct start $AGLDV04_CONTAINER
        sleep 5
    fi

    log_success "CT180 (agldv04) is running"
}

# Download configs from fgsrv6
download_configs() {
    log "Downloading configs from fgsrv6..."

    mkdir -p "$TEMP_DIR"

    log "  - Downloading .zshrc from fgsrv6..."
    if ssh root@$FGSRV6_HOST "cat /root/.zshrc" > "$TEMP_DIR/zshrc"; then
        log_success "  .zshrc downloaded ($(wc -l < "$TEMP_DIR/zshrc") lines)"
    else
        log_error "Failed to download .zshrc from fgsrv6"
        exit 1
    fi

    log "  - Downloading statusline from fgsrv6..."
    if ssh root@$FGSRV6_HOST "cat /root/.claude/statusline-command.sh" > "$TEMP_DIR/statusline"; then
        log_success "  statusline downloaded ($(wc -l < "$TEMP_DIR/statusline") lines)"
    else
        log_error "Failed to download statusline from fgsrv6"
        exit 1
    fi
}

# Create backups in CT180
create_backups() {
    log "Creating backups in CT180..."

    pct exec $AGLDV04_CONTAINER -- bash -c "
        # Backup .zshrc
        if [ -f /root/.zshrc ]; then
            cp /root/.zshrc /root/.zshrc.backup.$TIMESTAMP
            echo '  ✓ Backed up .zshrc'
        else
            echo '  ! No .zshrc found (will create new)'
        fi

        # Backup statusline
        mkdir -p /root/.claude
        if [ -f /root/.claude/statusline-command.sh ]; then
            cp /root/.claude/statusline-command.sh /root/.claude/statusline-command.sh.backup.$TIMESTAMP
            echo '  ✓ Backed up statusline'
        else
            echo '  ! No statusline found (will create new)'
        fi

        # List backups
        echo ''
        echo '  Existing backups:'
        ls -lh /root/.zshrc.backup.* 2>/dev/null | tail -5 || echo '    No .zshrc backups'
        ls -lh /root/.claude/*.backup.* 2>/dev/null | tail -5 || echo '    No statusline backups'
    "

    log_success "Backups completed"
}

# Copy configs to CT180
copy_configs() {
    log "Copying configs to CT180..."

    # Copy .zshrc
    log "  - Copying .zshrc..."
    pct push $AGLDV04_CONTAINER "$TEMP_DIR/zshrc" "/root/.zshrc"
    log_success "  .zshrc copied"

    # Copy statusline
    log "  - Copying statusline..."
    pct push $AGLDV04_CONTAINER "$TEMP_DIR/statusline" "/root/.claude/statusline-command.sh"
    pct exec $AGLDV04_CONTAINER -- chmod +x /root/.claude/statusline-command.sh
    log_success "  statusline copied and made executable"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."

    pct exec $AGLDV04_CONTAINER -- bash -c "
        echo '=== Verification Results ==='
        echo ''

        # Check .zshrc
        echo '✓ .zshrc:'
        if [ -f /root/.zshrc ]; then
            echo \"  - Exists: Yes\"
            echo \"  - Lines: $(wc -l < /root/.zshrc)\"
            echo \"  - Size: $(du -h /root/.zshrc | cut -f1)\"
        else
            echo '  - ERROR: .zshrc not found!'
            exit 1
        fi
        echo ''

        # Check statusline
        echo '✓ statusline-command.sh:'
        if [ -f /root/.claude/statusline-command.sh ]; then
            echo \"  - Exists: Yes\"
            echo \"  - Lines: $(wc -l < /root/.claude/statusline-command.sh)\"
            echo \"  - Size: $(du -h /root/.claude/statusline-command.sh | cut -f1)\"
            echo \"  - Executable: $([ -x /root/.claude/statusline-command.sh ] && echo 'Yes' || echo 'No')\"
        else
            echo '  - ERROR: statusline not found!'
            exit 1
        fi
        echo ''

        # Test statusline
        echo '✓ Testing statusline:'
        echo '{\"model\": {\"display_name\": \"Claude Sonnet 4.5\"}, \"workspace\": {\"current_dir\": \"/root\"}}' | \
            /root/.claude/statusline-command.sh 2>&1 | head -1
        echo ''

        echo '=== Verification Complete ==='
    "

    log_success "Verification passed"
}

# Cleanup
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    log_success "Temporary files removed"
}

# Show rollback instructions
show_rollback() {
    echo ""
    echo "========================================="
    log "Rollback Instructions"
    echo "========================================="
    echo ""
    echo "If you need to rollback to previous configs:"
    echo ""
    echo "  # Enter CT180"
    echo "  pct enter $AGLDV04_CONTAINER"
    echo ""
    echo "  # Rollback .zshrc"
    echo "  cp /root/.zshrc.backup.$TIMESTAMP /root/.zshrc"
    echo ""
    echo "  # Rollback statusline"
    echo "  cp /root/.claude/statusline-command.sh.backup.$TIMESTAMP /root/.claude/statusline-command.sh"
    echo ""
    echo "  # List all backups"
    echo "  ls -lh /root/.zshrc.backup.*"
    echo "  ls -lh /root/.claude/*.backup.*"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "  Update agldv04 (CT180) from fgsrv6"
    echo "========================================="
    echo ""
    echo "Source: fgsrv6 ($FGSRV6_HOST)"
    echo "Target: CT180 (agldv04/dokploy)"
    echo "Timestamp: $TIMESTAMP"
    echo ""

    check_proxmox
    check_container
    download_configs
    create_backups
    copy_configs

    if verify_installation; then
        cleanup
        echo ""
        echo "========================================="
        log_success "Update Complete!"
        echo "========================================="
        echo ""
        echo "Next steps:"
        echo "  1. Enter CT180: pct enter $AGLDV04_CONTAINER"
        echo "  2. Reload shell: source ~/.zshrc"
        echo "  3. Test commands: hive-help, cf-dev"
        echo "  4. Verify statusline: restart Claude Code in CT180"
        echo ""
        show_rollback
    else
        log_error "Verification failed"
        cleanup
        exit 1
    fi
}

# Run main
main "$@"
