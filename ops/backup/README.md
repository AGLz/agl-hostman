# AGL Hostman Backup System

Quick reference for the AGL Hostman backup and disaster recovery system.

## Quick Start

```bash
# Run backup now
./ops/backup/backup-agl-hostman.sh

# Check backup health
./ops/backup/monitor-backup-health.sh

# Restore from backup (interactive)
./ops/backup/restore-agl-hostman.sh

# Test backup restore
./ops/backup/test-backup-restore.sh
```

## Backup Locations

- **Daily**: `/mnt/shares/agl-hostman-backups/daily/` (7-day retention)
- **Weekly**: `/mnt/shares/agl-hostman-backups/weekly/` (4-week retention)
- **Monthly**: `/mnt/shares/agl-hostman-backups/monthly/` (12-month retention)
- **Logs**: `/mnt/shares/agl-hostman-backups/logs/`

## What Gets Backed Up

- PostgreSQL databases (all containers)
- MariaDB databases (all containers)
- Redis data (all instances)
- Docker volumes
- Application configuration
- Environment files (encrypted)

## SLA Targets

- **RTO** (Recovery Time): < 4 hours
- **RPO** (Data Loss): < 1 hour

## Schedule

| Backup | Time | Retention |
|--------|------|-----------|
| Daily | 02:00 UTC | 7 days |
| Weekly | Sun 03:00 UTC | 4 weeks |
| Monthly | 1st 04:00 UTC | 12 months |
| Health Check | Every 6h | N/A |
| Restore Test | Sun 05:00 UTC | N/A |

## Emergency Restore

Full system restore:
```bash
# 1. Stop everything
cd /mnt/overpower/apps/dev/agl/agl-hostman
docker compose down

# 2. Run restore
./ops/backup/restore-agl-hostman.sh

# 3. Start services
docker compose up -d
```

Database-only restore:
```bash
./ops/backup/restore-agl-hostman.sh
# Select option 2 (Database only)
```

## Configuration

Edit environment variables in `backup-config.env`:

```bash
# Alerts
export ALERT_EMAIL="ops@company.com"
export SLACK_WEBHOOK="https://hooks.slack.com/..."

# Offsite
export OFFSITE_ENABLED=true
export OFFSITE_TARGET="/mnt/storage/offsite/agl-hostman"
```

## Monitoring

Check backup status:
```bash
# Latest backups
ls -lth /mnt/shares/agl-hostman-backups/daily/ | head -10

# Backup size
du -sh /mnt/shares/agl-hostman-backups/

# Disk space
df -h /mnt/shares/agl-hostman-backups/

# Recent logs
tail -50 /mnt/shares/agl-hostman-backups/logs/backup-*.log
```

## Troubleshooting

**Backup fails?**
```bash
# Check disk space
df -h /mnt/shares/agl-hostman-backups

# Check Docker
docker ps -a

# Review logs
tail -100 /mnt/shares/agl-hostman-backups/logs/backup-*.log
```

**Restore fails?**
```bash
# Verify backup integrity
gunzip -t /mnt/shares/agl-hostman-backups/daily/<backup-file>

# Check test restore logs
tail -100 /mnt/shares/agl-hostman-backups/logs/test-*.log
```

## Full Documentation

See `BACKUP_DISASTER_RECOVERY.md` for complete documentation including:
- Detailed installation instructions
- Disaster recovery procedures
- Troubleshooting guides
- Security considerations
- Performance optimization
