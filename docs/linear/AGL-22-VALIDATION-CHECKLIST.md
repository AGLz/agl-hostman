# AGL-22: Automated Backup and Disaster Recovery - Validation Checklist

**Issue ID**: AGL-22
**Title**: Automated Backup and Disaster Recovery
**Priority**: High
**Estimate**: 2-3 weeks
**Current Status**: Partially Automated (60%)
**Document Version**: 1.0
**Last Updated**: 2026-02-11

---

## Checklist Overview

This validation checklist ensures comprehensive backup and disaster recovery implementation. Use this checklist during implementation and for final validation before marking task as complete.

**SLA Targets**:
- **RPO (Recovery Point Objective)**: < 1 hour
- **RTO (Recovery Time Objective)**: < 4 hours
- **Backup Success Rate**: 100%
- **Off-site Replication**: Daily
- **Restore Testing**: Quarterly

**Legend**:
- [ ] = Not started
- [~] = In progress
- [x] = Complete
- [!] = Failed/Blocked
- [n/a] = Not applicable
- ⚠️ = Manual verification required
- 🔴 = Critical priority
- 🟠 = High priority

---

## Phase 1: Backup Encryption & Security (Week 1)

### 1.1 GPG Encryption Setup

**GPG Key Generation**:
```bash
# Generate encryption key
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: AGL Backup Encryption
Name-Email: backup@aglz.io
Expire-Date: 0
%no-protection
%commit
EOF
```

- [ ] GPG installed (apt install gpg)
- [ ] Master encryption key generated (4096-bit RSA)
- [ ] Public key exported and backed up
- [ ] Private key secured offline
- [ ] Key expiration: Never (0)
- [ ] Revocation certificate created
- [ ] Key distributed to backup operators

**Key Backup**:
- [ ] Private key stored in secure location
- [ ] Private key encrypted with passphrase
- [ ] Private key copied to air-gapped storage
- [ ] Recovery procedure documented

### 1.2 Backup Script Encryption

**PostgreSQL Encryption**:
```bash
# Modify backup script
pg_dump -U postgres -Fc | \
  gpg --encrypt --recipient backup@aglz.io | \
  dd of=/backups/postgres-$(date +%Y%m%d).sql.gz.gpg
```

- [ ] pg_dump modified for encryption
- [ ] Encrypted backups created successfully
- [ ] Backup file extension: .gpg
- [ ] Compression before encryption (gzip)

**MariaDB Encryption**:
```bash
mysqldump -u root -p --all-databases | \
  gzip | \
  gpg --encrypt --recipient backup@aglz.io | \
  dd of=/backups/mariadb-$(date +%Y%m%d).sql.gz.gpg
```

- [ ] mysqldump modified for encryption
- [ ] Encrypted backups created
- [ ] All databases included

**Redis Encryption**:
```bash
redis-cli --rdb /tmp/dump.rdb BGSAVE
gpg --encrypt --recipient backup@aglz.io \
  --output /backups/redis-$(date +%Y%m%d).rdb.gpg \
  /tmp/dump.rdb
```

- [ ] Redis RDB encryption
- [ ] BGSAVE triggered before backup
- [ ] Encrypted RDB created

**Docker Volume Encryption**:
```bash
tar czf - /path/to/volume | \
  gpg --encrypt --recipient backup@aglz.io | \
  dd of=/backups/volume-$(date +%Y%m%d).tar.gz.gpg
```

- [ ] Docker volumes archived and encrypted
- [ ] All critical volumes included
- [ ] Tar integrity verified

### 1.3 Encryption Verification

**Test Decryption**:
```bash
# Test each backup type
gpg --decrypt --output /tmp/test.sql.gz /backups/postgres-*.gpg
gpg --decrypt --output /tmp/test.rdb /backups/redis-*.gpg
gpg --decrypt --output /tmp/test.tar.gz /backups/volume-*.gpg
```

- [ ] PostgreSQL backup decrypts successfully
- [ ] MariaDB backup decrypts successfully
- [ ] Redis backup decrypts successfully
- [ ] Docker volume backup decrypts successfully
- [ ] No data corruption after decryption

**Integrity Checks**:
```bash
# Verify encrypted files
for file in /backups/*.gpg; do
  gpg --list-packets "$file" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ $file is valid"
  else
    echo "❌ $file is corrupted"
  fi
done
```

- [ ] All encrypted files pass validation
- [ ] No corrupted backups found
- [ ] Automated integrity check in place

### 1.4 Secrets Backup

**Vault Export** (if using Vault):
```bash
# Export Vault secrets
vault operator init -status > /tmp/vault-status.txt
vault kv list -format=json agl > /tmp/vault-inventory.json
```

- [ ] Vault unseal keys backed up
- [ ] Vault root token backed up
- [ ] Vault secrets inventory exported
- [ ] Backup encrypted with GPG

**Application Secrets**:
```bash
# Laravel .env backup
cp /mnt/overpower/apps/dev/agl/agl-hostman/.env /backups/env-$(date +%Y%m%d).txt
gpg --encrypt --recipient backup@aglz.io \
  --output /backups/env-$(date +%Y%m%d).txt.gpg \
  /backups/env-$(date +%Y%m%d).txt
rm /backups/env-$(date +%Y%m%d).txt
```

- [ ] .env files backed up
- [ ] API keys documented
- [ ] SSH keys backed up
- [ ] GPG keys backed up
- [ ] All secret backups encrypted

### 1.5 Off-site Replication Security

**Encrypted Sync**:
```bash
# Modify rsync for encrypted files
rsync -avz --delete \
  -e "ssh -i /backup/ssh_key" \
  --numeric-ids \
  /backups/*.gpg \
  backup-server:/backups/encrypted/
```

- [ ] Only encrypted files transferred
- [ ] SSH key authentication
- [ ] Transfer integrity verified
- [ ] Remote storage encrypted at rest

---

## Phase 2: Immutable & Air-Gapped Backups (Week 2)

### 2.1 ZFS Immutable Backups

**Snapshot with Hold**:
```bash
# Create immutable snapshot
zfs snapshot rpool/backups@$(date +%Y%m%d-%H%M%S)

# Hold snapshot (prevents deletion)
zfs hold rpool/backups@$(date +%Y%m%d-%H%M%S)

# Verify hold
zfs get hold rpool/backups@$(date +%Y%m%d-%H%M%S)
# Expected: TAG (local) = timestamp
```

- [ ] ZFS pool configured for backups
- [ ] Automated snapshot creation
- [ ] Snapshot hold applied
- [ ] Hold prevents deletion
- [ ] Multiple snapshots held (retention)

**Retention with Holds**:
```bash
# List held snapshots
zfs list -t snapshot | grep "@"

# Release old holds (monthly)
zfs release rpool/backups@2025-01-*
```

- [ ] Snapshot hold retention policy
- [ ] Automated hold release (after retention)
- [ ] Manual hold release procedure

### 2.2 Air-Gapped Backup Location

**Physical Isolation**:
- [ ] Air-gapped storage identified
- [ ] Storage disconnected from network
- [ ] Physical access controlled
- [ ] Transfer process documented

**Backup to Air-Gap**:
```bash
# Copy to removable media
cp /backups/*.gpg /mnt/usb-airgap/

# Verify copies
diff -r /backups/ /mnt/usb-airgap/ || echo "Differences found"

# Eject and store securely
umount /mnt/usb-airgap
```

- [ ] Air-gap media available (USB drive)
- [ ] Automated copy to air-gap
- [ ] Verification after copy
- [ ] Secure storage of air-gap media
- [ ] Monthly air-gap refresh

**3-2-1-1-0 Strategy**:
- [ ] 3 copies (primary, secondary, air-gap)
- [ ] 2 media types (disk, USB)
- [ ] 1 off-site (remote backup server)
- [ ] 1 immutable/air-gapped
- [ ] 0 recovery errors (verified restores)

### 2.3 Backup Verification

**Pre-Backup Verification**:
```bash
# Check database consistency before backup
pg_isready -U postgres
mysqladmin ping -u root -p
redis-cli ping
```

- [ ] PostgreSQL consistency check
- [ ] MySQL/MariaDB consistency check
- [ ] Redis consistency check
- [ ] Backup aborted if inconsistent

**Post-Backup Verification**:
```bash
# Verify encrypted backup
gpg --verify /backups/postgres-*.gpg

# Check file size (sanity)
ls -lh /backups/*.gpg | awk '{print $5}'

# Verify backup contains data
zstd -t /backups/postgres-*.sql.gz 2>/dev/null
```

- [ ] GPG verification passes
- [ ] File sizes reasonable
- [ ] Backup contains data
- [ ] No zero-byte backups

### 2.4 Backup Catalog

**Inventory System**:
```bash
# Generate backup catalog
cat > /var/log/backup-catalog-$(date +%Y%m%d).txt <<EOF
BACKUP CATALOG - $(date)

=== Encrypted Backups ===
$(ls -lh /backups/*.gpg | tail -20)

=== Off-site Status ===
$(ssh backup-server "ls -lh /backups/encrypted/" | tail -10)

=== Air-gap Status ===
$(ls -lh /mnt/usb-airgap/ 2>/dev/null || echo "Not mounted")

=== Vault Backup ===
$(ls -lh /secure/vault-backup/ 2>/dev/null || echo "Not found")

=== Storage Status ===
$(df -h /backups | grep -v File)
EOF
```

- [ ] Daily backup catalog generated
- [ ] Catalog includes all backup types
- [ ] Catalog stored with backups
- [ ] Search capability for catalog

---

## Phase 3: Restore Procedures & Testing (Week 3)

### 3.1 Restore Procedures

**PostgreSQL Restore**:
```bash
# Decrypt backup
gpg --decrypt --output /tmp/postgres.sql.gz /backups/postgres-*.gpg

# Restore database
pg_restore -U postgres -d postgres /tmp/postgres.sql.gz

# Or for plain SQL
gunzip -c /tmp/postgres.sql.gz | psql -U postgres
```

- [ ] PostgreSQL restore documented
- [ ] PostgreSQL restore tested
- [ ] Point-in-time recovery documented
- [ ] Restore verification steps

**MariaDB Restore**:
```bash
# Decrypt backup
gpg --decrypt --output /tmp/mariadb.sql.gz /backups/mariadb-*.gpg
gunzip /tmp/mariadb.sql.gz

# Restore database
mysql -u root -p < /tmp/mariadb.sql
```

- [ ] MariaDB restore documented
- [ ] MariaDB restore tested
- [ ] Binary log recovery documented
- [ ] Restore verification steps

**Redis Restore**:
```bash
# Decrypt backup
gpg --decrypt --output /tmp/dump.rdb /backups/redis-*.gpg

# Stop Redis, copy RDB, start
redis-cli SHUTDOWN
cp /tmp/dump.rdb /var/lib/redis/dump.rdb
redis-server /etc/redis/redis.conf
```

- [ ] Redis restore documented
- [ ] Redis restore tested
- [ ] AOF recovery documented (if using AOF)
- [ ] Restore verification steps

**Docker Volume Restore**:
```bash
# Decrypt backup
gpg --decrypt --output /tmp/volume.tar.gz /backups/volume-*.gpg
gunzip /tmp/volume.tar.gz

# Restore volume
docker volume create volume-restore
docker run --rm -v volume-restore:/data -v /tmp:/backup alpine \
  tar xzf /backup/volume.tar.gz -C /data
```

- [ ] Volume restore documented
- [ ] Volume restore tested
- [ ] Container restart procedure
- [ ] Data verification steps

**VM/CT Restore** (Proxmox):
```bash
# Find backup
BACKUP_FILE=$(ls -t /mnt/pve/bb/dump/vzdump-qemu-100-*.vma.zst | head -1)

# Restore to temporary VM
qmrestore "$BACKUP_FILE" 999 --storage local-zfs

# Start VM
qm start 999
```

- [ ] VM restore documented
- [ ] CT restore documented
- [ ] Network reconfiguration documented
- [ ] VM verification steps

### 3.2 Automated Restore Testing

**Quarterly Test Script**:
```bash
#!/bin/bash
# quarterly-restore-test.sh

RESTORE_SUCCESS=0
TOTAL_TESTS=3

echo "Starting quarterly restore validation..."

# Test 1: Small VM Restore
TEST_VM=102
BACKUP_FILE=$(ls -t /mnt/pve/bb/dump/vzdump-qemu-${TEST_VM}-*.vma.zst | head -1)
qmrestore "$BACKUP_FILE" 998 --storage local-zfs
qm start 998
sleep 120
if qm status 998 | grep -q "running"; then
    ((RESTORE_SUCCESS++))
    echo "✅ Small VM restore test passed"
fi
qm stop 998
qm destroy 998

# Test 2: Database Restore
# ... (similar structure)

# Test 3: Volume Restore
# ... (similar structure)

echo "Validation Results: $RESTORE_SUCCESS/$TOTAL_TESTS"
if [ $RESTORE_SUCCESS -eq $TOTAL_TESTS ]; then
    echo "✅ All validation tests passed"
else
    echo "❌ Some validation tests failed - investigate immediately"
fi
```

- [ ] Test script created
- [ ] Script scheduled quarterly
- [ ] Test results documented
- [ ] Failed tests trigger alert

**Test Coverage**:
- [ ] Small VM restore (< 50GB)
- [ ] Large VM restore (> 50GB)
- [ ] Container restore
- [ ] PostgreSQL restore
- [ ] MariaDB restore
- [ ] Redis restore
- [ ] Docker volume restore

### 3.3 RTO/RPO Validation

**RPO Measurement**:
```bash
# Calculate data loss window
BACKUP_TIME=$(stat /backups/postgres-*.gpg | grep Modify | cut -d: -f2 | cut -d. -f1)
CURRENT_TIME=$(date +%s)
RPO_SECONDS=$((CURRENT_TIME - BACKUP_TIME))
RPO_HOURS=$((RPO_SECONDS / 3600))

echo "RPO: $RPO_HOURS hours"
# Target: < 1 hour
```

- [ ] RPO calculated for each backup type
- [ ] RPO < 1 hour for critical systems
- [ ] RPO documented in SLA dashboard

**RTO Measurement**:
```bash
# Time restore operation
START_TIME=$(date +%s)

# Execute restore
qmrestore /backups/vm-*.vma.zst 999 --storage local-zfs
qm start 999
# Wait for boot
sleep 180
# Verify functionality
# ... (health checks)

END_TIME=$(date +%s)
RTO_SECONDS=$((END_TIME - START_TIME))
RTO_HOURS=$((RTO_SECONDS / 3600))

echo "RTO: $RTO_HOURS hours"
# Target: < 4 hours
```

- [ ] RTO calculated for each restore type
- [ ] RTO < 4 hours for critical systems
- [ ] RTO documented in SLA dashboard
- [ ] RTO improvement plan if not met

---

## Phase 4: Monitoring & Alerting (Week 3)

### 4.1 Backup Monitoring

**Prometheus Metrics**:
```yaml
# Backup job monitoring
- job_name: 'proxmox-backup'
  static_configs:
    - targets: ['192.168.0.1:8006']
  metrics_path: '/pve-exporter'
```

- [ ] Backup job status monitored
- [ ] Backup duration tracked
- [ ] Backup size tracked
- [ ] Backup success rate calculated
- [ ] Backup failure alerts

**Alert Rules**:
```yaml
# Backup alerts
- alert: BackupJobFailed
  expr: backup_job_success == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Backup job failed"

- alert: BackupStorageHigh
  expr: backup_storage_usage_percent > 90
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Backup storage above 90%"

- alert: BackupTooOld
  expr: time() - backup_last_success_timestamp > 86400
  for: 1h
  labels:
    severity: critical
  annotations:
    summary: "No successful backup in 24 hours"
```

- [ ] Backup failure alert configured
- [ ] Storage usage alert configured
- [ ] Backup age alert configured
- [ ] Off-site sync failure alert
- [ ] Encryption failure alert

### 4.2 Dashboard & Visualization

**Backup Status Dashboard**:
- [ ] Last backup time for each system
- [ ] Backup duration trend
- [ ] Backup size trend
- [ ] Success/failure rate
- [ ] Storage usage
- [ ] Off-site sync status
- [ ] Next scheduled backup

**Grafana Panels**:
```yaml
Panels:
  - Backup Job Status (stat)
  - Backup Success Rate (gauge)
  - Storage Usage (gauge)
  - Backup Duration (graph)
  - Last Backup Time (stat)
  - Restore Test Results (table)
```

- [ ] Dashboard created
- [ ] Dashboard accessible
- [ ] Real-time data
- [ ] Historical data available

### 4.3 Backup Health Checks

**Automated Health Checks**:
```bash
#!/bin/bash
# daily-backup-health.sh

# Check backup jobs
pvesh get /cluster/backup | grep "TASK OK" || {
  echo "❌ Backup job failed"
  exit 1
}

# Check storage
STORAGE_USAGE=$(df -h /backups | awk 'NR==2 {print $5}' | tr -d '%')
if [ $STORAGE_USAGE -gt 90 ]; then
  echo "⚠️ Storage usage: $STORAGE_USAGE"
fi

# Check off-site sync
OFFSITE_COUNT=$(ssh backup-server "ls /backups/encrypted/*.gpg | wc -l")
LOCAL_COUNT=$(ls /backups/*.gpg | wc -l)
if [ $OFFSITE_COUNT -lt $LOCAL_COUNT ]; then
  echo "⚠️ Off-site sync behind: $OFFSITE_COUNT vs $LOCAL_COUNT"
fi

# Check encrypted file integrity
CORRUPTED=0
for file in /backups/*.gpg; do
  gpg --list-packets "$file" >/dev/null 2>&1 || ((CORRUPTED++))
done
if [ $CORRUPTED -gt 0 ]; then
  echo "❌ Found $CORRUPTED corrupted backups"
fi
```

- [ ] Health check script created
- [ ] Script runs daily
- [ ] Results logged
- [ ] Failures trigger alerts

---

## Validation Test Cases

### Test Case 1: Encrypted Backup Creation

**Objective**: Verify encrypted backups are created successfully

**Steps**:
1. Trigger manual backup
2. Verify backup file created with .gpg extension
3. Verify file size is reasonable
4. Test decryption of backup
5. Verify data integrity after decryption

**Expected Results**:
- [ ] Backup file created
- [ ] File has .gpg extension
- [ ] File size > 0 bytes
- [ ] Decryption succeeds
- [ ] Data intact after decryption
- [ ] Backup logged

**Pass/Fail**: [ ]

### Test Case 2: Off-site Replication

**Objective**: Verify encrypted backups replicate to off-site

**Steps**:
1. Create new backup
2. Wait for replication (max 4 hours)
3. Check off-site storage for file
4. Verify off-site file integrity
5. Verify encryption at off-site

**Expected Results**:
- [ ] Backup appears at off-site within SLA
- [ ] File size matches local
- [ ] File remains encrypted
- [ ] Off-site storage is secure
- [ ] Replication logged

**Pass/Fail**: [ ]

### Test Case 3: VM Restore

**Objective**: Verify VM can be restored from encrypted backup

**Steps**:
1. Identify VM backup to restore
2. Decrypt backup file
3. Restore to temporary VM ID
4. Start restored VM
5. Verify VM boots and is accessible
6. Verify VM functionality
7. Cleanup temporary VM

**Expected Results**:
- [ ] Backup decrypts successfully
- [ ] Restore completes without errors
- [ ] VM boots successfully
- [ ] VM is accessible via network
- [ ] VM data intact
- [ ] No data loss
- [ ] RTO < 4 hours

**Pass/Fail**: [ ]

### Test Case 4: Database Restore

**Objective**: Verify database can be restored from encrypted backup

**Steps**:
1. Stop database service
2. Decrypt database backup
3. Restore database
4. Start database service
5. Verify data integrity
6. Verify application connectivity
7. Run test queries

**Expected Results**:
- [ ] Backup decrypts successfully
- [ ] Restore completes without errors
- [ ] Database starts successfully
- [ ] Data integrity verified
- [ ] Application connects
- [ ] Queries return expected results
- [ ] RTO < 4 hours

**Pass/Fail**: [ ]

### Test Case 5: Air-Gap Recovery

**Objective**: Verify air-gapped backups can be accessed and restored

**Steps**:
1. Retrieve air-gap media
2. Mount air-gap media
3. Copy backup from air-gap
4. Decrypt backup (if needed)
5. Perform restore
6. Verify data integrity

**Expected Results**:
- [ ] Air-gap media accessible
- [ ] Backup files readable
- [ ] Backup decrypts successfully
- [ ] Restore completes
- [ ] Data integrity verified
- [ ] Process documented

**Pass/Fail**: [ ]

### Test Case 6: Complete Disaster Recovery

**Objective**: Verify complete system recovery from backups

**Steps**:
1. Simulate complete data loss
2. Recover from off-site backup
3. Restore databases
4. Restore VMs/containers
5. Restore Docker volumes
6. Restore secrets (from Vault backup)
7. Verify all services operational
8. Document RTO

**Expected Results**:
- [ ] All components restored
- [ ] All services operational
- [ ] No data loss
- [ ] RTO measured and < 8 hours (extended SLA)
- [ ] Recovery procedure validated
- [ ] Lessons documented

**Pass/Fail**: [ ]

---

## Sign-off Criteria

### Minimum Viable Product (MVP)

For AGL-22 to be marked as MVP complete:

**Encryption**:
- [ ] All backups encrypted with GPG
- [ ] GPG keys backed up securely
- [ ] Encryption verified
- [ ] Off-site sync uses encrypted files

**Restoration**:
- [ ] Restore procedures documented
- [ ] Restore tested for each backup type
- [ ] RTO measured and < 4 hours
- [ ] RPO measured and < 1 hour

**Monitoring**:
- [ ] Backup success monitored
- [ ] Backup failure alerts configured
- [ ] Storage usage monitored
- [ ] Backup dashboard created

**Testing**:
- [ ] Automated restore test script
- [ ] Quarterly test scheduled
- [ ] Test results documented

### Full Implementation

For AGL-22 to be marked as fully complete:

**All MVP Criteria** plus:
- [ ] Immutable backups configured (ZFS holds)
- [ ] Air-gapped backup location operational
- [ ] 3-2-1-1-0 strategy implemented
- [ ] Secrets backup automated
- [ ] Comprehensive DR runbook
- [ ] Complete disaster recovery test
- [ ] 100% backup success rate maintained
- [ ] Backup security documented

---

## Issue Tracking

### Blockers & Dependencies

| Issue | Description | Impact | Resolution |
|-------|-------------|---------|------------|
| | | | |

### Notes & Observations

| Date | Note | Author |
|------|-------|--------|
| | | |

---

## Appendix

### Appendix A: Backup Retention Policy

```yaml
Retention Policy:
  Small VMs (101, 102, 111, 112, 117, 176):
    Daily: 7 days
    Weekly: 4 weeks
    Monthly: 6 months
    Yearly: 1 year

  Large VMs (all others):
    Keep-last: 2

  Databases:
    Daily: 7 days
    Weekly: 4 weeks
    Monthly: 3 months

  Application Data:
    Daily: 7 days
    Weekly: 4 weeks
    Monthly: 3 months

  Secrets:
    Vault: Every backup
    GPG keys: Offline + quarterly
    SSH keys: Quarterly
```

### Appendix B: Backup Locations

```bash
# Local storage
/backups/
├── postgres/
│   └── postgres-YYYYMMDD.sql.gz.gpg
├── mariadb/
│   └── mariadb-YYYYMMDD.sql.gz.gpg
├── redis/
│   └── redis-YYYYMMDD.rdb.gpg
├── volumes/
│   └── volume-YYYYMMDD.tar.gz.gpg
└── secrets/
    └── env-YYYYMMDD.txt.gpg

# Off-site storage
backup-server:/backups/encrypted/
└── (replicated from local)

# Air-gap storage
/mnt/usb-airgap/
└── (manual copy, verified monthly)
```

### Appendix C: Useful Commands

```bash
# List encrypted backups
ls -lh /backups/*.gpg

# Decrypt single backup
gpg --decrypt --output output.sql.gz backup.sql.gz.gpg

# Verify backup integrity
gpg --list-packets backup.sql.gz.gpg

# Check GPG key info
gpg --list-keys backup@aglz.io

# Export public key
gpg --export --armor backup@aglz.io > backup-pubkey.asc

# Export private key
gpg --export-secret-keys --armor backup@aglz.io > backup-privkey.asc

# Verify Proxmox backup jobs
pvesh get /cluster/backup

# Manually trigger backup
vzdump <vmid> --mode snapshot --compress zstd --storage spark

# Check ZFS snapshots
zfs list -t snapshot

# Check ZFS holds
zfs holds

# Create ZFS snapshot
zfs snapshot rpool/backups@$(date +%Y%m%d)

# Hold ZFS snapshot
zfs hold rpool/backups@$(date +%Y%m%d)

# Release ZFS snapshot hold
zfs release rpool/backups@$(date +%Y%m%d)

# Calculate backup age
find /backups -name "*.gpg" -mtime +7 -ls
```

---

**Checklist Completed By**: _________________
**Date**: ___________________
**Reviewed By**: _________________
**Sign-off Date**: ___________________
**Status**: [ ] MVP Complete [ ] Fully Complete

**END OF AGL-22 VALIDATION CHECKLIST**
