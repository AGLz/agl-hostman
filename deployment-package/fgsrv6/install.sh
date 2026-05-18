#!/bin/bash

# Statusline Installation Script for FGSRV6
# Target: ssh root@186.202.57.120 (or 10.6.0.5 via WireGuard)

set -e

echo "========================================="
echo "  Statusline Installation for FGSRV6"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root or with sudo"
    exit 1
fi

# Detect operating system and install dependencies
echo "📦 Installing dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    echo "  → Detected Debian/Ubuntu system"
    apt-get update -qq
    apt-get install -y jq bc git curl
elif command -v yum >/dev/null 2>&1; then
    echo "  → Detected RHEL/CentOS system"
    yum install -y jq bc git curl
elif command -v apk >/dev/null 2>&1; then
    echo "  → Detected Alpine Linux system"
    apk add --no-cache jq bc git curl
else
    echo "  ⚠️  Could not detect package manager. Please install jq, bc, git manually."
fi

echo ""
echo "✅ Dependencies installed successfully"
echo ""

# Create .claude directory in root home
CLAUDE_DIR="/root/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "📁 Creating $CLAUDE_DIR..."
    mkdir -p "$CLAUDE_DIR"
fi

# Copy files
echo "📋 Installing configuration files..."
cp .claude/statusline-command.sh "$CLAUDE_DIR/"
chmod +x "$CLAUDE_DIR/statusline-command.sh"

cp .claude/settings.json "$CLAUDE_DIR/settings.json"

echo "  → Installed: $CLAUDE_DIR/statusline-command.sh"
echo "  → Installed: $CLAUDE_DIR/settings.json"

# Verify installation
echo ""
echo "🔍 Verifying installation..."

if [ -x "$CLAUDE_DIR/statusline-command.sh" ]; then
    echo "  ✅ statusline-command.sh is executable"
else
    echo "  ❌ statusline-command.sh is not executable"
    exit 1
fi

if [ -f "$CLAUDE_DIR/settings.json" ]; then
    echo "  ✅ settings.json exists"
else
    echo "  ❌ settings.json not found"
    exit 1
fi

# Test jq and bc
if command -v jq >/dev/null 2>&1; then
    echo "  ✅ jq is available"
else
    echo "  ❌ jq not found"
    exit 1
fi

if command -v bc >/dev/null 2>&1; then
    echo "  ✅ bc is available"
else
    echo "  ❌ bc not found"
    exit 1
fi

if command -v git >/dev/null 2>&1; then
    echo "  ✅ git is available"
else
    echo "  ❌ git not found"
    exit 1
fi

echo ""
echo "========================================="
echo "  ✅ Installation Complete!"
echo "========================================="
echo ""
echo "The statusline will now display:"
echo "  • Claude model name and current directory"
echo "  • Git branch (if in a git repository)"
echo "  • Swarm topology and agent count"
echo "  • Memory usage (color-coded)"
echo "  • CPU load (color-coded)"
echo "  • Session ID (when active)"
echo "  • Task success rate (color-coded)"
echo "  • Average task duration"
echo "  • Task streak"
echo "  • Active task count"
echo "  • Hooks status indicator"
echo ""
echo "Files installed to: $CLAUDE_DIR/"
echo ""
