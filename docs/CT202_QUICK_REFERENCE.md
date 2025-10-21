# CT202 N8N Diagnostic Quick Reference Card

**Container**: CT202 (n8n workflow automation)
**Host**: AGLSRV1 Proxmox
**Generated**: 2025-10-14

---

## Emergency Response (Under 2 Minutes)

### The "Big 5" Critical Commands
```bash
# 1. Container & Service Status
pct status 202 && pct exec 202 -- systemctl status n8n --no-pager

# 2. Resource Check
pct exec 202 -- free -m && pct exec 202 -- df -h

# 3. Recent Errors
pct exec 202 -- journalctl -u n8n -n 50 --no-pager -p err

# 4. Process Overview
pct exec 202 -- top -b -n 1 | head -20

# 5. Network Connectivity
pct exec 202 -- ping -c 4 8.8.8.8 && pct exec 202 -- netstat -tlnp | grep 5678
```

---

## Automated Diagnostic Tools

### Full Diagnostic Report
```bash
/root/host-admin/scripts/ct202-diagnostic.sh
# Output: /root/host-admin/claudedocs/CT202_diagnostic_YYYYMMDD_HHMMSS.txt
```

### Support Bundle (For Escalation)
```bash
/root/host-admin/scripts/ct202-support-bundle.sh
# Output: /root/host-admin/claudedocs/ct202_support_YYYYMMDD_HHMMSS.tar.gz
```

### Baseline Monitoring
```bash
# Manual run
/root/host-admin/scripts/ct202-baseline-monitor.sh

# Setup automated monitoring (every 15 minutes)
(crontab -l 2>/dev/null; echo "*/15 * * * * /root/host-admin/scripts/ct202-baseline-monitor.sh") | crontab -
```

---

## Health Status Thresholds

### Resource Health Matrix
| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| CPU Usage | < 60% | 60-85% | > 85% |
| Memory | < 75% | 75-90% | > 90% |
| Disk Space | < 80% | 80-90% | > 90% |
| I/O Wait | < 10% | 10-30% | > 30% |
| Swap Used | 0% | < 20% | > 20% |

### Quick Health Check
```bash
# CPU
pct exec 202 -- uptime | awk -F'load average:' '{print $2}'

# Memory percentage
pct exec 202 -- free -m | grep Mem | awk '{printf "Memory: %.1f%%\n", ($3/$2)*100}'

# Disk percentage
pct exec 202 -- df -h / | tail -1 | awk '{print "Disk: " $5}'

# Service status
pct exec 202 -- systemctl is-active n8n
```

---

## Common Issues Fast Track

### Issue: Service Won't Start
```bash
# Check service errors
pct exec 202 -- journalctl -u n8n -n 100 --no-pager | grep -i error

# Check port conflicts
pct exec 202 -- netstat -tlnp | grep 5678

# Verify permissions
pct exec 202 -- ls -la /root/.n8n/

# Check dependencies
pct exec 202 -- systemctl cat n8n
```

### Issue: High CPU Usage
```bash
# Identify CPU hogs
pct exec 202 -- top -b -n 2 -d 5 | tail -20

# n8n workflow activity
pct exec 202 -- journalctl -u n8n -n 50 --no-pager | grep -i execution

# Check CPU allocation
pct config 202 | grep cores
```

### Issue: Memory Exhaustion
```bash
# Check OOM events
pct exec 202 -- dmesg | grep -i "out of memory"

# Memory breakdown
pct exec 202 -- ps aux --sort=-%mem | head -10

# Memory limits
pct config 202 | grep -E "memory|swap"
```

### Issue: Disk Full
```bash
# Space hogs
pct exec 202 -- du -sh /* 2>/dev/null | sort -h | tail -10

# Large files
pct exec 202 -- find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null

# Log sizes
pct exec 202 -- du -sh /var/log/* /root/.n8n/
```

### Issue: Network Problems
```bash
# Connectivity test
pct exec 202 -- ping -c 4 8.8.8.8
pct exec 202 -- nslookup google.com

# Check configuration
pct exec 202 -- ip addr show
pct exec 202 -- cat /etc/resolv.conf

# Active connections
pct exec 202 -- ss -tunap | grep ESTABLISHED | wc -l
```

---

## Log Analysis Shortcuts

### Find Errors (Last Hour)
```bash
pct exec 202 -- journalctl -u n8n --since "1 hour ago" -p err --no-pager
```

### Error Pattern Frequency
```bash
pct exec 202 -- journalctl -u n8n -n 1000 --no-pager | \
  grep -oE "(ERROR|WARN|FATAL)" | sort | uniq -c | sort -rn
```

### Connection Failures
```bash
pct exec 202 -- journalctl -u n8n --since "1 hour ago" --no-pager | \
  grep -i "refused\|timeout\|fail"
```

### Service Restart History
```bash
pct exec 202 -- journalctl -u n8n --since "7 days ago" --no-pager | \
  grep -E "Started|Stopped|Failed"
```

---

## Real-Time Monitoring

### Live Resource Monitor
```bash
watch -n 5 'pct status 202; echo ""; \
pct exec 202 -- systemctl is-active n8n; echo ""; \
pct exec 202 -- free -m | grep -E "Mem|Swap"; echo ""; \
pct exec 202 -- df -h / ; echo ""; \
pct exec 202 -- uptime'
```

### Live Log Tail
```bash
pct exec 202 -- journalctl -u n8n -f
```

### Live Process Monitor
```bash
pct exec 202 -- htop
```

---

## Escalation Contacts

### Level 1: Routine (1-2 hours)
- Performance degradation
- Minor errors
- **Action**: Run diagnostics, review logs

### Level 2: Service Down (2-6 hours)
- Service unavailable
- Critical errors
- **Action**: Root cause analysis, configuration review

### Level 3: Infrastructure (6-24 hours)
- Storage failure
- Host issues
- **Action**: Storage recovery, container migration

### Level 4: Emergency (24+ hours)
- Data loss
- Complete failure
- **Action**: Disaster recovery, all hands

---

## Key File Locations

### Configuration
- Container config: `/etc/pve/lxc/202.conf`
- Service definition: `/etc/systemd/system/n8n.service` (in container)
- n8n config: `/root/.n8n/` (in container)

### Logs
- Service logs: `journalctl -u n8n`
- System logs: `/var/log/syslog` (in container)
- Kernel logs: `dmesg` (in container)

### Data
- n8n workflows: `/root/.n8n/database.sqlite` (in container)
- n8n files: `/root/.n8n/` (in container)

### Diagnostics
- Diagnostic reports: `/root/host-admin/claudedocs/CT202_diagnostic_*.txt`
- Baseline data: `/root/host-admin/claudedocs/ct202_baseline_*.log`
- Support bundles: `/root/host-admin/claudedocs/ct202_support_*.tar.gz`

---

## Useful Command Aliases

Add to ~/.bashrc for quick access:

```bash
# CT202 Quick Commands
alias ct202-status='pct status 202 && pct exec 202 -- systemctl status n8n --no-pager'
alias ct202-logs='pct exec 202 -- journalctl -u n8n -f'
alias ct202-errors='pct exec 202 -- journalctl -u n8n -p err -n 50 --no-pager'
alias ct202-top='pct exec 202 -- top'
alias ct202-diag='/root/host-admin/scripts/ct202-diagnostic.sh'
alias ct202-enter='pct enter 202'
```

---

## Decision Tree Summary

```
Issue Reported
├─ Container Unresponsive?
│  ├─ YES → Check host resources → Review config
│  └─ NO → Check service status
│     ├─ Service Down → Review logs → Check dependencies
│     └─ Service Up → Performance issue?
│        ├─ High CPU → Workflow analysis
│        ├─ High Memory → OOM investigation
│        ├─ Disk Full → Space cleanup
│        └─ Network → Connectivity test
```

---

## Preventive Maintenance

### Daily (Automated)
- Service health check
- Disk space monitoring
- Error log review
- Backup verification

### Weekly (Manual)
- Performance baseline review
- Workflow efficiency analysis
- Log cleanup
- Configuration audit

### Monthly (Scheduled)
- Database maintenance
- Resource allocation review
- Security updates
- Capacity planning

---

## Documentation Reference

**Full Strategy**: `/root/host-admin/claudedocs/CT202_N8N_DIAGNOSTIC_STRATEGY.md`

**Generated**: 2025-10-14
**Version**: 1.0
**Maintained By**: Hive Mind Analyst Agent
