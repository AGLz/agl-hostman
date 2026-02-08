---
name: backup-automation-verification
description: "Automated backup creation, verification, and restore testing for databases, files, and configurations. Use when implementing disaster recovery, compliance requirements, or data protection policies."
category: infrastructure
priority: P0
tags: [backup, disaster-recovery, automation, compliance]
---

# Backup Automation & Verification

**CRITICAL SKILL** - Disaster recovery and data protection infrastructure.

This skill provides automated backup creation, verification, and restore testing for databases, files, and configurations. Essential for business continuity, compliance requirements (GDPR, SOC2, HIPAA), and protecting against catastrophic data loss.

## When to use this skill

- Implementing automated database backups
- Setting up file storage backup automation
- Configuring backup retention and cleanup policies
- Implementing backup verification and integrity checks
- Creating automated restore testing procedures
- Setting up off-site backup replication (S3, Glacier)
- Implementing backup encryption and security
- Meeting compliance requirements (GDPR, SOC2, HIPAA)
- Creating disaster recovery runbooks
- Setting RTO/RPO targets and monitoring
- Implementing multi-region backup strategies
- Managing backup storage costs and lifecycle
- Testing backup restoration processes regularly
- Setting up backup monitoring and alerting

## Overview

### The 3-2-1 Backup Rule

The industry standard backup strategy:

- **3** copies of your data (production + 2 backup copies)
- **2** different storage types (local disk + cloud storage)
- **1** off-site backup (S3, Glacier, or remote location)

### Recovery Objectives

| Metric | Description | Typical Target |
|--------|-------------|----------------|
| **RTO** | Recovery Time Objective - time to restore service | 1-4 hours |
| **RPO** | Recovery Point Objective - max acceptable data loss | 15 min - 24 hours |

### Backup Types

| Type | Description | Speed | Storage |
|------|-------------|-------|---------|
| **Full** | Complete backup of all data | Slow | Largest |
| **Incremental** | Changes since last backup | Fast | Smallest |
| **Differential** | Changes since last full | Medium | Medium |
| **Snapshot** | Point-in-time filesystem state | Fastest | Varies |

## Contents

### Scripts (scripts/)

| Script | Purpose |
|--------|---------|
| `backup-database.sh` | Automated database backup with compression |
| `backup-files.sh` | Backup critical files and directories |
| `backup-verify.sh` | Verify backup integrity with checksums |
| `backup-cleanup.sh` | Remove old backups per retention policy |
| `backup-restore-test.sh` | Automated restore testing to staging |
| `backup-report.sh` | Generate backup status and health reports |

### Templates (templates/)

| Template | Purpose |
|----------|---------|
| `backup-schedule.yml` | Crontab schedule template |
| `backup-notification.md` | Alert template for failures |
| `backup-config.php` | Laravel backup configuration |
| `disaster-recovery.md` | DR runbook template |

## Database Backups

### MySQL/MariaDB

```bash
# Full backup with compression
mysqldump --single-transaction --quick --lock-tables=false \
  -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME | \
  gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Verify backup
gunzip -c backup.sql.gz | head -n 5
```

### PostgreSQL

```bash
# Full backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME | \
  gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Verify backup
pg_restore --list backup.sql.gz
```

### SQLite

```bash
# Online backup (no locking)
sqlite3 $DB_PATH ".backup backup_$(date +%Y%m%d).db"

# Verify
sqlite3 backup.db "PRAGMA integrity_check;"
```

## File Backups

### Critical Paths to Backup

```bash
# Laravel application storage
/storage/app/
/storage/framework/
/storage/logs/

# Configuration
/.env
/config/

# User uploads
/public/uploads/
/storage/app/public/
```

### Backup with tar

```bash
tar -czf backup_files_$(date +%Y%m%d).tar.gz \
  /var/www/html/storage/app \
  /var/www/html/.env \
  /var/www/html/public/uploads
```

## Encryption

### GPG Encryption

```bash
# Encrypt backup
gpg --encrypt --recipient ops@company.com backup.sql.gz

# Decrypt backup
gpg --decrypt backup.sql.gz.gpg > backup.sql.gz
```

### OpenSSL Encryption

```bash
# Encrypt with AES-256
openssl enc -aes-256-cbc -salt -in backup.sql.gz \
  -out backup.sql.gz.enc -k $BACKUP_KEY

# Decrypt
openssl enc -d -aes-256-cbc -in backup.sql.gz.enc \
  -out backup.sql.gz -k $BACKUP_KEY
```

## Retention Policies

### Recommended Retention Schedule

| Backup Type | Retention | Schedule |
|-------------|-----------|----------|
| Hourly | 24 hours | Every hour |
| Daily | 7-30 days | Daily at 2 AM |
| Weekly | 4-12 weeks | Sunday at 3 AM |
| Monthly | 12 months | 1st of month |
| Yearly | 7 years | January 1st |

### Automated Cleanup

```bash
# Keep last 7 daily backups
find /backups/daily -name "backup_*.sql.gz" -mtime +7 -delete

# Keep last 4 weekly backups
find /backups/weekly -name "backup_*.sql.gz" -mtime +28 -delete

# Keep last 12 monthly backups
find /backups/monthly -name "backup_*.sql.gz" -mtime +365 -delete
```

## Verification

### Checksum Verification

```bash
# Create checksums
sha256sum backup.sql.gz > checksums.txt

# Verify backups
sha256sum -c checksums.txt
```

### Automated Integrity Check

```bash
# Test gzip integrity
gzip -t backup.sql.gz

# Test SQL file integrity
zcat backup.sql.gz | head -n 100
```

## Off-site Storage

### AWS S3

```bash
# Upload to S3
aws s3 cp backup.sql.gz s3://backup-bucket/database/

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket backup-bucket \
  --versioning-configuration Status=Enabled

# Lifecycle policy for Glacier
aws s3api put-bucket-lifecycle-configuration \
  --bucket backup-bucket \
  --lifecycle-configuration file://lifecycle.json
```

### S3 Lifecycle Policy

```json
{
  "Rules": [
    {
      "Id": "BackupArchive",
      "Status": "Enabled",
      "Prefix": "backups/",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
```

### Rclone for Multiple Clouds

```bash
# Sync to multiple providers
rclone sync /backups/ s3:backup-bucket/
rclone sync /backups/ b2:backup-bucket/
rclone sync /backups/ azure:backup-container/
```

## Disaster Recovery

### RTO/RPO Targets by System

| System | RTO | RPO | Priority |
|--------|-----|-----|----------|
| Database | 1 hour | 15 min | Critical |
| File Storage | 2 hours | 1 hour | High |
| Configuration | 30 min | Instant | Critical |
| Application | 1 hour | Instant | High |

### Recovery Steps

```bash
# 1. Assess damage
identify_affected_systems.sh

# 2. Select backup
list_available_backups.sh

# 3. Prepare environment
provision_recovery_environment.sh

# 4. Restore database
restore_database.sh backup_20250107.sql.gz

# 5. Restore files
restore_files.sh backup_files_20250107.tar.gz

# 6. Verify integrity
run_health_checks.sh

# 7. Switch DNS
update_dns.sh recovery.example.com

# 8. Monitor
monitor_recovery.sh
```

## Compliance

### GDPR Requirements

- Right to erasure (data deletion)
- Data portability (backup exports)
- Breach notification (72 hours)
- Data protection by design

### SOC2 Requirements

- Access controls on backups
- Encryption at rest and in transit
- Regular restore testing
- Audit logging of all operations

### HIPAA Requirements

- Protected Health Information (PHI) encryption
- Business Associate Agreements (BAAs) with cloud providers
- 6-year retention for medical records
- Audit trails for all access

## Best Practices

1. **Automate everything** - Manual backups fail
2. **Test restores regularly** - Untested backups are useless
3. **Encrypt backups** - At rest and in transit
4. **Use lifecycle policies** - Auto-delete old backups
5. **Monitor backup jobs** - Alert on failures
6. **Document procedures** - Keep runbooks updated
7. **Geographic redundancy** - Multiple regions
8. **Version control backups** - Track changes
9. **Secure credentials** - Rotate access keys
10. **Compliance requirements** - Meet regulatory standards

## Quick Start

```bash
# Run all backup scripts
./scripts/backup-database.sh
./scripts/backup-files.sh
./scripts/backup-verify.sh
./scripts/backup-report.sh

# Test restore to staging
./scripts/backup-restore-test.sh

# Clean old backups
./scripts/backup-cleanup.sh
```

## References

- [Laravel Backup Guide](../.claude/skills/devops/backup-strategies/assets/backup-guide.md)
- [PBS Documentation](../../../docs/deployments/PBS-QUICK-REFERENCE.md)
- [Proxmox Backup](../../../docs/deployments/PBS-AUTOMATED-BACKUP-DEPLOYMENT.md)
