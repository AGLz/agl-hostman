# CT202 (n8n) Container Diagnostic Strategy
**AGLSRV1 Proxmox Host Analysis Framework**

**Generated**: 2025-10-14
**Target**: CT202 (n8n workflow automation container)
**Objective**: Systematic root cause analysis and health assessment

---

## Executive Summary

This diagnostic strategy provides a structured approach to analyzing CT202 container issues on the AGLSRV1 Proxmox host. The framework emphasizes evidence-based investigation, baseline health metrics, and systematic troubleshooting to identify root causes efficiently.

**Key Focus Areas**:
- Container resource utilization (CPU, RAM, disk I/O)
- n8n application health and performance
- Storage subsystem integrity
- Network connectivity and throughput
- Proxmox LXC infrastructure

---

## 1. Systematic Diagnostic Checklist

### Phase 1: Initial Assessment (5 minutes)
```bash
# Checkpoint 1: Container Existence & State
pct list | grep 202
pct status 202

# Checkpoint 2: Basic Resource Overview
pct config 202
pct df 202

# Checkpoint 3: Quick Health Indicators
pct exec 202 -- systemctl status n8n 2>/dev/null || echo "Service check failed"
pct exec 202 -- ps aux | grep n8n
pct exec 202 -- uptime
```

**Success Criteria**:
- Container exists and responds to commands
- n8n service is running
- Uptime > 0 (container hasn't crashed recently)

**Escalation Point**: If container doesn't respond → Skip to Phase 5 (Infrastructure Analysis)

---

### Phase 2: Resource Utilization Analysis (10 minutes)

#### CPU Metrics
```bash
# Real-time CPU usage (30-second sample)
pct exec 202 -- top -b -n 3 -d 10 | grep -E "Cpu|n8n"

# Historical CPU patterns
pct exec 202 -- sar -u 5 12 2>/dev/null || echo "sysstat not installed"

# Process-level CPU consumption
pct exec 202 -- ps aux --sort=-%cpu | head -20
```

**Baseline Health Indicators**:
- Normal: CPU usage < 60% average, < 90% peak
- Warning: CPU usage 60-85% sustained
- Critical: CPU usage > 85% sustained OR 100% for >5 minutes

#### Memory Metrics
```bash
# Current memory state
pct exec 202 -- free -m
pct exec 202 -- cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree"

# Memory allocation to n8n process
pct exec 202 -- ps aux --sort=-%mem | head -10
pct exec 202 -- pmap -x $(pct exec 202 -- pgrep -f n8n) 2>/dev/null | tail -1

# OOM killer activity check
pct exec 202 -- dmesg | grep -i "out of memory\|killed process"
pct exec 202 -- grep -i "out of memory" /var/log/syslog 2>/dev/null
```

**Baseline Health Indicators**:
- Normal: Memory usage < 75%, no swap usage
- Warning: Memory usage 75-90% OR swap usage < 20%
- Critical: Memory usage > 90% OR swap usage > 20% OR OOM events detected

#### Disk I/O Metrics
```bash
# I/O statistics (requires sysstat)
pct exec 202 -- iostat -x 5 6 2>/dev/null || echo "iostat unavailable"

# Disk usage and inodes
pct exec 202 -- df -h
pct exec 202 -- df -i

# Top I/O consuming processes
pct exec 202 -- iotop -b -n 3 -d 5 2>/dev/null || echo "iotop unavailable"

# Check for I/O wait
pct exec 202 -- vmstat 5 6
```

**Baseline Health Indicators**:
- Normal: Disk usage < 80%, inode usage < 80%, I/O wait < 10%
- Warning: Disk 80-90% OR inode 80-90% OR I/O wait 10-30%
- Critical: Disk > 90% OR inode > 90% OR I/O wait > 30%

#### Network Metrics
```bash
# Network interface statistics
pct exec 202 -- ip -s link show
pct exec 202 -- netstat -i

# Active connections
pct exec 202 -- ss -s
pct exec 202 -- netstat -tunap | grep -E "ESTABLISHED|LISTEN" | wc -l

# Network throughput (requires iftop or similar)
pct exec 202 -- iftop -t -s 10 2>/dev/null || echo "iftop unavailable"

# DNS resolution check
pct exec 202 -- nslookup google.com
pct exec 202 -- ping -c 4 8.8.8.8
```

**Baseline Health Indicators**:
- Normal: No packet loss, latency < 50ms, no errors/drops
- Warning: Packet loss 1-5% OR latency 50-200ms
- Critical: Packet loss > 5% OR latency > 200ms OR connection failures

---

### Phase 3: Application-Specific Analysis (15 minutes)

#### n8n Service Health
```bash
# Service status and logs
pct exec 202 -- systemctl status n8n --no-pager -l
pct exec 202 -- journalctl -u n8n -n 100 --no-pager

# n8n process tree
pct exec 202 -- pstree -p $(pct exec 202 -- pgrep -f n8n)

# Port binding verification
pct exec 202 -- netstat -tlnp | grep 5678
pct exec 202 -- lsof -i :5678 2>/dev/null || netstat -tlnp | grep 5678
```

#### n8n Application Logs
```bash
# Primary log locations (adjust paths as needed)
pct exec 202 -- tail -100 /root/.n8n/n8n.log 2>/dev/null
pct exec 202 -- tail -100 /var/log/n8n/n8n.log 2>/dev/null
pct exec 202 -- journalctl -u n8n -n 200 --no-pager

# Error pattern analysis
pct exec 202 -- grep -i "error\|fatal\|exception\|fail" /root/.n8n/n8n.log 2>/dev/null | tail -50
pct exec 202 -- journalctl -u n8n -p err -n 50 --no-pager

# Database connectivity (if using SQLite)
pct exec 202 -- ls -lh /root/.n8n/database.sqlite 2>/dev/null
pct exec 202 -- sqlite3 /root/.n8n/database.sqlite "PRAGMA integrity_check;" 2>/dev/null

# Database connectivity (if using PostgreSQL/MySQL)
pct exec 202 -- netstat -tan | grep -E "5432|3306"
```

**Critical Log Patterns to Monitor**:
- `ERROR`: Application errors requiring investigation
- `FATAL`: Critical failures causing service disruption
- `ECONNREFUSED`: Database/service connection failures
- `ENOMEM`: Memory allocation failures
- `ENOSPC`: Disk space exhaustion
- `Timeout`: Network or resource timeout issues
- `Queue full`: Workflow execution backlog

#### n8n Configuration Review
```bash
# Environment configuration
pct exec 202 -- cat /etc/systemd/system/n8n.service 2>/dev/null
pct exec 202 -- env | grep N8N

# n8n version and installation
pct exec 202 -- n8n --version 2>/dev/null || npm list -g n8n 2>/dev/null

# Workflow execution status
pct exec 202 -- curl -s http://localhost:5678/healthz 2>/dev/null || echo "Health endpoint unavailable"
```

**Baseline Health Indicators**:
- Normal: Service active, no recent errors, health endpoint returns 200
- Warning: Service active but recent errors, slow response times
- Critical: Service inactive OR persistent errors OR health endpoint fails

---

### Phase 4: Storage Subsystem Analysis (10 minutes)

#### Container Storage Assessment
```bash
# Storage allocation on Proxmox host
pvesm status
lvs | grep -E "vm-202|ct-202"
zfs list | grep -E "vm-202|ct-202" 2>/dev/null

# Container disk usage breakdown
pct exec 202 -- du -sh /* 2>/dev/null | sort -h
pct exec 202 -- du -sh /root/.n8n 2>/dev/null
pct exec 202 -- du -sh /var/log 2>/dev/null

# Large file identification
pct exec 202 -- find / -type f -size +100M 2>/dev/null | head -20
```

#### ZFS Pool Health (if applicable)
```bash
# Pool status
zpool status
zpool list
zfs list -t all

# I/O statistics
zpool iostat -v 5 6

# Error detection
zpool status | grep -i error
zfs get all | grep -i error
```

**Baseline Health Indicators**:
- Normal: No pool errors, < 80% capacity, no degraded disks
- Warning: Pool 80-90% full OR non-critical errors
- Critical: Pool > 90% full OR degraded/faulted disks OR critical errors

---

### Phase 5: Infrastructure & Proxmox Analysis (10 minutes)

#### Proxmox Host Resource State
```bash
# Overall host resources
free -m
df -h
uptime
top -b -n 1 | head -20

# All container resource usage
pct list
for ct in $(pct list | tail -n +2 | awk '{print $1}'); do
  echo "=== CT $ct ==="
  pct status $ct
  pct df $ct
done
```

#### Container Configuration Audit
```bash
# CT202 configuration
cat /etc/pve/lxc/202.conf

# Resource limits verification
pct config 202 | grep -E "cores|memory|rootfs|swap"

# Mount points and binds
pct mount 202 2>/dev/null || echo "Manual mount required"
mount | grep 202
```

#### Network Infrastructure
```bash
# Bridge and network configuration
brctl show
ip addr show
cat /etc/network/interfaces | grep -A 10 vmbr

# Container network config
pct exec 202 -- cat /etc/network/interfaces
pct exec 202 -- ip addr show
pct exec 202 -- ip route show
```

**Baseline Health Indicators**:
- Normal: Config matches requirements, network functional, no resource starvation
- Warning: Near resource limits OR network latency
- Critical: Misconfigured resources OR network failure OR resource exhaustion

---

## 2. Critical Commands Quick Reference

### Emergency Diagnostics (Under 2 minutes)
```bash
# The "Big 5" - Run these first
pct status 202
pct exec 202 -- systemctl status n8n --no-pager
pct exec 202 -- free -m && df -h
pct exec 202 -- top -b -n 1 | head -20
pct exec 202 -- journalctl -u n8n -n 50 --no-pager -p err
```

### Performance Snapshot
```bash
# Single comprehensive output
pct exec 202 -- bash -c "
echo '=== SYSTEM INFO ==='
uname -a
uptime
echo -e '\n=== CPU ==='
top -b -n 1 | head -15
echo -e '\n=== MEMORY ==='
free -m
echo -e '\n=== DISK ==='
df -h
echo -e '\n=== NETWORK ==='
ss -s
echo -e '\n=== N8N SERVICE ==='
systemctl status n8n --no-pager -l
echo -e '\n=== RECENT ERRORS ==='
journalctl -u n8n -n 20 -p err --no-pager
"
```

### Log Analysis
```bash
# Error timeline (last 24 hours)
pct exec 202 -- journalctl -u n8n --since "24 hours ago" -p err --no-pager

# Pattern frequency analysis
pct exec 202 -- journalctl -u n8n -n 1000 --no-pager | \
  grep -oE "(ERROR|WARN|FATAL|Exception)" | sort | uniq -c | sort -rn

# Connection failure tracking
pct exec 202 -- journalctl -u n8n --since "1 hour ago" --no-pager | \
  grep -i "refused\|timeout\|fail" | tail -20
```

---

## 3. Health Check Criteria & Scoring

### Component Health Matrix

| Component | Metric | Healthy | Degraded | Critical |
|-----------|--------|---------|----------|----------|
| **CPU** | Usage % | < 60% | 60-85% | > 85% |
| **CPU** | Load Avg | < cores | cores × 1.5 | > cores × 2 |
| **Memory** | Usage % | < 75% | 75-90% | > 90% |
| **Memory** | Swap Used | 0% | < 20% | > 20% |
| **Disk** | Usage % | < 80% | 80-90% | > 90% |
| **Disk** | Inode % | < 80% | 80-90% | > 90% |
| **Disk** | I/O Wait | < 10% | 10-30% | > 30% |
| **Network** | Packet Loss | 0% | 1-5% | > 5% |
| **Network** | Latency | < 50ms | 50-200ms | > 200ms |
| **n8n Service** | Status | Active | Active w/ errors | Inactive |
| **n8n Logs** | Error Rate | < 5/hour | 5-20/hour | > 20/hour |
| **Storage** | Pool Health | Online | Warnings | Degraded/Faulted |

### Overall Health Score Calculation
```
Health Score = (Healthy Components / Total Components) × 100

90-100%: Excellent - No action required
70-89%:  Good - Monitor degraded components
50-69%:  Fair - Investigation required
< 50%:   Poor - Immediate action required
```

---

## 4. Troubleshooting Decision Tree

```
CT202 Issue Reported
│
├─ Container Unresponsive?
│  ├─ YES → Check Proxmox host resources
│  │        ├─ Host overloaded? → Investigate competing containers/VMs
│  │        └─ Host healthy? → Check container config (memory/CPU limits)
│  │
│  └─ NO → Container responds
│     │
│     ├─ n8n Service Running?
│     │  ├─ NO → Check service logs (journalctl -u n8n)
│     │  │       ├─ Service crashed? → Memory/disk issue investigation
│     │  │       └─ Service won't start? → Configuration/dependency issue
│     │  │
│     │  └─ YES → Performance Issue?
│     │     │
│     │     ├─ Slow Response
│     │     │  ├─ High CPU? → Workflow analysis, resource limits
│     │     │  ├─ High Memory? → Memory leak investigation, workflow optimization
│     │     │  └─ High I/O? → Database optimization, disk performance
│     │     │
│     │     ├─ Connection Errors
│     │     │  ├─ Database? → DB connectivity, credentials, network
│     │     │  ├─ External APIs? → DNS, firewall, proxy settings
│     │     │  └─ Browser access? → Network config, port forwarding
│     │     │
│     │     └─ Workflow Failures
│     │        ├─ Specific workflow? → Workflow configuration review
│     │        ├─ All workflows? → System resource exhaustion
│     │        └─ Intermittent? → Network/resource contention
│     │
│     └─ Disk Issues?
│        ├─ Full Disk → Space cleanup, log rotation, database maintenance
│        ├─ I/O Errors → Storage subsystem health (ZFS/LVM)
│        └─ Performance → IOPS limits, storage backend optimization
```

---

## 5. Diagnostic Procedures by Symptom

### Symptom: Container Won't Start
```bash
# Step 1: Verify container configuration
cat /etc/pve/lxc/202.conf

# Step 2: Check for config errors
pct start 202 -v

# Step 3: Review Proxmox logs
tail -100 /var/log/pve/tasks/active

# Step 4: Verify storage availability
pvesm status
lvs -a | grep 202
zfs list | grep 202

# Step 5: Check resource conflicts
pct list
ps aux | grep "lxc.*202"
```

**Escalation**: Storage backend failure, configuration corruption, resource exhaustion

---

### Symptom: High CPU Usage
```bash
# Step 1: Identify CPU-consuming processes
pct exec 202 -- top -b -n 3 -d 5

# Step 2: Analyze n8n workflow execution
pct exec 202 -- journalctl -u n8n -n 100 --no-pager | grep -i "execution"

# Step 3: Check for runaway processes
pct exec 202 -- ps aux --sort=-%cpu | head -20
pct exec 202 -- pstree -p

# Step 4: Review CPU allocation
pct config 202 | grep cores
nproc

# Step 5: Analyze workflow complexity
# (Requires n8n API access or database query)
pct exec 202 -- curl -s http://localhost:5678/api/v1/workflows 2>/dev/null
```

**Escalation**: Infinite loops in workflows, insufficient CPU allocation, host CPU contention

---

### Symptom: Memory Exhaustion / OOM
```bash
# Step 1: Current memory state
pct exec 202 -- free -m
pct exec 202 -- cat /proc/meminfo

# Step 2: Check OOM killer activity
pct exec 202 -- dmesg | grep -i "out of memory"
pct exec 202 -- journalctl -k | grep -i "oom"

# Step 3: Memory allocation analysis
pct exec 202 -- ps aux --sort=-%mem | head -20
pct exec 202 -- pmap -x $(pgrep -f n8n)

# Step 4: Review memory limits
pct config 202 | grep -E "memory|swap"

# Step 5: Analyze memory growth pattern
# Run multiple times over 5-minute intervals
for i in {1..5}; do
  echo "=== Sample $i ==="
  pct exec 202 -- free -m | grep Mem
  sleep 60
done
```

**Escalation**: Memory leak in n8n, insufficient memory allocation, workflow data volume issues

---

### Symptom: Disk Space Exhausted
```bash
# Step 1: Disk usage overview
pct exec 202 -- df -h
pct exec 202 -- df -i

# Step 2: Identify large directories
pct exec 202 -- du -sh /* 2>/dev/null | sort -h | tail -10
pct exec 202 -- du -sh /root/.n8n/* 2>/dev/null | sort -h

# Step 3: Find large files
pct exec 202 -- find / -type f -size +50M -exec ls -lh {} \; 2>/dev/null | head -20

# Step 4: Check log files
pct exec 202 -- du -sh /var/log/*
pct exec 202 -- ls -lh /var/log/*.log

# Step 5: Database size
pct exec 202 -- ls -lh /root/.n8n/database.sqlite 2>/dev/null
pct exec 202 -- du -sh /root/.n8n/
```

**Escalation**: Rapid log growth, database bloat, workflow data accumulation, storage backend full

---

### Symptom: Network Connectivity Issues
```bash
# Step 1: Basic connectivity
pct exec 202 -- ping -c 4 8.8.8.8
pct exec 202 -- nslookup google.com
pct exec 202 -- curl -I https://www.google.com

# Step 2: Container network config
pct exec 202 -- ip addr show
pct exec 202 -- ip route show
pct exec 202 -- cat /etc/resolv.conf

# Step 3: Port accessibility
pct exec 202 -- netstat -tlnp | grep 5678
pct exec 202 -- ss -tlnp | grep 5678

# Step 4: Firewall rules
iptables -L -n -v | grep 202
pct exec 202 -- iptables -L -n -v

# Step 5: Host network config
ip addr show
brctl show
cat /etc/network/interfaces
```

**Escalation**: Network misconfiguration, firewall blocking, DNS failure, routing issues

---

## 6. Automated Diagnostic Script

Create `/root/host-admin/scripts/ct202-diagnostic.sh`:

```bash
#!/bin/bash
# CT202 (n8n) Comprehensive Diagnostic Script
# Usage: ./ct202-diagnostic.sh [--output /path/to/report.txt]

CTID=202
OUTPUT_FILE="${1:-/root/host-admin/claudedocs/CT202_diagnostic_$(date +%Y%m%d_%H%M%S).txt}"

exec > >(tee -a "$OUTPUT_FILE") 2>&1

echo "============================================"
echo "CT202 N8N DIAGNOSTIC REPORT"
echo "Generated: $(date)"
echo "============================================"
echo ""

# Function: Section header
section() {
    echo ""
    echo "============================================"
    echo "$1"
    echo "============================================"
}

# Function: Command with timeout
run_cmd() {
    local desc="$1"
    local cmd="$2"
    echo "### $desc"
    timeout 30 bash -c "$cmd" 2>&1 || echo "Command timed out or failed"
    echo ""
}

# Phase 1: Container Status
section "PHASE 1: CONTAINER STATUS"
run_cmd "Container List" "pct list | grep -E 'VMID|$CTID'"
run_cmd "Container Status" "pct status $CTID"
run_cmd "Container Config" "pct config $CTID"
run_cmd "Container Disk Usage" "pct df $CTID"

# Phase 2: Resource Utilization
section "PHASE 2: RESOURCE UTILIZATION"
run_cmd "CPU Usage" "pct exec $CTID -- top -b -n 2 -d 5 | tail -20"
run_cmd "Memory Status" "pct exec $CTID -- free -m"
run_cmd "Memory Details" "pct exec $CTID -- cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|Cached|Swap'"
run_cmd "Disk Usage" "pct exec $CTID -- df -h"
run_cmd "Inode Usage" "pct exec $CTID -- df -i"
run_cmd "Top Processes by CPU" "pct exec $CTID -- ps aux --sort=-%cpu | head -15"
run_cmd "Top Processes by Memory" "pct exec $CTID -- ps aux --sort=-%mem | head -15"

# Phase 3: n8n Application
section "PHASE 3: N8N APPLICATION"
run_cmd "n8n Service Status" "pct exec $CTID -- systemctl status n8n --no-pager -l"
run_cmd "n8n Process Tree" "pct exec $CTID -- pstree -p \$(pgrep -f n8n)"
run_cmd "n8n Port Binding" "pct exec $CTID -- netstat -tlnp | grep 5678"
run_cmd "n8n Version" "pct exec $CTID -- n8n --version 2>/dev/null || npm list -g n8n 2>/dev/null || echo 'Version check failed'"
run_cmd "n8n Recent Logs (50 lines)" "pct exec $CTID -- journalctl -u n8n -n 50 --no-pager"
run_cmd "n8n Recent Errors" "pct exec $CTID -- journalctl -u n8n -p err -n 30 --no-pager"

# Phase 4: Storage
section "PHASE 4: STORAGE ANALYSIS"
run_cmd "Large Directories" "pct exec $CTID -- du -sh /* 2>/dev/null | sort -h | tail -10"
run_cmd "n8n Data Directory" "pct exec $CTID -- du -sh /root/.n8n/* 2>/dev/null | sort -h"
run_cmd "Large Files (>100M)" "pct exec $CTID -- find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10"
run_cmd "Log Directory Size" "pct exec $CTID -- du -sh /var/log/* 2>/dev/null"

# Phase 5: Network
section "PHASE 5: NETWORK DIAGNOSTICS"
run_cmd "Network Interfaces" "pct exec $CTID -- ip addr show"
run_cmd "Network Routes" "pct exec $CTID -- ip route show"
run_cmd "DNS Configuration" "pct exec $CTID -- cat /etc/resolv.conf"
run_cmd "Internet Connectivity" "pct exec $CTID -- ping -c 4 8.8.8.8"
run_cmd "DNS Resolution" "pct exec $CTID -- nslookup google.com"
run_cmd "Active Connections" "pct exec $CTID -- ss -s"

# Phase 6: System Errors
section "PHASE 6: SYSTEM ERROR ANALYSIS"
run_cmd "OOM Events" "pct exec $CTID -- dmesg | grep -i 'out of memory' | tail -10"
run_cmd "System Errors (dmesg)" "pct exec $CTID -- dmesg | grep -i 'error' | tail -20"
run_cmd "Kernel Messages" "pct exec $CTID -- journalctl -k -n 30 --no-pager"

# Phase 7: Proxmox Host Context
section "PHASE 7: PROXMOX HOST CONTEXT"
run_cmd "Host Resource Summary" "free -m && echo '' && df -h | head -10"
run_cmd "Container LXC Config" "cat /etc/pve/lxc/$CTID.conf"
run_cmd "Storage Backend" "pvesm status"
run_cmd "All Containers Overview" "pct list"

# Summary
section "DIAGNOSTIC SUMMARY"
echo "Report completed: $(date)"
echo "Output saved to: $OUTPUT_FILE"
echo ""
echo "Next Steps:"
echo "1. Review resource utilization (Phase 2)"
echo "2. Check n8n service errors (Phase 3)"
echo "3. Analyze storage capacity (Phase 4)"
echo "4. Verify network connectivity (Phase 5)"
echo ""
echo "For detailed analysis, run:"
echo "  cat $OUTPUT_FILE | less"
```

**Usage**:
```bash
chmod +x /root/host-admin/scripts/ct202-diagnostic.sh
./ct202-diagnostic.sh
# Output: /root/host-admin/claudedocs/CT202_diagnostic_YYYYMMDD_HHMMSS.txt
```

---

## 7. Monitoring & Baseline Establishment

### Establishing Baseline Metrics (First 7 days)
```bash
# Create monitoring script
cat > /root/host-admin/scripts/ct202-baseline-monitor.sh << 'EOF'
#!/bin/bash
LOGFILE="/root/host-admin/claudedocs/ct202_baseline_$(date +%Y%m%d).log"
echo "$(date '+%Y-%m-%d %H:%M:%S'),\
$(pct exec 202 -- uptime | awk -F'load average:' '{print $2}' | xargs),\
$(pct exec 202 -- free -m | grep Mem | awk '{print $3,$2}' | awk '{printf "%.0f", ($1/$2)*100}'),\
$(pct exec 202 -- df -h / | tail -1 | awk '{print $5}' | tr -d '%'),\
$(pct exec 202 -- systemctl is-active n8n)" >> "$LOGFILE"
EOF

chmod +x /root/host-admin/scripts/ct202-baseline-monitor.sh

# Add to crontab (every 15 minutes)
(crontab -l 2>/dev/null; echo "*/15 * * * * /root/host-admin/scripts/ct202-baseline-monitor.sh") | crontab -
```

**Baseline Data Format**: `timestamp,load_avg,mem_usage_%,disk_usage_%,service_status`

### Real-Time Monitoring Dashboard
```bash
watch -n 5 'echo "=== CT202 LIVE MONITOR ==="; \
pct status 202; \
echo ""; \
pct exec 202 -- systemctl is-active n8n; \
echo ""; \
pct exec 202 -- free -m | grep -E "Mem|Swap"; \
echo ""; \
pct exec 202 -- df -h / ; \
echo ""; \
pct exec 202 -- uptime'
```

---

## 8. Escalation Matrix

### Level 1: Routine Investigation (Analyst)
**Triggers**: Performance degradation, minor errors
**Actions**: Run diagnostic script, review logs, check baselines
**Resolution Time**: 1-2 hours

### Level 2: Service Disruption (Senior Admin)
**Triggers**: Service down, critical errors, resource exhaustion
**Actions**: Root cause analysis, configuration review, resource adjustment
**Resolution Time**: 2-6 hours

### Level 3: Infrastructure Failure (System Architect)
**Triggers**: Storage failure, host issues, data corruption
**Actions**: Storage recovery, container migration, backup restoration
**Resolution Time**: 6-24 hours

### Level 4: Emergency Response (All Hands)
**Triggers**: Data loss, security breach, complete system failure
**Actions**: Disaster recovery, incident response, forensic analysis
**Resolution Time**: 24+ hours

---

## 9. Preventive Maintenance Schedule

### Daily Automated Checks
- Service health verification
- Disk space monitoring (alert at 85%)
- Error log review
- Backup verification

### Weekly Manual Review
- Performance baseline comparison
- Workflow efficiency analysis
- Log rotation and cleanup
- Configuration audit

### Monthly Optimization
- Database maintenance (vacuum, optimize)
- Resource allocation review
- Security update application
- Capacity planning assessment

---

## 10. Data Collection for Support/Escalation

If escalation is required, collect this data package:

```bash
# Create support bundle
BUNDLE_DIR="/root/host-admin/claudedocs/ct202_support_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BUNDLE_DIR"

# Run full diagnostic
/root/host-admin/scripts/ct202-diagnostic.sh "$BUNDLE_DIR/diagnostic_report.txt"

# Collect configuration
pct config 202 > "$BUNDLE_DIR/container_config.txt"
cat /etc/pve/lxc/202.conf > "$BUNDLE_DIR/lxc_config.conf"

# Collect recent logs
pct exec 202 -- journalctl -u n8n -n 500 --no-pager > "$BUNDLE_DIR/n8n_service.log"
pct exec 202 -- dmesg > "$BUNDLE_DIR/dmesg.log"

# Archive and compress
tar -czf "$BUNDLE_DIR.tar.gz" -C "$(dirname $BUNDLE_DIR)" "$(basename $BUNDLE_DIR)"
echo "Support bundle created: $BUNDLE_DIR.tar.gz"
```

---

## Appendix A: Common Issues & Solutions

### Issue: n8n service won't start
**Symptoms**: Service inactive, startup errors
**Investigation**:
```bash
journalctl -u n8n -n 100 --no-pager
systemctl cat n8n
ls -la /root/.n8n/
```
**Common Causes**:
- Corrupted database
- Permission issues
- Port already in use
- Missing dependencies

### Issue: Workflows timing out
**Symptoms**: Execution failures, timeout errors
**Investigation**:
```bash
grep -i timeout /root/.n8n/n8n.log
ps aux | grep n8n
netstat -an | grep ESTABLISHED | wc -l
```
**Common Causes**:
- Resource constraints
- Network latency
- External API rate limits
- Database query performance

### Issue: High memory consumption
**Symptoms**: OOM events, swap usage, slow performance
**Investigation**:
```bash
pmap -x $(pgrep -f n8n)
ls -lh /root/.n8n/database.sqlite
free -m && cat /proc/meminfo
```
**Common Causes**:
- Memory leak in workflows
- Large dataset processing
- Insufficient memory allocation
- Database cache bloat

---

## Appendix B: Useful Commands Reference

### Container Management
```bash
pct list                          # List all containers
pct status 202                    # Check container status
pct start/stop/restart 202        # Control container
pct enter 202                     # Interactive shell
pct exec 202 -- <command>         # Execute command
pct console 202                   # Console access
```

### Log Analysis
```bash
journalctl -u n8n -f              # Follow service logs
journalctl -u n8n --since "1 hour ago"
journalctl -u n8n -p err          # Errors only
journalctl -k                     # Kernel messages
dmesg -T                          # Kernel ring buffer
```

### Performance Monitoring
```bash
htop                              # Interactive process viewer
iotop                             # I/O monitoring
iftop                             # Network bandwidth
vmstat 5                          # System statistics
iostat -x 5                       # I/O statistics
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-14
**Maintained By**: Hive Mind Analyst Agent
**Review Schedule**: Monthly or after major incidents
