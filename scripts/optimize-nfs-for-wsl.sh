#!/bin/bash
# Optimize NFS Server for WSL2 Compatibility
# Run on aglfs1 (CT178) @ 192.168.0.178
# Date: 2025-10-21

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}NFS Server Optimization for WSL2${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root${NC}"
    exit 1
fi

# Check if running on aglfs1
HOSTNAME=$(hostname)
if [ "$HOSTNAME" != "aglfs1" ]; then
    echo -e "${YELLOW}WARNING: This script is designed for aglfs1${NC}"
    echo -e "Current hostname: $HOSTNAME"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: Backup current configuration
echo -e "${YELLOW}[1/6] Backing up current configuration...${NC}"

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/nfs-backup-${BACKUP_DATE}"

mkdir -p "$BACKUP_DIR"

if [ -f /etc/exports ]; then
    cp /etc/exports "$BACKUP_DIR/exports.backup"
    echo -e "  ${GREEN}✓${NC} Backed up /etc/exports"
fi

if [ -f /etc/nfs.conf ]; then
    cp /etc/nfs.conf "$BACKUP_DIR/nfs.conf.backup"
    echo -e "  ${GREEN}✓${NC} Backed up /etc/nfs.conf"
fi

if [ -d /etc/sysctl.d ]; then
    cp -r /etc/sysctl.d "$BACKUP_DIR/sysctl.d.backup"
    echo -e "  ${GREEN}✓${NC} Backed up /etc/sysctl.d"
fi

echo -e "  ${CYAN}Backup location: $BACKUP_DIR${NC}\n"

# Step 2: Update /etc/exports with WSL optimizations
echo -e "${YELLOW}[2/6] Updating /etc/exports with WSL-optimized settings...${NC}"

cat > /etc/exports << 'EOF'
# Standard exports for local networks
/srv 10.0.0.0/8(rw,fsid=0,no_subtree_check) 172.16.0.0/12(rw,fsid=0,no_subtree_check) 192.168.0.0/16(rw,fsid=0,no_subtree_check)
/srv/storage 10.0.0.0/8(rw,fsid=1,no_subtree_check) 172.16.0.0/12(rw,fsid=1,no_subtree_check) 192.168.0.0/16(rw,fsid=1,no_subtree_check)
/srv/homes 10.0.0.0/8(rw,fsid=2,no_subtree_check) 172.16.0.0/12(rw,fsid=2,no_subtree_check) 192.168.0.0/16(rw,fsid=2,no_subtree_check)

# WSL2-optimized exports
# Options explained:
#   async - Asynchronous writes for better performance
#   no_wdelay - Respond immediately to writes (better latency)
#   no_root_squash - Root on client = root on server
#   insecure - Allow connections from ports > 1024 (WSL2 requirement)
#   no_subtree_check - Disable subtree checking (performance)
#   fsid=X - Unique filesystem ID
#   nohide - Show nested filesystems
/mnt/overpower *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=10,nohide)
/mnt/power     *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=11,nohide)
/mnt/storage   *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=12,nohide)
/mnt/shares    *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=13,nohide)
/mnt/spark     *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=14,nohide)
EOF

echo -e "  ${GREEN}✓${NC} Updated /etc/exports\n"

# Step 3: Configure /etc/nfs.conf
echo -e "${YELLOW}[3/6] Configuring /etc/nfs.conf...${NC}"

cat > /etc/nfs.conf << 'EOF'
[general]
# pipefs-directory=/run/rpc_pipefs

[nfsd]
# Number of server threads (increased for virtualized clients)
threads=16

# NFS versions to support
vers3=y
vers4=y
vers4.0=y
vers4.1=y
vers4.2=y

# TCP only (WSL2 doesn't support UDP)
udp=n
tcp=y

# Grace period for client recovery (increased for WSL2)
grace-time=90

# Lease time for NFSv4 (seconds)
lease-time=90

[mountd]
# Mount daemon threads
threads=8

# Manage supplementary groups
manage-gids=y

# Port for mount daemon (optional, for firewall rules)
# port=20048

[statd]
# NLM port (optional, for firewall rules)
port=32765
outgoing-port=32766

[lockd]
# NLM UDP/TCP ports
udp-port=32768
tcp-port=32768

[sm-notify]
# Retry time for SM notifications
retry-time=900
EOF

echo -e "  ${GREEN}✓${NC} Configured /etc/nfs.conf\n"

# Step 4: Apply sysctl network tuning
echo -e "${YELLOW}[4/6] Applying network tuning (sysctl)...${NC}"

cat > /etc/sysctl.d/90-nfs-wsl-tuning.conf << 'EOF'
# NFS WSL2 Network Tuning
# Applied: 2025-10-21

# TCP keepalive (detect dead connections faster)
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# TCP buffer sizes (accommodate large transfers)
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Connection handling
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 4096

# Enable TCP optimizations
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1

# Reduce swappiness (keep NFS data in memory)
vm.swappiness = 10

# Increase inotify limits (for file watchers)
fs.inotify.max_user_watches = 524288
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/90-nfs-wsl-tuning.conf > /dev/null 2>&1

echo -e "  ${GREEN}✓${NC} Applied sysctl network tuning\n"

# Step 5: Reload exports and restart services
echo -e "${YELLOW}[5/6] Reloading exports and restarting services...${NC}"

# Reload exports
exportfs -ra

echo -e "  ${GREEN}✓${NC} Reloaded NFS exports"

# Restart NFS server
systemctl restart nfs-server
echo -e "  ${GREEN}✓${NC} Restarted nfs-server"

# Restart related services
systemctl restart nfs-idmapd 2>/dev/null || true
systemctl restart rpc-statd 2>/dev/null || true

sleep 2

# Verify services are running
if systemctl is-active --quiet nfs-server; then
    echo -e "  ${GREEN}✓${NC} NFS server is active"
else
    echo -e "  ${RED}✗${NC} NFS server failed to start"
    systemctl status nfs-server
    exit 1
fi

echo ""

# Step 6: Verification
echo -e "${YELLOW}[6/6] Verification...${NC}"

echo -e "\n${CYAN}Active Exports:${NC}"
exportfs -v

echo -e "\n${CYAN}NFS Server Status:${NC}"
systemctl status nfs-server --no-pager | head -10

echo -e "\n${CYAN}NFS Versions Supported:${NC}"
cat /proc/fs/nfsd/versions

echo -e "\n${CYAN}Active NFS Processes:${NC}"
ps aux | grep -E 'nfsd|rpc\.' | grep -v grep

# Summary
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}OPTIMIZATION COMPLETE${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "${GREEN}✓ Configuration optimized for WSL2${NC}"
echo -e "${GREEN}✓ Backup saved to: $BACKUP_DIR${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Test from WSL with:"
echo -e "   ${CYAN}showmount -e 192.168.0.178${NC}"
echo -e ""
echo -e "2. Try mounting (WSL):"
echo -e "   ${CYAN}sudo mount -t nfs -o vers=3,tcp,soft,timeo=600,retrans=3,rsize=32768,wsize=32768,nolock \\${NC}"
echo -e "   ${CYAN}    192.168.0.178:/mnt/overpower /mnt/test-nfs${NC}"
echo -e ""
echo -e "3. If mount fails (expected due to WSL kernel limitations):"
echo -e "   ${CYAN}Continue using SSHFS: /mnt/overpower-sshfs${NC}\n"

echo -e "${YELLOW}Notes:${NC}"
echo -e "- These optimizations help but cannot fix WSL2 kernel limitations"
echo -e "- NFS will work better for Linux VMs and Proxmox hosts"
echo -e "- SSHFS remains the recommended solution for WSL2\n"

# Save optimization log
LOG_FILE="/var/log/nfs-wsl-optimization-${BACKUP_DATE}.log"
{
    echo "NFS WSL Optimization Applied: $(date)"
    echo "Backup location: $BACKUP_DIR"
    echo ""
    echo "Active Exports:"
    exportfs -v
    echo ""
    echo "sysctl settings:"
    sysctl -a 2>/dev/null | grep -E 'tcp_keepalive|tcp_rmem|tcp_wmem|swappiness'
} > "$LOG_FILE"

echo -e "${CYAN}Optimization log saved to: $LOG_FILE${NC}\n"
