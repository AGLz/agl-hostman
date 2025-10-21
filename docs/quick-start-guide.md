# AGLSRV1 Storage Architecture - Quick Start Guide

## Executive Summary

This guide provides step-by-step instructions to implement the multi-protocol storage architecture connecting 4 remote Proxmox hosts to AGLSRV1 via Tailscale VPN.

**Timeline:** 4 weeks (phased implementation)
**Protocols:** NFS v4.2, iSCSI, Proxmox Backup Server (PBS)
**Remote Hosts:** AGLSRV6, AGLSRV6b, FGSRV5, FGSRV6

---

## Prerequisites Checklist

### AGLSRV1 (Storage Server)
- [ ] Debian/Ubuntu or Proxmox VE installed
- [ ] Minimum 32GB RAM, 8+ CPU cores
- [ ] Storage pool configured (~24TB usable recommended)
- [ ] Tailscale installed and configured
- [ ] Static IP on Tailscale network

### Remote Hosts
- [ ] Proxmox VE installed
- [ ] Tailscale installed and configured
- [ ] Network connectivity to AGLSRV1 via Tailscale verified
- [ ] SSH key authentication configured (optional but recommended)

---

## Phase 1: Foundation Setup (Week 1)

### Step 1: Install Required Packages on AGLSRV1

```bash
# Update system
apt update && apt upgrade -y

# Install NFS server
apt install -y nfs-kernel-server nfs-common

# Install iSCSI target
apt install -y targetcli-fb

# Install Proxmox Backup Server (if not already installed)
# Add PBS repository
echo "deb http://download.proxmox.com/debian/pbs $(lsb_release -sc) pbs-no-subscription" \
  > /etc/apt/sources.list.d/pbs.list

wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg \
  -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg

apt update
apt install -y proxmox-backup-server

# Install monitoring tools
apt install -y smartmontools iperf3 bc jq mailutils
```

### Step 2: Create Storage Directory Structure

```bash
# Create directory hierarchy
mkdir -p /mnt/storage/remote/{aglsrv6,aglsrv6b,fgsrv5,fgsrv6}/{data,backups,iso,templates,staging}
mkdir -p /mnt/storage/shared/{iso,templates,tools}
mkdir -p /mnt/storage/iscsi

# Set permissions
chmod 755 /mnt/storage/remote/*
chmod 700 /mnt/storage/remote/*/backups
chmod 755 /mnt/storage/shared/*

# Verify structure
tree -L 3 /mnt/storage
```

### Step 3: Configure Tailscale Network

```bash
# Ensure Tailscale is running
tailscale status

# Get AGLSRV1's Tailscale IP
TAILSCALE_IP=$(ip -4 addr show tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "AGLSRV1 Tailscale IP: $TAILSCALE_IP"

# Test connectivity to each remote host
ping -c 3 100.98.108.66   # AGLSRV6
ping -c 3 100.98.119.51   # AGLSRV6b
ping -c 3 100.71.107.26   # FGSRV5
ping -c 3 100.83.51.9     # FGSRV6
```

### Step 4: Configure Firewall

```bash
# Install UFW if not present
apt install -y ufw

# Configure firewall rules
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0

# Allow storage services from Tailscale network
ufw allow from 100.0.0.0/8 to any port 2049 proto tcp comment "NFS"
ufw allow from 100.0.0.0/8 to any port 111 proto tcp comment "RPC"
ufw allow from 100.0.0.0/8 to any port 3260 proto tcp comment "iSCSI"
ufw allow from 100.0.0.0/8 to any port 8007 proto tcp comment "PBS"
ufw allow from 100.0.0.0/8 to any port 22 proto tcp comment "SSH"

# Enable firewall
ufw --force enable
ufw status verbose
```

---

## Phase 2: NFS Configuration (Week 1)

### Step 1: Configure NFS Exports

```bash
# Copy template
cp /root/host-admin/config/templates/nfs-exports.conf.template /etc/exports

# Edit /etc/exports with actual Tailscale IPs
cat > /etc/exports <<'EOF'
# AGLSRV6 (100.98.108.66)
/mnt/storage/remote/aglsrv6/data    100.98.108.66(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/remote/aglsrv6/staging 100.98.108.66(rw,async,no_subtree_check,no_root_squash,sec=sys)

# AGLSRV6b (100.98.119.51)
/mnt/storage/remote/aglsrv6b/data    100.98.119.51(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/remote/aglsrv6b/staging 100.98.119.51(rw,async,no_subtree_check,no_root_squash,sec=sys)

# FGSRV5 (100.71.107.26)
/mnt/storage/remote/fgsrv5/data    100.71.107.26(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/remote/fgsrv5/staging 100.71.107.26(rw,async,no_subtree_check,no_root_squash,sec=sys)

# FGSRV6 (100.83.51.9)
/mnt/storage/remote/fgsrv6/data    100.83.51.9(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/remote/fgsrv6/staging 100.83.51.9(rw,async,no_subtree_check,no_root_squash,sec=sys)

# Shared resources (all hosts read-only)
/mnt/storage/shared/iso       100.0.0.0/8(ro,sync,no_subtree_check,all_squash,sec=sys)
/mnt/storage/shared/templates 100.0.0.0/8(ro,sync,no_subtree_check,all_squash,sec=sys)
EOF

# Validate and apply
exportfs -arv
showmount -e localhost
```

### Step 2: Optimize NFS Performance

```bash
# Configure NFS server threads
cat > /etc/nfs.conf <<'EOF'
[nfsd]
threads=64
tcp=y
udp=n
vers4=y
vers4.2=y

[mountd]
manage-gids=y
EOF

# Apply kernel tuning for Tailscale/VPN
cat > /etc/sysctl.d/99-tailscale-storage.conf <<'EOF'
# TCP tuning for high-latency VPN
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# NFS optimization
sunrpc.tcp_slot_table_entries = 128
EOF

sysctl -p /etc/sysctl.d/99-tailscale-storage.conf

# Restart NFS
systemctl restart nfs-server
systemctl enable nfs-server
```

### Step 3: Configure NFS Clients (On Each Remote Host)

Run on AGLSRV6, AGLSRV6b, FGSRV5, FGSRV6:

```bash
# Install NFS client
apt install -y nfs-common

# Create mount points
mkdir -p /mnt/aglsrv1/{data,iso,templates,staging}

# Get AGLSRV1 Tailscale IP
AGLSRV1_IP="<AGLSRV1_TAILSCALE_IP>"  # Replace with actual IP

# Test mount
mount -t nfs4 -o rw,hard,intr,rsize=1048576,wsize=1048576 \
  $AGLSRV1_IP:/mnt/storage/remote/$(hostname)/data \
  /mnt/aglsrv1/data

# Verify
df -h /mnt/aglsrv1/data
touch /mnt/aglsrv1/data/test.txt && rm /mnt/aglsrv1/data/test.txt

# Add to /etc/fstab for persistence
cat >> /etc/fstab <<EOF
# AGLSRV1 Remote Storage via Tailscale
$AGLSRV1_IP:/mnt/storage/remote/$(hostname)/data  /mnt/aglsrv1/data  nfs4  rw,hard,intr,rsize=1048576,wsize=1048576,timeo=600,retrans=2,_netdev  0  0
$AGLSRV1_IP:/mnt/storage/shared/iso               /mnt/aglsrv1/iso   nfs4  ro,hard,intr,rsize=1048576,timeo=600,_netdev  0  0
EOF

# Mount all
mount -a
```

---

## Phase 3: iSCSI Configuration (Week 2)

### Step 1: Configure iSCSI Target on AGLSRV1

```bash
# Make setup script executable
chmod +x /root/host-admin/config/templates/iscsi-target-setup.sh

# Run setup script
/root/host-admin/config/templates/iscsi-target-setup.sh

# Save CHAP credentials
cat /root/iscsi-chap-credentials.txt
# Format: hostname:username:password

# Verify configuration
targetcli ls
systemctl status target
```

### Step 2: Configure iSCSI Initiators (On Each Remote Host)

Run on each remote host (example for AGLSRV6):

```bash
# Install iSCSI initiator
apt install -y open-iscsi

# Set initiator name
echo "InitiatorName=iqn.2025-01.local.aglsrv6:initiator" > /etc/iscsi/initiatorname.iscsi

# Get CHAP credentials from AGLSRV1:/root/iscsi-chap-credentials.txt
CHAP_USER="aglsrv6"
CHAP_PASS="<password_from_file>"

# Configure CHAP authentication
cat >> /etc/iscsi/iscsid.conf <<EOF
node.session.auth.authmethod = CHAP
node.session.auth.username = $CHAP_USER
node.session.auth.password = $CHAP_PASS
node.session.timeo.replacement_timeout = 120
node.conn[0].timeo.noop_out_interval = 5
node.conn[0].timeo.noop_out_timeout = 10
EOF

# Restart iSCSI
systemctl restart iscsid open-iscsi

# Discover targets
AGLSRV1_IP="<AGLSRV1_TAILSCALE_IP>"
iscsiadm -m discovery -t st -p $AGLSRV1_IP:3260

# Login to target
iscsiadm -m node --targetname iqn.2025-01.local.aglsrv1:storage \
  --portal $AGLSRV1_IP:3260 --login

# Verify session
iscsiadm -m session
lsblk  # Look for new disk device
```

### Step 3: Use iSCSI LUN in Proxmox

```bash
# Find iSCSI device
ISCSI_DEV=$(lsblk -o NAME,TYPE,SIZE | grep disk | grep 500G | awk '{print $1}')

# Create LVM VG on iSCSI device
pvcreate /dev/$ISCSI_DEV
vgcreate iscsi-remote /dev/$ISCSI_DEV

# Add to Proxmox storage configuration
pvesm add lvm iscsi-remote --vgname iscsi-remote --content images,rootdir

# Verify
pvesm status
```

---

## Phase 4: Proxmox Backup Server (PBS) Configuration (Week 2)

### Step 1: Setup PBS Datastores on AGLSRV1

```bash
# Make setup script executable
chmod +x /root/host-admin/config/templates/pbs-datastore-setup.sh

# Run PBS setup
/root/host-admin/config/templates/pbs-datastore-setup.sh

# Save API token
cat /root/pbs-api-token.txt
# Format: backup@pbs!remote-backup:TOKEN_SECRET

# Get PBS fingerprint
proxmox-backup-manager cert info
```

### Step 2: Add PBS Storage to Remote Proxmox Hosts

For AGLSRV6/AGLSRV6b (which have PBS containers):

```bash
# Get values from AGLSRV1
AGLSRV1_IP="<AGLSRV1_TAILSCALE_IP>"
PBS_TOKEN="<from /root/pbs-api-token.txt>"
PBS_FINGERPRINT="<from proxmox-backup-manager cert info>"
HOSTNAME=$(hostname)

# Add PBS storage via CLI
pvesm add pbs remote-pbs-aglsrv1 \
  --server $AGLSRV1_IP \
  --datastore remote-$HOSTNAME \
  --username backup@pbs \
  --password $PBS_TOKEN \
  --fingerprint $PBS_FINGERPRINT

# Or via Web UI:
# Datacenter > Storage > Add > Proxmox Backup Server
```

### Step 3: Create Backup Jobs

Via Proxmox web UI:

1. Datacenter > Backup
2. Add > Select remote-pbs-aglsrv1 storage
3. Configure schedule (e.g., daily at 2 AM)
4. Select VMs/CTs to backup
5. Set retention policy (7 daily, 4 weekly, 6 monthly)

---

## Phase 5: Monitoring & Validation (Week 3)

### Step 1: Deploy Health Monitoring

```bash
# Make monitoring script executable
chmod +x /root/host-admin/scripts/storage-health-monitor.sh

# Run manual health check
/root/host-admin/scripts/storage-health-monitor.sh

# Schedule daily health checks via cron
cat > /etc/cron.d/storage-health <<'EOF'
# Daily storage health check at 6 AM
0 6 * * * root /root/host-admin/scripts/storage-health-monitor.sh
EOF

# Configure email alerts (optional)
export ALERT_EMAIL="admin@example.com"
```

### Step 2: Performance Testing

```bash
# NFS performance test
dd if=/dev/zero of=/mnt/aglsrv1/data/test.img bs=1M count=1024 conv=fdatasync
rm /mnt/aglsrv1/data/test.img

# iSCSI performance test
fio --name=iscsi-test --filename=/dev/sdb --size=1G --rw=randwrite --bs=4k --direct=1 --numjobs=4 --time_based --runtime=60

# Network throughput test (requires iperf3 server on remote host)
iperf3 -c 100.98.108.66 -t 30 -P 4
```

### Step 3: Test Backup & Restore

```bash
# Trigger manual backup via Proxmox UI or CLI
vzdump 100 --storage remote-pbs-aglsrv1 --mode snapshot --compress zstd

# Verify backup
proxmox-backup-client list --repository backup@pbs@$AGLSRV1_IP:remote-$(hostname)

# Test restore (dry-run)
qmrestore remote-pbs-aglsrv1:backup/vm/100/... 999 --storage local-lvm
```

---

## Phase 6: Production Hardening (Week 4)

### Security Hardening

```bash
# Enable automatic security updates
apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# Harden SSH (on all hosts)
sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable audit logging
apt install -y auditd
auditctl -w /mnt/storage/remote -p wa -k remote-storage-access
auditctl -w /etc/exports -p wa -k nfs-config-change
```

### Backup Strategy for Backup Server

```bash
# Install rclone for cloud backup
curl https://rclone.org/install.sh | bash

# Configure S3/B2 remote (follow rclone config wizard)
rclone config

# Schedule weekly offsite backup
cat > /etc/cron.weekly/pbs-offsite-backup <<'EOF'
#!/bin/bash
rclone sync /mnt/storage/remote/ remote-s3:backup-bucket/aglsrv1/ \
  --transfers 8 --fast-list --exclude "*.tmp" \
  --log-file /var/log/rclone-backup.log
EOF

chmod +x /etc/cron.weekly/pbs-offsite-backup
```

---

## Common Operations

### Adding a New Remote Host

```bash
# On AGLSRV1:
mkdir -p /mnt/storage/remote/newhost/{data,backups,iso,templates,staging}

# Add to /etc/exports
echo "/mnt/storage/remote/newhost/data 100.x.x.x(rw,sync,no_subtree_check,no_root_squash,sec=sys)" >> /etc/exports
exportfs -arv

# Create iSCSI LUN
targetcli /backstores/fileio create lun-newhost-001 /mnt/storage/iscsi/lun-newhost-001.img 500G
targetcli /iscsi/iqn.2025-01.local.aglsrv1:storage/tpg1/luns create /backstores/fileio/lun-newhost-001

# Create PBS datastore
proxmox-backup-manager datastore create remote-newhost \
  --path /mnt/storage/remote/newhost/backups \
  --gc-schedule "daily 03:00"
```

### Emergency Procedures

**If AGLSRV1 becomes unavailable:**

```bash
# On remote hosts: gracefully unmount NFS
umount -a -t nfs4

# Disconnect iSCSI sessions
iscsiadm -m node -u

# Enable local storage temporarily
pvesm set local-lvm --disable 0
```

**To restore AGLSRV1:**

```bash
# 1. Bring up server
# 2. Verify network connectivity
tailscale status
ping -c 3 100.98.108.66

# 3. Start services
systemctl restart nfs-server target proxmox-backup

# 4. Verify exports/targets
showmount -e localhost
targetcli ls

# 5. Reconnect clients
# Run on each remote host:
mount -a
iscsiadm -m node --login
```

---

## Troubleshooting Guide

### NFS Issues

**Problem:** Mount hangs or timeout

```bash
# Check connectivity
ping <AGLSRV1_IP>

# Check NFS service
systemctl status nfs-server

# Check firewall
ufw status | grep 2049

# Force unmount and remount
umount -f -l /mnt/aglsrv1/data
mount -a
```

### iSCSI Issues

**Problem:** Session disconnects

```bash
# Check logs
journalctl -u iscsid -f

# Verify CHAP credentials
cat /etc/iscsi/iscsid.conf | grep auth

# Reconnect
iscsiadm -m node --logout
iscsiadm -m node --login
```

### PBS Issues

**Problem:** Backup fails

```bash
# Check datastore status
proxmox-backup-manager datastore status

# Verify disk space
df -h /mnt/storage/remote/*/backups

# Run garbage collection
proxmox-backup-manager garbage-collect --datastore remote-aglsrv6

# Check PBS logs
journalctl -u proxmox-backup -f
```

---

## Performance Benchmarks

Expected performance over Tailscale VPN:

| Protocol | Sequential Read | Sequential Write | Latency |
|----------|----------------|------------------|---------|
| NFS v4.2 | 250-400 MB/s | 200-350 MB/s | 5-15ms |
| iSCSI | 300-500 MB/s | 250-400 MB/s | 3-10ms |
| PBS | 150-300 MB/s | 100-250 MB/s | N/A |

Actual performance depends on:
- Network bandwidth between sites
- Tailscale relay vs direct connection
- Disk I/O on AGLSRV1
- Concurrent operations

---

## Success Criteria

- [ ] All 4 remote hosts can ping AGLSRV1 via Tailscale
- [ ] NFS mounts on all remote hosts are active and writable
- [ ] iSCSI sessions are established and stable
- [ ] PBS datastores are created and accessible
- [ ] At least one successful backup completed per remote host
- [ ] Monitoring scripts run without errors
- [ ] Performance meets minimum thresholds (100+ MB/s)
- [ ] Failover procedures tested successfully

---

## Next Steps After Deployment

1. **Week 5:** Migrate existing VMs/CTs to remote storage
2. **Week 6:** Optimize performance based on usage patterns
3. **Month 2:** Implement HA failover with secondary AGLSRV1
4. **Month 3:** Deploy edge caching on remote hosts
5. **Quarter 2:** Evaluate NVMe-oF migration for lower latency

---

## Support Resources

- **Architecture Documentation:** `/root/host-admin/docs/storage-architecture.md`
- **Configuration Templates:** `/root/host-admin/config/templates/`
- **Monitoring Scripts:** `/root/host-admin/scripts/`
- **Health Check Log:** `/var/log/storage-health.log`
- **Setup Logs:** `/var/log/iscsi-setup.log`, `/var/log/pbs-setup.log`

**Emergency Contacts:**
- Storage Admin: admin@example.com
- On-call Engineer: oncall@example.com

---

**Document Version:** 1.0
**Last Updated:** 2025-10-14
**Status:** Ready for Implementation
