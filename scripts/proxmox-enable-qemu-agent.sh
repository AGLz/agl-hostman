#!/bin/bash
# Enable QEMU Guest Agent for VM on Proxmox host
# Usage: ./proxmox-enable-qemu-agent.sh [VMID] [HOST]
# Example: ./proxmox-enable-qemu-agent.sh 104 192.168.0.245
# Run from any machine with SSH access to the Proxmox host

set -e

VMID="${1:-104}"
HOST="${2:-192.168.0.245}"

echo "=== Proxmox QEMU Guest Agent ==="
echo "VM ID: $VMID"
echo "Host:  $HOST"
echo ""

echo "1. Enabling agent in VM config..."
ssh "root@$HOST" "qm set $VMID --agent 1"

echo ""
echo "2. Testing agent communication..."
if ssh "root@$HOST" "qm agent $VMID ping" 2>/dev/null; then
    echo ""
    echo "✅ QEMU Guest Agent OK - VM $VMID is manageable from Proxmox"
else
    echo ""
    echo "⚠️  Agent ping failed. Ensure:"
    echo "   - QEMU Guest Agent is installed in the VM (Windows: QEMU-GA service)"
    echo "   - VM has virtio-serial device (default in Proxmox)"
    echo "   - VM was started after enabling agent"
    exit 1
fi
