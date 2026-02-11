# Backup Restoration Guide

## Overview

This guide covers automated backup restoration testing for AGL Hostman infrastructure, ensuring SLA compliance with RTO < 4 hours and RPO < 1 hour.

**AGL-22**: Automated Backup and Disaster Recovery

## Table of Contents

1. [Quick Start](#quick-start)
2. [SLA Compliance](#sla-compliance)
3. [Restoration Testing](#restoration-testing)
4. [Disaster Recovery Procedures](#disaster-recovery-procedures)
5. [Troubleshooting](#troubleshooting)
6. [Maintenance](#maintenance)

---

## Quick Start

### Running Restoration Tests

```bash
# Run all restoration tests
cd /mnt/overpower/apps/dev/agl/agl-hostman
npm run test:backup-restoration

# Or run with Python
python tests/backup/verify_restoration.py

# Or run with Bash
bash tests/backup/test_restoration.sh
```

### Running Specific Tests

```bash
# PostgreSQL restoration test
npm test -- tests/backup/restoration.test.js -t "PostgreSQL"

# RPO compliance check
python tests/backup/verify_restoration.py --check rpo

# Integrity verification only
bash tests/backup/test_restoration.sh --integrity-only
```

---

## SLA Compliance

### RTO: Recovery Time Objective

**Target**: < 4 hours

RTO is the maximum acceptable time to restore services after a disaster.

**Current Performance**:
- Config restoration: ~2 minutes
- Database restoration: ~30 minutes
- Full system restoration: ~2 hours

### RPO: Recovery Point Objective

**Target**: < 1 hour

RPO is the maximum acceptable data loss measured in time.

**Current Backup Schedule**:
- Incremental: Every 15 minutes
- Differential: Every hour
- Full backup: Daily at 02:00 UTC

### SLA Monitoring

```bash
# Check current SLA status
python scripts/backup/check_sla.py

# View SLA history
cat /mnt/shares/agl-hostman-backups/test-restorations/sla-report-*.json
```

---

## Restoration Testing

### Automated Tests

#### Test Suite Locations

| Test Type | Location | Language |
|-----------|----------|----------|
| Integration Tests | `tests/backup/restoration.test.js` | JavaScript |
| Verification Tests | `tests/backup/verify_restoration.py` | Python |
| Shell Tests | `tests/backup/test_restoration.sh` | Bash |

#### Test Categories

1. **Backup Availability**
   - Daily backups present
   - Correct file types
   - Valid timestamps

2. **Integrity Verification**
   - GZIP integrity checks
   - TAR archive validation
   - SQL dump verification
   - RDB file format check

3. **RPO Compliance**
   - Backup age verification
   - Within 1-hour window
   - Coverage across all data types

4. **Extraction Tests**
   - PostgreSQL SQL extraction
   - MariaDB SQL extraction
   - Redis RDB extraction
   - Volume archive extraction
   - Config archive extraction

5. **RTO Testing**
   - Restoration speed measurement
   - Complete workflow validation
   - Performance benchmarking

6. **Retention Policy**
   - Daily cleanup (7 days)
   - Weekly promotion
   - Monthly promotion

### Running Tests Manually

#### PostgreSQL Restoration Test

```bash
# Find latest backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*postgres*.sql.gz | head -1)

# Verify integrity
gzip -t "$BACKUP"

# Extract and verify
mkdir -p /tmp/restore-test
gzip -cd "$BACKUP" > /tmp/restore-test/restore.sql
head -n 50 /tmp/restore-test/restore.sql
```

#### MariaDB Restoration Test

```bash
# Find latest backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*mariadb*.sql.gz | head -1)

# Verify integrity
gzip -t "$BACKUP"

# Extract and verify
mkdir -p /tmp/restore-test
gzip -cd "$BACKUP" > /tmp/restore-test/restore.sql
head -n 50 /tmp/restore-test/restore.sql
```

#### Redis Restoration Test

```bash
# Find latest backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*redis*.rdb.gz | head -1)

# Verify integrity
gzip -t "$BACKUP"

# Extract and verify
mkdir -p /tmp/restore-test
gzip -cd "$BACKUP" > /tmp/restore-test/dump.rdb
file /tmp/restore-test/dump.rdb
```

#### Volume Restoration Test

```bash
# Find latest backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/volume_*.tar.gz | head -1)

# Verify integrity
gzip -t "$BACKUP"

# List contents
gzip -cd "$BACKUP" | tar -tz | head -n 20
```

---

## Disaster Recovery Procedures

### Full System Recovery

#### Step 1: Assess Damage (0-15 minutes)

```bash
# Check system status
ssh fgsrv07.agl.hostman "systemctl status docker"

# Check data integrity
docker ps -a
docker volume ls
```

#### Step 2: Restore Configuration (15-30 minutes)

```bash
# Extract latest config backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/app_config_*.tar.gz | head -1)
mkdir -p /tmp/emergency-restore
tar -xzf "$BACKUP" -C /tmp/emergency-restore

# Restore configuration
cd /tmp/emergency-restore
cp docker-compose.yml /mnt/overpower/apps/dev/agl/agl-hostman/

# Verify environment
cd /mnt/overpower/apps/dev/agl/agl-hostman
source .env
```

#### Step 3: Restore Volumes (30-60 minutes)

```bash
# Restore database volumes
for vol in agl-hostman-db-data agl-hostman-redis-data; do
    BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/volume_${vol}_*.tar.gz | head -1)
    docker run --rm -v "${vol}:/volume" -v "/tmp:/backup" alpine \
        tar -xzf "/backup/$(basename $BACKUP)" -C /volume
done
```

#### Step 4: Restore Databases (60-90 minutes)

**PostgreSQL**

```bash
# Stop existing container
docker stop crowbar-postgres
docker rm crowbar-postgres

# Start fresh container
docker-compose up -d crowbar-postgres

# Wait for ready
docker exec crowbar-postgres pg_isready

# Restore backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*postgres*.sql.gz | head -1)
gzip -cd "$BACKUP" | docker exec -i crowbar-postgres psql -U postgres
```

**MariaDB**

```bash
# Stop existing container
docker stop api9-mariadb
docker rm api9-mariadb

# Start fresh container
docker-compose up -d api9-mariadb

# Wait for ready
docker exec api9-mariadb mysqladmin ping -h localhost

# Restore backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*mariadb*.sql.gz | head -1)
gzip -cd "$BACKUP" | docker exec -i api9-mariadb mysql -u root
```

**Redis**

```bash
# Stop existing container
docker stop crowbar-redis
docker rm crowbar-redis

# Start fresh container with data directory
docker-compose up -d crowbar-redis

# Copy RDB file
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*redis*.rdb.gz | head -1)
gzip -cd "$BACKUP" > /tmp/dump.rdb
docker cp /tmp/dump.rdb crowbar-redis:/data/dump.rdb
docker restart crowbar-redis
```

#### Step 5: Verify Services (90-120 minutes)

```bash
# Check all containers
docker ps

# Run health checks
npm run test:health

# Verify application access
curl -f https://agl.hostman/health || exit 1
```

### Single File Restoration

```bash
# From volume backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/volume_*.tar.gz | head -1)
gzip -cd "$BACKUP" | tar -xz --wildcards "*/path/to/file" -C /tmp
```

### Single Database Restoration

```bash
# From PostgreSQL backup
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*postgres*.sql.gz | head -1)
gzip -cd "$BACKUP" | docker exec -i crowbar-postgres psql -U postgres -d target_database
```

---

## Troubleshooting

### Common Issues

#### Issue: Corrupt Backup File

**Symptoms**:
```
gzip: backup.sql.gz: unexpected end of file
```

**Solution**:
```bash
# Check for older backups
ls -lt /mnt/shares/agl-hostman-backups/daily/ | head -10

# Try weekly backup
ls -lt /mnt/shares/agl-hostman-backups/weekly/ | head -10

# Check if offsite replica is available
ls /mnt/storage/offsite/agl-hostman/daily/
```

#### Issue: Slow Restoration

**Symptoms**:
- Restoration taking longer than 4 hours

**Solution**:
```bash
# Check disk I/O
iostat -x 1

# Check network if restoring from remote
iftop

# Consider parallel restoration
# (extract multiple backups simultaneously)
```

#### Issue: Container Won't Start After Restoration

**Symptoms**:
```
Error: Database initialization failed
```

**Solution**:
```bash
# Check logs
docker logs crowbar-postgres

# Verify data directory
docker exec crowbar-postgres ls -la /var/lib/postgresql/data

# Try reinitializing and restoring again
docker volume rm agl-hostman-db-data
docker volume create agl-hostman-db-data
# ... repeat restoration ...
```

### Recovery Testing

```bash
# Test restoration in isolated environment
docker network create restore-test

# Start test containers
docker run --network restore-test --name test-postgres \
    -e POSTGRES_PASSWORD=test postgres:15

# Restore backup to test
BACKUP=$(ls -t /mnt/shares/agl-hostman-backups/daily/*postgres*.sql.gz | head -1)
gzip -cd "$BACKUP" | docker exec -i test-postgres psql -U postgres

# Verify data
docker exec -it test-postgres psql -U postgres -l

# Cleanup
docker stop test-postgres
docker rm test-postgres
docker network rm restore-test
```

---

## Maintenance

### Daily Tasks

```bash
# Check backup status
bash ops/backup/backup-agl-hostman.sh --status

# Verify latest backups
ls -lt /mnt/shares/agl-hostman-backups/daily/ | head -5

# Check disk space
df -h /mnt/shares/agl-hostman-backups
```

### Weekly Tasks

```bash
# Run full restoration test
python tests/backup/verify_restoration.py

# Review SLA compliance
python scripts/backup/check_sla.py --weekly

# Test recovery procedures
bash tests/backup/test_restoration.sh --full
```

### Monthly Tasks

```bash
# Full DR drill
# 1. Simulate disaster
# 2. Perform full restoration
# 3. Verify all services
# 4. Document lessons learned

# Review retention policy
# Update if needed based on compliance requirements
```

### Periodic Restoration Testing

Automated restoration tests run weekly:

```bash
# View scheduled tests
crontab -l | grep restoration

# Manually trigger
python tests/backup/verify_restoration.py --force
```

---

## Dashboard and Monitoring

### Test Results Dashboard

View test results at:
```
http://dashboard.agl.hostman/backup-tests
```

Or locally:
```bash
python -m http.server 8080 -d tests/backup/reports
open http://localhost:8080
```

### Metrics

Key metrics tracked:
- Backup success rate
- Restoration success rate
- RTO compliance
- RPO compliance
- Backup sizes
- Restoration durations

### Alerts

Alerts configured for:
- Backup failures
- Restoration test failures
- SLA violations
- Low disk space
- Stale backups

---

## Appendix

### Backup Locations

| Type | Location | Retention |
|------|----------|-----------|
| Daily | `/mnt/shares/agl-hostman-backups/daily/` | 7 days |
| Weekly | `/mnt/shares/agl-hostman-backups/weekly/` | 4 weeks |
| Monthly | `/mnt/shares/agl-hostman-backups/monthly/` | 12 months |
| Offsite | `/mnt/storage/offsite/agl-hostman/` | Mirror of daily |

### Backup Naming Convention

```
<container>_<type>_<timestamp>.<extension>

Examples:
- crowbar-postgres_postgres_20250210_020000.sql.gz
- api9-mariadb_mariadb_20250210_020000.sql.gz
- crowbar-redis_redis_20250210_020000.rdb.gz
- volume_agl-hostman-db-data_20250210_020000.tar.gz
- app_config_20250210_020000.tar.gz
```

### Contact

For issues or questions:
- **Documentation**: See AGL-22 in project tracking
- **Emergency**: Contact infrastructure team
- **Script Issues**: Check `/ops/backup/` directory

---

**Document Version**: 1.0
**Last Updated**: 2025-02-10
**Author**: AGL Infrastructure Team
