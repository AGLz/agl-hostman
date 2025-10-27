#!/bin/bash
#
# Harbor CT182 - Proxmox LXC Container Creation Script
# Server: aglsrv1
# IP: 192.168.1.182
# Purpose: Enterprise container registry with vulnerability scanning
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Container Configuration
CTID=182
HOSTNAME="harbor"
STORAGE="local-lvm"
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
DISK_SIZE="100G"
MEMORY=8192
SWAP=4096
CORES=4
BRIDGE="vmbr0"
IP_ADDRESS="192.168.1.182/24"
GATEWAY="192.168.1.1"
DNS="1.1.1.1"
PASSWORD=""  # Will prompt if not set

# Harbor Requirements
# Minimum: 4GB RAM, 40GB storage
# Recommended: 8GB RAM, 100GB storage
# Production: 16GB RAM, 200GB+ storage

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Harbor CT182 Container Creation${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running on Proxmox
if ! command -v pct &> /dev/null; then
    echo -e "${RED}ERROR: This script must be run on a Proxmox host${NC}"
    exit 1
fi

# Check if container already exists
if pct status $CTID &> /dev/null; then
    echo -e "${YELLOW}WARNING: Container $CTID already exists${NC}"
    read -p "Do you want to destroy and recreate it? (yes/no): " -r
    if [[ $REPLY == "yes" ]]; then
        echo -e "${YELLOW}Stopping and destroying CT$CTID...${NC}"
        pct stop $CTID || true
        pct destroy $CTID
    else
        echo -e "${RED}Aborted${NC}"
        exit 1
    fi
fi

# Prompt for password if not set
if [ -z "$PASSWORD" ]; then
    read -sp "Enter root password for container: " PASSWORD
    echo
    read -sp "Confirm password: " PASSWORD_CONFIRM
    echo
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo -e "${RED}ERROR: Passwords do not match${NC}"
        exit 1
    fi
fi

# Check if template exists
if ! pvesm list local | grep -q "${TEMPLATE##*/}"; then
    echo -e "${YELLOW}Template not found, downloading Debian 12...${NC}"
    pveam update
    pveam download local debian-12-standard_12.7-1_amd64.tar.zst
fi

echo -e "${GREEN}Creating LXC container CT$CTID...${NC}"

# Create container
pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --storage $STORAGE \
    --rootfs $STORAGE:$DISK_SIZE \
    --memory $MEMORY \
    --swap $SWAP \
    --cores $CORES \
    --net0 name=eth0,bridge=$BRIDGE,ip=$IP_ADDRESS,gw=$GATEWAY \
    --nameserver $DNS \
    --password "$PASSWORD" \
    --unprivileged 0 \
    --features nesting=1,keyctl=1 \
    --onboot 1 \
    --description "Harbor - Enterprise Container Registry with Vulnerability Scanning"

echo -e "${GREEN}Container created successfully!${NC}"

# Enable nesting and other required features for Docker
echo -e "${GREEN}Configuring container features...${NC}"
cat >> /etc/pve/lxc/${CTID}.conf << EOF

# Harbor Docker Requirements
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.mount.auto: proc:rw sys:rw

# Resource limits for Harbor
lxc.prlimit.nofile: 65536
EOF

echo -e "${GREEN}Starting container...${NC}"
pct start $CTID

# Wait for container to boot
echo -e "${YELLOW}Waiting for container to start...${NC}"
sleep 5

# Update container
echo -e "${GREEN}Updating container packages...${NC}"
pct exec $CTID -- bash -c "apt-get update && apt-get upgrade -y"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Container Creation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Container ID: ${YELLOW}$CTID${NC}"
echo -e "Hostname: ${YELLOW}$HOSTNAME${NC}"
echo -e "IP Address: ${YELLOW}${IP_ADDRESS%/*}${NC}"
echo -e "Memory: ${YELLOW}${MEMORY}MB${NC}"
echo -e "Disk: ${YELLOW}$DISK_SIZE${NC}"
echo -e "Cores: ${YELLOW}$CORES${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Run: ${GREEN}./install-harbor.sh${NC}"
echo -e "2. Access Harbor at: ${GREEN}https://${IP_ADDRESS%/*}${NC}"
echo -e "${GREEN}========================================${NC}"
