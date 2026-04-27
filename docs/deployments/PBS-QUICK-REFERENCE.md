# PBS Automated Backup - Quick Reference

> **Version**: 1.0.0 | **Created**: 2026-02-07

---

## Files Created

### Main Scripts

| Script | Purpose | Size |
|--------|---------|------|
| `/scripts/configure-pbs-automated-backups.sh` | Main PBS setup and configuration | 23KB |
| `/scripts/pbs-backup-health-check.sh` | Health monitoring and reporting | 13KB |
| `/scripts/pbs-emergency-restore.sh` | Disaster recovery procedures | 11KB |

### Documentation

| Document | Purpose |
|----------|---------|
| `/docs/deployments/PBS-AUTOMATED-BACKUP-DEPLOYMENT.md` | Complete deployment runbook |

---

## Quick Start

### 1. Initial Setup (One-Time)

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman

# Run automated configuration
./scripts/configure-pbs-automated-backups.sh
```

**What it does:**
- Installs PBS on CT113 (AGLSRV6)
- Creates datastores for each host
- Configures Proxmox storage
- Creates backup jobs (staggered 2 AM - 3:15 AM)
- Sets up health monitoring
- Configures remote sync to AGLSRV1

### 2. Verify Deployment

```bash
# Run health check
./scripts/pbs-backup-health-check.sh

# Check PBS web UI
# URL: https://10.6.0.14:8007
# User: root@pam
# Pass: <AGLSRV6 root password>
```

### 3. Monitor Daily

```bash
# Quick health check
./scripts/pbs-backup-health-check.sh

# Full check with email
./scripts/pbs-backup-health-check.sh --full --email
```

---

## Architecture

```
CT113 (AGLSRV6) - PBS Server
├── WireGuard: 10.6.0.14:8007
├── Tailscale: 100.65.189.83:8007
└── Storage: /mnt/backups

Datastores Created:
├── datastore-aglsrv1  → 7d,4w,6m retention
├── datastore-aglsrv3  → 7d,4w,6m retention
├── datastore-aglsrv5  → 7d,4w,6m retention
├── datastore-aglsrv6  → 7d,4w,6m retention
├── datastore-aglsrv6c → 7d,4w,6m retention
└── datastore-aglsrv6d → 7d,4w,6m retention

Backup Schedule (Staggered):
├── 02:00 - AGLSRV1
├── 02:15 - AGLSRV3
├── 02:30 - AGLSRV5
├── 02:45 - AGLSRV6
├── 03:00 - AGLSRV6C
└── 03:15 - AGLSRV6D

Maintenance Schedule:
├── 03:00-04:00 - Garbage Collection (staggered)
├── 04:00-05:00 - Prune (staggered)
├── 05:00-06:00 - Verification (staggered)
└── 06:00 - Remote sync to AGLSRV1
```

---

## Common Commands

### Check Backup Status

```bash
# On any Proxmox host
pvesm status | grep remote-pbs

# View last backup log
ls -lt /var/log/vzdump/*.log | head -1 | xargs tail -20
```

### Manual Backup

```bash
# Backup specific VM/CT
vzdump 179 --storage remote-pbs --mode snapshot --compress zstd
```

### List Available Backups

```bash
# Via PBS server
ssh root@10.6.0.14 "proxmox-backup-manager snapshot-list datastore-aglsrv1"

# Via restore script
./scripts/pbs-emergency-restore.sh list datastore-aglsrv1
```

### Restore VM/CT

```bash
# Interactive restore wizard
./scripts/pbs-emergency-restore.sh interactive

# Direct restore (to new VMID for safety)
./scripts/pbs-emergency-restore.sh restore-ct \
    179 \
    datastore-aglsrv1 \
    "2026-02-07 02:00:00" \
    local-zfs \
    999
```

---

## Troubleshooting

### PBS Not Running

```bash
ssh root@10.6.0.14 << 'EOF'
systemctl status proxmox-backup-proxy
systemctl restart proxmox-backup-proxy
systemctl status proxmox-backup
EOF
```

### Storage Full

```bash
ssh root@10.6.0.14 << 'EOF'
# Check usage
df -h /mnt/backups

# Trigger manual GC
proxmox-backup-manager datastore start-gc datastore-aglsrv1

# Trigger prune (dry-run first)
proxmox-backup-manager datastore prune datastore-aglsrv1 --dry-run
EOF
```

### Backup Failing

```bash
# Check connectivity
ping 10.6.0.14
nc -zv 10.6.0.14 8007

# Check storage config on Proxmox host
cat /etc/pve/storage.cfg | grep -A5 "pbs: remote-pbs"

# View backup log
tail -50 /var/log/vzdump/vzdump-lxc-179-*.log
```

---

## Key Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| Storage Config | `/etc/pve/storage.cfg` | Proxmox storage definitions |
| Backup Jobs | `/etc/pve/jobs.cfg` | Automated backup schedules |
| PBS Config | CT113 `/etc/proxmox-backup/` | PBS server configuration |
| Health Monitor | `/usr/local/bin/pbs-health-monitor.sh` | Automated health checks |
| Sync Script | `/usr/local/bin/pbs-remote-sync.sh` | Offsite backup sync |

---

## Important Notes

### Storage Warnings

- AGLSRV1 `spark` storage is at 98% capacity (7.1T / 7.2T)
- Monitor `/mnt/backups` on CT113 for space
- Plan storage expansion at 80% usage

### Connectivity

- **Primary**: WireGuard (10.6.0.14) - fastest for local backups
- **Backup**: Tailscale (100.65.189.83) - remote/fallback access
- Ensure both networks are operational

### Retention Policies

Default retention (adjustable per datastore):
- **7 daily** - Last 7 days
- **4 weekly** - Last 4 Sundays
- **6 monthly** - Last 6 months

### Security

- API tokens stored in `/root/pbs-token.txt` on CT113
- Rotate tokens regularly (quarterly recommended)
- Use firewall rules to restrict port 8007 access

---

## Performance Tuning

### Backup Speed

For faster backups (use during maintenance windows):

```bash
# In /etc/pve/storage.cfg
pbs: remote-pbs
    backup-max-performance 1  # Already enabled
    compress zstd             # Best compression
    # compress lzo            # Faster, less compression
    # compress 0              # No compression, fastest
```

### Network Optimization

- Prefer WireGuard (10.6.0.x) over Tailscale for backup traffic
- Schedule backups during off-peak hours
- Monitor bandwidth usage during backup windows

---

## Automation

### Cron Jobs Created

On PBS server (CT113):

```cron
*/15 * * * * /usr/local/bin/pbs-health-monitor.sh      # Health checks
0 3 * * * /usr/local/bin/pbs-gc-staggered.sh           # Garbage collection
0 4 * * * /usr/local/bin/pbs-prune-staggered.sh         # Prune old backups
0 5 * * * /usr/local/bin/pbs-verify-staggered.sh        # Verify backups
0 6 * * * /usr/local/bin/pbs-remote-sync.sh             # Sync to AGLSRV1
```

### Monitoring Automation

Add to crontab on admin host:

```bash
crontab -e

# Health check every 6 hours with email
0 */6 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/pbs-backup-health-check.sh --email

# Daily summary at 8 AM
0 8 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/pbs-backup-health-check.sh | mail -s "PBS Daily Summary" admin@aglz.io
```

---

## Related Documentation

- **Complete Deployment Guide**: `/docs/deployments/PBS-AUTOMATED-BACKUP-DEPLOYMENT.md`
- **Infrastructure Map**: `/docs/INFRA.md`
- **Hosts Configuration**: `/docs/HOSTS.md`
- **Backup Errors Diagnosis**: `/docs/BACKUP-ERRORS-DIAGNOSIS.md`
- **ZFS Alerts Solutions**: `/docs/ZFS-ALERTS-SOLUTIONS.md`

---

## Support

| Issue | Contact |
|-------|---------|
| PBS Issues | https://forum.proxmox.com/forum/viewforum.php?fid=72 |
| Documentation | https://pbs.proxmox.com/docs/ |
| Infrastructure | `agl@aglz.io` |

---

**Last Updated**: 2026-02-07
**Status**: Production Ready
