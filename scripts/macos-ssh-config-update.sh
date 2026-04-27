#!/bin/bash
# Update SSH config with Tailscale IPs for AGL infrastructure
# This script adds optimized SSH entries for macOS → infrastructure access

SSH_CONFIG="$HOME/.ssh/config"
BACKUP_FILE="$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"

echo "Backing up SSH config to: $BACKUP_FILE"
cp "$SSH_CONFIG" "$BACKUP_FILE"

echo "Adding AGL infrastructure entries to SSH config..."

# Check if entries already exist
if grep -q "# AGL Infrastructure - Tailscale Access" "$SSH_CONFIG"; then
    echo "AGL entries already exist. Skipping..."
    exit 0
fi

# Append new configuration
cat >> "$SSH_CONFIG" << 'EOF'

# ============================================================================
# AGL Infrastructure - Tailscale Access (macOS)
# Generated: 2025-10-29
# ============================================================================

# CT179 - Primary Development Container (48GB RAM, Docker, triple-stack)
Host ct179 agldv03
  HostName 100.94.221.87
  User root
  IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
  ServerAliveCountMax 3
  Compression yes
  ControlMaster auto
  ControlPath ~/.ssh/controlmasters/%r@%h:%p
  ControlPersist 10m

# CT183 - Archon AI Command Center (MCP Server, RAG, Task Management)
Host ct183 archon
  HostName 100.80.30.59
  User root
  IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
  ServerAliveCountMax 3
  # Port forwards for MCP and Web UI
  LocalForward 8051 localhost:8051
  LocalForward 8052 localhost:8052

# CT180 - Dokploy (Deployment Platform)
Host ct180 dokploy
  HostName 100.116.218.100
  User root
  IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
  ServerAliveCountMax 3

# CT108 - AGLSRV6 Development Container
Host ct108 agldv06
  HostName 100.71.229.12
  User root
  IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
  ServerAliveCountMax 3

# AGLSRV1 - Main Proxmox Host (192.168.0.245)
Host aglsrv1-ts
  HostName 100.107.113.33
  User root
  IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
  ServerAliveCountMax 3

# AGLSRV6 - Secondary Proxmox Host (Remote)
Host aglsrv6-ts
  HostName 100.119.25.106
  User root
  IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
  ServerAliveCountMax 3

# ============================================================================
# SSH Multiplexing for all AGL hosts
# ============================================================================
Host ct* aglsrv* agldv*
  ControlMaster auto
  ControlPath ~/.ssh/controlmasters/%r@%h:%p
  ControlPersist 10m
  Compression yes

EOF

# Create control masters directory if it doesn't exist
mkdir -p "$HOME/.ssh/controlmasters"

echo "✓ SSH config updated successfully!"
echo "✓ Backup saved to: $BACKUP_FILE"
echo ""
echo "Test connections:"
echo "  ssh ct179 'hostname'"
echo "  ssh ct183 'docker ps | grep archon'"
echo "  ssh ct180 'curl -s http://localhost:3000/api/health'"
