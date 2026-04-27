# Backup Quick Reference Guide

**Version:** 1.0
**Last Updated:** 2026-02-10

---

## Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| Infrastructure Lead | admin@agl.io | 24/7 |
| DBA Team | dba@agl.io | Business hours |
| Storage Admin | storage@agl.io | Business hours |

---

## Backup Schedule Overview

```
02:00 - Critical Systems (CT183 Archon, CT184 Supabase)
03:00 - High Priority (CT180 Dokploy, CT182 Harbor)
04:00 - Standard Systems (CT173 Cacheng) - Sunday only
05:00 - Full Backup (All Systems) - Sunday only
08:00 - Verification (Daily)
06:00 - Off-site Sync to FGSRV07 (Daily)
```

---

## Quick Commands

### Check Backup Status
```bash
# List all backup jobs
pvesh get /cluster/backup

# Check last backup status
tail -f /var/log/vzdump.log

# View PBS datastore info
ssh root@10.6.0.14 "proxmox-backup-manager datastore info --datastore aglsrv6-pbs"
```

### Manual Backup
```bash
# Backup single container
vzdump 183 --storage aglsrv6-pbs --mode snapshot

# Backup with specific compression
vzdump 183 --storage aglsrv6-pbs --compress zstd

# Full backup (stops container)
vzdump 183 --storage aglsrv6-pbs --mode stop
```

### Restore Operations
```bash
# Restore container
pct restore 200 aglsrv6-pbs:backup/vzdump-lxc-183-2026-02-10.tar.zst

# Restore to different storage
pct restore 200 aglsrv6-pbs:backup/vzdump-lxc-183-* --storage local-lvm

# List available backups
pvesh get /nodes/$(hostname)/lxc/183/backup
```

### Verification
```bash
# Run full verification
/usr/local/bin/backup-verify.sh --full --email

# Check verification state
cat /var/lib/backup-verify/state.json | jq .

# View verification logs
tail -f /var/log/backup-verify.log
```

---

## Container Inventory

| VMID | Name | IP | Criticality | Schedule | Retention |
|------|------|----|-------------|----------|-----------|
| CT173 | cacheng | 192.168.0.173 | Standard | Weekly (Sun 04:00) | 4W, 6M |
| CT180 | dokploy | 192.168.0.180 | High | Daily (03:00) | 7D, 4W, 6M |
| CT182 | harbor | 192.168.0.182 | High | Daily (03:00) | 7D, 4W, 6M |
| CT183 | archon | 192.168.0.183 | Critical | Daily (02:00) | 7D, 4W, 12M |
| CT184 | supabase | 192.168.0.184 | Critical | Daily (02:00) | 7D, 4W, 12M |

---

## PBS Storage Information

**Primary PBS:** AGLSRV6 (10.6.0.14:8007)
- Datastore: aglsrv6-pbs (1.2TB)
- Datastore: aglsrv6b-pbs (1.0TB)
- Retention: 7 daily, 4 weekly, 12 monthly

**Off-site:** FGSRV07 (100.109.181.93)
- Datastore: local-backup
- Synced from: aglsrv6-pbs
- Schedule: Daily 06:00

---

## Common Issues & Solutions

### Backup Failed - No Space
```bash
# Check PBS storage
ssh root@10.6.0.14 "df -h /var/lib/proxmox-backup/local-backup"

# Run manual prune
ssh root@10.6.0.14 "proxmox-backup-client prune --repository 10.6.0.14:aglsrv6-pbs --keep-daily 7 --keep-weekly 4 --keep-monthly 12"

# Run garbage collection
ssh root@10.6.0.14 "proxmox-backup-client gc --repository 10.6.0.14:aglsrv6-pbs"
```

### Restore Failed - Snapshot Not Found
```bash
# List available snapshots
ssh root@10.6.0.14 "proxmox-backup-client snapshot list --repository 10.6.0.14:aglsrv6-pbs"

# Search for specific container
ssh root@10.6.0.14 "proxmox-backup-client snapshot list --repository 10.6.0.14:aglsrv6-pbs | grep ct/183"
```

### Sync to FGSRV07 Failed
```bash
# Check FGSRV07 connectivity
ping -c 2 100.109.181.93

# Check sync job status
ssh root@100.109.181.93 "proxmox-backup-manager sync-job list"

# Run manual sync
ssh root@100.109.181.93 "proxmox-backup-manager sync-job run fgsrv07-local-backup"
```

---

## SLA Summary

| Metric | Target | Current |
|--------|--------|---------|
| RTO (Critical) | < 4 hours | ~30 min |
| RTO (Standard) | < 8 hours | ~2 hours |
| RPO (Critical) | < 1 hour | 24 hours* |
| RPO (Standard) | < 24 hours | 7 days |
| Retention Compliance | > 95% | Pending |

*Note: RPO can be improved with hourly incremental backups

---

## Maintenance Schedule

**Daily:**
- 08:00 - Backup verification
- Review backup logs
- Check PBS storage

**Weekly:**
- Sunday - Full backup of all systems
- Review retention compliance
- Test restore procedure (1 container)

**Monthly:**
- Full backup integrity verification
- Disaster recovery drill
- Capacity planning review
- Update documentation

---

## Useful File Locations

| File | Purpose |
|------|---------|
| `/var/log/vzdump.log` | Backup logs |
| `/var/log/backup-verify.log` | Verification logs |
| `/var/lib/backup-verify/state.json` | Verification state |
| `/etc/pve/jobs/*.conf` | Backup job configs |
| `/etc/cron.d/backup-schedule` | Cron schedules |
| `/usr/local/bin/backup-*.sh` | Backup scripts |

---

## Monitoring Dashboard

**Grafana:** http://192.168.0.245:3000/d/backup-monitoring
**Prometheus:** http://192.168.0.245:9090

**Key Metrics:**
- `backup_last_success_timestamp`
- `backup_duration_seconds`
- `pbs_storage_usage_percentage`
- `backup_retention_compliance_ratio`

---

**For detailed procedures, see:** `/docs/backup-schedule.md`
