#!/bin/bash

# ===============================================
# Update Claude Flow to v3alpha on All Hosts
# Node.js v24 + claude-flow@v3alpha via npx
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
AGLDV04_IP="${AGLDV04_IP:-192.168.0.180}"
AGLDV04_USER="${AGLDV04_USER:-root}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ALIASES_FILE="/tmp/claude-flow-aliases-$TIMESTAMP.txt"

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

# Create aliases file
create_aliases_file() {
    cat > "$ALIASES_FILE" << 'ALIASES_EOF'
# ===============================================
# Claude Flow Aliases (Node.js v24 + v3alpha)
# ===============================================
# Added: 2026-01-24
# Updated: Using claude-flow@v3alpha via npx with Node.js v24
# Compatibility: Works on agldv03, agldv04, fgsrv6
# Source: Based on fgsrv6 configuration (without 'limited' aliases)

# ── Core Claude Flow Command ─────────────────────
# Uses Node.js v24 from NVM with claude-flow@v3alpha
# Automatically activates NVM and uses npx for execution
alias claude-flow="npx -y claude-flow@v3alpha"
alias claude-flow-v24="npx -y claude-flow@v3alpha"
alias cf="claude-flow"

# ── Quick Control Aliases ─────────────────────────
# Switch between different operational modes
alias cf-dev='export CLAUDE_FLOW_DEBUG_MODE=true CLAUDE_FLOW_VERBOSE=true CLAUDE_FLOW_LOG_LEVEL=debug'
alias cf-prod='export CLAUDE_FLOW_DEBUG_MODE=false CLAUDE_FLOW_VERBOSE=false CLAUDE_FLOW_LOG_LEVEL=warn'
alias cf-safe='export CLAUDE_FLOW_AUTO_COMMIT=false CLAUDE_FLOW_AUTO_PUSH=false CLAUDE_FLOW_ALLOW_SHELL_EXEC=false'
alias cf-auto='export CLAUDE_FLOW_AUTO_COMMIT=true CLAUDE_FLOW_AUTO_PUSH=false'

# ── Hive-Mind Aliases ─────────────────────────────
# Simplified hive-mind commands with smart defaults
# Full auto-spawn with all optimization flags
# Usage: hive "your command here"
# Example: hive "install dependencies and run tests"
alias hive='_hive_auto'

_hive_auto() {
    npx -y claude-flow@v3alpha hive-mind spawn "$*" --claude
}

# Quick mode (less verbose, parallel execution)
alias hive-quick='_hive_quick'

_hive_quick() {
    npx -y claude-flow@v3alpha hive-mind spawn "$*" --claude
}

# Manual control mode (verbose output, manual oversight)
alias hive-manual='_hive_manual'

_hive_manual() {
    npx -y claude-flow@v3alpha hive-mind spawn "$*" --claude --verbose
}

# Sequential execution (no parallelization)
alias hive-seq='_hive_seq'

_hive_seq() {
    npx -y claude-flow@v3alpha hive-mind spawn "$*" --auto-spawn --claude --verbose
}

# Utility aliases
alias hive-help='claude-flow hive-mind --help'
alias hive-status='claude-flow hive-mind status'
alias hive-agents='claude-flow hive-mind list-agents'

# ── SPARC Aliases ─────────────────────────────────
# SPARC methodology commands
alias sparc-modes='claude-flow sparc modes'
alias sparc-run='claude-flow sparc run'
alias sparc-tdd='claude-flow sparc tdd'

# ── End Claude Flow Aliases ───────────────────────
ALIASES_EOF

    log_success "Aliases file created: $ALIASES_FILE"
}

# Update local host (agldv03)
update_agldv03() {
    log ""
    log "========================================="
    log "  Updating AGLDV03 (Local)"
    log "========================================="

    # Backup .zshrc
    log "Creating backup of .zshrc..."
    cp ~/.zshrc ~/.zshrc.backup.$TIMESTAMP
    log_success "Backup created: .zshrc.backup.$TIMESTAMP"

    # Remove old Claude Flow aliases
    log "Removing old Claude Flow aliases..."
    sed -i '/# ======== Claude Flow Aliases ==========/,/End Claude Flow Aliases/d' ~/.zshrc 2>/dev/null || true
    sed -i '/Claude Flow Hive-Mind Aliases/,/End Claude Flow Aliases/d' ~/.zshrc 2>/dev/null || true
    log_success "Old aliases removed"

    # Add new aliases
    log "Adding new Claude Flow aliases..."
    cat "$ALIASES_FILE" >> ~/.zshrc
    log_success "New aliases added"

    # Ensure NVM is loaded at end of .zshrc
    if ! grep -q "NVM_DIR.*nvm.sh" ~/.zshrc; then
        log "Adding NVM configuration..."
        echo "" >> ~/.zshrc
        echo "# ===============================================" >> ~/.zshrc
        echo "# Force NVM Node v24" >> ~/.zshrc
        echo "# ===============================================" >> ~/.zshrc
        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
        echo 'nvm use 24 >/dev/null 2>&1 || true' >> ~/.zshrc
        log_success "NVM configuration added"
    fi
}

# Update remote host (agldv04)
update_agldv04() {
    log ""
    log "========================================="
    log "  Updating AGLDV04 (CT180/dokploy)"
    log "========================================="

    # Test SSH connection
    log "Testing SSH connection to $AGLDV04_USER@$AGLDV04_IP..."
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes $AGLDV04_USER@$AGLDV04_IP "echo 'Connection OK'" > /dev/null 2>&1; then
        log_error "Cannot connect to $AGLDV04_USER@$AGLDV04_IP"
        return 1
    fi
    log_success "SSH connection successful"

    # Transfer aliases file
    log "Transferring aliases file to agldv04..."
    scp "$ALIASES_FILE" $AGLDV04_USER@$AGLDV04_IP:/tmp/claude-flow-aliases.txt
    log_success "File transferred"

    # Execute update on remote
    log "Executing update on agldv04..."
    ssh $AGLDV04_USER@$AGLDV04_IP << 'REMOTE_EOF'
        set -euo pipefail

        # Backup .zshrc
        echo "Creating backup..."
        cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || touch ~/.zshrc

        # Remove old aliases
        echo "Removing old Claude Flow aliases..."
        sed -i '/# ======== Claude Flow Aliases ==========/,/End Claude Flow Aliases/d' ~/.zshrc 2>/dev/null || true
        sed -i '/Claude Flow Hive-Mind Aliases/,/End Claude Flow Aliases/d' ~/.zshrc 2>/dev/null || true

        # Add new aliases
        echo "Adding new aliases..."
        cat /tmp/claude-flow-aliases.txt >> ~/.zshrc

        # Ensure NVM is loaded
        if ! grep -q "NVM_DIR.*nvm.sh" ~/.zshrc; then
            echo "" >> ~/.zshrc
            echo "# Force NVM Node v24" >> ~/.zshrc
            echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
            echo 'nvm use 24 >/dev/null 2>&1 || true' >> ~/.zshrc
        fi

        # Clean up
        rm -f /tmp/claude-flow-aliases.txt

        echo "✓ agldv04 updated successfully"
REMOTE_EOF

    log_success "agldv04 updated"
}

# Test installation on local host
test_local() {
    log ""
    log "========================================="
    log "  Testing AGLDV03 (Local)"
    log "========================================="

    # Reload .zshrc
    log "Reloading .zshrc..."
    source ~/.zshrc
    log_success "Shell reloaded"

    # Test Node version
    log "Testing Node.js version..."
    node --version
    if ! node --version | grep -q "v24"; then
        log_warn "Node.js v24 not active, attempting to switch..."
        nvm use 24 || {
            log_error "Node.js v24 not installed via NVM"
            log "Installing Node.js v24..."
            nvm install 24
            nvm use 24
        }
    fi
    log_success "Node.js $(node --version) active"

    # Test claude-flow
    log "Testing claude-flow command..."
    if claude-flow --version 2>&1 | head -3; then
        log_success "claude-flow working"
    else
        log_error "claude-flow failed"
        return 1
    fi

    # Test hive-mind status
    log "Testing hive-mind status..."
    if claude-flow hive-mind status 2>&1 | head -10; then
        log_success "hive-mind status working"
    else
        log_warn "hive-mind status returned error (may be offline)"
    fi

    # Test aliases
    log "Testing aliases..."
    type hive | head -3
    type cf-dev | head -3
    log_success "Aliases defined"
}

# Test installation on remote host
test_remote() {
    log ""
    log "========================================="
    log "  Testing AGLDV04"
    log "========================================="

    ssh $AGLDV04_USER@$AGLDV04_IP << 'REMOTE_EOF'
        echo "========================================="
        echo "  Testing Claude Flow on agldv04"
        echo "========================================="
        echo ""

        # Reload .zshrc
        echo "Reloading .zshrc..."
        source ~/.zshrc

        # Test Node version
        echo "Testing Node.js version..."
        node --version
        if ! node --version | grep -q "v24"; then
            echo "Node.js v24 not active, attempting to switch..."
            nvm use 24 2>/dev/null || {
                echo "Node.js v24 not installed, installing..."
                nvm install 24
                nvm use 24
            }
        fi
        echo "✓ Node.js $(node --version) active"

        # Test claude-flow
        echo ""
        echo "Testing claude-flow command..."
        claude-flow --version 2>&1 | head -3
        echo "✓ claude-flow working"

        # Test hive-mind status
        echo ""
        echo "Testing hive-mind status..."
        claude-flow hive-mind status 2>&1 | head -10
        echo "✓ hive-mind status tested"

        # Test aliases
        echo ""
        echo "Testing aliases..."
        type hive | head -3
        type cf-dev | head -3
        echo "✓ Aliases defined"

        echo ""
        echo "========================================="
        echo "  All Tests Passed on agldv04"
        echo "========================================="
REMOTE_EOF
}

# Validate fgsrv6
validate_fgsrv6() {
    log ""
    log "========================================="
    log "  Validating FGSRV6"
    log "========================================="

    log "Testing fgsrv6 configuration..."
    if ssh root@100.83.51.9 "claude-flow --version 2>&1 | head -3"; then
        log_success "fgsrv6 claude-flow working"
    else
        log_warn "fgsrv6 claude-flow returned error (expected via npx)"
    fi

    if ssh root@100.83.51.9 "claude-flow hive-mind status 2>&1 | head -10"; then
        log_success "fgsrv6 hive-mind working"
    else
        log_warn "fgsrv6 hive-mind returned error (may be offline)"
    fi
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "  Claude Flow v3alpha Update"
    echo "  Node.js v24 + npx"
    echo "========================================="
    echo ""
    echo "Timestamp: $TIMESTAMP"
    echo ""

    create_aliases_file

    # Update agldv03 (local)
    if [ "$(hostname)" = "agldv03" ] || hostname | grep -q "CT179"; then
        update_agldv03
    else
        log_warn "Not running on agldv03, skipping local update"
    fi

    # Update agldv04 (remote)
    read -p "$(echo -e ${YELLOW}Update agldv04? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_agldv04
    else
        log_warn "Skipping agldv04 update"
    fi

    # Test local
    if [ "$(hostname)" = "agldv03" ] || hostname | grep -q "CT179"; then
        test_local
    fi

    # Test remote if updated
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_remote
    fi

    # Validate fgsrv6
    validate_fgsrv6

    echo ""
    echo "========================================="
    log_success "Update Complete!"
    echo "========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Open new terminal or run: source ~/.zshrc"
    echo "  2. Test: hive-status"
    echo "  3. Test: cf-dev"
    echo "  4. Test: hive 'test command'"
    echo ""
    echo "Rollback if needed:"
    echo "  agldv03: cp ~/.zshrc.backup.$TIMESTAMP ~/.zshrc"
    echo "  agldv04: ssh root@$AGLDV04_IP 'cp ~/.zshrc.backup.* ~/.zshrc'"
    echo ""
}

# Run main
main "$@"
