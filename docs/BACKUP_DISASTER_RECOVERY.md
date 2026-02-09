# AGL Hostman - Backup and Disaster Recovery Documentation

## Overview

This document provides comprehensive information about the backup and disaster recovery procedures for AGL Hostman. The backup system is designed to meet the following SLA targets:

- **RTO (Recovery Time Objective)**: < 4 hours
- **RPO (Recovery Point Objective)**: < 1 hour

## Architecture

### Backup Components

1. **Database Backups**
   - PostgreSQL: Automated dumps using `pg_dump` (custom format)
   - MariaDB: Automated dumps using `mysqldump`
   - System PostgreSQL: Direct dumps from host service

2. **Redis Backups**
   - RDB file snapshots
   - Automatic BGSAVE before backup

3. **Docker Volume Backups**
   - tar.gz archives of named volumes
   - Includes both data and metadata

4. **Application Configuration**
   - docker-compose.yml
   - Docker configuration files
   - Scripts and documentation
   - Encrypted environment files

### Backup Storage Structure

```
/mnt/shares/agl-hostman-backups/
├── daily/          # Daily backups (7-day retention)
├── weekly/         # Weekly backups (4-week retention)
├── monthly/        # Monthly backups (12-month retention)
├── logs/           # Backup and restore logs
└── wal/            # PostgreSQL WAL archives (for PITR)
```

## Backup Schedule

| Schedule | Time (UTC) | Retention | Purpose |
|----------|------------|-----------|---------|
| Daily | 02:00 | 7 days | Point-in-time recovery |
| Weekly | Sunday 03:00 | 4 weeks | Weekly restore points |
| Monthly | 1st 04:00 | 12 months | Long-term archival |
| Health Check | Every 6 hours | N/A | Monitor backup health |
| Restore Test | Sunday 05:00 | N/A | Validate backups |

## Backup Scripts

### 1. backup-agl-hostman.sh

Main backup script that performs the following:

1. **Pre-backup checks**
   - Disk space verification
   - Docker daemon availability
   - Directory structure validation

2. **Database backups**
   - PostgreSQL containers
   - MariaDB containers
   - System PostgreSQL

3. **Redis backups**
   - All Redis instances

4. **Docker volumes**
   - Application data volumes

5. **Application configuration**
   - Config files
   - Environment files (encrypted)

6. **Post-backup tasks**
   - Offsite replication
   - Retention policy application
   - Report generation

**Usage:**
```bash
# Run backup manually
./ops/backup/backup-agl-hostman.sh

# Run with custom config
export ALERT_EMAIL="ops@company.com"
export SLACK_WEBHOOK="https://hooks.slack.com/..."
./ops/backup/backup-agl-hostman.sh
```

### 2. restore-agl-hostman.sh

Disaster recovery script that restores from backups:

**Interactive mode:**
```bash
./ops/backup/restore-agl-hostman.sh
```

**Automated mode:**
```bash
./ops/backup/restore-agl-hostman.sh --timestamp 20250208_020000 daily
```

**Restore types:**
1. Full restore (all databases, Redis, volumes, config)
2. Database only
3. Redis only
4. Docker volumes only
5. Application configuration only

### 3. monitor-backup-health.sh

Health monitoring script that checks:

- Latest backup age
- Backup file integrity
- Disk space availability
- Offsite replication status

**Usage:**
```bash
./ops/backup/monitor-backup-health.sh
```

**Cron:**
```bash
0 */6 * * * /path/to/monitor-backup-health.sh
```

### 4. test-backup-restore.sh

Automated backup testing script that validates:

- Backup file integrity
- Backup completeness
- PostgreSQL restore capability
- Redis restore capability
- Restore speed (RTO validation)

**Usage:**
```bash
./ops/backup/test-backup-restore.sh
```

## Installation

### 1. Setup Backup Directories

```bash
sudo mkdir -p /mnt/shares/agl-hostman-backups/{daily,weekly,monthly,logs,wal}
sudo chown -R $(whoami):$(whoami) /mnt/shares/agl-hostman-backups
chmod 750 /mnt/shares/agl-hostman-backups
```

### 2. Install Dependencies

```bash
# Required packages
sudo apt-get update
sudo apt-get install -y gzip rsync gpg mailutils curl

# For PostgreSQL system backups
sudo apt-get install -y postgresql-client
```

### 3. Configure Offsite Replication (Optional)

If using offsite storage:

```bash
# Create offsite directory
sudo mkdir -p /mnt/storage/offsite/agl-hostman

# Or configure SSH for remote replication
ssh-keygen -t ed25519 -C "agl-hostman-backup"
ssh-copy-id backup-user@remote-server
```

### 4. Setup Cron Jobs

```bash
# Edit crontab
crontab -e

# Add the contents of crontab.setup
# Or automatically install:
crontab -l | { cat; cat /mnt/overpower/apps/dev/agl/agl-hostman/ops/backup/crontab.setup; } | crontab -
```

### 5. Configure Alerts

Edit `backup-config.env`:

```bash
# Email alerts
ALERT_EMAIL="ops@yourcompany.com"

# Slack alerts (optional)
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### 6. Set Permissions

```bash
chmod +x /mnt/overpower/apps/dev/agl/agl-hostman/ops/backup/*.sh
```

### 7. Test Backup System

```bash
# Run initial backup
cd /mnt/overpower/apps/dev/agl/agl-hostman
./ops/backup/backup-agl-hostman.sh

# Run health check
./ops/backup/monitor-backup-health.sh

# Run restore test
./ops/backup/test-backup-restore.sh
```

## Disaster Recovery Procedures

### Scenario 1: Database Corruption

**Symptoms:**
- Application errors accessing database
- PostgreSQL/MariaDB reports corruption
- Data inconsistency

**Recovery Steps:**

1. Stop affected services:
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
docker compose down
```

2. Identify latest good backup:
```bash
ls -lth /mnt/shares/agl-hostman-backups/daily/*postgres*.sql.gz | head -5
```

3. Restore database:
```bash
./ops/backup/restore-agl-hostman.sh
# Select option 2 (Database only)
# Choose backup timestamp
```

4. Start services:
```bash
docker compose up -d
```

5. Verify:
```bash
docker compose logs -f
```

### Scenario 2: Complete System Failure

**Symptoms:**
- Entire server unavailable
- Hardware failure
- Data center outage

**Recovery Steps:**

1. Provision new server
2. Install Docker and dependencies
3. Clone application repository:
```bash
git clone <repository-url> /mnt/overpower/apps/dev/agl/agl-hostman
cd /mnt/overpower/apps/dev/agl/agl-hostman
```

4. Mount backup storage or transfer backups:
```bash
rsync -avz backup-server:/mnt/shares/agl-hostman-backups/ /mnt/shares/agl-hostman-backups/
```

5. Run full restore:
```bash
./ops/backup/restore-agl-hostman.sh
# Select option 1 (Full restore)
# Choose appropriate backup (daily/weekly/monthly)
```

6. Update DNS/load balancer
7. Verify all services

### Scenario 3: Accidental Data Deletion

**Symptoms:**
- User reports missing data
- Specific records deleted

**Recovery Steps:**

1. Identify time of deletion
2. Find appropriate backup:
```bash
# Point-in-time recovery if using WAL archives
# Or select backup from before deletion
ls -lh /mnt/shares/agl-hostman-backups/daily/*postgres*.sql.gz
```

3. Restore to test environment first:
```bash
# Create test container
docker run -d --name test-restore -e POSTGRES_PASSWORD=test postgres:16-alpine

# Restore backup to test
gunzip -c <backup-file> | docker exec -i test-restore pg_restore -U postgres -d testdb

# Verify data
docker exec -it test-restore psql -U postgres -d testdb
```

4. If data found, restore to production:
```bash
./ops/backup/restore-agl-hostman.sh --timestamp <backup-timestamp> daily
```

## Monitoring and Alerting

### Backup Health Metrics

Monitor these key metrics:

1. **Backup Age**: Latest backup should be < 26 hours old
2. **Backup Size**: Should be consistent with expected data size
3. **File Integrity**: All .gz files should pass gzip test
4. **Disk Space**: Maintain > 50GB free space

### Alert Conditions

Alerts are triggered for:

- Backup failure
- Corrupt backup files
- Backup age exceeding threshold
- Low disk space
- Offsite replication failure
- Restore test failures

### Logging

Logs are stored in:
```
/mnt/shares/agl-hostman-backups/logs/
├── backup-<timestamp>.log      # Individual backup logs
├── restore-<timestamp>.log     # Individual restore logs
├── test-<timestamp>.log        # Test restore logs
├── health-report-<timestamp>.txt  # Health check reports
└── cron-*.log                  # Scheduled job logs
```

## Maintenance

### Regular Tasks

| Task | Frequency | Command |
|------|-----------|---------|
| Review backup logs | Daily | Check logs for errors |
| Verify backup integrity | Weekly | Run test-backup-restore.sh |
| Check disk space | Weekly | df -h /mnt/shares/agl-hostman-backups |
| Review retention policy | Monthly | Verify old backups are cleaned |
| Test full restore | Quarterly | Run full restore in test environment |
| Update documentation | As needed | Keep procedures current |

### Cleanup

Old logs are automatically cleaned after 30 days. Manual cleanup:

```bash
# Remove backups older than X days
find /mnt/shares/agl-hostman-backups/daily -name "*.sql.gz" -mtime +7 -delete

# Clean old logs
find /mnt/shares/agl-hostman-backups/logs -name "*.log" -mtime +30 -delete
```

## Security Considerations

1. **Encryption**: Environment files are encrypted with GPG
2. **Access Control**: Backup directory has restricted permissions (750)
3. **Secure Transfer**: Offsite replication uses SSH/rsync
4. **Secrets Management**: Never store passwords in backup scripts
5. **Audit Trail**: All operations are logged

## Troubleshooting

### Issue: Backup fails with "disk space" error

**Solution:**
```bash
# Check available space
df -h /mnt/shares/agl-hostman-backups

# Free up space by cleaning old backups
find /mnt/shares/agl-hostman-backups/daily -type f -mtime +7 -delete
```

### Issue: Database dump fails

**Solution:**
```bash
# Check container status
docker ps -a | grep postgres

# Check database connectivity
docker exec <container> pg_isready

# Review database logs
docker logs <container>
```

### Issue: Offsite replication fails

**Solution:**
```bash
# Test SSH connection
ssh backup-user@remote-server

# Check rsync manually
rsync -avz --dry-run /mnt/shares/agl-hostman-backups/daily/ \
    backup-user@remote-server:/path/to/backups/daily/
```

### Issue: GPG decryption fails

**Solution:**
```bash
# Test GPG with correct passphrase
gpg --batch --yes --passphrase <passphrase> \
    --output test.env --decrypt <env-file>.enc

# If passphrase unknown, restore from unencrypted backup
```

## Performance Optimization

### Backup Speed

- Enable parallel backups for multiple databases
- Use compression level 6 (balanced)
- Consider incremental backups for large datasets

### Restore Speed

Current restore capabilities:
- PostgreSQL: ~50MB/s
- Redis: ~100MB/s
- Full restore: ~30-60 minutes (within 4-hour RTO)

Optimization tips:
- Keep backups on fast storage (SSD if possible)
- Pre-create empty databases before restore
- Use parallel restore for multiple databases

## Support

For issues or questions:

1. Check logs in `/mnt/shares/agl-hostman-backups/logs/`
2. Review this documentation
3. Run health check: `./ops/backup/monitor-backup-health.sh`
4. Contact DevOps team: devops@agl.local

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-02-08 | Initial implementation |
