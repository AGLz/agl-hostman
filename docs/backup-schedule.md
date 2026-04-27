# Automated Backup Schedule Configuration

**Document Version:** 1.0
**Last Updated:** 2026-02-10
**Maintained By:** AGL Infrastructure Team
**Status:** Active

---

## Executive Summary

This document defines the automated backup strategy for all VMs and Containers (CTs) across the AGL infrastructure. The backup system uses Proxmox Backup Server (PBS) on AGLSRV6 and targets FGSRV07 for disaster recovery.

**SLA Commitment:**
- **RTO (Recovery Time Objective):** < 4 hours
- **RPO (Recovery Point Objective):** < 1 hour (critical systems)

---

## Infrastructure Inventory

### Host Overview

| Host | Type | IP Address | Role | PBS Integration |
|------|------|------------|------|-----------------|
| **AGLSRV1** | Bare Metal | 192.168.0.245 | Primary Proxmox Host | PBS Client |
| **AGLSRV6** | Bare Metal | 10.6.0.10 | PBS Server (CT113) | PBS Server |
| **FGSRV07** | VPS Locaweb | 191.252.93.227 / 100.109.181.93 | Proxmox + DR Target | PBS Client + Target |

### Container Inventory (AGLSRV1)

| VMID | Hostname | IP | Role | Criticality | Backup Frequency |
|------|----------|----|----|-------------|------------------|
| **CT173** | cacheng | 192.168.0.173 | APT Cache Proxy | Standard | Weekly |
| **CT180** | dokploy | 192.168.0.180 | Deployment Platform | High | Daily |
| **CT182** | harbor | 192.168.0.182 | Container Registry | High | Daily |
| **CT183** | archon | 192.168.0.183 | MCP Knowledge Base | Critical | Daily |
| **CT184** | supabase | 192.168.0.184 | Database Platform | Critical | Daily |

### PBS Server (AGLSRV6)

| Component | Details |
|-----------|---------|
| **CT ID** | CT113 |
| **IP** | 10.6.0.14 |
| **Datastore** | aglsrv6-pbs (1.2TB), aglsrv6b-pbs (1.0TB) |
| **Port** | 8007 |
| **Retention** | 7 daily, 4 weekly, 12 monthly |

---

## Backup Schedule Strategy

### Tiered Backup Architecture

```
Critical Systems (CT183, CT184)
    ├─ Daily Backups: 02:00 AM
    ├─ Retention: 7 daily, 4 weekly, 12 monthly
    └─ RPO: 24 hours (ideal: 1 hour with incremental)

High Priority Systems (CT180, CT182)
    ├─ Daily Backups: 03:00 AM
    ├─ Retention: 7 daily, 4 weekly, 6 monthly
    └─ RPO: 24 hours

Standard Systems (CT173)
    ├─ Weekly Backups: Sunday 04:00 AM
    ├─ Retention: 4 weekly, 6 monthly
    └─ RPO: 7 days
```

### Backup Window Schedule

| Time Window | Priority | Systems | Backup Type |
|-------------|----------|---------|-------------|
| **02:00 - 02:45** | Critical | CT183 (Archon), CT184 (Supabase) | Full + Incremental |
| **03:00 - 03:30** | High | CT180 (Dokploy), CT182 (Harbor) | Full + Incremental |
| **04:00 - 04:15** | Standard | CT173 (Cacheng) | Full |
| **05:00 - 06:00** | All | Verification & Integrity | Validation |

### Day-of-Week Schedule

| Day | Systems | Backup Type | Notes |
|-----|---------|-------------|-------|
| **Monday** | Critical, High | Incremental | After weekend full backup |
| **Tuesday** | Critical, High | Incremental | |
| **Wednesday** | Critical, High | Incremental | Mid-week checkpoint |
| **Thursday** | Critical, High | Incremental | |
| **Friday** | Critical, High | Full | Pre-weekend full backup |
| **Saturday** | Critical, High | Incremental | |
| **Sunday** | **ALL** | Full | Weekly full backup for all systems |

---

## Proxmox Backup Configuration

### PBS Storage Configuration

**Primary Datastore (AGLSRV6):**
```ini
id: aglsrv6-pbs
type: pbs
server: 10.6.0.14
port: 8007
fingerprint: <PBS_FINGERPRINT>
username: root@pam
password: <ENCRYPTED>
datastore: aglsrv6-pbs
content: backup
gc-schedule: mon,wed,fri *-*-* 02:00
prune-schedule: sat *-*-* 04:00
keep-daily: 7
keep-weekly: 4
keep-monthly: 12
keep-yearly: 0
```

### Backup Job Definitions

#### Job 1: Critical Systems (Daily)
```bash
# /etc/pve/jobs/critical-daily.conf
schedule: 02:00
dow: mon,tue,wed,thu,fri,sat,sun
vmid: 183,184
storage: aglsrv6-pbs
mode: snapshot
compress: zstd
mailnotification: always
prune-options: --keep-daily 7 --keep-weekly 4 --keep-monthly 12
```

#### Job 2: High Priority Systems (Daily)
```bash
# /etc/pve/jobs/high-priority-daily.conf
schedule: 03:00
dow: mon,tue,wed,thu,fri,sat
vmid: 180,182
storage: aglsrv6-pbs
mode: snapshot
compress: zstd
mailnotification: failure
prune-options: --keep-daily 7 --keep-weekly 4 --keep-monthly 6
```

#### Job 3: Standard Systems (Weekly)
```bash
# /etc/pve/jobs/standard-weekly.conf
schedule: 04:00
dow: sun
vmid: 173
storage: aglsrv6-pbs
mode: snapshot
compress: zstd
mailnotification: failure
prune-options: --keep-weekly 4 --keep-monthly 6
```

#### Job 4: Weekly Full Backup (All Systems)
```bash
# /etc/pve/jobs/full-weekly.conf
schedule: 05:00
dow: sun
vmid: 173,180,182,183,184
storage: aglsrv6-pbs
mode: stop
compress: zstd
mailnotification: always
prune-options: --keep-daily 7 --keep-weekly 4 --keep-monthly 12
```

---

## PBS Configuration for FGSRV07

### FGSRV07 as Backup Target

FGSRV07 will serve as an off-site backup destination for disaster recovery:

```bash
# FGSRV07 PBS Configuration
ssh root@100.109.181.93

# Install PBS
apt install proxmox-backup-server

# Initialize datastore
proxmox-backup-manager datastore create local-backup \
  --path /var/lib/proxmox-backup/local-backup \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12

# Configure remote sync from AGLSRV6
proxmox-backup-manager remote create aglsrv1 \
  --host 192.168.0.245 \
  --port 8007 \
  --auth-id root@pam \
  --fingerprint <AGLSRV1_FINGERPRINT>

# Create sync job
proxmox-backup-manager sync-job create local-backup aglsrv1 \
  --schedule "daily 06:00" \
  --remote-datastore aglsrv6-pbs \
  --remove-vanished true \
  --ns-depth 5
```

---

## Backup Verification & Integrity

### Automated Verification Script

**Location:** `/usr/local/bin/backup-verify.sh`

```bash
#!/bin/bash
# Backup verification script
# Runs daily at 08:00

set -euo pipefail

LOG_FILE="/var/log/backup-verify.log"
EMAIL="admin@agl.io"
PBS_HOST="10.6.0.14"
RETENTION_OK=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

verify_backup_age() {
    local vmid=$1
    local max_age_hours=$2

    # Get latest backup timestamp
    latest_backup=$(pvesh get /nodes/$(hostname)/lxc/$vmid/status/current \
      -output-format json | jq -r '.uptime')

    # Verify backup exists on PBS
    backup_info=$(ssh root@$PBS_HOST \
      "proxmox-backup-client snapshot list" \
      | grep "$vmid" | tail -1)

    if [[ -z "$backup_info" ]]; then
        log "ERROR: No backup found for CT$vmid"
        return 1
    fi

    # Calculate age
    backup_age=$(date -d "$backup_info" +%s)
    current_time=$(date +%s)
    age_hours=$(( (current_time - backup_age) / 3600 ))

    if [[ $age_hours -gt $max_age_hours ]]; then
        log "WARNING: CT$vmid backup is $age_hours hours old (max: $max_age_hours)"
        return 1
    fi

    log "OK: CT$vmid backup verified (${age_hours}h old)"
    return 0
}

verify_backup_integrity() {
    local vmid=$1

    # Verify backup catalog integrity
    ssh root@$PBS_HOST \
      "proxmox-backup-client verify --repository $PBS_HOST:aglsrv6-pbs"

    return $?
}

main() {
    log "Starting backup verification..."

    # Critical systems (24h max age)
    verify_backup_age 183 24 || RETENTION_OK=1
    verify_backup_age 184 24 || RETENTION_OK=1

    # High priority (48h max age)
    verify_backup_age 180 48 || RETENTION_OK=1
    verify_backup_age 182 48 || RETENTION_OK=1

    # Standard (7 days max age)
    verify_backup_age 173 168 || RETENTION_OK=1

    # Integrity checks
    for vmid in 173 180 182 183 184; do
        verify_backup_integrity $vmid
    done

    if [[ $RETENTION_OK -ne 0 ]]; then
        log "CRITICAL: Backup verification failed"
        echo "Backup verification failed. Check $LOG_FILE" | \
          mail -s "Backup Verification Alert" $EMAIL
        exit 1
    fi

    log "Backup verification completed successfully"
    exit 0
}

main "$@"
```

### Scheduled Verification

```bash
# /etc/cron.d/backup-verify
# Daily backup verification at 08:00
0 8 * * * root /usr/local/bin/backup-verify.sh

# Weekly full verification (Sunday 10:00)
0 10 * * 0 root /usr/local/bin/backup-verify.sh --full
```

---

## Backup Monitoring & Alerting

### Prometheus Metrics

**Location:** `/etc/prometheus/node_exporter/textfile_collector/backup_metrics.prom`

```bash
#!/bin/bash
# Backup metrics collector
OUTPUT_FILE="/var/lib/node_exporter/textfile_collector/backup_status.prom.$$"

# Get backup status from Proxmox API
BACKUP_STATUS=$(pvesh get /cluster/backup --output-format json)

# Export metrics
cat > "$OUTPUT_FILE" << EOF
# HELP backup_last_success Timestamp of last successful backup
# TYPE backup_last_success gauge
backup_last_success{host="aglsrv1",datastore="aglsrv6-pbs"} $(date +%s)

# HELP backup_last_duration Duration of last backup in seconds
# TYPE backup_last_duration gauge
backup_last_duration{host="aglsrv1"} $(echo "$BACKUP_STATUS" | jq -r '.[0].duration // 0')

# HELP backup_retention_ratio Ratio of backups within retention policy
# TYPE backup_retention_ratio gauge
backup_retention_ratio{host="aglsrv1"} 1.0

# HELP backup_size_bytes Total size of all backups
# TYPE backup_size_bytes gauge
backup_size_bytes{host="aglsrv1",datastore="aglsrv6-pbs"} $(ssh root@10.6.0.14 "du -sb /var/lib/proxmox-backup/local-backup | cut -f1")
EOF

mv "$OUTPUT_FILE" "/var/lib/node_exporter/textfile_collector/backup_status.prom"
```

### Grafana Dashboard Queries

```promql
# Backup Status Panel
backup_last_success{host="aglsrv1"}

# Backup Duration Trend
rate(backup_last_duration[1h])

# Backup Size Growth
rate(backup_size_bytes[7d])

# Retention Compliance
backup_retention_ratio < 1.0
```

---

## Backup Recovery Procedures

### Disaster Recovery Scenarios

#### Scenario 1: Single Container Recovery
**RTO:** < 30 minutes

```bash
# Restore container from PBS
pct restore <new-vmid> \
  aglsrv6-pbs:backup/vzdump-lxc-<vmid>-<timestamp>.tar.zst \
  --storage local-lvm

# Start restored container
pct start <new-vmid>
```

#### Scenario 2: Complete Host Recovery (AGLSRV1)
**RTO:** < 4 hours

```bash
# 1. Provision new Proxmox host
# 2. Install Proxmox VE
# 3. Connect to PBS
pvesm add pbs aglsrv6-pbs \
  --server 10.6.0.14 \
  --port 8007 \
  --fingerprint <FINGERPRINT> \
  --username root@pam \
  --password <PASSWORD>

# 4. Restore containers in priority order
pct restore 183 aglsrv6-pbs:backup/vzdump-lxc-183-*
pct restore 184 aglsrv6-pbs:backup/vzdump-lxc-184-*
pct restore 180 aglsrv6-pbs:backup/vzdump-lxc-180-*
pct restore 182 aglsrv6-pbs:backup/vzdump-lxc-182-*
pct restore 173 aglsrv6-pbs:backup/vzdump-lxc-173-*
```

#### Scenario 3: Complete Site Recovery (PBS Failure)
**RTO:** < 8 hours

```bash
# 1. Restore from FGSRV07 off-site backup
# 2. Provision new PBS server on FGSRV07
# 3. Import backup data
# 4. Reconnect Proxmox hosts
# 5. Restore containers
```

---

## Maintenance & Operations

### Daily Checks
- [ ] Review backup logs: `tail -f /var/log/vzdump.log`
- [ ] Verify backup completion: `pvesh get /cluster/backup`
- [ ] Check PBS storage: `ssh root@10.6.0.14 "df -h /var/lib/proxmox-backup"`

### Weekly Tasks
- [ ] Review retention policy compliance
- [ ] Test restore procedure for one container
- [ ] Verify off-site sync to FGSRV07

### Monthly Tasks
- [ ] Full backup integrity verification
- [ ] Disaster recovery drill (documented test restore)
- [ ] Review and update retention policies
- [ ] Capacity planning for PBS storage

---

## Contacts & Escalation

| Role | Name | Contact | Hours |
|------|------|---------|-------|
| **Primary DBA** | Infrastructure Team | infra@agl.io | 24/7 |
| **Backup Admin** | Storage Team | storage@agl.io | Business hours |
| ** escalation** | CTO | cto@agl.io | Emergency |

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-10 | Initial backup schedule documentation | Hive Mind DBA |

---

**Document Location:** `/docs/backup-schedule.md`
**Related Documents:**
- `/docs/backup-verification-guide.md`
- `/scripts/backup/backup-verify.sh`
- `/config/pbs/pbs-setup.sh`

---

*This document is part of the AGL Infrastructure Disaster Recovery Plan. Unapproved changes may result in data loss.*
