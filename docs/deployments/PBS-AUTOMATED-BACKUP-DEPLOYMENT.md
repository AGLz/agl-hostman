# PBS Automated Backup Deployment Runbook

> **Document Version**: 1.0.0
> **Last Updated**: 2026-02-07
> **Author**: Deployment Engineer Agent
> **Status**: Production Ready

---

## Overview

This document provides comprehensive procedures for deploying and managing Proxmox Backup Server (PBS) automated backups across the AGL infrastructure.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AGL Infrastructure                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐        ┌──────────────────┐             │
│  │   AGLSRV1        │        │   AGLSRV6        │             │
│  │  (192.168.0.245) │        │  (192.168.0.202) │             │
│  │  CT179, CT180,   │        │  CT113 (PBS)     │             │
│  │  CT183, CT200    │        │  CT108, CT111    │             │
│  └────────┬─────────┘        └────────┬─────────┘             │
│           │                           │                        │
│           └───────────┬───────────────┘                        │
│                       │                                        │
│                       ▼                                        │
│              ┌─────────────────┐                               │
│              │  PBS Backups    │                               │
│              │  CT113:10.6.0.14│                               │
│              │  Port: 8007     │                               │
│              └─────────────────┘                               │
│                       │                                        │
│                       │ Daily Sync                             │
│                       ▼                                        │
│              ┌─────────────────┐                               │
│              │ AGLSRV1 Spark   │                               │
│              │ (Offsite Copy)  │                               │
│              └─────────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Host | IP | Purpose |
|-----------|------|-----|---------|
| **PBS Server** | CT113 (AGLSRV6) | 10.6.0.14:8007 | Primary backup storage |
| **PBS Storage** | CT113 | /mnt/backups | Backup repository |
| **Remote Sync** | AGLSRV1 | /mnt/spark/pbs-remote | Offsite backup copy |
| **Monitoring** | CT113 | /usr/local/bin/pbs-health-monitor.sh | Health checks |

---

## Prerequisites

### Infrastructure Requirements

- [x] CT113 container running on AGLSRV6
- [x] WireGuard connectivity (10.6.0.14)
- [x] Tailscale connectivity (100.65.189.83)
- [x] At least 500GB storage for backups
- [x] SSH key authentication configured

### Software Requirements

- Proxmox VE 8.x+ on all hosts
- SSH access to all Proxmox hosts
- Bash 4.0+ for scripts

### Network Requirements

- WireGuard mesh network operational
- Tailscale VPN as backup access
- Firewall allows port 8007 (PBS web UI)

---

## Deployment Procedures

### Phase 1: PBS Server Setup

#### 1.1 Verify CT113 Container

```bash
# From CT179 or any admin host
ssh root@10.6.0.12  # AGLSRV6

# Check CT113 status
pct list | grep 113

# Start if stopped
pct start 113

# Enter container
pct enter 113
```

#### 1.2 Install Proxmox Backup Server

```bash
# Inside CT113
cat <<'EOF'
# Update system
apt-get update && apt-get upgrade -y

# Add PBS repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pbs bookworm main" > \
    /etc/apt/sources.list.d/pbs.list

# Add repository key
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O \
    /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# Install PBS
apt-get update
apt-get install -y proxmox-backup-server

# Enable services
systemctl enable proxmox-backup-proxy
systemctl enable proxmox-backup
systemctl start proxmox-backup-proxy
systemctl start proxmox-backup
EOF

# Exit container
exit
```

#### 1.3 Create Storage Directories

```bash
# Inside CT113
pct enter 113

# Create backup storage
mkdir -p /mnt/backups
chown backup:backup /mnt/backups
chmod 750 /mnt/backups

# Verify storage
df -h /mnt/backups
```

#### 1.4 Access PBS Web UI

```bash
# Get container IP
pct exec 113 ip addr show eth0 | grep 'inet '

# Access web UI
# URL: https://10.6.0.14:8007
# Default user: root@pam
# Password: <root password of AGLSRV6>
```

---

### Phase 2: Automated Configuration

#### 2.1 Run Configuration Script

```bash
# From CT179 or admin host
cd /mnt/overpower/apps/dev/agl/agl-hostman
chmod +x scripts/configure-pbs-automated-backups.sh

# Run configuration
./scripts/configure-pbs-automated-backups.sh
```

**The script will:**
1. Check PBS server connectivity
2. Install PBS if needed
3. Create backup user and API token
4. Create datastores for each host
5. Configure Proxmox VE storage on all hosts
6. Create backup jobs with staggered schedules
7. Setup health monitoring
8. Configure remote sync to AGLSRV1

#### 2.2 Configure PBS Datastores

The script creates these datastores:

| Datastore | Purpose | Retention |
|-----------|---------|-----------|
| datastore-aglsrv1 | AGLSRV1 backups | 7d, 4w, 6m |
| datastore-aglsrv3 | AGLSRV3 backups | 7d, 4w, 6m |
| datastore-aglsrv5 | AGLSRV5 backups | 7d, 4w, 6m |
| datastore-aglsrv6 | AGLSRV6 backups | 7d, 4w, 6m |
| datastore-aglsrv6c | AGLSRV6C backups | 7d, 4w, 6m |
| datastore-aglsrv6d | AGLSRV6D backups | 7d, 4w, 6m |

#### 2.3 Configure Backup Jobs

Jobs are scheduled with staggered times:

| Host | Schedule | VMs/CTs |
|------|----------|---------|
| AGLSRV1 | 02:00 | All running |
| AGLSRV3 | 02:15 | All running |
| AGLSRV5 | 02:30 | All running |
| AGLSRV6 | 02:45 | All running |
| AGLSRV6C | 03:00 | All running |
| AGLSRV6D | 03:15 | All running |

---

### Phase 3: Verification

#### 3.1 Check PBS Server Status

```bash
# Check service status
ssh root@10.6.0.14 "systemctl status proxmox-backup-proxy"

# Check datastores
ssh root@10.6.0.14 "proxmox-backup-manager datastore list"

# Check disk space
ssh root@10.6.0.14 "df -h /mnt/backups"
```

#### 3.2 Verify Proxmox Storage Configuration

```bash
# On each Proxmox host
pvesm status | grep remote-pbs

# Should show:
# remote-pbs     pbs     -       -       -       -       -
```

#### 3.3 Run Health Check

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
chmod +x scripts/pbs-backup-health-check.sh

# Standard check
./scripts/pbs-backup-health-check.sh

# Full check with email
./scripts/pbs-backup-health-check.sh --full --email
```

#### 3.4 Test Backup

```bash
# On AGLSRV1
ssh root@100.107.113.33

# Create test backup of small CT
vzdump 102 --storage remote-pbs --mode snapshot --compress zstd

# Monitor progress
tail -f /var/log/vzdump/vzdump-lxc-102-*.log
```

---

## Maintenance Procedures

### Daily Monitoring

```bash
# Run health check
./scripts/pbs-backup-health-check.sh

# Check last backup status
ssh root@100.107.113.33 "ls -lt /var/log/vzdump/*.log | head -1"
```

### Weekly Tasks

1. **Review backup logs**
   ```bash
   ssh root@10.6.0.14 "journalctl -u proxmox-backup --since '7 days ago' | grep -i backup"
   ```

2. **Check storage usage**
   ```bash
   ssh root@10.6.0.14 "proxmox-backup-manager datastore list | grep datastore"
   ```

3. **Verify GC/Prune jobs**
   ```bash
   ssh root@10.6.0.14 "crontab -l | grep -E '(gc|prune|verify)'"
   ```

### Monthly Tasks

1. **Test restore procedure**
   ```bash
   ./scripts/pbs-emergency-restore.sh interactive
   ```

2. **Review retention policies**
   - Adjust retention if needed
   - Consider archive requirements

3. **Capacity planning**
   - Monitor storage growth trends
   - Plan for expansion at 80% capacity

---

## Disaster Recovery

### Restore Procedures

#### Interactive Restore

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
chmod +x scripts/pbs-emergency-restore.sh

# Run interactive wizard
./scripts/pbs-emergency-restore.sh interactive
```

#### Restore Specific VM/CT

```bash
# List available backups
./scripts/pbs-emergency-restore.sh list datastore-aglsrv1

# Restore container (to new VMID to be safe)
./scripts/pbs-emergency-restore.sh restore-ct \
    179 \
    datastore-aglsrv1 \
    "2026-02-07 02:00:00" \
    local-zfs \
    999
```

#### Emergency Full Restore

```bash
# Restore all VMs/CTs to AGLSRV1
./scripts/pbs-emergency-restore.sh restore-all \
    100.107.113.33 \
    datastore-aglsrv1
```

**WARNING**: This will overwrite existing VMs/CTs!

### Recovery Priority

In case of host failure, restore in this order:

1. **Infrastructure services** (CT102 pihole, CT101 cloudflared)
2. **Development environment** (CT179 agldv03)
3. **Production services** (user-facing applications)
4. **Supporting services** (monitoring, logging)

---

## Troubleshooting

### PBS Service Issues

#### Service Not Starting

```bash
# Check service status
ssh root@10.6.0.14 "systemctl status proxmox-backup-proxy"

# Check logs
ssh root@10.6.0.14 "journalctl -u proxmox-backup-proxy -n 50"

# Restart service
ssh root@10.6.0.14 "systemctl restart proxmox-backup-proxy"
```

#### High Memory Usage

```bash
# Check memory
ssh root@10.6.0.14 "free -h"

# Check PBS memory
ssh root@10.6.0.14 "ps aux | grep proxmox"

# Restart if needed
ssh root@10.6.0.14 "systemctl restart proxmox-backup"
```

### Backup Failures

#### Connection Timeout

```bash
# Check connectivity
ping 10.6.0.14

# Check PBS port
nc -zv 10.6.0.14 8007

# Verify API token
ssh root@100.107.113.33 "cat /etc/pve/storage.cfg | grep -A5 'pbs: remote-pbs'"
```

#### Insufficient Space

```bash
# Check storage
ssh root@10.6.0.14 "df -h /mnt/backups"

# Trigger manual GC
ssh root@10.6.0.14 "proxmox-backup-manager datastore start-gc datastore-aglsrv1"

# Trigger manual prune
ssh root@10.6.0.14 "proxmox-backup-manager datastore prune datastore-aglsrv1 --dry-run"
```

#### Slow Backup Speed

```bash
# Check network bandwidth
iperf3 -c 10.6.0.14

# Adjust compression (in Proxmox storage config)
# Change "compress zstd" to "compress lzo" or "compress gzip"

# Disable performance mode (slower but less impact)
# In Proxmox UI: Datacenter > Storage > remote-pbs > Edit
# Uncheck "Backup Max Performance"
```

### Datastore Issues

#### Degraded Datastore

```bash
# Check datastore status
ssh root@10.6.0.14 "proxmox-backup-manager datastore list"

# Check task logs
ssh root@10.6.0.14 "proxmox-backup-manager task list"

# Restart PBS
ssh root@10.6.0.14 "systemctl restart proxmox-backup"
```

#### Corrupted Snapshots

```bash
# Verify snapshots
ssh root@10.6.0.14 "proxmox-backup-manager snapshot verify-all datastore-aglsrv1"

# Remove corrupted snapshots (use with caution)
ssh root@10.6.0.14 "proxmox-backup-manager snapshot remove <snapshot_path>"
```

---

## Performance Tuning

### Backup Performance

#### Enable Maximum Performance

```bash
# On each Proxmox host
# Edit /etc/pve/storage.cfg
pbs: remote-pbs
    backup-max-performance 1  # Already enabled by config script
```

#### Adjust Compression Levels

```bash
# In backup job config
# vzdump: <job-name>
#     compress zstd  # Best compression, slower
#     compress lzo   # Good balance
#     compress gzip  # Faster, less compression
#     compress 0     # No compression, fastest
```

### Storage Performance

#### Optimize GC Schedule

```bash
# On PBS server
# Adjust GC schedule to off-peak hours
proxmox-backup-manager datastore update datastore-aglsrv1 \
    --gc-schedule "daily 03:00"
```

#### Prune Strategy

```bash
# Adjust retention to balance storage vs. retention
proxmox-backup-manager datastore update datastore-aglsrv1 \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6
```

### Network Optimization

#### Use WireGuard for Local Backups

WireGuard provides faster local network backups vs. Tailscale.

```bash
# Prefer 10.6.0.x over 100.x.x.x for backup traffic
# Update /etc/pve/storage.cfg to use WireGuard IPs
```

#### Off-Peak Scheduling

Stagger backups during low-usage hours (2 AM - 6 AM).

---

## Security

### Access Control

#### PBS User Permissions

```bash
# Verify backup user permissions
ssh root@10.6.0.14 "proxmox-backup-manager acl list"

# Grant additional permissions if needed
proxmox-backup-manager acl update /datastore/datastore-aglsrv1 \
    --role DatastoreBackup \
    --auth-id backup@pam
```

#### API Token Rotation

```bash
# Generate new token
ssh root@10.6.0.14 "proxmox-backup-manager user generate-token backup@pam remote-backup"

# Update all Proxmox hosts with new token
# (Run configuration script again)
```

### Network Security

#### Firewall Rules

```bash
# On AGLSRV6 (PBS host)
# Allow PBS port from Proxmox hosts only
iptables -A INPUT -p tcp --dport 8007 -s 10.6.0.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8007 -s 192.168.0.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8007 -j DROP
```

#### TLS Certificate

```bash
# Check certificate status
ssh root@10.6.0.14 "proxmox-backup-manager cert info"

# Renew certificate
ssh root@10.6.0.14 "proxmox-backup-manager cert renew"
```

---

## Monitoring and Alerting

### Health Check Automation

```bash
# Add to crontab for automated checks
crontab -e

# Add:
0 */6 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/pbs-backup-health-check.sh --email
```

### Alert Thresholds

Configure alerts for:

| Metric | Warning | Critical |
|--------|---------|----------|
| Storage Usage | 80% | 90% |
| Backup Age | 48 hours | 72 hours |
| Failed Backups | 1 | 3 |
| GC Duration | 2 hours | 4 hours |

### Grafana Integration (Optional)

```bash
# Install Prometheus exporter on PBS
ssh root@10.6.0.14 "apt-get install -y prometheus-node-exporter"

# Configure Grafana dashboard
# Import dashboard: PBS Monitoring
```

---

## Appendix

### Quick Reference Commands

```bash
# Check PBS status
ssh root@10.6.0.14 "systemctl status proxmox-backup-proxy"

# List datastores
ssh root@10.6.0.14 "proxmox-backup-manager datastore list"

# Check storage
ssh root@10.6.0.14 "df -h /mnt/backups"

# Run health check
./scripts/pbs-backup-health-check.sh

# Interactive restore
./scripts/pbs-emergency-restore.sh interactive

# Manual backup
vzdump <vmid> --storage remote-pbs --mode snapshot

# View logs
tail -f /var/log/vzdump/vzdump-*.log
```

### File Locations

| File | Location |
|------|----------|
| PBS Logs | /var/log/proxmox-backup/ |
| Backup Logs | /var/log/vzdump/ |
| Storage Config | /etc/pve/storage.cfg |
| Backup Jobs | /etc/pve/jobs.cfg |
| Health Monitor | /usr/local/bin/pbs-health-monitor.sh |
| Sync Script | /usr/local/bin/pbs-remote-sync.sh |

### Support Contacts

| Role | Contact |
|------|---------|
| Infrastructure | agl@aglz.io |
| PBS Support | https://forum.proxmox.com/forum/viewforum.php?fid=72 |
| Proxmox Docs | https://pbs.proxmox.com/docs/ |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-07 | Initial release - PBS automated backup deployment |

---

**Document Status**: Production Ready
**Next Review**: 2026-03-07
**Approved By**: Deployment Engineer Agent
