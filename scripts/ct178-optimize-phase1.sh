#!/bin/bash
# CT178 File Server Optimization - Phase 1 (Quick Wins)
# Implements immediate performance improvements
# Created: 2025-10-14

set -e  # Exit on error

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}======================================"
echo -e " CT178 Optimization - Phase 1"
echo -e " Quick Performance Wins"
echo -e "======================================${NC}"
echo ""

# Check if running on AGLSRV1
if ! pct status 178 &>/dev/null; then
    echo -e "${RED}Error: Must run on AGLSRV1 Proxmox host${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️ This script will:${NC}"
echo "  1. Check and warn about disk space (spark pool 100% full)"
echo "  2. Increase CT178 memory from 2GB to 8GB"
echo "  3. Increase CT178 CPU cores from 4 to 8"
echo "  4. Optimize Samba configuration"
echo "  5. Increase NFS server threads"
echo "  6. Apply network tuning"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${BOLD}Step 1: Checking Disk Space${NC}"
echo "======================================"

# Check spark pool usage
SPARK_USAGE=$(pct exec 178 -- df -h /mnt/power | awk 'NR==2{print $5}' | tr -d '%')

echo "Spark pool usage: ${SPARK_USAGE}%"

if [ "$SPARK_USAGE" -gt 95 ]; then
    echo -e "${RED}🔴 CRITICAL: Spark pool is ${SPARK_USAGE}% full!${NC}"
    echo -e "${RED}   Performance will be SEVERELY degraded.${NC}"
    echo ""
    echo "Top 10 largest directories on /mnt/power:"
    pct exec 178 -- du -sh /mnt/power/* 2>/dev/null | sort -hr | head -10
    echo ""
    echo -e "${YELLOW}⚠️ RECOMMENDATION: Free up space before continuing${NC}"
    echo "   Target: Get below 80% for optimal performance"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please free up disk space first. Exiting."
        exit 0
    fi
elif [ "$SPARK_USAGE" -gt 80 ]; then
    echo -e "${YELLOW}⚠️ WARNING: Spark pool is ${SPARK_USAGE}% full${NC}"
    echo "   Performance may be impacted. Consider freeing space."
else
    echo -e "${GREEN}✅ Spark pool usage OK (${SPARK_USAGE}%)${NC}"
fi

echo ""
echo -e "${BOLD}Step 2: Increasing Container Resources${NC}"
echo "======================================"

# Get current settings
CURRENT_MEM=$(pct config 178 | grep "^memory:" | awk '{print $2}')
CURRENT_CORES=$(pct config 178 | grep "^cores:" | awk '{print $2}')

echo "Current memory: ${CURRENT_MEM}MB"
echo "Current cores: ${CURRENT_CORES}"

# Stop container
echo "Stopping CT178..."
pct stop 178
sleep 5

# Increase resources
echo "Setting memory to 8192MB..."
pct set 178 -memory 8192

echo "Setting swap to 4096MB..."
pct set 178 -swap 4096

echo "Setting cores to 8..."
pct set 178 -cores 8

# Start container
echo "Starting CT178..."
pct start 178
sleep 15

# Verify
NEW_MEM=$(pct config 178 | grep "^memory:" | awk '{print $2}')
NEW_CORES=$(pct config 178 | grep "^cores:" | awk '{print $2}')

echo -e "${GREEN}✅ Resources updated:${NC}"
echo "   Memory: ${CURRENT_MEM}MB → ${NEW_MEM}MB"
echo "   Cores: ${CURRENT_CORES} → ${NEW_CORES}"

echo ""
echo -e "${BOLD}Step 3: Optimizing Samba Configuration${NC}"
echo "======================================"

# Backup existing config
echo "Backing up current Samba configuration..."
pct exec 178 -- cp /etc/samba/smb.conf /etc/samba/smb.conf.backup-$(date +%Y%m%d-%H%M%S)

# Create optimized smb.conf
echo "Creating optimized Samba configuration..."
pct exec 178 -- bash << 'SAMBA_EOF'
cat > /etc/samba/smb.conf << 'EOF'
[global]
workgroup = WORKGROUP
server string = CT178 File Server
security = user
map to guest = Bad User

# Performance - Protocol
server min protocol = SMB2
server multi channel support = yes

# Performance - Core Settings
read raw = yes
write raw = yes
max xmit = 65535
dead time = 15
getwd cache = yes

# Performance - Async I/O
aio read size = 16384
aio write size = 16384
aio write behind = true
use sendfile = yes
vfs objects = aio_pthread

# Performance - Oplocks (client caching)
oplocks = yes
level2 oplocks = yes
kernel oplocks = no
kernel share modes = no

# Performance - Logging
log level = 0
max log size = 50

# Disable unnecessary features
load printers = no
printing = bsd
printcap name = /dev/null
disable spoolss = yes

# Symlinks support
unix extensions = no
wide links = yes

[shares]
path = /mnt/shares
browseable = yes
writable = yes
guest ok = yes
create mask = 0664
directory mask = 0775

[overpower]
path = /mnt/overpower
browseable = yes
writable = yes
guest ok = yes
create mask = 0664
directory mask = 0775

[power]
path = /mnt/power
browseable = yes
writable = yes
guest ok = yes
create mask = 0664
directory mask = 0775

[storage]
path = /mnt/storage
browseable = yes
writable = yes
guest ok = yes
create mask = 0664
directory mask = 0775
EOF
SAMBA_EOF

# Test Samba config
echo "Testing Samba configuration..."
if pct exec 178 -- testparm -s /etc/samba/smb.conf &>/dev/null; then
    echo -e "${GREEN}✅ Samba configuration valid${NC}"
else
    echo -e "${RED}❌ Samba configuration has errors!${NC}"
    pct exec 178 -- testparm
    exit 1
fi

# Restart Samba
echo "Restarting Samba services..."
pct exec 178 -- systemctl restart smbd nmbd

# Verify services
if pct exec 178 -- systemctl is-active smbd | grep -q "active"; then
    echo -e "${GREEN}✅ Samba (smbd) is running${NC}"
else
    echo -e "${RED}❌ Samba (smbd) failed to start${NC}"
    exit 1
fi

if pct exec 178 -- systemctl is-active nmbd | grep -q "active"; then
    echo -e "${GREEN}✅ Samba (nmbd) is running${NC}"
else
    echo -e "${RED}❌ Samba (nmbd) failed to start${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}Step 4: Optimizing NFS Server${NC}"
echo "======================================"

# Backup NFS config
echo "Backing up NFS configuration..."
pct exec 178 -- cp /etc/default/nfs-kernel-server /etc/default/nfs-kernel-server.backup-$(date +%Y%m%d-%H%M%S)

# Increase NFS threads
echo "Increasing NFS daemon threads to 16..."
pct exec 178 -- bash << 'NFS_EOF'
# Update NFS thread count
sed -i 's/^#\?RPCNFSDCOUNT=.*/RPCNFSDCOUNT=16/' /etc/default/nfs-kernel-server

# Add if not exists
if ! grep -q "RPCNFSDCOUNT" /etc/default/nfs-kernel-server; then
    echo "RPCNFSDCOUNT=16" >> /etc/default/nfs-kernel-server
fi

# Enable both v3 and v4
sed -i 's/^#\?RPCNFSDOPTS=.*/RPCNFSDOPTS="-V 3 -V 4 -N 2"/' /etc/default/nfs-kernel-server

# Add if not exists
if ! grep -q "RPCNFSDOPTS" /etc/default/nfs-kernel-server; then
    echo 'RPCNFSDOPTS="-V 3 -V 4 -N 2"' >> /etc/default/nfs-kernel-server
fi
NFS_EOF

# Restart NFS
echo "Restarting NFS server..."
pct exec 178 -- systemctl restart nfs-kernel-server

# Verify
if pct exec 178 -- systemctl is-active nfs-kernel-server | grep -q "active"; then
    echo -e "${GREEN}✅ NFS server is running${NC}"

    # Check thread count
    NFS_THREADS=$(pct exec 178 -- cat /proc/fs/nfsd/threads 2>/dev/null || echo "unknown")
    echo "   NFS daemon threads: ${NFS_THREADS}"
else
    echo -e "${RED}❌ NFS server failed to start${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}Step 5: Applying Network Tuning${NC}"
echo "======================================"

# Create network tuning config
echo "Creating network tuning configuration..."
pct exec 178 -- bash << 'NET_EOF'
cat > /etc/sysctl.d/99-fileserver-tuning.conf << 'EOF'
# Network Performance Tuning for File Server
# Applied: 2025-10-14

# TCP Buffer Sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Connection Handling
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 8192

# TCP Performance
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1

# BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Reduce TIME_WAIT
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1

# Local port range
net.ipv4.ip_local_port_range = 1024 65535
EOF

# Apply tuning
sysctl -p /etc/sysctl.d/99-fileserver-tuning.conf
NET_EOF

echo -e "${GREEN}✅ Network tuning applied${NC}"

# Verify BBR
BBR_STATUS=$(pct exec 178 -- sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
echo "   TCP congestion control: ${BBR_STATUS}"

echo ""
echo -e "${BOLD}======================================"
echo -e " Phase 1 Optimization Complete!"
echo -e "======================================${NC}"
echo ""
echo -e "${GREEN}✅ Summary of Changes:${NC}"
echo ""
echo "  📊 Resources:"
echo "     - Memory: ${CURRENT_MEM}MB → 8192MB"
echo "     - CPU Cores: ${CURRENT_CORES} → 8"
echo ""
echo "  🚀 Services Optimized:"
echo "     - Samba: Async I/O, sendfile, oplocks enabled"
echo "     - NFS: 16 daemon threads, v3+v4 enabled"
echo "     - Network: BBR, optimized TCP buffers"
echo ""
echo -e "${YELLOW}⚠️ IMPORTANT NOTES:${NC}"
echo ""
echo "  1. Disk Space: Spark pool at ${SPARK_USAGE}%"
if [ "$SPARK_USAGE" -gt 80 ]; then
    echo -e "     ${RED}→ FREE UP SPACE! Performance degraded above 80%${NC}"
fi
echo ""
echo "  2. Test File Transfers:"
echo "     - SMB: \\\\192.168.0.178\\storage"
echo "     - NFS: mount -t nfs 192.168.0.178:/mnt/storage /mnt/test"
echo "     - SFTP: sftp root@192.168.0.178"
echo ""
echo "  3. Expected Improvement: 2-5x faster transfers"
echo ""
echo "  4. Next Steps:"
echo "     - Monitor performance with: /root/scripts/ct178-monitor.sh"
echo "     - Proceed to Phase 2 for further optimization"
echo "     - See: /root/host-admin/claudedocs/CT178_FILESERVER_PERFORMANCE_OPTIMIZATION.md"
echo ""
echo -e "${GREEN}✅ Optimization complete!${NC}"
echo ""
