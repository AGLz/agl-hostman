# Disaster Recovery Runbook

**Document Version**: 1.0
**Last Updated**: 2026-02-10
**Maintained By**: AGL Infrastructure Team

---

## Executive Summary

This runbook provides step-by-step procedures for recovering AGL infrastructure services in the event of a disaster.

**RTO**: < 4 hours for critical services
**RPO**: < 1 hour for critical services

---

## Critical Services Priority

| Priority | Service | RTO | RPO |
|----------|---------|-----|-----|
| **P0** | Databases (PostgreSQL, MariaDB) | 2 hours | 1 hour |
| **P1** | Application containers (Docker) | 3 hours | 1 hour |
| **P2** | Proxmox VMs/CTs | 4 hours | 24 hours |
| **P3** | Development environments | 8 hours | 7 days |

---

## Infrastructure Overview

### Primary Infrastructure

| Host | Location | IP Address | Role | Status |
|------|----------|------------|------|--------|
| **AGLSRV1** | Local | 192.168.0.245 | Main Proxmox Host | Active |
| **FGSRV07** | VPS Locaweb | 191.252.93.227 | Proxmox Host | Active |
| **FGSRV06** | VPS Locaweb | 100.83.51.9 | NFS Storage (132GB) | Active |
| **FGSRV05** | VPS Locaweb | 100.71.107.26 | NFS Storage (14GB) | Active |

### Backup Locations

| Location | Type | Size | Access |
|----------|------|------|--------|
| `/spark/base/dump` | Local Proxmox | 7.65 GB | AGLSRV1 |
| `/mnt/shares/agl-hostman-backups` | Local Application | ~200 GB | AGLSRV1 |
| **Backblaze B2** | Offsite Cloud | 400 GB | rclone |
| **Hetzner Storage** | Offsite VPS | 1 TB | rsync over SSH |

---

## Contact Information

### Primary Contacts

| Role | Email | Availability |
|------|-------|---------------|
| **Infrastructure Lead** | ops@agl.local | 24/7 |
| **Database Admin** | dba@agl.local | Business Hours |
| **DevOps Engineer** | devops@agl.local | Business Hours |

---

## Quick Reference Commands

### Proxmox Recovery
```bash
# Restore VM
qmrestore /path/to/backup.vma.zst <vmid> --storage local

# Restore container
pct restore <ctid> /path/to/backup.tar.zst --storage local

# Start VM/CT
qm start <vmid>
pct start <ctid>
```

### Database Recovery
```bash
# PostgreSQL restore
gunzip -c <backup.sql.gz> | psql -U postgres -d database

# MariaDB restore
gunzip -c <backup.sql.gz> | mysql -u root -p database
```

### Offsite Recovery
```bash
# From Backblaze B2
rclone copy agl-hostman-backups:daily/ /tmp/restore/
gpg --output file.tar.gz --decrypt file.tar.gz.gpg

# From Hetzner Storage
rsync -avz -e 'ssh -p 23' user@host:daily/ /tmp/restore/
```

---

## Testing Schedule

### Quarterly DR Testing
**Schedule**: First Sunday of each quarter (January, April, July, October)
**Test Duration**: 8 hours
**Scenarios**:
- Q1: Single server failure recovery
- Q2: Database corruption recovery
- Q3: Complete site failure recovery
- Q4: Ransomware response drill

### Monthly Restore Testing
**Schedule**: First Friday of each month
**Test Duration**: 1 hour
**Process**: Select random backup from offsite, verify integrity

### Weekly Health Checks
**Schedule**: Every Monday morning at 06:00
**Duration**: 5 minutes
**Command**: `./scripts/backup/monitor-replication.sh --email`

---

## Disaster Scenarios

### Scenario 1: Single Server Failure
**Recovery Time**: 1-2 hours
1. Identify failed host
2. Restore VMs/CTs to alternate host
3. Verify services

### Scenario 2: Complete Site Failure
**Recovery Time**: 4-8 hours
1. Declare disaster
2. Assess damage
3. Execute recovery procedures
4. Restore from offsite backups

### Scenario 3: Data Corruption
**Recovery Time**: 2-4 hours
1. Isolate affected systems
2. Restore from backup
3. Verify data integrity

### Scenario 4: Ransomware Attack
**Recovery Time**: 8-24 hours
**IMMEDIATE ACTION**:
- Disconnect ALL systems from network
- Do NOT pay ransom
- Contact security team
- Preserve evidence

---

## Emergency Quick Reference

```
EMERGENCY CONTACTS
==================
Infrastructure Lead: ops@agl.local
RUNBOOK: /mnt/overpower/apps/dev/agl/agl-hostman/docs/disaster-recovery-runbook.md
OFFSITE BACKUP LOCATIONS:
- Backblaze B2: agl-hostman-backups
- Hetzner Storage: uXXXXXX.your-storagebox.de
CRITICAL SYSTEMS:
- AGLSRV1: 192.168.0.245 (Main Proxmox)
- FGSRV07: 191.252.93.227 (VPS Proxmox)
RECOVERY PRIORITY:
1. Databases (PostgreSQL, MariaDB)
2. Application Containers (Docker)
3. Proxmox VMs/CTs
```

---

**End of Disaster Recovery Runbook**
