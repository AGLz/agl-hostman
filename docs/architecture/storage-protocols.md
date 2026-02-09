# Storage Protocols

This document provides detailed information about the storage protocols used in AGL Hostman, including NFS, iSCSI, and PBS.

## Overview

AGL Hostman supports multiple storage protocols to meet different use cases:

- **NFS (Network File System)**: File-based storage for general file sharing
- **iSCSI (Internet Small Computer System Interface)**: Block-based storage for VMs
- **PBS (Proxmox Backup Server)**: Dedicated backup storage system

## NFS Configuration

### 1. NFS Overview

NFS (Network File System) is a distributed file system protocol that allows clients to access files over a network. It's ideal for:

- VM disk images and templates
- General file sharing
- ISO library storage
- User home directories

### 2. NFS Server Configuration on AGLSRV1

#### Installation
```bash
# Install NFS server
sudo apt update
sudo apt install -y nfs-kernel-server

# Create export directories
sudo mkdir -p /export/data
sudo mkdir -p /export/backups
sudo mkdir -p /export/iso
sudo mkdir -p /export/vms

# Set permissions
sudo chown -R nobody:nogroup /export/*
sudo chmod -R 755 /export/*
```

#### `/etc/exports` Configuration
```bash
# Edit exports file
sudo nano /etc/exports

# Add the following exports:
/export/data       100.64.0.0/16(rw,sync,no_subtree_check,no_root_squash)
/export/backups    100.64.0.0/16(ro,sync,no_subtree_check)
/export/iso        100.64.0.0/16(rw,sync,no_subtree_check,no_root_squash)
/export/vms        100.64.0.0/16(rw,sync,no_subtree_check,no_root_squash)
```

#### Start and Enable NFS
```bash
# Start NFS services
sudo systemctl start nfs-server
sudo systemctl enable nfs-server

# Check status
sudo systemctl status nfs-server
```

### 3. NFS Client Configuration

#### Install NFS Client
```bash
# Install NFS client
sudo apt update
sudo apt install -y nfs-common
```

#### Mount NFS Shares
```bash
# Create mount points
sudo mkdir -p /nfs/data
sudo mkdir -p /nfs/backups
sudo mkdir -p /nfs/iso
sudo mkdir -p /nfs/vms

# Mount NFS shares
sudo mount -t nfs aglsrv1.local:/export/data /nfs/data
sudo mount -t nfs aglsrv1.local:/export/backups /nfs/backups
sudo mount -t nfs aglsrv1.local:/export/iso /nfs/iso
sudo mount -t nfs aglsrv1.local:/export/vms /nfs/vms

# Add to fstab for automatic mounting
echo "aglsrv1.local:/export/data /nfs/data nfs defaults,_netdev,hard,intr,tcp,nfsvers=4.2 0 0" | sudo tee -a /etc/fstab
echo "aglsrv1.local:/export/backups /nfs/backups nfs defaults,_netdev,hard,intr,tcp,nfsvers=4.2,ro 0 0" | sudo tee -a /etc/fstab
echo "aglsrv1.local:/export/iso /nfs/iso nfs defaults,_netdev,hard,intr,tcp,nfsvers=4.2 0 0" | sudo tee -a /etc/fstab
echo "aglsrv1.local:/export/vms /nfs/vms nfs defaults,_netdev,hard,intr,tcp,nfsvers=4.2 0 0" | sudo tee -a /etc/fstab
```

### 4. NFS Performance Optimization

#### Kernel Tuning
```bash
# Edit sysctl.conf
sudo nano /etc/sysctl.conf

# Add the following optimizations:
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.netdev_max_backlog = 30000
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.somaxconn = 65535
```

#### Mount Options Optimization
```bash
# Optimized fstab entries
echo "aglsrv1.local:/export/vms /nfs/vms nfs rw,_netdev,hard,intr,tcp,rsize=1048576,wsize=1048576,nfsvers=4.2,async,noatime,nodiratime 0 0" | sudo tee -a /etc/fstab
echo "aglsrv1.local:/export/data /nfs/data nfs rw,_netdev,hard,intr,tcp,rsize=1048576,wsize=1048576,nfsvers=4.2,async,noatime,nodiratime 0 0" | sudo tee -a /etc/fstab
```

#### Jumbo Frames
```bash
# Enable jumbo frames for high-performance transfers
sudo ethtool -K eth0 tx off
sudo ethtool -K eth0 rx off
sudo ethtool -K eth0 sg on
sudo ethtool -K eth0 tso on
sudo ethtool -K eth0 gso on
sudo ethtool -K eth0 gro on
```

### 5. NFS Monitoring

#### Performance Metrics
```bash
# Check NFS performance
nfsstat -c
nfsstat -s

# Check mounted file systems
df -h /nfs/*

# Check I/O operations
iostat -x /nfs/data 1
```

#### Monitoring Scripts
```bash
#!/bin/bash
# nfs-monitor.sh
# Monitor NFS performance

# Check mount status
mountpoint -q /nfs/data || echo "NFS data not mounted"

# Check response time
time_out=$(ping -c 1 aglsrv1.local | awk '/time=/ {print $8}' | cut -d'=' -f2)
echo "NFS response time: $time_out"

# Check throughput
dd if=/nfs/data/testfile of=/dev/null bs=1M count=1000 2>&1 | grep copied
```

## iSCSI Configuration

### 1. iSCSI Overview

iSCSI is a storage networking standard that allows data storage over TCP/IP. It's ideal for:

- VM disk storage
- Database storage
- High-performance block storage
- SAN-like functionality

### 2. iSCSI Target Configuration on AGLSRV1

#### Installation
```bash
# Install iSCSI target
sudo apt update
sudo apt install -y tgt

# Create iSCSI storage
sudo mkdir -p /iscsi/storage
sudo truncate -s 500G /iscsi/storage/main.img
sudo truncate -s 1T /iscsi/storage/backup.img
sudo truncate -s 2T /iscsi/storage/archive.img
```

#### Target Configuration
```bash
# Create iSCSI target configuration
sudo nano /etc/tgt/conf.d/agl-hostman.conf

# Add the following configuration:
<target iqn.2025-10.com.aglhostman:storage-main>
    backing-store /iscsi/storage/main.img
    initiator-address 100.64.0.0/16
    incominguser agl-hostman secure-password
</target>

<target iqn.2025-10.com.aglhostman:storage-backup>
    backing-store /iscsi/storage/backup.img
    initiator-address 100.64.0.0/16
    incominguser agl-hostman secure-password
</target>

<target iqn.2025-10.com.aglhostman:storage-archive>
    backing-store /iscsi/storage/archive.img
    initiator-address 100.64.0.0/16
    incominguser agl-hostman secure-password
</target>
```

#### Start and Enable iSCSI Target
```bash
# Start tgt service
sudo systemctl start tgt
sudo systemctl enable tgt

# Check target status
sudo tgtadm --mode target --op show
```

### 3. iSCSI Initiator Configuration

#### Installation
```bash
# Install iSCSI initiator
sudo apt update
sudo apt install -y open-iscsi
```

#### Configure Initiator
```bash
# Edit initiator configuration
sudo nano /etc/iscsi/iscsid.conf

# Configure initiator
node.startup = automatic
node.session.auth.method = CHAP
node.session.auth.username = agl-hostman
node.session.auth.password = secure-password
node.session.timeo.replacement_timeout = 30
node.conn[0].timeo.login_timeout = 20
node.conn[0].timeo.logout_timeout = 15
```

#### Discover and Connect to Targets
```bash
# Discover targets
iscsiadm -m discovery -t st -p aglsrv1.local

# Login to targets
iscsiadm -m node -T iqn.2025-10.com.aglhostman:storage-main -p aglsrv1.local -l
iscsiadm -m node -T iqn.2025-10.com.aglhostman:storage-backup -p aglsrv1.local -l
iscsiadm -m node -T iqn.2025-10.com.aglhostman:storage-archive -p aglsrv1.local -l

# Check connected sessions
iscsiadm -m session
```

#### Format and Mount iSCSI Devices
```bash
# Check for iSCSI devices
lsblk

# Format devices (first time only)
sudo mkfs.ext4 /dev/sdb
sudo mkfs.ext4 /dev/sdc
sudo mkfs.ext4 /dev/sdd

# Create mount points
sudo mkdir -p /iscsi/main
sudo mkdir -p /iscsi/backup
sudo mkdir -p /iscsi/archive

# Mount devices
sudo mount /dev/sdb /iscsi/main
sudo mount /dev/sdc /iscsi/backup
sudo mount /dev/sdd /iscsi/archive

# Add to fstab
echo "/dev/sdb /iscsi/main ext4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab
echo "/dev/sdc /iscsi/backup ext4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab
echo "/dev/sdd /iscsi/archive ext4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab
```

### 4. iSCSI Performance Optimization

#### Multipathing
```bash
# Install multipathing tools
sudo apt install -y multipath-tools

# Configure multipath
sudo nano /etc/multipath.conf

# Add multipath configuration:
defaults {
    user_friendly_names yes
    path_grouping_policy multibus
    failback immediate
    no_path_retry fail
}

blacklist {
    devnode "^(ram|loop|fd|md|sr|scd|st)[0-9]*"
    devnode "^sr[0-9]*"
}

devices {
    device {
        vendor "LIO-ORG"
        product "storage"
        path_grouping_policy multibus
        path_selector "service-time 0"
        failback immediate
        hardware_handler "1 alua"
        prio "alua"
    }
}
```

#### Network Optimization
```bash
# Enable jumbo frames for iSCSI
sudo ethtool -K eth0 rxvlan off
sudo ethtool -K eth0 txvlan off
sudo ethtool -K eth0 rxhash off

# Configure MTU
sudo ip link set mtu 9000 dev eth0
```

#### Kernel Tuning
```bash
# Add to /etc/sysctl.conf
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_congestion_control = bbr
```

### 5. iSCSI Monitoring

#### Performance Metrics
```bash
# Check iSCSI sessions
iscsiadm -m session -P 3

# Check block device performance
iostat -x /dev/sd[bcd] 1

# Check multipath status
multipath -ll
```

#### Monitoring Scripts
```bash
#!/bin/bash
# iscsi-monitor.sh
# Monitor iSCSI performance

# Check iSCSI sessions
session_count=$(iscsiadm -m session | wc -l)
echo "iSCSI sessions: $session_count"

# Check device latency
iostat -d /dev/sdb 1 5 | tail -1

# Check multipath status
echo "Multipath devices:"
multipath -ll 2>/dev/null || echo "No multipath devices configured"
```

## PBS Configuration

### 1. PBS Overview

Proxmox Backup Server (PBS) is a dedicated backup solution for virtual environments. It features:

- Deduplication
- Compression
- Encryption
- Incremental backups
- Backup verification

### 2. PBS Installation on AGLSRV1

#### System Requirements
- CPU: 4 cores minimum
- RAM: 8GB minimum
- Storage: 1TB+ for backups

#### Installation
```bash
# Add Proxmox repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pbs bullseye pbs-no-subscription" | sudo tee /etc/apt/sources.list.d/pbs.list

# Add repository key
wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
apt update && apt dist-upgrade

# Install PBS
sudo apt install -y proxmox-backup-server

# Initialize PBS
proxmox-backup-manager setup
```

#### Basic Configuration
```bash
# Set up backup user
proxmox-backup-manager user create agl-hostman@pam --password secure-password

# Create backup repository
proxmox-backup-manager datastore create agl-backups --format zfs --storage local-zfs

# Set up SSH access for remote clients
sudo useradd -m -s /bin/bash agl-backup
sudo -u agl-backup ssh-keygen -t ed25519 -f /home/agl-backup/.ssh/pbs_backup
sudo chown agl-backup:agl-backup /home/agl-backup/.ssh/pbs_backup
```

### 3. Client Configuration

#### Install PBS Client
```bash
# On each Proxmox host
apt update
apt install -y proxmox-backup-client
```

#### Configure Client
```bash
# Create client configuration
sudo nano /etc/proxmox-backup/server.conf

# Add server configuration
server aglsrv1.local {
    auth {
        password "secure-password"
    }
}
```

#### Register Client
```bash
# Register with PBS server
proxmox-backup-client register aglsrv1.local agl-backup-data --repository agl-backups
```

### 4. Backup Configuration

#### Schedule Backups
```bash
# Create backup job
proxmox-backup-manager job create agl-backupschedule --schedule "0 2 * * *" --datastore agl-backups --notification email
```

#### Backup Types
```bash
# Full backup (monthly)
proxmox-backup-manager job create full-backup --schedule "0 2 1 * *" --datastore agl-backups --mode full

# Differential backup (weekly)
proxmox-backup-manager job create diff-backup --schedule "0 2 * * 0" --datastore agl-backups --mode differential

# Incremental backup (daily)
proxmox-backup-manager job create incr-backup --schedule "0 2 * * *" --datastore agl-backups --mode snapshot
```

#### Backup Exclusions
```bash
# Create backup exclusion list
cat > /etc/proxmox-backup/exclude.txt << EOF
*.log
*.tmp
*/cache/*
*/tmp/*
*/.git/*
*/node_modules/*
EOF
```

### 5. PBS Performance Optimization

#### Storage Configuration
```bash
# ZFS optimization
zpool set compression=lz4 agl-backups
zpool set atime=off agl-backups
zpool set sync=always agl-backups
```

#### Network Optimization
```bash
# Increase TCP buffer sizes
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
sysctl -p
```

#### Backup Optimization
```bash
# Configure chunk size
proxmox-backup-manager config set agl-backups chunk-size=4M
```

### 6. PBS Monitoring

#### Backup Status
```bash
# Check backup status
proxmox-backup-manager job list
proxmox-backup-manager job show agl-backupschedule

# Check backup history
proxmox-backup-manager datastore history agl-backups
```

#### Performance Metrics
```bash
# Check ZFS performance
zpool iostat agl-backups 1

# Check network performance
iftop -i eth0
```

#### Monitoring Scripts
```bash
#!/bin/bash
# pbs-monitor.sh
# Monitor PBS performance

# Check backup jobs
echo "Backup Jobs:"
proxmox-backup-manager job list --output-format=json | jq -r '.[].status'

# Check storage usage
echo "Storage Usage:"
df -h /mnt/pbs-data

# Check ZFS performance
echo "ZFS Performance:"
zpool iostat agl-backups 1 5 | tail -1
```

## Storage Protocol Comparison

### 1. Performance Comparison

| Protocol | Read Speed | Write Speed | Latency | Best Use Case |
|----------|------------|-------------|---------|---------------|
| **NFS 4.2** | 300-500 MB/s | 200-400 MB/s | 5-15ms | File sharing, VM templates |
| **iSCSI** | 400-600 MB/s | 300-500 MB/s | 1-5ms | VM disks, databases |
| **PBS** | 100-300 MB/s | 50-200 MB/s | 10-30ms | Backup storage |

### 2. Feature Comparison

| Feature | NFS | iSCSI | PBS |
|--------|-----|-------|-----|
| **File Sharing** | ✅ | ❌ | ❌ |
| **Block Storage** | ❌ | ✅ | ❌ |
| **Backup** | ⚠️ | ❌ | ✅ |
| **Deduplication** | ❌ | ❌ | ✅ |
| **Compression** | Limited | Limited | ✅ |
| **Encryption** | ❌ | ⚠️ | ✅ |
| **Mounting** | Simple | Complex | Complex |

### 3. Use Cases

#### NFS Use Cases
- VM templates and ISO storage
- General file sharing
- Home directories
- Web server content
- Development environments

#### iSCSI Use Cases
- VM disk storage
- Database storage
- High-performance applications
- SAN-like functionality
- Business-critical systems

#### PBS Use Cases
- Virtual machine backups
- System backups
- Application backups
- Long-term storage
- Disaster recovery

## Storage Best Practices

### 1. NFS Best Practices
- Use NFS 4.2 for best performance
- Mount with proper options (hard, intr, tcp)
- Enable jumbo frames for high-throughput scenarios
- Monitor NFS performance regularly
- Use dedicated storage for high-I/O workloads

### 2. iSCSI Best Practices
- Use multipathing for redundancy
- Enable jumbo frames for performance
- Use CHAP authentication for security
- Monitor I/O performance
- Regularly check connection status

### 3. PBS Best Practices
- Use ZFS for optimal performance
- Enable compression and deduplication
- Implement proper retention policies
- Regularly test restores
- Monitor storage capacity

## Troubleshooting

### 1. Common Issues

#### NFS Issues
- Mount hangs or fails
- Poor performance
- Permission denied
- File locking issues

#### iSCSI Issues
- Connection timeouts
- Path failures
- Performance degradation
- Authentication issues

#### PBS Issues
- Backup failures
- Storage capacity
- Network timeouts
- Client connection issues

### 2. Troubleshooting Commands

#### NFS Troubleshooting
```bash
# Check NFS server status
showmount -e aglsrv1.local

# Test NFS mount
mount -t nfs aglsrv1.local:/export/data /mnt/test
umount /mnt/test

# Check NFS performance
nfsstat -c
```

#### iSCSI Troubleshooting
```bash
# Check iSCSI sessions
iscsiadm -m session

# Check multipath status
multipath -ll

# Test iSCSI connectivity
ping aglsrv1.local
```

#### PBS Troubleshooting
```bash
# Check PBS status
systemctl status proxmox-backup-server

# Check backup jobs
proxmox-backup-manager job list

# Test connection
proxmox-backup-client ping aglsrv1.local
```

---

*Next: [Network Topology](network-topology.md)*

*Previous: [Architecture Overview](overview.md)*