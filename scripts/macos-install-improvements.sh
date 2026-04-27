#!/bin/bash
# macOS AI Engineer Experience Improvements - Installation Script
# This script sets up all productivity enhancements for AGL infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}AGL macOS AI Engineer Setup${NC}"
echo -e "${CYAN}================================${NC}\n"

# ============================================================================
# 1. Update SSH Config
# ============================================================================
echo -e "${YELLOW}[1/6] Updating SSH config with Tailscale entries...${NC}"
bash "$SCRIPT_DIR/macos-ssh-config-update.sh"
echo -e "${GREEN}✓ SSH config updated${NC}\n"

# ============================================================================
# 2. Install Shell Functions
# ============================================================================
echo -e "${YELLOW}[2/6] Installing shell functions and aliases...${NC}"

SHELL_RC="$HOME/.zshrc"
SOURCE_LINE="source $SCRIPT_DIR/macos-agl-setup.sh"

if grep -q "macos-agl-setup.sh" "$SHELL_RC" 2>/dev/null; then
    echo "  Already configured in $SHELL_RC"
else
    echo "" >> "$SHELL_RC"
    echo "# AGL Infrastructure Quick Access" >> "$SHELL_RC"
    echo "$SOURCE_LINE" >> "$SHELL_RC"
    echo -e "${GREEN}✓ Added to $SHELL_RC${NC}"
fi

# Load functions in current shell
source "$SCRIPT_DIR/macos-agl-setup.sh"
echo -e "${GREEN}✓ Shell functions loaded${NC}\n"

# ============================================================================
# 3. Configure Claude MCP - Archon
# ============================================================================
echo -e "${YELLOW}[3/6] Configuring Claude MCP servers...${NC}"

# Check if claude command exists
if ! command -v claude &> /dev/null; then
    echo -e "${RED}⚠ Claude CLI not found. Install from: https://docs.claude.com${NC}"
else
    # Check if Archon is already configured
    if claude mcp list 2>/dev/null | grep -q "archon"; then
        echo "  Archon MCP already configured"
    else
        echo "  Adding Archon MCP server (Tailscale)..."
        claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp || true
        echo -e "${GREEN}✓ Archon MCP added${NC}"
    fi

    echo ""
    echo "  MCP Servers configured:"
    claude mcp list | grep -E "Connected|Disconnected" || echo "  (none)"
fi
echo ""

# ============================================================================
# 4. Create Quick Access Scripts
# ============================================================================
echo -e "${YELLOW}[4/6] Creating quick access launchers...${NC}"

mkdir -p "$HOME/.local/bin"

# Create agl command
cat > "$HOME/.local/bin/agl" << EOF
#!/bin/bash
cd /Users/admin/apps/dev/agl/agl-hostman
exec "\$SHELL"
EOF
chmod +x "$HOME/.local/bin/agl"

# Create archon-ui launcher
cat > "$HOME/.local/bin/archon-ui" << EOF
#!/bin/bash
echo "Opening Archon Web UI..."
open "http://localhost:8052" || open "https://archon.aglz.io"
EOF
chmod +x "$HOME/.local/bin/archon-ui"

# Create dokploy-ui launcher
cat > "$HOME/.local/bin/dokploy-ui" << EOF
#!/bin/bash
echo "Opening Dokploy Dashboard..."
open "https://dok.aglz.io"
EOF
chmod +x "$HOME/.local/bin/dokploy-ui"

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
    export PATH="$HOME/.local/bin:$PATH"
fi

echo -e "${GREEN}✓ Quick launchers created in ~/.local/bin${NC}\n"

# ============================================================================
# 5. Create VS Code Integration (if installed)
# ============================================================================
echo -e "${YELLOW}[5/6] Checking for VS Code...${NC}"

if command -v code &> /dev/null; then
    VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
    echo "  VS Code detected"
    echo "  Settings: $VSCODE_SETTINGS"
    echo "  (Manual configuration recommended)"
else
    echo "  VS Code not found (optional)"
fi
echo ""

# ============================================================================
# 6. Test Connectivity
# ============================================================================
echo -e "${YELLOW}[6/6] Testing infrastructure connectivity...${NC}"

# Test key hosts
for host in "100.94.221.87:CT179" "100.80.30.59:CT183-Archon" "100.107.113.33:AGLSRV1"; do
    ip=$(echo $host | cut -d: -f1)
    name=$(echo $host | cut -d: -f2)
    if ping -c 1 -W 2 $ip &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $name ($ip) reachable"
    else
        echo -e "  ${RED}✗${NC} $name ($ip) not reachable"
    fi
done
echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}\n"

echo -e "${CYAN}Quick Start:${NC}"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Run 'agl-help' to see all available commands"
echo "  3. Run 'agl-status' to check infrastructure"
echo "  4. Run 'archon-health' to test Archon MCP"
echo ""

echo -e "${CYAN}Key Commands:${NC}"
echo "  agl-ct179         - SSH to primary development container"
echo "  agl-ct183         - SSH to Archon AI Command Center"
echo "  archon-health     - Check Archon MCP status"
echo "  agl-docs          - Browse documentation"
echo "  agl-status        - Infrastructure overview"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Test SSH: ssh ct179 'hostname'"
echo "  2. Verify Claude MCP: claude mcp list"
echo "  3. Check Archon: archon-health"
echo "  4. Read docs: agl-docs infra"
echo ""

echo -e "${YELLOW}Backup Files:${NC}"
echo "  SSH config: ~/.ssh/config.backup.*"
echo ""

echo "Happy coding! 🚀"
