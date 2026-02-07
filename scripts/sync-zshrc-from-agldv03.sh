#!/bin/bash

# ===============================================
# ZSHRC Synchronization Script - From agldv03
# ===============================================
# Synchronizes .zshrc configuration from agldv03 (CT179)
# to agldv04 (CT181) and fgsrv6, preserving host-specific settings
#
# Source: CT179 (agldv03) - Current host
# Targets:
#   - agldv04 (CT181 on AGLSRV1) - Use Tailscale IP: 100.113.9.98
#   - fgsrv6 (VPS at 100.83.51.9 via Tailscale)
# ===============================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_DIR="/tmp/zshrc_sync_$TIMESTAMP"
PROJECT_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"

# Target hosts (using Tailscale IPs as primary)
AGLDV04_IP="100.113.9.98"  # CT181 (agldv04) Tailscale IP
AGLDV04_CONTAINER="181"     # CT181 on AGLSRV1 (for pct commands if on same host)
FGSRV6_HOST="100.83.51.9"   # Tailscale IP
FGSRV6_HOST_ALT="186.202.57.120"  # Public IP (fallback)

# Files to sync
SOURCE_ZSHRC="/root/.zshrc"
SOURCE_CLAUDE_FLOW_V3="$PROJECT_ROOT/claude-flow-v3-config.zsh"
SOURCE_STATUSLINE="$PROJECT_ROOT/.claude/statusline-command.sh"

# Access mode: 'ssh' for remote access, 'pct' for Proxmox container access
ACCESS_MODE="${ACCESS_MODE:-ssh}"  # Default to SSH (Tailscale)

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

log_info() {
    echo -e "${CYAN}[i]${NC} $1"
}

# Check if running on Proxmox host
check_proxmox() {
    if command -v pct &> /dev/null; then
        log_success "Proxmox detected (can use pct for CT181)"
        return 0
    else
        log_info "Not on Proxmox host (using SSH for all targets)"
        return 1
    fi
}

# Test connection to agldv04 (CT181)
check_agldv04() {
    log "Testing connection to agldv04 (CT181 at $AGLDV04_IP)..."

    if ssh -o ConnectTimeout=5 -o BatchMode=yes root@$AGLDV04_IP "echo 'OK'" > /dev/null 2>&1; then
        log_success "Connected via Tailscale: $AGLDV04_IP"
        return 0
    fi

    log_error "Cannot connect to agldv04"
    log "  Try: export AGLDV04_IP=<correct_ip>"
    log "  Or use local LAN IP if on same network"
    return 1
}

# Test connection to fgsrv6
check_fgsrv6() {
    log "Testing connection to fgsrv6..."

    # Try Tailscale first
    if ssh -o ConnectTimeout=5 -o BatchMode=yes root@$FGSRV6_HOST "echo 'OK'" > /dev/null 2>&1; then
        FGSRV6_IP=$FGSRV6_HOST
        log_success "Connected via Tailscale: $FGSRV6_IP"
        return 0
    fi

    # Try public IP
    if ssh -o ConnectTimeout=5 -o BatchMode=yes root@$FGSRV6_HOST_ALT "echo 'OK'" > /dev/null 2>&1; then
        FGSRV6_IP=$FGSRV6_HOST_ALT
        log_success "Connected via public IP: $FGSRV6_IP"
        return 0
    fi

    log_error "Cannot connect to fgsrv6"
    return 1
}

# Extract host-specific section from fgsrv6
extract_fgsrv6_specific() {
    local temp_dir="$1"

    log "Extracting fgsrv6-specific configurations..."

    # Get fgsrv6 .zshrc
    ssh root@$FGSRV6_IP "cat /root/.zshrc" > "$temp_dir/fgsrv6_zshrc_original"

    # Extract node-limited aliases if they exist
    grep -A 5 "# Limites de recursos para Node.js" "$temp_dir/fgsrv6_zshrc_original" > "$temp_dir/fgsrv6_node_limits" || true

    # Check if node-limited aliases are active (not commented out)
    if grep -q "^alias node='node-limited'" "$temp_dir/fgsrv6_zshrc_original"; then
        log_info "Found active node-limited aliases on fgsrv6"
        echo "active" > "$temp_dir/fgsrv6_node_limits_status"
    else
        log_info "No active node-limited aliases found on fgsrv6"
        echo "commented" > "$temp_dir/fgsrv6_node_limits_status"
    fi

    log_success "Extracted fgsrv6-specific configs"
}

# Prepare merged configuration for fgsrv6
prepare_fgsrv6_zshrc() {
    local temp_dir="$1"
    local output_file="$2"
    local node_status=$(cat "$temp_dir/fgsrv6_node_limits_status" 2>/dev/null || echo "none")

    log "Preparing merged .zshrc for fgsrv6..."

    # Start with source .zshrc
    cp "$SOURCE_ZSHRC" "$output_file"

    # If fgsrv6 has active node-limited aliases, preserve them
    if [ "$node_status" = "active" ]; then
        log_info "Preserving fgsrv6's active node-limited aliases..."

        # Find the "# Limites de recursos para Node.js" section and uncomment the aliases
        sed -i 's/^# REMOVIDO: alias node=/alias node=/' "$output_file"
        sed -i 's/^# REMOVIDO: alias npm=/alias npm=/' "$output_file"
    fi

    log_success "Merged .zshrc prepared for fgsrv6"
}

# Sync to agldv04 (CT181) via SSH
sync_to_agldv04_ssh() {
    local temp_dir="$1"

    log ""
    log "========================================="
    log "  Syncing to agldv04 (CT181) via SSH"
    log "========================================="
    log "Target: root@$AGLDV04_IP"

    # Backup existing
    log "Creating backup on agldv04..."
    ssh root@$AGLDV04_IP "
        if [ -f /root/.zshrc ]; then
            cp /root/.zshrc /root/.zshrc.backup.$TIMESTAMP
            echo '  ✓ Backed up .zshrc'
        fi
        if [ -f /root/.claude/statusline-command.sh ]; then
            mkdir -p /root/.claude
            cp /root/.claude/statusline-command.sh /root/.claude/statusline-command.sh.backup.$TIMESTAMP
            echo '  ✓ Backed up statusline'
        fi
        if [ -f /root/claude-flow-v3-config.zsh ]; then
            cp /root/claude-flow-v3-config.zsh /root/claude-flow-v3-config.zsh.backup.$TIMESTAMP
            echo '  ✓ Backed up claude-flow-v3-config.zsh'
        fi
    "

    # Copy claude-flow-v3-config.zsh
    log "Copying claude-flow-v3-config.zsh..."
    cat "$SOURCE_CLAUDE_FLOW_V3" | ssh root@$AGLDV04_IP "cat > /root/claude-flow-v3-config.zsh"
    log_success "  ✓ claude-flow-v3-config.zsh copied"

    # Copy statusline
    log "Copying statusline-command.sh..."
    ssh root@$AGLDV04_IP "mkdir -p /root/.claude"
    cat "$SOURCE_STATUSLINE" | ssh root@$AGLDV04_IP "cat > /root/.claude/statusline-command.sh"
    ssh root@$AGLDV04_IP "chmod +x /root/.claude/statusline-command.sh"
    log_success "  ✓ statusline-command.sh copied"

    # Copy .zshrc
    log "Copying .zshrc..."
    cat "$SOURCE_ZSHRC" | ssh root@$AGLDV04_IP "cat > /root/.zshrc"
    log_success "  ✓ .zshrc copied"

    # Verify
    log "Verifying installation..."
    ssh root@$AGLDV04_IP "
        echo '=== Verification Results ==='
        echo ''
        echo '✓ .zshrc:'
        echo \"  - Lines: \$(wc -l < /root/.zshrc)\"
        echo \"  - Size: \$(du -h /root/.zshrc | cut -f1)\"
        echo ''
        echo '✓ claude-flow-v3-config.zsh:'
        [ -f /root/claude-flow-v3-config.zsh ] && echo \"  - Exists: Yes\" || echo \"  - ERROR: Not found\"
        [ -f /root/claude-flow-v3-config.zsh ] && echo \"  - Version: \$(grep CLAUDE_FLOW_VERSION= /root/claude-flow-v3-config.zsh | cut -d'=' -f2 | tr -d '\"')\"
        echo ''
        echo '✓ statusline-command.sh:'
        [ -f /root/.claude/statusline-command.sh ] && echo \"  - Exists: Yes, Executable: \$( [ -x /root/.claude/statusline-command.sh ] && echo 'Yes' || echo 'No' )\" || echo \"  - ERROR: Not found\"
        echo ''
        echo '=== Claude Flow Version Check ==='
        grep 'CLAUDE_FLOW_VERSION=' /root/claude-flow-v3-config.zsh || echo 'Version not found'
    "

    log_success "agldv04 sync complete!"
}

# Sync to agldv04 (CT181) via pct (if on same Proxmox host)
sync_to_agldv04_pct() {
    local temp_dir="$1"

    log ""
    log "========================================="
    log "  Syncing to agldv04 (CT181) via pct"
    log "========================================="
    log "Target: CT181 on AGLSRV1"

    # Backup existing
    log "Creating backup in CT181..."
    pct exec $AGLDV04_CONTAINER -- bash -c "
        if [ -f /root/.zshrc ]; then
            cp /root/.zshrc /root/.zshrc.backup.$TIMESTAMP
            echo '  ✓ Backed up .zshrc'
        fi
        if [ -f /root/.claude/statusline-command.sh ]; then
            mkdir -p /root/.claude
            cp /root/.claude/statusline-command.sh /root/.claude/statusline-command.sh.backup.$TIMESTAMP
            echo '  ✓ Backed up statusline'
        fi
        if [ -f /root/claude-flow-v3-config.zsh ]; then
            cp /root/claude-flow-v3-config.zsh /root/claude-flow-v3-config.zsh.backup.$TIMESTAMP
            echo '  ✓ Backed up claude-flow-v3-config.zsh'
        fi
    "

    # Copy claude-flow-v3-config.zsh
    log "Copying claude-flow-v3-config.zsh..."
    pct push $AGLDV04_CONTAINER "$SOURCE_CLAUDE_FLOW_V3" "/root/claude-flow-v3-config.zsh"
    log_success "  ✓ claude-flow-v3-config.zsh copied"

    # Copy statusline
    log "Copying statusline-command.sh..."
    pct exec $AGLDV04_CONTAINER -- mkdir -p /root/.claude
    pct push $AGLDV04_CONTAINER "$SOURCE_STATUSLINE" "/root/.claude/statusline-command.sh"
    pct exec $AGLDV04_CONTAINER -- chmod +x /root/.claude/statusline-command.sh
    log_success "  ✓ statusline-command.sh copied"

    # Copy .zshrc
    log "Copying .zshrc..."
    pct push $AGLDV04_CONTAINER "$SOURCE_ZSHRC" "/root/.zshrc"
    log_success "  ✓ .zshrc copied"

    # Verify
    log "Verifying installation..."
    pct exec $AGLDV04_CONTAINER -- bash -c "
        echo '=== Verification Results ==='
        echo ''
        echo '✓ .zshrc:'
        echo \"  - Lines: \$(wc -l < /root/.zshrc)\"
        echo \"  - Size: \$(du -h /root/.zshrc | cut -f1)\"
        echo ''
        echo '✓ claude-flow-v3-config.zsh:'
        [ -f /root/claude-flow-v3-config.zsh ] && echo \"  - Exists: Yes\" || echo \"  - ERROR: Not found\"
        [ -f /root/claude-flow-v3-config.zsh ] && echo \"  - Version: \$(grep CLAUDE_FLOW_VERSION= /root/claude-flow-v3-config.zsh | cut -d'=' -f2 | tr -d '\"')\"
        echo ''
        echo '✓ statusline-command.sh:'
        [ -f /root/.claude/statusline-command.sh ] && echo \"  - Exists: Yes, Executable: \$( [ -x /root/.claude/statusline-command.sh ] && echo 'Yes' || echo 'No' )\" || echo \"  - ERROR: Not found\"
        echo ''
        echo '=== Claude Flow Version Check ==='
        grep 'CLAUDE_FLOW_VERSION=' /root/claude-flow-v3-config.zsh || echo 'Version not found'
    "

    log_success "agldv04 sync complete!"
}

# Sync to fgsrv6
sync_to_fgsrv6() {
    local temp_dir="$1"

    log ""
    log "========================================="
    log "  Syncing to fgsrv6 ($FGSRV6_IP)"
    log "========================================="

    # Backup existing
    log "Creating backup on fgsrv6..."
    ssh root@$FGSRV6_IP "
        if [ -f /root/.zshrc ]; then
            cp /root/.zshrc /root/.zshrc.backup.$TIMESTAMP
            echo '  ✓ Backed up .zshrc'
        fi
        if [ -f /root/.claude/statusline-command.sh ]; then
            mkdir -p /root/.claude
            cp /root/.claude/statusline-command.sh /root/.claude/statusline-command.sh.backup.$TIMESTAMP
            echo '  ✓ Backed up statusline'
        fi
        if [ -f /root/claude-flow-v3-config.zsh ]; then
            cp /root/claude-flow-v3-config.zsh /root/claude-flow-v3-config.zsh.backup.$TIMESTAMP
            echo '  ✓ Backed up claude-flow-v3-config.zsh'
        fi
    "

    # Prepare merged .zshrc for fgsrv6
    prepare_fgsrv6_zshrc "$temp_dir" "$temp_dir/fgsrv6_zshrc_merged"

    # Copy claude-flow-v3-config.zsh
    log "Copying claude-flow-v3-config.zsh..."
    cat "$SOURCE_CLAUDE_FLOW_V3" | ssh root@$FGSRV6_IP "cat > /root/claude-flow-v3-config.zsh"
    log_success "  ✓ claude-flow-v3-config.zsh copied"

    # Copy statusline
    log "Copying statusline-command.sh..."
    ssh root@$FGSRV6_IP "mkdir -p /root/.claude"
    cat "$SOURCE_STATUSLINE" | ssh root@$FGSRV6_IP "cat > /root/.claude/statusline-command.sh"
    ssh root@$FGSRV6_IP "chmod +x /root/.claude/statusline-command.sh"
    log_success "  ✓ statusline-command.sh copied"

    # Copy merged .zshrc
    log "Copying merged .zshrc..."
    cat "$temp_dir/fgsrv6_zshrc_merged" | ssh root@$FGSRV6_IP "cat > /root/.zshrc"
    log_success "  ✓ .zshrc copied"

    # Verify
    log "Verifying installation..."
    ssh root@$FGSRV6_IP "
        echo '=== Verification Results ==='
        echo ''
        echo '✓ .zshrc:'
        echo \"  - Lines: \$(wc -l < /root/.zshrc)\"
        echo \"  - Size: \$(du -h /root/.zshrc | cut -f1)\"
        echo ''
        echo '✓ claude-flow-v3-config.zsh:'
        [ -f /root/claude-flow-v3-config.zsh ] && echo \"  - Exists: Yes\" || echo \"  - ERROR: Not found\"
        [ -f /root/claude-flow-v3-config.zsh ] && echo \"  - Version: \$(grep CLAUDE_FLOW_VERSION= /root/claude-flow-v3-config.zsh | cut -d'=' -f2 | tr -d '\"')\"
        echo ''
        echo '✓ statusline-command.sh:'
        [ -f /root/.claude/statusline-command.sh ] && echo \"  - Exists: Yes, Executable: \$( [ -x /root/.claude/statusline-command.sh ] && echo 'Yes' || echo 'No' )\" || echo \"  - ERROR: Not found\"
        echo ''
        echo '=== Node Limited Aliases Status ==='
        grep -A2 '# Limites de recursos para Node.js' /root/.zshrc || echo 'Not found'
    "

    log_success "fgsrv6 sync complete!"
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "  ZSHRC Synchronization from agldv03"
    echo "========================================="
    echo ""
    echo "Source: CT179 (agldv03) - Current host"
    echo "Targets:"
    echo "  - agldv04 (CT181) at $AGLDV04_IP (Tailscale)"
    echo "  - fgsrv6 (VPS) at $FGSRV6_HOST (Tailscale)"
    echo ""
    echo "Timestamp: $TIMESTAMP"
    echo ""

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Pre-flight checks
    HAS_PROXMOX=false
    if check_proxmox; then
        HAS_PROXMOX=true
    fi

    # Check targets
    AGLDV04_AVAILABLE=false
    FGSRV6_AVAILABLE=false

    if check_agldv04; then
        AGLDV04_AVAILABLE=true
    fi

    if check_fgsrv6; then
        FGSRV6_AVAILABLE=true
        extract_fgsrv6_specific "$TEMP_DIR"
    fi

    # Sync to available targets
    if [ "$AGLDV04_AVAILABLE" = true ]; then
        if [ "$HAS_PROXMOX" = true ] && [ "$ACCESS_MODE" != "ssh" ]; then
            sync_to_agldv04_pct "$TEMP_DIR"
        else
            sync_to_agldv04_ssh "$TEMP_DIR"
        fi
    fi

    if [ "$FGSRV6_AVAILABLE" = true ]; then
        sync_to_fgsrv6 "$TEMP_DIR"
    fi

    # Cleanup
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    log_success "Temporary files removed"

    # Summary
    echo ""
    echo "========================================="
    log_success "Synchronization Complete!"
    echo "========================================="
    echo ""
    echo "Next steps:"
    echo ""
    if [ "$AGLDV04_AVAILABLE" = true ]; then
        echo "  For agldv04 (CT181):"
        echo "    1. SSH: ssh root@$AGLDV04_IP"
        echo "    2. Reload shell: source ~/.zshrc"
        echo "    3. Test commands: cf --version, hive-help"
        echo "    4. Verify statusline: restart Claude Code"
        echo ""
    fi
    if [ "$FGSRV6_AVAILABLE" = true ]; then
        echo "  For fgsrv6:"
        echo "    1. SSH: ssh root@$FGSRV6_IP"
        echo "    2. Reload shell: source ~/.zshrc"
        echo "    3. Test commands: cf --version, hive-help"
        echo "    4. Verify statusline: restart Claude Code"
        echo ""
    fi
    echo "Rollback instructions:"
    if [ "$AGLDV04_AVAILABLE" = true ]; then
        echo "  agldv04: ssh root@$AGLDV04_IP 'cp /root/.zshrc.backup.$TIMESTAMP /root/.zshrc'"
    fi
    if [ "$FGSRV6_AVAILABLE" = true ]; then
        echo "  fgsrv6: ssh root@$FGSRV6_IP 'cp /root/.zshrc.backup.$TIMESTAMP /root/.zshrc'"
    fi
    echo ""
}

# Run main
main "$@"
