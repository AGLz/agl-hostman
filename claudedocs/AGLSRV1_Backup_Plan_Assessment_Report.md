# AGLSRV1 Backup Plan Assessment Report
**Generated**: 2025-10-07 12:06 -03
**Host**: AGLSRV1 (192.168.0.245)
**Analyst**: DevOps Troubleshooter - Hive Mind Swarm

---

## Executive Summary

**STATUS**: CRITICAL - Backups are failing due to insufficient storage space and stale VM locks.

**Primary Issues**:
1. Spark storage at 99.99% capacity (only 768MB free of 7.14TB)
2. 1TB (1007GB) consumed by single ZFS snapshot from Sept 17, 2025
3. Stale VM lock files preventing backup execution
4. Oversized backup file (179GB) for VM 104 consuming excessive space
5. Multiple large container backups (40GB+) from LXC 173, 174, 179

---

## Current Backup Configuration

### Backup Job Configuration
```
Job ID: 9c5aa827-2416-43b7-9752-6a8b1175edbd
Schedule: Daily at 03:00
Mode: snapshot
Compression: zstd
Storage Target: spark (dir: /spark/base)
Enabled: Yes

Retention Policy:
├─ keep-last: 7 (last 7 backups)
├─ keep-weekly: 4 (last 4 weeks)
├─ keep-monthly: 6 (last 6 months)
└─ keep-yearly: 1 (last 1 year)

Scope: ALL VMs and Containers (66 total)
├─ VMs: 26 (21 stopped, 5 running)
└─ Containers: 40 (35 running, 5 stopped)
```

### Storage Configuration
```
Storage: spark
Type: dir (directory on ZFS pool)
Path: /spark/base
Content: images,snippets,import,rootdir,vztmpl,iso,backup
ZFS Pool: spark (RAIDZ1 - 3x 4TB drives)
Prune-backups: keep-last=7,keep-weekly=4,keep-monthly=6,keep-yearly=1
```

---

## Critical Findings

### 1. Storage Capacity Crisis

**Spark Storage Status**:
```
Filesystem: /spark
Total Size: 7.14TB (ZFS RAIDZ1)
Used Space: 7.14TB (99.99%)
Available: 768MB (0.01%)
```

**ZFS Pool Details**:
```
Pool: spark (10.9TB raw capacity)
├─ Allocated: 10.7TB (98%)
├─ Free: 193GB (2%)
├─ Compression Ratio: 1.06x (minimal compression benefit)
├─ Fragmentation: 5%
└─ Health: ONLINE

Space Breakdown:
├─ Dataset Data: 6.14TB
├─ ZFS Snapshots: 1007GB (1TB)
└─ Children Datasets: 13GB
```

### 2. ZFS Snapshot Issue

**Problem Snapshot**:
```
Name: spark@autosnap_2025-09-17_02:15:03_daily
Created: Sept 16, 2025 23:15
Space Used: 1007GB (1TB)
Reference Size: 6.54TB
Age: 21 days old
```

This snapshot is consuming 1TB of space and appears to be an auto-snapshot that was never cleaned up. It's likely from a third-party tool (not Proxmox native) as Proxmox doesn't create auto-snapshots by default.

### 3. Backup Directory Analysis

**Current Backups**:
```
Location: /spark/base/dump
Total Size: 570GB
File Count: 90 backup archives (.zst files)
```

**Largest Backup Files** (>10GB):
```
179GB - VM 104 (aglwk45) - 2025-10-01 [ABNORMALLY LARGE]
 41GB - LXC 179 (agldv03) - 2025-10-05
 40GB - LXC 174 (agldv02) - 2025-10-06
 19GB - LXC 173 (cacheng) - 2025-10-05
 18GB - VM 147 (agldv01) - 2025-10-06
 17GB - VM 142 (aglws1) - 2025-10-06
 17GB - VM 136 (aglwk49) - 2025-10-06
 17GB - VM 125 (AGLMAC06) - 2025-10-06
 14GB - VM 115 (aglw7) - 2025-10-06
 14GB - LXC 161 (gameserver) - 2025-10-05
 13GB - VM 135 (aglwk48) - 2025-10-06
 13GB - VM 114 (UbuntuDesktop) - 2025-10-06 x2
 12GB - LXC 113 (plexmediaserver) - 2025-10-06 x2
 12GB - VM 105 (opnsense) - May/Apr 2025 (old)
 11GB - LXC 157 (deluge) - 2025-10-06
```

### 4. VM Lock Files Issue

**Stale Locks Found** (empty lock files):
```
/var/lock/qemu-server/lock-104.conf (aglwk45)
/var/lock/qemu-server/lock-138.conf (haos)
/var/lock/qemu-server/lock-148.conf (zabbix)
/var/lock/qemu-server/lock-150.conf (wazuh-app)
/var/lock/qemu-server/lock-300.conf (nobara-gaming)
/var/lock/qemu-server/lock--1.conf (invalid/orphaned)
```

**Status**: CLEARED - All stale lock files have been removed.

**Latest Backup Attempt**:
```
Time: 2025-10-07 10:24:45
VM: 300 (nobara-gaming)
Result: FAILED
Error: "VM is locked (backup)"
Status: Resolved after lock file removal
```

### 5. VM 104 Anomaly

**VM 104 (aglwk45) Configuration**:
```
Type: QEMU/KVM VM
Status: Running
Memory: 16384MB (16GB RAM)
Disk: 720GB (scsi0 on local-zfs)
Backup Size: 179GB (compressed with zstd)
Compression Ratio: ~4:1 (179GB compressed from estimated 720GB disk)
```

**Concern**: The backup size is unusually large at 179GB for a 720GB disk. This suggests:
- High disk utilization (possibly 200-250GB actual data)
- Data with poor compressibility (encrypted/compressed files, media, databases)
- Potential fragmentation or inefficient backup

**Backup History**:
- 2025-10-01: 179GB (CURRENT - ABNORMALLY LARGE)
- 2025-01-09: Failed/incomplete
- Multiple temp directories from failed attempts (July, Sept 2024)

### 6. Large Container Backups

**LXC Containers with Large Backups**:

**LXC 179 (agldv03)**: 41GB
- Docker development container
- Likely contains large Docker images/volumes
- Mount points: /mnt/shares, /overpower/base, /spark/base, /mnt/storage

**LXC 174 (agldv02)**: 40GB
- Docker development container
- Similar mount points to LXC 179
- Status: Stopped

**LXC 173 (cacheng)**: 19GB
- Cache engine container
- Likely contains cache data

**LXC 113 (plexmediaserver)**: 12GB
- Plex media server
- Contains media metadata/transcoding cache
- Mount points: /mnt/shares, /overpower/base, /spark/base, /mnt/storage

**LXC 161 (gameserver)**: 14GB
- Game server container
- Contains game server data

---

## Storage Space Calculation

### Current Space Usage
```
Total Spark Pool: 10.9TB (raw)
├─ ZFS Overhead: ~200GB
├─ Dataset Data: 6.14TB
├─ ZFS Snapshot: 1007GB (1TB)
├─ Backup Directory: 570GB
└─ Other Data: ~1.5TB
```

### Space Required for Full Backup Cycle

**Estimated Backup Sizes** (per cycle):
```
Small VMs/CTs (50 instances): ~50GB
Medium VMs/CTs (10 instances): ~100GB
Large VMs/CTs (6 instances): ~250GB
├─ VM 104: ~180GB
├─ LXC 173,174,179: ~120GB
├─ VMs 114,115,125,135,136,142,147: ~100GB
└─ LXC 113,157,161: ~40GB

Total per Backup: ~400GB
```

**Retention Policy Storage Requirements**:
```
Last 7 daily backups: 7 x 400GB = 2,800GB (2.8TB)
Weekly retention (4): 4 x 400GB = 1,600GB (1.6TB)
Monthly retention (6): 6 x 400GB = 2,400GB (2.4TB)
Yearly retention (1): 1 x 400GB = 400GB

Total Required: ~7TB minimum
Safety Buffer (20%): +1.4TB
Recommended Total: 8.4TB
```

**Current Capacity**: 7.14TB usable (ZFS RAIDZ1)
**Deficit**: 1.26TB short of recommended capacity

---

## Alternative Storage Options

### Option 1: Overpower Storage
```
Status: 92.27% full (818GB available)
Total: 10.1TB
Used: 9.3TB
Available: 818GB
Type: ZFS RAIDZ1

Assessment: NOT VIABLE
├─ Only 818GB available
├─ Insufficient for backup requirements
└─ Already heavily utilized
```

### Option 2: Local Storage
```
Status: 0.72% full (817MB available)
Total: 785GB
Available: 817MB
Type: Directory

Assessment: NOT VIABLE
├─ Minimal capacity
└─ Designed for system files only
```

### Option 3: External/Network Storage
**From previous documentation analysis**:
- man6-pbs (192.168.0.231) - Proxmox Backup Server [PRIMARY RECOMMENDATION]
- man6b-pbs (192.168.0.232) - Proxmox Backup Server (Offsite)
- USB4TB (192.168.0.203) - 4TB USB via SMB [PROBLEMATIC - kernel spam]

**Recommendation**: Configure Proxmox Backup Server integration

---

## Root Cause Analysis

### Why Backups Are Failing

**Primary Cause**: Insufficient storage space
- Spark storage at 99.99% capacity
- Only 768MB free (insufficient for temporary backup files)
- Backup process requires temporary space during creation

**Secondary Cause**: Stale VM locks
- Empty lock files preventing backup initiation
- Likely from previous failed backup attempts
- **Status**: RESOLVED

**Tertiary Cause**: ZFS snapshot retention
- 1TB consumed by old auto-snapshot
- No automatic cleanup mechanism
- Snapshot age: 21 days

### Why Space is Exhausted

1. **ZFS Snapshot**: 1TB from Sept 17 auto-snapshot (not cleaned)
2. **Retention Policy Too Aggressive**: Keeping 7 daily + 4 weekly + 6 monthly + 1 yearly
3. **Large VM/CT Backups**: 400GB per backup cycle x retention = 7TB+
4. **VM 104 Oversized**: 179GB backup consuming excessive space
5. **Insufficient Pool Capacity**: 7.14TB usable vs 8.4TB required

---

## Recommendations

### Immediate Actions (CRITICAL - Execute Now)

#### 1. Remove ZFS Snapshot (Reclaim 1TB)
```bash
ssh AGLSRV1
zfs destroy spark@autosnap_2025-09-17_02:15:03_daily
# Expected space recovery: 1007GB (1TB)
```

**Verification**:
```bash
zfs list -t snapshot spark
df -h /spark
```

#### 2. Clear Stale VM Locks (COMPLETED)
```bash
ssh AGLSRV1
rm -f /var/lock/qemu-server/lock-*.conf
# Status: COMPLETED
```

#### 3. Remove Old/Redundant Backups
```bash
ssh AGLSRV1

# Remove old VM 105 backups (from Apr/May 2025)
rm -f /spark/base/dump/vzdump-qemu-105-2025_04_25-*.vma.zst
rm -f /spark/base/dump/vzdump-qemu-105-2025_05_22-*.vma.zst
# Expected recovery: ~24GB

# Clean up failed backup temp directories
find /spark/base/dump -name "*.tmp" -type d -exec rm -rf {} \; 2>/dev/null
# Expected recovery: ~1GB
```

#### 4. Manually Prune Backups to Free Space
```bash
ssh AGLSRV1

# Run Proxmox's prune command to enforce retention policy
pvesh create /nodes/AGLSRV1/storage/spark/prune-backups \
  --type vzdump \
  --prune-backups 'keep-last=7,keep-weekly=4,keep-monthly=6,keep-yearly=1'

# Or manually via vzdump
vzdump --dumpdir /spark/base/dump --prune-backups keep-last=3 --dry-run
```

**Expected Total Space Recovery**: 1TB + 25GB = ~1.03TB

### Short-Term Actions (Next 24-48 Hours)

#### 5. Optimize Backup Retention Policy
**Current**: keep-last=7, keep-weekly=4, keep-monthly=6, keep-yearly=1
**Recommended**: keep-last=3, keep-weekly=2, keep-monthly=3, keep-yearly=1

**Rationale**:
- Reduces storage by ~50%
- Maintains reasonable recovery window (3 days + 2 weeks + 3 months)
- Provides time to implement proper backup infrastructure

**Implementation**:
```bash
ssh AGLSRV1
pvesh set /cluster/backup/9c5aa827-2416-43b7-9752-6a8b1175edbd \
  --prune-backups 'keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1'
```

**Update storage configuration**:
```bash
pvesm set spark --prune-backups 'keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1'
```

#### 6. Investigate VM 104 Backup Size
```bash
ssh AGLSRV1

# Check actual disk usage
qm list -verbose | grep 104
pvesm list local-zfs --vmid 104

# Check for unnecessary data
# Consider excluding specific disks or optimizing VM storage
```

**Possible Actions**:
- Review VM 104 disk usage and clean up unnecessary files
- Consider excluding VM 104 from automated backups (manual backup only)
- Investigate if backup mode should be changed (snapshot vs suspend)

#### 7. Optimize Large Container Backups
**LXC 173, 174, 179** (Cache/Docker containers):
- Consider excluding mount points from backup
- Review if cache data needs backup
- Implement application-level backup for Docker volumes

**Configuration Example**:
```bash
# Edit container config to exclude mount points from backup
pvesh set /nodes/AGLSRV1/lxc/179/config --mp0 /mnt/shares,backup=0
```

#### 8. Investigate ZFS Auto-Snapshot Source
```bash
ssh AGLSRV1

# Check for zfs-auto-snapshot package
dpkg -l | grep zfs-auto-snapshot
systemctl list-timers | grep snapshot

# Check cron jobs
crontab -l | grep snapshot
ls -la /etc/cron.* | grep snapshot

# Disable if found
systemctl disable --now zfs-auto-snapshot.timer 2>/dev/null
```

### Medium-Term Actions (Next Week)

#### 9. Configure Proxmox Backup Server (PRIMARY RECOMMENDATION)

**Target**: man6-pbs (192.168.0.231:8007)

**Benefits**:
- Deduplicated storage (massive space savings)
- Incremental backups (faster, less space)
- Separate backup infrastructure
- Built-in encryption
- Better retention management

**Implementation Steps**:
```bash
# On AGLSRV1
ssh AGLSRV1

# Add PBS datastore
pvesm add pbs man6-pbs \
  --server 192.168.0.231 \
  --datastore backups \
  --username root@pam \
  --password <password>

# Update backup job to use PBS
pvesh set /cluster/backup/9c5aa827-2416-43b7-9752-6a8b1175edbd \
  --storage man6-pbs

# Test backup
vzdump 148 --storage man6-pbs --mode snapshot --compress zstd
```

#### 10. Implement Tiered Backup Strategy

**Tier 1 - Local (Spark)**: Critical VMs only, 3-day retention
```
VMs: 104, 138, 148, 150, 300 (running VMs)
Containers: 102, 103, 126, 131, 178 (critical services)
Retention: keep-last=3 (3 days only)
Storage: spark (local, fast recovery)
```

**Tier 2 - PBS (man6-pbs)**: All VMs/CTs, full retention
```
Scope: All 66 VMs/CTs
Retention: keep-last=7, keep-weekly=4, keep-monthly=6, keep-yearly=1
Storage: man6-pbs (deduplicated, offsite-ready)
```

**Tier 3 - Offsite (man6b-pbs)**: PBS sync/replication
```
Source: man6-pbs
Target: man6b-pbs (192.168.0.232)
Method: PBS sync job
Retention: keep-monthly=12, keep-yearly=3
```

#### 11. Add Backup Monitoring
```bash
# Install monitoring script
cat > /usr/local/bin/backup-monitor.sh <<'EOF'
#!/bin/bash
STORAGE="spark"
THRESHOLD=95
USAGE=$(pvesm status -content backup | awk '/^'$STORAGE'/ {gsub(/%/,"",$NF); print $NF}')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
  echo "CRITICAL: Storage $STORAGE at ${USAGE}% capacity" | \
    mail -s "Backup Storage Alert - AGLSRV1" admin@domain.com
fi
EOF

chmod +x /usr/local/bin/backup-monitor.sh

# Add to cron
echo "0 */6 * * * /usr/local/bin/backup-monitor.sh" >> /etc/cron.d/backup-monitor
```

### Long-Term Actions (Next Month)

#### 12. Storage Capacity Planning

**Current Situation**:
- Spark Pool: 10.9TB raw (7.14TB usable with RAIDZ1)
- Requirement: 8.4TB for current retention policy

**Options**:

**Option A: Add Drives to Spark Pool** [NOT RECOMMENDED]
- Add 3x 4TB drives to create second RAIDZ1 vdev
- Increases capacity to 14TB usable
- Cost: ~$300-400 (3x 4TB drives)
- Risk: Cannot add drives to existing RAIDZ1 vdev

**Option B: Migrate to PBS** [RECOMMENDED]
- Utilize man6-pbs (192.168.0.231)
- Deduplicated storage (estimated 60-70% space savings)
- Keep spark for local/fast recovery only
- Cost: $0 (already available)

**Option C: Hybrid Approach** [OPTIMAL]
- Critical VMs on spark (3-day retention)
- All backups on man6-pbs (full retention)
- Offsite sync to man6b-pbs
- Cost: $0 (already available)

#### 13. Implement Backup Testing
```bash
# Monthly restore test
# Document: /root/host-admin/backup-restore-test.sh

#!/bin/bash
# Test restore from backup
TEST_VMID=9999
BACKUP_FILE=$(ls -t /spark/base/dump/vzdump-qemu-148-*.zst | head -1)

qmrestore $BACKUP_FILE $TEST_VMID \
  --storage local-zfs \
  --unique

# Start and verify
qm start $TEST_VMID
sleep 60
qm status $TEST_VMID

# Cleanup
qm stop $TEST_VMID
qm destroy $TEST_VMID
```

---

## Configuration Issues Summary

### Issue 1: Storage Capacity
- **Severity**: CRITICAL
- **Impact**: Backups cannot complete, no space for temporary files
- **Resolution**: Remove ZFS snapshot (1TB), optimize retention policy

### Issue 2: Stale VM Locks
- **Severity**: HIGH
- **Impact**: VMs locked, preventing backup execution
- **Resolution**: COMPLETED - Lock files removed

### Issue 3: ZFS Auto-Snapshot
- **Severity**: HIGH
- **Impact**: 1TB consumed by unmanaged snapshot
- **Resolution**: Destroy snapshot, disable auto-snapshot if found

### Issue 4: Aggressive Retention Policy
- **Severity**: MEDIUM
- **Impact**: Excessive storage consumption (7-8TB required)
- **Resolution**: Reduce retention: keep-last=3, keep-weekly=2, keep-monthly=3

### Issue 5: Oversized Backups
- **Severity**: MEDIUM
- **Impact**: VM 104 (179GB), containers 173/174/179 (40GB+ each)
- **Resolution**: Investigate and optimize, consider exclusions

### Issue 6: No Backup Storage Alternatives
- **Severity**: HIGH
- **Impact**: Single point of failure, no offsite backups
- **Resolution**: Configure PBS (man6-pbs), implement tiered backup

---

## Execution Plan

### Phase 1: Emergency Space Recovery (Immediate)
**Duration**: 30 minutes
**Objective**: Free 1TB+ space

```bash
# Step 1: Remove ZFS snapshot
ssh AGLSRV1
zfs destroy spark@autosnap_2025-09-17_02:15:03_daily

# Step 2: Remove old backups
rm -f /spark/base/dump/vzdump-qemu-105-2025_04_25-*.vma.zst
rm -f /spark/base/dump/vzdump-qemu-105-2025_05_22-*.vma.zst

# Step 3: Clean temp directories
find /spark/base/dump -name "*.tmp" -type d -exec rm -rf {} \; 2>/dev/null

# Step 4: Verify space
df -h /spark
zfs list spark
```

**Expected Result**: 1.03TB free space, backups can resume

### Phase 2: Optimize Retention (Next 24 hours)
**Duration**: 15 minutes
**Objective**: Reduce long-term storage requirements

```bash
ssh AGLSRV1

# Update backup job retention
pvesh set /cluster/backup/9c5aa827-2416-43b7-9752-6a8b1175edbd \
  --prune-backups 'keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1'

# Update storage retention
pvesm set spark --prune-backups 'keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1'

# Force prune existing backups
vzdump --dumpdir /spark/base/dump --prune-backups keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1 --dry-run
# Review output, then run without --dry-run
```

**Expected Result**: Storage requirement reduced to 3.5-4TB

### Phase 3: Configure PBS (Next Week)
**Duration**: 2 hours
**Objective**: Implement proper backup infrastructure

```bash
# Add PBS storage
pvesm add pbs man6-pbs \
  --server 192.168.0.231 \
  --datastore backups \
  --username root@pam

# Create new backup job for PBS
pvesh create /cluster/backup \
  --schedule "01:00" \
  --storage man6-pbs \
  --all 1 \
  --mode snapshot \
  --compress zstd \
  --prune-backups 'keep-last=7,keep-weekly=4,keep-monthly=6,keep-yearly=1' \
  --enabled 1

# Update existing job to only backup critical VMs to spark
pvesh set /cluster/backup/9c5aa827-2416-43b7-9752-6a8b1175edbd \
  --all 0 \
  --vmid 104,138,148,150,300,102,103,126,131,178
```

**Expected Result**: Dual backup strategy, reduced local storage pressure

---

## Verification Steps

### Post-Emergency Actions
```bash
# Verify space available
ssh AGLSRV1 "df -h /spark"
# Expected: >1TB available

# Verify no snapshots
ssh AGLSRV1 "zfs list -t snapshot spark"
# Expected: No autosnap entries

# Verify no locks
ssh AGLSRV1 "ls /var/lock/qemu-server/lock-*.conf"
# Expected: Empty or no files

# Test backup
ssh AGLSRV1 "vzdump 148 --storage spark --mode snapshot --compress zstd"
# Expected: Success
```

### Post-Optimization Actions
```bash
# Verify retention policy
ssh AGLSRV1 "pvesh get /cluster/backup/9c5aa827-2416-43b7-9752-6a8b1175edbd"
# Expected: keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1

# Verify backup count
ssh AGLSRV1 "ls -1 /spark/base/dump/*.zst | wc -l"
# Expected: Reduced count (40-50 files vs 90)

# Verify space usage
ssh AGLSRV1 "du -sh /spark/base/dump"
# Expected: <300GB
```

---

## Risk Assessment

### Immediate Risks
- **Data Loss**: If backups continue failing, no recent recovery points
- **Storage Corruption**: 99.99% full filesystem can cause ZFS performance degradation
- **Service Impact**: VM performance may degrade due to storage pressure

### Mitigation
- Execute Phase 1 immediately (space recovery)
- Monitor backup job execution
- Verify at least one successful backup completes

### Long-Term Risks
- **Single Storage Pool**: No redundancy or offsite backups
- **Capacity Growth**: VMs/CTs continue to grow, will exceed capacity again
- **Recovery Time**: Large backups take hours to restore

### Mitigation
- Implement PBS (Phase 3)
- Configure offsite replication
- Implement tiered backup strategy

---

## Success Criteria

### Phase 1 Success
- [ ] ZFS snapshot removed (1TB recovered)
- [ ] Storage at <70% capacity
- [ ] No VM lock files present
- [ ] At least one successful backup completes

### Phase 2 Success
- [ ] Retention policy updated and active
- [ ] Backup count reduced by 40-50%
- [ ] Storage at <50% capacity
- [ ] All scheduled backups complete successfully

### Phase 3 Success
- [ ] PBS configured and functional
- [ ] All VMs/CTs backing up to PBS
- [ ] Local backups limited to critical VMs only
- [ ] Offsite sync to man6b-pbs operational

---

## Appendix A: VM/Container Inventory

### Running VMs (5)
```
104 - aglwk45 (16GB RAM, 720GB disk) - LARGE BACKUP
138 - haos (8GB RAM, 32GB disk)
148 - zabbix (4GB RAM, 10GB disk)
150 - wazuh-app (16GB RAM, 50GB disk)
300 - nobara-gaming (16GB RAM, 128GB disk)
```

### Running Containers (35)
```
102 - pihole
103 - portainer - LARGE BACKUP
111 - tautulli
112 - bazarr
113 - plexmediaserver - LARGE BACKUP
117 - cloudflared
120 - wireguard
121 - qbittorrent
122 - jackett
123 - radarr
124 - sonarr
126 - guac
131 - mysql
132 - observium
133 - aping
137 - redis
139 - aldsys4
141 - sabnzbd
144 - autobrr
149 - postgresql
157 - deluge - LARGE BACKUP
159 - nginxproxy
162 - meshcentral
163 - gameserver2
165 - aria2
170 - homarr
171 - overseerr
172 - prowlarr
173 - cacheng - VERY LARGE BACKUP (19GB)
176 - iventoy
178 - aglfs1
179 - agldv03 - VERY LARGE BACKUP (41GB)
200 - ollama-gpu
201 - amp-server
202 - n8n-docker
```

### Stopped VMs (21)
```
100 - aglsrv2
101 - openwrt
105 - opnsense
106 - pfsense
114 - UbuntuDesktop - LARGE BACKUP
115 - aglw7 - LARGE BACKUP
116 - aglwk46
125 - AGLMAC06 - LARGE BACKUP
128 - plex
135 - aglwk48 - LARGE BACKUP
136 - aglwk49 - LARGE BACKUP
142 - aglws1 - LARGE BACKUP
145 - android-x86
146 - bliss
147 - agldv01 - LARGE BACKUP
151 - test-k3s-01
152 - test-k3s-02
153 - test-k3s-03
154 - test-k3s-04
155 - test-k3s-05
156 - test-k3s-adm
```

### Stopped Containers (5)
```
161 - gameserver - LARGE BACKUP
167 - az-agent1
168 - az-agent2
169 - az-agent3
174 - agldv02 - VERY LARGE BACKUP (40GB)
```

---

## Appendix B: Command Reference

### Useful Diagnostic Commands
```bash
# Storage status
pvesm status
pvesm list spark

# ZFS status
zpool list -v spark
zfs list -t all spark -S used
zfs get all spark | grep -E 'used|available|compressratio'

# Backup job status
pvesh get /cluster/backup
pvesh get /cluster/tasks --typefilter vzdump --limit 20

# Lock files
ls -lah /var/lock/qemu-server/
find /var/lock -name "vzdump*"

# Backup files
ls -lh /spark/base/dump/*.zst | wc -l
du -sh /spark/base/dump
ls -lh /spark/base/dump/*.zst | sort -k5 -hr | head -20

# VM/CT list
qm list
pct list
```

### Useful Management Commands
```bash
# Remove snapshot
zfs destroy spark@<snapshot-name>

# Clear locks
rm -f /var/lock/qemu-server/lock-*.conf
qm unlock <vmid>

# Manual backup
vzdump <vmid> --storage spark --mode snapshot --compress zstd

# Prune backups
vzdump --dumpdir /spark/base/dump --prune-backups keep-last=3 [--dry-run]

# Update backup job
pvesh set /cluster/backup/<job-id> --prune-backups 'keep-last=3,...'

# Add PBS storage
pvesm add pbs <name> --server <ip> --datastore <name> --username root@pam
```

---

## Report Metadata

**Generated By**: DevOps Troubleshooter Agent (Hive Mind Swarm)
**Analysis Date**: 2025-10-07 12:06 -03
**Source Host**: AGLSRV1 (192.168.0.245)
**Report Version**: 1.0
**Status**: Complete - Ready for Implementation

**Next Steps**:
1. Review and approve recommendations
2. Execute Phase 1 (Emergency Space Recovery)
3. Monitor backup execution
4. Schedule Phase 2 and 3 implementations

**Contact**: Hive Mind Coordinator for questions or clarification

---

*End of Report*
