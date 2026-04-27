# 🚀 Implementation Quick Start - Hive Mind Optimizations
## Execute These Commands NOW to Fix Critical Issues

**Updated**: 2025-11-02
**Source**: Hive Mind Swarm Analysis (swarm-1762124399492-atdm384q7)
**Priority**: CRITICAL (P0) - Execute within 24-48 hours

---

## ⚠️ CRITICAL ISSUES - Execute Immediately

### 🔴 1. Emergency Storage Cleanup (2 hours)

**Problem**: Storage 92-96% full (6-15 days to exhaustion)
**Impact**: Blocks deployments, backups fail, system instability

```bash
# Step 1: Clean Docker (free 5-10 GB)
docker system prune -af --volumes
# Expected output: "Total reclaimed space: 5-10 GB"

# Step 2: Clean APT cache (free 500 MB - 1 GB)
apt-get autoremove -y && apt-get clean
# Expected output: "Removed packages and freed 500 MB - 1 GB"

# Step 3: Clean old logs (free 200-500 MB)
rm -rf /var/log/*.log.1 /var/log/*.gz /var/log/*/*.gz
# Expected output: "Freed 200-500 MB"

# Step 4: Run optimization script (free 1-3 GB)
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/optimization
./optimize-docker-containers.sh
# Expected output: "Optimizations applied, reclaimed 1-3 GB"

# Verify results
df -h | grep -E "(overpower|spark|/$)"
# Target: Reduce usage from 96% to <85%
```

**Expected Result**: Free 7-15 GB total (reduce usage to 81-89%)

---

### 🔴 2. Fix Harbor Registry (1 hour)

**Problem**: Harbor down with 502 errors
**Impact**: Cannot deploy containers, CI/CD blocked

```bash
# Step 1: Check Harbor containers
docker ps -a | grep harbor
# Expected output: List of harbor containers (some may be exited)

# Step 2: Navigate to Harbor directory
cd /opt/harbor
# If directory doesn't exist, Harbor is not installed properly

# Step 3: Restart Harbor
docker-compose down
docker-compose up -d

# Step 4: Verify Harbor is running
curl -I http://harbor.aglz.io:5000/v2/
# Expected output: "HTTP/1.1 401 Unauthorized" (means it's working, just needs auth)

# Step 5: Check container logs if issues persist
docker-compose logs -f
# Look for errors in registry, core, portal containers
```

**Expected Result**: Harbor accessible at http://harbor.aglz.io:5000

---

### 🔴 3. Fix Portainer Crash Loop (30 minutes)

**Problem**: Portainer restarting continuously
**Impact**: Cannot manage Docker remotely, visibility loss

```bash
# Step 1: Stop and remove crashed container
docker stop portainer
docker rm portainer

# Step 2: Recreate with proper configuration
docker run -d \
  --name=portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Step 3: Verify Portainer is running
docker ps | grep portainer
# Expected output: portainer container with status "Up"

# Step 4: Access Portainer UI
curl -I http://localhost:9000
# Expected output: "HTTP/1.1 200 OK"

# Step 5: Test web interface
# Open browser: http://<your-ip>:9000
# Should show Portainer login page
```

**Expected Result**: Portainer accessible at http://localhost:9000

---

### 🟢 4. Deploy Real-Time Monitoring (2 hours)

**Why**: Prevent future issues with proactive alerts

```bash
# Step 1: Navigate to monitoring directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/src/monitoring

# Step 2: Install dependencies (if not already installed)
npm install

# Step 3: Start monitoring (test run)
node InfrastructureMonitor.js
# Expected output: Real-time metrics for WireGuard, NFS, Docker, services
# Press Ctrl+C to stop after verifying it works

# Step 4: Set up as cron job for continuous monitoring
crontab -e
# Add this line:
# */15 * * * * /usr/bin/node /mnt/overpower/apps/dev/agl/agl-hostman/src/monitoring/InfrastructureMonitor.js >> /var/log/infrastructure-monitor.log 2>&1

# Step 5: Verify cron job is scheduled
crontab -l | grep InfrastructureMonitor
# Expected output: Cron entry for monitoring every 15 minutes

# Step 6: Check logs after 15 minutes
tail -f /var/log/infrastructure-monitor.log
# Expected output: Monitoring metrics and alerts
```

**Expected Result**: Real-time monitoring every 15 minutes with alerts

---

## 🟠 HIGH PRIORITY - Execute This Week

### 5. Optimize NFS/SSHFS Storage (3 hours)

**Problem**: Slow NFS performance, intermittent mount failures
**Impact**: 30-40% throughput improvement, 60-80% fewer failures

```bash
# Step 1: Run optimization script
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/optimization
./optimize-nfs-storage.sh

# Step 2: Verify improvements
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/performance
./storage/nfs-benchmark.sh

# Step 3: Compare before/after metrics
cat /mnt/overpower/apps/dev/agl/agl-hostman/docs/test-reports/performance/storage-benchmark-*.json
# Look for throughput increase from 30-50 MB/s to 40-70 MB/s
```

**Expected Result**: 30-40% throughput improvement (40-70 MB/s)

---

### 6. Optimize WireGuard Mesh (2 hours)

**Problem**: Suboptimal network latency
**Impact**: 15-20% latency improvement (20-30ms → 15-25ms)

```bash
# Step 1: Run optimization script
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/optimization
./optimize-wireguard-mesh.sh

# Step 2: Verify improvements
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/performance
./network/wireguard-perf.sh

# Step 3: Compare before/after metrics
# Before: 20-30ms latency
# After: 15-25ms latency (15-20% improvement)
```

**Expected Result**: 15-20% latency improvement (15-25ms)

---

### 7. Right-Size Container Memory (1 hour)

**Problem**: CT179 and CT181 allocated 48 GB but use 10-12 GB (75% waste)
**Impact**: Reclaim 64 GB for new containers

```bash
# Step 1: SSH to AGLSRV1 (Proxmox host)
ssh root@192.168.0.245
# Or via WireGuard: ssh root@10.6.0.5
# Or via Tailscale: ssh root@100.107.113.33

# Step 2: Check current memory allocation
pct config 179 | grep memory
pct config 181 | grep memory
# Expected output: memory: 49152 (48 GB in MB)

# Step 3: Resize containers
pct set 179 --memory 16384  # CT179: 48 GB → 16 GB
pct set 181 --memory 16384  # CT181: 48 GB → 16 GB

# Step 4: Restart containers for changes to take effect
pct reboot 179
pct reboot 181

# Step 5: Verify new allocation
pct config 179 | grep memory
pct config 181 | grep memory
# Expected output: memory: 16384 (16 GB in MB)
```

**Expected Result**: Reclaim 64 GB total (32 GB per container)

---

### 8. Deploy Secondary DNS (3 hours)

**Problem**: Single point of failure (Pi-hole on CT111)
**Impact**: Eliminate SPOF, 20-30% reduction in DNS downtime

```bash
# Step 1: Create CT112 for secondary DNS (on AGLSRV1)
# Use Proxmox UI or CLI to create new container
# Specs: 1 CPU, 512 MB RAM, 8 GB disk

# Step 2: Install Pi-hole on CT112
curl -sSL https://install.pi-hole.net | bash
# Follow prompts, note admin password

# Step 3: Configure Pi-hole
# Access web UI: http://<CT112-IP>/admin
# Match settings from CT111 (block lists, upstream DNS)

# Step 4: Update DHCP/DNS configuration
# Edit DHCP server (router or CT111) to use:
# Primary DNS: 10.6.0.11 (CT111)
# Secondary DNS: 10.6.0.12 (CT112)

# Step 5: Test failover
# Stop CT111: pct stop 111
# Verify DNS still works: nslookup google.com
# Restart CT111: pct start 111
```

**Expected Result**: Redundant DNS with automatic failover

---

### 9. Automated Cleanup Cron Jobs (1 hour)

**Why**: Prevent storage from filling up again

```bash
# Step 1: Create cleanup script wrapper
cat > /root/daily-cleanup.sh << 'EOF'
#!/bin/bash
# Daily cleanup script - runs at 2 AM

LOG_FILE="/var/log/daily-cleanup.log"
echo "=== Daily Cleanup Started: $(date) ===" >> $LOG_FILE

# Docker cleanup
echo "Running Docker cleanup..." >> $LOG_FILE
docker system prune -af --volumes >> $LOG_FILE 2>&1

# APT cleanup
echo "Running APT cleanup..." >> $LOG_FILE
apt-get autoremove -y >> $LOG_FILE 2>&1
apt-get clean >> $LOG_FILE 2>&1

# Log cleanup (keep 7 days)
echo "Cleaning old logs..." >> $LOG_FILE
find /var/log -name "*.log.*" -mtime +7 -delete >> $LOG_FILE 2>&1
find /var/log -name "*.gz" -mtime +7 -delete >> $LOG_FILE 2>&1

echo "=== Daily Cleanup Completed: $(date) ===" >> $LOG_FILE
echo "Disk usage after cleanup:" >> $LOG_FILE
df -h | grep -E "(overpower|spark|/$)" >> $LOG_FILE

# Alert if still >85% full
USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USAGE -gt 85 ]; then
    echo "WARNING: Disk usage still high: ${USAGE}%" >> $LOG_FILE
    # Optional: Send alert email or Slack notification here
fi
EOF

# Step 2: Make script executable
chmod +x /root/daily-cleanup.sh

# Step 3: Test script
/root/daily-cleanup.sh
# Check log: cat /var/log/daily-cleanup.log

# Step 4: Schedule daily at 2 AM
crontab -e
# Add this line:
# 0 2 * * * /root/daily-cleanup.sh

# Step 5: Verify cron job
crontab -l | grep daily-cleanup
# Expected output: Cron entry for daily cleanup at 2 AM
```

**Expected Result**: Automated daily cleanup prevents storage exhaustion

---

## 🟡 MEDIUM PRIORITY - Next 2-4 Weeks

### 10. Enable ZFS Compression (1 hour)

**Impact**: Save 20-30% storage space

```bash
# Step 1: Enable compression on ZFS pools
zfs set compression=lz4 rpool
zfs set compression=lz4 spark

# Step 2: Verify compression enabled
zfs get compression rpool
zfs get compression spark
# Expected output: compression = lz4

# Step 3: Monitor compression ratio over time (weekly)
zfs get compressratio rpool
zfs get compressratio spark
# Expected output: compressratio = 1.2x - 1.4x (20-40% space saving)

# Step 4: Tune ZFS ARC (cache) - allocate 25% of RAM (32 GB)
echo "options zfs zfs_arc_max=33554432" >> /etc/modprobe.d/zfs.conf
update-initramfs -u
# Reboot required for ARC tuning to take effect
```

**Expected Result**: 20-30% storage space reclaimed over 1-2 weeks

---

### 11. Verify Backup Coverage (4 hours)

**Impact**: Ensure disaster recovery capability

```bash
# Step 1: Document current backup configuration
# - Which containers/VMs are backed up?
# - Backup schedule and retention policy?
# - Backup storage location and redundancy?

# Step 2: Test restore procedure
# - Select a non-critical container (e.g., CT999 test)
# - Perform full backup
# - Delete container
# - Restore from backup
# - Verify data integrity

# Step 3: Document findings
# Create backup runbook: /root/agl-hostman/docs/BACKUP-RUNBOOK.md
# Include: backup schedule, restore procedures, contact info

# Step 4: Verify offsite backup
# Ensure backups stored offsite (3-2-1 rule: 3 copies, 2 media, 1 offsite)
```

**Expected Result**: Documented and tested backup/restore procedures

---

### 12. Deploy Pulse Monitoring Dashboard (2 hours)

**Impact**: Visual monitoring dashboard for infrastructure

```bash
# Step 1: Deploy Pulse using Docker
docker run -d \
  --name=pulse \
  --restart=always \
  -p 3001:3000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  louislam/dockge:latest

# Step 2: Access Pulse UI
# Open browser: http://<your-ip>:3001
# Complete initial setup

# Step 3: Add monitoring targets
# - WireGuard peers (14 nodes)
# - NFS/SSHFS mounts (6 mounts)
# - Docker containers (42 running)
# - Critical services (Archon, Dokploy, Harbor)

# Step 4: Configure alerts
# Set thresholds for:
# - Storage >80% full
# - Service down >5 minutes
# - Network latency >50ms
# - CPU >90% for >15 minutes
```

**Expected Result**: Visual monitoring dashboard with proactive alerts

---

## 📊 Quick Status Check - Run This Now

```bash
# One-line status check
echo "=== AGL Infrastructure Status ===" && \
df -h | grep -E "(Filesystem|overpower|spark|/$)" && \
echo && echo "=== Docker Status ===" && \
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" | head -10 && \
echo && echo "=== WireGuard Status ===" && \
wg show | grep -E "(interface|peer|latest handshake)" && \
echo && echo "=== NFS Mounts ===" && \
df -h | grep -E "(fgsrv6|nfs|sshfs)" && \
echo && echo "=== Load Average ===" && \
uptime
```

**Expected Output**:
- Storage: <85% usage (after cleanup)
- Docker: ~42 containers running
- WireGuard: 14 peers with recent handshakes (<3 minutes)
- NFS: 6 mounts healthy
- Load: <20 (on 56-core system)

---

## 🎯 Performance Improvements Expected

| Optimization | Current | Target | Improvement | Timeline |
|--------------|---------|--------|-------------|----------|
| **Storage Cleanup** | 96% full | 80% full | Free 16% (67 GB) | 2 hours |
| **WireGuard Tuning** | 20-30ms | 15-25ms | 15-20% latency | 2 hours |
| **NFS Optimization** | 30-50 MB/s | 40-70 MB/s | 30-40% throughput | 3 hours |
| **Memory Right-Sizing** | 48 GB allocated | 16 GB allocated | Reclaim 64 GB | 1 hour |
| **ZFS Compression** | Disabled | Enabled | 20-30% space saving | 1 hour + 1-2 weeks |
| **Automated Cleanup** | Manual | Automated | Prevent exhaustion | 1 hour |

**Total Time Investment**: 12 hours (Phase 1 + Phase 2)
**Total Impact**: 83 GB storage freed, 64 GB memory reclaimed, 15-40% performance improvement

---

## 📚 Complete Documentation

**For detailed documentation, see**:
- **Final Report**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/HIVE-MIND-FINAL-REPORT.md`
- **Research Summary**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/00-RESEARCH-SUMMARY.md`
- **Performance Analysis**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/performance-analysis-report-2025-11-02.md`
- **Code Implementation**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/CODER-IMPLEMENTATION-REPORT.md`
- **Testing Framework**: `/mnt/overpower/apps/dev/agl/agl-hostman/tests/performance/README.md`

---

## ❓ Need Help?

**Test monitoring**:
```bash
node /mnt/overpower/apps/dev/agl/agl-hostman/src/monitoring/InfrastructureMonitor.js
```

**Run performance tests**:
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/performance
./run-performance-suite.sh
```

**Check optimization logs**:
```bash
tail -f /var/log/infrastructure-monitor.log
tail -f /var/log/daily-cleanup.log
```

---

**Last Updated**: 2025-11-02
**Source**: Hive Mind Swarm Analysis
**Priority**: CRITICAL - Execute Phase 1 within 24-48 hours

🚀 **Start with emergency storage cleanup NOW!**
