#!/bin/bash
# CT111 Optimization Script (AGLSRV6)
# Apply same optimizations as CT178

set -e

echo "=== CT111 Optimization Script ==="
echo "Target: CT111 on AGLSRV6 (100.98.108.66)"
echo ""

# This script should be run on AGLSRV6 host
SSH_TARGET="root@100.98.108.66"

echo "Connecting to AGLSRV6..."
ssh $SSH_TARGET << 'REMOTE_EOF'

# Create optimized Samba config
echo "1. Creating optimized Samba configuration..."
pct exec 111 -- bash << 'CT111_SAMBA'
cat > /etc/samba/smb.conf << 'SMB_CONF'
[global]
workgroup = WORKGROUP
server string = CT111 File Server
security = user
map to guest = Bad User
server min protocol = SMB2
server multi channel support = yes
read raw = yes
write raw = yes
max xmit = 65535
dead time = 15
getwd cache = yes
aio read size = 16384
aio write size = 16384
aio write behind = true
use sendfile = yes
vfs objects = aio_pthread
oplocks = yes
level2 oplocks = yes
kernel oplocks = no
kernel share modes = no
aio max threads = 100
max open files = 65535
server signing = disabled
client signing = disabled
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
strict allocate = yes
log level = 0
max log size = 50
load printers = no
printing = bsd
printcap name = /dev/null
disable spoolss = yes
unix extensions = no
wide links = yes

[shares]
path = /mnt/shares
browseable = yes
writable = yes
guest ok = yes

[sistema]
path = /mnt/sistema
browseable = yes
writable = yes
guest ok = yes

[bb]
path = /mnt/bb
browseable = yes
writable = yes
guest ok = yes

[bkp]
path = /mnt/bkp
browseable = yes
writable = yes
guest ok = yes
SMB_CONF

systemctl restart smbd nmbd
systemctl enable smbd nmbd
CT111_SAMBA

echo "✅ Samba configured"

# Configure NFS
echo "2. Configuring NFS..."
pct exec 111 -- bash << 'CT111_NFS'
echo 'RPCNFSDCOUNT=16' > /etc/default/nfs-kernel-server
echo 16 > /proc/fs/nfsd/threads
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server
CT111_NFS

echo "✅ NFS configured"

# Network tuning
echo "3. Applying network tuning..."
pct exec 111 -- sysctl -w net.ipv4.tcp_congestion_control=bbr
pct exec 111 -- sysctl -w net.ipv4.tcp_fastopen=3

echo ""
echo "✅ CT111 optimization complete!"
echo ""
echo "Services:"
pct exec 111 -- systemctl is-active smbd nmbd nfs-kernel-server

REMOTE_EOF

echo ""
echo "Done!"
