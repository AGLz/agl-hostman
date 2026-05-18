#!/bin/bash
# Tailscale Distributed Storage Setup
# Creates a distributed storage pool using Tailscale mesh network
# Combines local and remote PBS datastores

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} Tailscale Distributed Storage Setup${NC}"
echo -e "${BOLD}======================================${NC}"
echo ""

# Configuration
LOCAL_STORAGE="/overpower"
MOUNT_BASE="/mnt/tailscale-storage"
MERGERFS_MOUNT="/mnt/distributed-storage"

# Tailscale nodes
AGLSRV1_IP="100.107.113.33"  # Local
AGLSRV6_IP="100.98.108.66"   # Remote PBS
AGLSRV6B_IP="100.98.119.51"  # Remote PBS

echo -e "${YELLOW}Configuration:${NC}"
echo "  Local storage: $LOCAL_STORAGE"
echo "  Mount base: $MOUNT_BASE"
echo "  MergerFS mount: $MERGERFS_MOUNT"
echo ""
echo "  AGLSRV1:  $AGLSRV1_IP (local)"
echo "  AGLSRV6:  $AGLSRV6_IP (remote)"
echo "  AGLSRV6b: $AGLSRV6B_IP (remote)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Step 1: Install dependencies
echo ""
echo -e "${BOLD}Step 1: Installing dependencies${NC}"
apt-get update -qq
apt-get install -y sshfs mergerfs > /dev/null 2>&1
echo -e "${GREEN}✅ SSHFS and MergerFS installed${NC}"

# Step 2: Create mount points
echo ""
echo -e "${BOLD}Step 2: Creating mount points${NC}"
mkdir -p $MOUNT_BASE/{local,pbs-aglsrv6,pbs-aglsrv6b}
mkdir -p $MERGERFS_MOUNT
echo -e "${GREEN}✅ Mount points created${NC}"

# Step 3: Mount local storage
echo ""
echo -e "${BOLD}Step 3: Mounting local storage${NC}"
if mountpoint -q $MOUNT_BASE/local; then
    echo "  Already mounted"
else
    mount --bind $LOCAL_STORAGE $MOUNT_BASE/local
    echo -e "${GREEN}✅ Local storage mounted${NC}"
fi

# Step 4: Setup SSH keys
echo ""
echo -e "${BOLD}Step 4: SSH key setup${NC}"
if [ ! -f /root/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
fi
echo -e "${GREEN}✅ SSH key ready${NC}"

echo ""
echo -e "${YELLOW}⚠️ Manual step required:${NC}"
echo "  Copy SSH key to remote hosts:"
echo "    ssh-copy-id root@$AGLSRV6_IP"
echo "    ssh-copy-id root@$AGLSRV6B_IP"
echo ""
read -p "Press enter when SSH keys are copied..."

# Step 5: Find PBS datastores on remote hosts
echo ""
echo -e "${BOLD}Step 5: Locating PBS datastores${NC}"

echo "  Checking AGLSRV6..."
AGLSRV6_PBS=$(ssh -o StrictHostKeyChecking=no root@$AGLSRV6_IP "find /mnt /srv /var/lib -name 'datastore' -type d 2>/dev/null | head -1" || echo "")
if [ -n "$AGLSRV6_PBS" ]; then
    echo -e "${GREEN}  ✅ Found: $AGLSRV6_PBS${NC}"
else
    echo -e "${YELLOW}  ⚠️ No PBS datastore found, will use /mnt/shares${NC}"
    AGLSRV6_PBS="/mnt/shares"
fi

echo "  Checking AGLSRV6b..."
AGLSRV6B_PBS=$(ssh -o StrictHostKeyChecking=no root@$AGLSRV6B_IP "find /mnt /srv /var/lib -name 'datastore' -type d 2>/dev/null | head -1" || echo "")
if [ -n "$AGLSRV6B_PBS" ]; then
    echo -e "${GREEN}  ✅ Found: $AGLSRV6B_PBS${NC}"
else
    echo -e "${YELLOW}  ⚠️ No PBS datastore found, will use /mnt/shares${NC}"
    AGLSRV6B_PBS="/mnt/shares"
fi

# Step 6: Mount remote PBS via SSHFS
echo ""
echo -e "${BOLD}Step 6: Mounting remote PBS via SSHFS${NC}"

echo "  Mounting AGLSRV6..."
if mountpoint -q $MOUNT_BASE/pbs-aglsrv6; then
    echo "  Already mounted"
else
    sshfs root@$AGLSRV6_IP:$AGLSRV6_PBS $MOUNT_BASE/pbs-aglsrv6 \
        -o allow_other,default_permissions,reconnect,ServerAliveInterval=15
    echo -e "${GREEN}  ✅ AGLSRV6 mounted${NC}"
fi

echo "  Mounting AGLSRV6b..."
if mountpoint -q $MOUNT_BASE/pbs-aglsrv6b; then
    echo "  Already mounted"
else
    sshfs root@$AGLSRV6B_IP:$AGLSRV6B_PBS $MOUNT_BASE/pbs-aglsrv6b \
        -o allow_other,default_permissions,reconnect,ServerAliveInterval=15
    echo -e "${GREEN}  ✅ AGLSRV6b mounted${NC}"
fi

# Step 7: Create MergerFS pool
echo ""
echo -e "${BOLD}Step 7: Creating MergerFS distributed pool${NC}"

if mountpoint -q $MERGERFS_MOUNT; then
    echo "  Already mounted"
else
    mergerfs \
        $MOUNT_BASE/local:$MOUNT_BASE/pbs-aglsrv6:$MOUNT_BASE/pbs-aglsrv6b \
        $MERGERFS_MOUNT \
        -o category.create=mfs,moveonenospc=true,minfreespace=50G,cache.files=auto-full
    echo -e "${GREEN}  ✅ MergerFS pool created${NC}"
fi

# Step 8: Verify
echo ""
echo -e "${BOLD}Step 8: Verification${NC}"
df -h | grep -E 'tailscale-storage|distributed-storage'

echo ""
echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} Setup Complete!${NC}"
echo -e "${BOLD}======================================${NC}"
echo ""
echo -e "${GREEN}✅ Distributed storage ready at: $MERGERFS_MOUNT${NC}"
echo ""
echo "Storage pools combined:"
echo "  - AGLSRV1 local: $LOCAL_STORAGE"
echo "  - AGLSRV6 PBS: $AGLSRV6_PBS (via Tailscale)"
echo "  - AGLSRV6b PBS: $AGLSRV6B_PBS (via Tailscale)"
echo ""
echo "Access via:"
echo "  SMB: \\\\192.168.0.178\\distributed"
echo "  NFS: 192.168.0.178:/mnt/distributed-storage"
echo ""
echo "To make persistent, add to /etc/fstab and /etc/rc.local"
