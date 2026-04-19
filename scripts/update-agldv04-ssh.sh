#!/bin/bash

# ===============================================
# Update agldv04 (CT180) via SSH from agldv03
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
AGLDV04_IP="${AGLDV04_IP:-10.6.0.20}"  # WireGuard IP (update if needed)
AGLDV04_USER="${AGLDV04_USER:-root}"
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

# Test SSH connection
test_connection() {
    log "Testing SSH connection to $AGLDV04_USER@$AGLDV04_IP..."

    if ssh -o ConnectTimeout=5 -o BatchMode=yes $AGLDV04_USER@$AGLDV04_IP "echo 'Connection OK'" > /dev/null 2>&1; then
        log_success "SSH connection successful"
        return 0
    else
        log_error "Cannot connect to $AGLDV04_USER@$AGLDV04_IP"
        log ""
        log "Possible solutions:"
        log "  1. Check IP address: export AGLDV04_IP=<correct_ip>"
        log "  2. Try Tailscale IP: export AGLDV04_IP=100.x.x.x"
        log "  3. Try local IP: export AGLDV04_IP=192.168.0.x"
        log "  4. Check SSH key: ssh-copy-id $AGLDV04_USER@$AGLDV04_IP"
        exit 1
    fi
}

# Download configs from fgsrv6
download_configs() {
    log "Downloading configs from fgsrv6..."

    mkdir -p "$TEMP_DIR"

    log "  - Downloading .zshrc from fgsrv6..."
    if ssh root@100.83.51.9 "cat /root/.zshrc" > "$TEMP_DIR/zshrc"; then
        log_success "  .zshrc downloaded ($(wc -l < "$TEMP_DIR/zshrc") lines)"
    else
        log_error "Failed to download .zshrc from fgsrv6"
        exit 1
    fi

    log "  - Downloading statusline from fgsrv6..."
    if ssh root@100.83.51.9 "cat /root/.claude/statusline-command.sh" > "$TEMP_DIR/statusline"; then
        log_success "  statusline downloaded ($(wc -l < "$TEMP_DIR/statusline") lines)"
    else
        log_error "Failed to download statusline from fgsrv6"
        exit 1
    fi
}

# Create backups in agldv04
create_backups() {
    log "Creating backups in agldv04..."

    ssh $AGLDV04_USER@$AGLDV04_IP "
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

# Copy configs to agldv04
copy_configs() {
    log "Copying configs to agldv04..."

    # Copy .zshrc
    log "  - Copying .zshrc..."
    cat "$TEMP_DIR/zshrc" | ssh $AGLDV04_USER@$AGLDV04_IP "cat > /root/.zshrc"
    log_success "  .zshrc copied"

    # Copy statusline
    log "  - Copying statusline..."
    cat "$TEMP_DIR/statusline" | ssh $AGLDV04_USER@$AGLDV04_IP "cat > /root/.claude/statusline-command.sh"
    ssh $AGLDV04_USER@$AGLDV04_IP "chmod +x /root/.claude/statusline-command.sh"
    log_success "  statusline copied and made executable"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."

    ssh $AGLDV04_USER@$AGLDV04_IP "
        echo '=== Verification Results ==='
        echo ''

        # Check .zshrc
        echo '✓ .zshrc:'
        if [ -f /root/.zshrc ]; then
            echo \"  - Exists: Yes\"
            echo \"  - Lines: $(wc -l < /root/.zshrc)\"
            echo \"  - Size: \$(du -h /root/.zshrc | cut -f1)\"
        else
            echo '  - ERROR: .zshrc not found!'
            exit 1
        fi
        echo ''

        # Check statusline
        echo '✓ statusline-command.sh:'
        if [ -f /root/.claude/statusline-command.sh ]; then
            echo \"  - Exists: Yes\"
            echo \"  - Lines: \$(wc -l < /root/.claude/statusline-command.sh)\"
            echo \"  - Size: \$(du -h /root/.claude/statusline-command.sh | cut -f1)\"
            echo \"  - Executable: \$([ -x /root/.claude/statusline-command.sh ] && echo 'Yes' || echo 'No')\"
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
    echo "  # SSH to agldv04"
    echo "  ssh $AGLDV04_USER@$AGLDV04_IP"
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
    echo "Source: fgsrv6 (100.83.51.9)"
    echo "Target: agldv04 ($AGLDV04_USER@$AGLDV04_IP)"
    echo "Timestamp: $TIMESTAMP"
    echo ""

    test_connection
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
        echo "  1. SSH to agldv04: ssh $AGLDV04_USER@$AGLDV04_IP"
        echo "  2. Reload shell: source ~/.zshrc"
        echo "  3. Test commands: hive-help, cf-dev"
        echo "  4. Verify statusline: restart Claude Code in agldv04"
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
