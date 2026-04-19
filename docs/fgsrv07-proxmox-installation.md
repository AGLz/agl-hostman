# Proxmox VE Installation Guide - FGSRV07

## Server Information

| Property | Value |
|----------|-------|
| **Hostname** | FGSRV07 |
| **Type** | VPS Locaweb |
| **Operating System** | Debian 13 (Trixie) |
| **IP Address** | 191.252.93.227 |
| **SSH Access** | Key-based authentication configured |

## Table of Contents

1. [Prerequisites & System Requirements](#1-prerequisites--system-requirements)
2. [Pre-Installation Checks](#2-pre-installation-checks)
3. [Repository Configuration](#3-repository-configuration)
4. [Proxmox VE Installation](#4-proxmox-ve-installation)
5. [Initial Web Interface Configuration](#5-initial-web-interface-configuration)
6. [Network Configuration](#6-network-configuration)
7. [Storage Setup](#7-storage-setup)
8. [Post-Installation Tasks](#8-post-installation-tasks)
9. [Cluster Integration](#9-cluster-integration)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites & System Requirements

### Minimum Requirements for Proxmox VE 8.x

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 64-bit processor | 4+ cores |
| **RAM** | 2 GB | 8+ GB |
| **Disk** | 32 GB | 100+ GB SSD/NVMe |
| **Network** | 1 Gbps | 10 Gbps |

### FGSRV07 Specifications

Verify your VPS meets these requirements before proceeding:

```bash
# Check CPU
lscpu | grep "Model name"

# Check RAM
free -h

# Check Disk
df -h

# Check Network Speed
ethtool eth0 || ip link show
```

---

## 2. Pre-Installation Checks

### 2.1 Update System to Latest

```bash
# Ensure you have root privileges
sudo -i

# Update package lists
apt update

# Upgrade all packages
apt upgrade -y

# Reboot if kernel was updated
# reboot
```

### 2.2 Verify Debian Version

```bash
cat /etc/debian_version
# Should output: 13.x
```

### 2.3 Check Hostname Configuration

```bash
# Set hostname if not already configured
hostnamectl set-hostname fgsrv07

# Verify
hostname
hostnamectl
```

### 2.4 Configure /etc/hosts

```bash
# Edit hosts file
nano /etc/hosts
```

Ensure it contains:

```text
127.0.0.1 localhost.localdomain localhost
191.252.93.227 fgsrv07.agl.hostman fgsrv07

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

### 2.5 Verify Network Configuration

```bash
# Check IP configuration
ip addr show

# Check default route
ip route show

# Test connectivity
ping -c 4 google.com
```

### 2.6 Check for Conflicting Services

```bash
# Services that may conflict with Proxmox
systemctl stop libvirtd.service
systemctl disable libvirtd.service

# Stop any existing LXC containers
systemctl stop lxc.service
systemctl disable lxc.service
```

---

## 3. Repository Configuration

### 3.1 Add Proxmox Repositories for Debian 13

**Note:** Debian 13 (Trixie) requires using the Debian Testing repositories for Proxmox.

```bash
# Add Proxmox VE repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list

# Since we're on Debian 13, we need to adjust repository priorities
# Create apt preferences file
cat > /etc/apt/preferences.d/pve.pref << 'EOF'
Package: *
Pin: release o=Proxmox
Pin-Priority: 1000
EOF
```

### 3.2 Add Required Repositories

```bash
# Ensure contrib and non-free are enabled
sed -i 's/main contrib non-free/main contrib non-free non-free-firmware/g' /etc/apt/sources.list

# For Debian 13, add necessary repositories
cat > /etc/apt/sources.list.d/debian-trixie.list << 'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
```

### 3.3 Add Proxmox Repository Key

```bash
# Download and add the Proxmox signing key
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# Verify key was added
ls -l /etc/apt/trusted.gpg.d/
```

### 3.4 Update Package Lists

```bash
# Update all repositories
apt update

# Check for errors
apt list --upgradable
```

---

## 4. Proxmox VE Installation

### 4.1 Install Proxmox VE Kernel

```bash
# Install Proxmox kernel
apt install pve-kernel-6.8 -y

# List installed kernels
dpkg --list | grep pve-kernel
```

### 4.2 Reboot into Proxmox Kernel

```bash
# Reboot to load the new kernel
reboot

# After reboot, verify kernel
uname -r
# Should show: 6.8.x-pve
```

### 4.3 Install Proxmox VE Packages

```bash
# Become root again
sudo -i

# Update repositories
apt update

# Install complete Proxmox VE suite
apt install proxmox-ve postfix open-iscsi -y
```

### 4.4 Postfix Configuration

During installation, configure Postfix mail server:

```text
General type of mail configuration: Internet Site
System mail name: fgsrv07.agl.hostman
```

Or for non-production:

```text
General type of mail configuration: Local only
```

### 4.5 Additional Required Packages

```bash
# Install additional packages for full functionality
apt install \
  pve-firewall \
  pve-ha-manager \
  lvm2 \
  lxc-pve \
  lxcfs \
  criu \
  proxmox-widget-toolkit \
  -y

# Install useful tools
apt install \
  vim \
  htop \
  net-tools \
  tcpdump \
  rsync \
 -y
```

---

## 5. Initial Web Interface Configuration

### 5.1 Access the Web Interface

After installation completes:

1. Open web browser to: `https://191.252.93.227:8006`
2. Accept the self-signed SSL certificate warning
3. Login with:
   - **Username:** `root`
   - **Password:** Your server's root password

### 5.2 Create Admin User

It's recommended to create a separate admin user:

```bash
# In web interface or CLI
pveum useradd admin@pve
pveum passwd admin@pve
pveum aclmod / -user admin@pve -role Administrator
```

### 5.3 Configure Datacenter Settings

Via Web Interface:

1. Navigate to **Datacenter → Options**
2. Set these options:

| Setting | Value |
|---------|-------|
| **Keyboard Layout** | en-us |
| **Console** | SPICE (enhanced) |
| **Email from** | pve@fgsrv07.agl.hostman |
| **Max Workers** | 4 (adjust based on CPU) |

### 5.4 Create Network Bridge

```bash
# Configure network bridge for VM/CT traffic
nano /etc/network/interfaces
```

Add bridge configuration:

```text
auto lo
iface lo inet loopback

auto enp0s3
iface enp0s3 inet manual

auto vmbr0
iface vmbr0 inet static
    address 191.252.93.227/24
    gateway 191.252.93.1
    bridge-ports enp0s3
    bridge-stp off
    bridge-fd 0
```

**Adjust interface names** (enp0s3) based on your actual interface from `ip addr show`.

Restart networking:

```bash
systemctl restart networking
```

---

## 6. Network Configuration

### 6.1 Network Bridge for VMs/Containers

The default bridge `vmbr0` should already be configured. Verify:

```bash
# Check network configuration
cat /etc/network/interfaces

# Verify bridge is up
ip link show vmbr0
brctl show
```

### 6.2 Optional: Create Additional Bridge for Isolated Networks

For isolated VM/LXC networks:

```bash
# Edit interfaces
nano /etc/network/interfaces
```

Add:

```text
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Restart:

```bash
systemctl restart networking
```

### 6.3 Configure Firewall

Enable and configure the Proxmox firewall:

```bash
# Enable at datacenter level
pve-firewall enable

# Enable specific rules
pvesh create /cluster/firewall/options --input ACCEPT --output ACCEPT --enable 1

# Allow SSH, HTTP, HTTPS from management network
pvesh create /cluster/firewall/rules --pos 1 --action ACCEPT --source 0.0.0.0/0 --proto tcp --dport 22
pvesh create /cluster/firewall/rules --pos 2 --action ACCEPT --source 0.0.0.0/0 --proto tcp --dport 8006
```

### 6.4 Test Network Connectivity

```bash
# Test from VM/CT
# Create a test container first, then:
pct enter <container-id>
ping -c 4 8.8.8.8
curl https://google.com
```

---

## 7. Storage Setup

### 7.1 Identify Available Storage

```bash
# List all disks
lsblk -f

# List all block devices
fdisk -l | grep '^Disk'

# Check existing LVM
vgdisplay
lvdisplay
```

### 7.2 Configure LVM Storage

For VPS environments, check if you have additional block devices:

```bash
# Create physical volume (if using separate disk)
pvcreate /dev/sdb

# Create volume group
vgcreate pve /dev/sdb

# Create logical volume
lvcreate -L 50G -n data pve
```

### 7.3 Add Directory Storage (Recommended for VPS)

Create a storage directory:

```bash
# Create storage directory
mkdir -p /var/lib/vz/storage

# Set permissions
chown root:root /var/lib/vz/storage
chmod 755 /var/lib/vz/storage
```

Add via Web Interface:

1. Navigate to **Datacenter → Storage → Add → Directory**
2. Configure:

| Field | Value |
|-------|-------|
| **ID** | vz-storage |
| **Directory** | /var/lib/vz/storage |
| **Content** | ISO image, VZDump backup file, Container template |
| **Nodes** | fgsrv07 |

### 7.4 Configure Default Storage

Set storage locations in `/etc/pve/storage.cfg`:

```text
dir: local
        path /var/lib/vz
        content vztmpl,iso,backup,snippets
        maxfiles 10

dir: local-backup
        path /var/lib/vz/backup
        content vztmpl,iso,backup,snippets
        maxfiles 10
```

### 7.5 Verify Storage Configuration

```bash
# Check storage configuration
cat /etc/pve/storage.cfg

# List storage
pvesm status

# Test storage
pvesm alloc local test.img 1G
```

---

## 8. Post-Installation Tasks

### 8.1 Update Proxmox VE

```bash
# Update all Proxmox packages
apt update
apt dist-upgrade -y

# Check Proxmox version
pveversion -v
```

### 8.2 Configure Notifications

```bash
# Edit notification settings
nano /etc/pve/vzdump.cron

# Or via Web Interface:
# Datacenter → Notifications → Add Notification Target
```

### 8.3 Configure Time Sync

```bash
# Ensure time synchronization is active
timedatectl set-ntp true

# Verify
timedatectl status
```

### 8.4 Set Up Backup Strategy

```bash
# Create backup schedule
nano /etc/pve/vzdump.cron
```

Example weekly backup:

```bash
# Full backup every Sunday at 2 AM
00 2 * * 0 root vzdump --all --storage local-backup --mode snapshot --compress zstd --mailnotification always
```

### 8.5 Security Hardening

```bash
# Disable root login via SSH (use admin user)
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# Configure fail2ban for SSH protection
apt install fail2ban -y
systemctl enable fail2ban
systemctl start fail2ban

# Review firewall rules
pve-firewall compile
pve-firewall start
```

### 8.6 Monitoring Setup

Install and configure monitoring:

```bash
# Install Proxmox Stats
apt install prometheus-node-exporter -y
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

# Verify metrics are available
curl http://localhost:9100/metrics
```

---

## 9. Cluster Integration

### 9.1 Prepare for Cluster Join

To join FGSRV07 to an existing Proxmox cluster:

```bash
# Ensure cluster communication ports are open:
# TCP: 5404-5406 (Corosync)
# TCP: 3121 (qemu server)
# TCP: 5900-5999 (VNC/SPICE)
# TCP: 8006 (Web UI)

# Add firewall rules
iptables -I INPUT -p tcp --dport 5404:5406 -j ACCEPT
iptables -I INPUT -p tcp --dport 3121 -j ACCEPT
iptables -I INPUT -p tcp --dport 5900:5999 -j ACCEPT
iptables -I INPUT -p tcp --dport 8006 -j ACCEPT

# Make persistent
apt install iptables-persistent -y
netfilter-persistent save
```

### 9.2 Join Existing Cluster

Via Web Interface:

1. Login to FGSRV07 web interface
2. Navigate to **Datacenter → Cluster → Join Cluster**
3. Enter cluster information:

| Field | Value |
|-------|-------|
| **Cluster Join Information** | (obtain from existing node) |
| **Cluster IP** | (IP address of existing cluster node) |
| **Root Password** | (root password of cluster) |

Or via CLI:

```bash
# Join cluster via CLI
pvecm add <cluster-ip> --link0 <local-ip>

# Example:
# pvecm add 191.252.93.1 --link0 191.252.93.227
```

### 9.3 Verify Cluster Status

```bash
# Check cluster status
pvecm status

# List nodes
pvecm nodes

# Check cluster resources
pvesh get /cluster/resources --type node
```

### 9.4 Configure Cluster Resources

After joining:

```bash
# Set up shared storage (if available)
pvesm add <storage-type> <options>

# Configure HA (High Availability)
ha-manager add vm:<vmid>
ha-manager enable vm:<vmid>
```

---

## 10. Troubleshooting

### 10.1 Common Issues

#### Issue: Web Interface Not Accessible

```bash
# Check if services are running
systemctl status pveproxy
systemctl status pvefm

# Restart services
systemctl restart pveproxy
systemctl restart pvefm

# Check firewall
iptables -L -n | grep 8006

# Verify SSL certificate
pvecm updatecerts --force
```

#### Issue: VMs Cannot Access Network

```bash
# Check bridge configuration
brctl show
ip addr show vmbr0

# Verify forwarding
sysctl net.ipv4.ip_forward
# Should return 1

# Enable forwarding if needed
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

#### Issue: Storage Not Available

```bash
# Check storage status
pvesm status

# Re-scan storage
pvesm scan <storage-type>

# Check LVM
vgdisplay
lvdisplay

# Mount directory storage
mount <device> /var/lib/vz/storage
```

### 10.2 Check System Logs

```bash
# System logs
journalctl -xe

# Proxmox logs
tail -f /var/log/syslog
tail -f /var/log/daemon.log

# Cluster logs
tail -f /var/log/corosync.log

# VM/CT logs
tail -f /var/log/pve/tasks/index
```

### 10.3 Performance Issues

```bash
# Check resource usage
pveperf

# Check running tasks
pvesh get /cluster/tasks

# Kill stuck tasks
pvesh delete /cluster/tasks/<upid>
```

### 10.4 Network Issues

```bash
# Test bridge
tcpdump -i vmbr0 -n

# Check for MTU issues
ip link show

# Test DNS
nslookup google.com
```

---

## 11. Maintenance Commands

### 11.1 Regular Maintenance

```bash
# Update system
apt update && apt upgrade -y

# Clean package cache
apt clean
apt autoclean

# Remove old kernels
# (Proxmox keeps old kernels for rollback)
# Manual cleanup if needed:
dpkg --list | grep pve-kernel
apt remove pve-kernel-<old-version>
```

### 11.2 Backup and Restore

```bash
# Backup VM
vzdump 100 --storage local-backup --mode snapshot

# Restore VM
pct restore <new-id> /var/lib/vz/dump/vzdump-lxc-100-*.tar.gz

# List backups
ls -lh /var/lib/vz/dump/
```

### 11.3 System Monitoring

```bash
# Real-time monitoring
htop

# I/O statistics
iostat -x 1

# Network statistics
nethogs

# Disk usage
df -h
du -sh /var/lib/vz/*
```

---

## 12. Additional Resources

### Official Documentation

- **Proxmox VE Documentation:** https://pve.proxmox.com/wiki/Main_Page
- **Debian Documentation:** https://www.debian.org/doc/
- **Proxmox Forums:** https://forum.proxmox.com/

### Quick Reference

| Task | Command |
|------|---------|
| Check Version | `pveversion` |
| List VMs | `qm list` |
| List Containers | `pct list` |
| Start VM | `qm start <vmid>` |
| Stop VM | `qm stop <vmid>` |
| Enter Container | `pct enter <ctid>` |
| Check Status | `pvecm status` |
| View Logs | `journalctl -f` |

---

## Installation Complete!

Your Proxmox VE installation on FGSRV07 is now complete. You can:

1. Access the web interface at `https://191.252.93.227:8006`
2. Create VMs and LXC containers
3. Configure storage and networking
4. Join to existing cluster (if applicable)
5. Set up backups and monitoring

For issues or questions, refer to the troubleshooting section or official Proxmox documentation.

---

**Document Version:** 1.0
**Last Updated:** 2025-02-09
**Author:** AGL Documentation Team
