# Hive Mind CODER Agent - Deliverables

## Quick Start Guide

### Track 1: Backup System (COMPLETED ✓)

#### Installation

1. **Setup MySQL credentials** (for security):
```bash
cat > ~/.my.cnf << 'EOF'
[client]
user=root
password=YOUR_PASSWORD_HERE
EOF
chmod 600 ~/.my.cnf
```

2. **Create backup directory**:
```bash
sudo mkdir -p /var/backups/mysql/fgdev
sudo chown $(whoami):$(whoami) /var/backups/mysql/fgdev
```

3. **Make scripts executable**:
```bash
chmod +x /mnt/overpower/apps/dev/agl/hostman/hive/code/backup-db-sync.sh
chmod +x /mnt/overpower/apps/dev/agl/hostman/hive/code/backup-monitor.sh
```

4. **Test backup manually**:
```bash
/mnt/overpower/apps/dev/agl/hostman/hive/code/backup-db-sync.sh
```

5. **Install cron jobs**:
```bash
crontab -e
# Then copy contents from crontab-backup.txt
```

6. **Verify cron installation**:
```bash
crontab -l
```

#### Monitoring

**View backup logs**:
```bash
tail -f /var/backups/mysql/fgdev/backup.log
```

**Run health check**:
```bash
/mnt/overpower/apps/dev/agl/hostman/hive/code/backup-monitor.sh
```

**Check disk space**:
```bash
df -h /var/backups
```

**List all backups**:
```bash
ls -lh /var/backups/mysql/fgdev/*.sql.gz
```

---

### Track 2: Migration Planning (IN PROGRESS)

#### Current Status
- Architecture document created
- Waiting for Analyst's PHP compatibility report
- Next steps: Route mapping and shim layer implementation

#### Read Migration Architecture
```bash
cat /mnt/overpower/apps/dev/agl/hostman/hive/code/MIGRATION_ARCHITECTURE.md
```

---

## File Inventory

### Core Scripts
| File | Purpose | Status |
|------|---------|--------|
| `backup-db-sync.sh` | 4x daily backup automation | ✓ Complete |
| `backup-monitor.sh` | Health monitoring and alerts | ✓ Complete |
| `crontab-backup.txt` | Cron schedule configuration | ✓ Complete |

### Documentation
| File | Purpose | Status |
|------|---------|--------|
| `MIGRATION_ARCHITECTURE.md` | Complete migration plan | ✓ Complete |
| `README.md` | This file | ✓ Complete |

### Pending Deliverables (Track 2)
| File | Purpose | Status |
|------|---------|--------|
| `rollback-api.sh` | Emergency rollback script | Waiting for route map |
| `transform-namespaces.sh` | Code transformation | Waiting for PHP audit |
| `shim/LegacyDatabaseShim.php` | Database compatibility | Waiting for PHP audit |
| `shim/RouteMapper.php` | Route mapping logic | Waiting for critical paths |
| `shim/FeatureFlags.php` | Gradual rollout system | Waiting for critical paths |

---

## Backup System Features

### Automated Operations
- ✓ 4x daily backups (00:00, 06:00, 12:00, 18:00 BRT)
- ✓ Automatic compression (gzip -9)
- ✓ 7-day retention policy
- ✓ Lock file protection (prevents concurrent runs)
- ✓ Integrity verification (gzip test + SQL validation)
- ✓ Automatic restore to target database

### Safety Features
- ✓ Pre-flight checks (MySQL connection, database existence)
- ✓ Transactional dumps (--single-transaction)
- ✓ Error handling and logging
- ✓ Syslog integration
- ✓ Lock file cleanup (removes stale locks after 1 hour)

### Monitoring Features
- ✓ Backup freshness check (alert if >8 hours old)
- ✓ Backup size validation (alert if <1 MB)
- ✓ Backup integrity verification
- ✓ Disk space monitoring (alert at 80% usage)
- ✓ Log error scanning (last 24 hours)
- ✓ Retention policy verification

---

## Configuration

### Backup Script Variables
```bash
SOURCE_DB="falgimoveis11"        # Production database
TARGET_DB="fgdev"                # Staging/development database
BACKUP_DIR="/var/backups/mysql/fgdev"
RETENTION_DAYS=7                 # Keep backups for 7 days
```

### Monitor Script Variables
```bash
ALERT_THRESHOLD_HOURS=8          # Alert if no backup in 8 hours
MIN_BACKUP_SIZE_MB=1             # Minimum expected backup size
DISK_SPACE_WARNING=80            # Alert if disk usage >80%
ENABLE_EMAIL_ALERTS=false        # Set to true to enable email
ALERT_EMAIL="admin@example.com"
```

### Cron Schedule (BRT Timezone)
```
00:00 BRT (03:00 UTC) - Midnight backup
06:00 BRT (09:00 UTC) - Morning backup
12:00 BRT (15:00 UTC) - Noon backup
18:00 BRT (21:00 UTC) - Evening backup
```

---

## Troubleshooting

### Backup fails with "MySQL connection failed"
```bash
# Check MySQL service
sudo systemctl status mysql

# Test MySQL connection
mysql -u root -p -e "SELECT 1"

# Verify ~/.my.cnf
cat ~/.my.cnf
```

### Backup fails with "Database does not exist"
```bash
# List all databases
mysql -u root -p -e "SHOW DATABASES"

# Create target database if missing
mysql -u root -p -e "CREATE DATABASE fgdev"
```

### Lock file persists after crash
```bash
# Remove stale lock (only if no backup is running)
rm -f /var/backups/mysql/fgdev/.backup.lock
```

### Disk space full
```bash
# Check disk usage
df -h /var/backups

# Manually clean old backups (older than 7 days)
find /var/backups/mysql/fgdev -name "*.sql.gz" -mtime +7 -delete
```

### Monitor alerts not working
```bash
# Check syslog for alerts
sudo journalctl -t db-backup-monitor -f

# Enable email alerts
# Edit backup-monitor.sh and set:
# ENABLE_EMAIL_ALERTS=true
# ALERT_EMAIL="your-email@example.com"
```

---

## Next Steps for Track 2

1. **Wait for Analyst Report**: PHP compatibility assessment
2. **Route Mapping**: Identify critical paths based on traffic analysis
3. **Shim Layer Implementation**: Build compatibility wrappers
4. **Rollback Scripts**: Create emergency procedures
5. **Testing Suite**: Develop validation tests
6. **Deployment**: Incremental rollout with monitoring

---

## Support

**Created by**: CODER Agent (Hive Mind)
**Date**: 2025-10-13
**Project**: Hostman API Migration (API1 → API8)

For questions or issues, coordinate with:
- **Queen**: Strategic oversight
- **Analyst**: PHP compatibility assessment
- **Tester**: Validation and quality assurance
