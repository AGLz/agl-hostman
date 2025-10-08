# ZFS Data Corruption Prevention - Operational Runbook

## Emergency Response Guide

### 🚨 Critical Issues - Immediate Action Required

#### Pool Degraded/Faulted
**Symptoms:** Pool status shows DEGRADED or FAULTED
**Immediate Actions:**
1. Check pool status: `zpool status -v`
2. Identify failed device(s)
3. If spare available: `zpool replace <pool> <failed_disk> <spare_disk>`
4. If no spare: Immediately acquire replacement disk
5. Monitor rebuild: `zpool status -v` (every 15 minutes)
6. Notify team via configured alerts

**Critical Commands:**
```bash
# Check detailed pool status
zpool status -v

# Replace failed disk
zpool replace tank /dev/sda /dev/sdb

# Check resilver progress
watch -n 60 'zpool status -v'

# Force import if pool disappeared
zpool import -f tank
```

#### Data Corruption Detected
**Symptoms:** Checksum errors in zpool status
**Immediate Actions:**
1. Document error details: `zpool status -v > /tmp/corruption-$(date +%Y%m%d_%H%M%S).txt`
2. Initiate immediate scrub: `zpool scrub <pool>`
3. Check recent backups are intact
4. Monitor scrub progress: `watch zpool status`
5. Prepare for possible data restoration

#### Pool Unavailable
**Symptoms:** Cannot access pool, import fails
**Immediate Actions:**
1. Check if pool can be imported: `zpool import`
2. Try force import: `zpool import -f <pool>`
3. Check system messages: `dmesg | tail -50`
4. Verify disk connectivity: `lsblk`
5. If recovery impossible, restore from backup

### ⚠️ Warning Conditions - Plan and Act

#### High Capacity Usage (>80%)
**Actions:**
1. Identify largest consumers: `zfs list -o space`
2. Clean old snapshots: Check retention policies
3. Review backup cleanup
4. Plan capacity expansion

#### ARC Hit Ratio Low (<85%)
**Actions:**
1. Check ARC stats: `cat /proc/spl/kstat/zfs/arcstats`
2. Review memory allocation
3. Consider L2ARC if available
4. Tune prefetch settings

#### SMART Errors
**Actions:**
1. Check SMART details: `smartctl -a /dev/sdX`
2. Plan disk replacement
3. Monitor disk closely
4. Update spare disk inventory

## Regular Maintenance Procedures

### Daily Tasks (Automated)
- Health monitoring runs continuously
- Daily snapshots created at 01:00
- Alert system monitors for issues
- Log rotation and cleanup

### Weekly Tasks
```bash
# Run weekly scrub (automated Sunday 02:00)
/opt/zfs-protection/scripts/zfs-scrub-manager.sh auto

# Review capacity trends
zfs list -o space | head -20

# Check backup completion
tail -100 /var/log/zfs-protection/backup.log
```

### Monthly Tasks
```bash
# Full system health check
/opt/zfs-protection/scripts/zfs-health-monitor.sh --check

# Review and update configurations
vi /etc/zfs-protection/*.conf

# Test recovery procedures (on test system)
# Update disaster recovery documentation
```

### Quarterly Tasks
```bash
# Full backup restoration test
# Review capacity planning
# Update spare hardware inventory
# Review and update contact information
# Performance baseline review
```

## Monitoring and Alerting

### Alert Severity Levels

#### CRITICAL - Immediate Response Required
- Pool degraded/faulted
- Pool unavailable
- Data corruption detected
- Backup failures
- System unavailable

#### WARNING - Response Within Business Hours
- High capacity usage (>80%)
- SMART warnings
- Performance degradation
- Scrub errors found
- Network connectivity issues

#### INFO - For Awareness
- Successful backup completion
- Scrub completion
- Routine maintenance notifications

### Alert Response Procedures

1. **Acknowledge Alert**: Confirm receipt within 15 minutes
2. **Assess Severity**: Review system status and error details
3. **Document Actions**: Log all investigation and remediation steps
4. **Escalate if Needed**: Follow escalation matrix for critical issues
5. **Update Status**: Communicate status to stakeholders
6. **Post-Incident**: Complete post-mortem for critical issues

## Backup and Recovery Procedures

### 3-2-1 Backup Strategy Implementation

#### 3 Copies of Data
1. **Production Data**: Live ZFS pools
2. **Local Backup**: ZFS send/receive to backup pool
3. **Off-site Backup**: Replication to remote location

#### 2 Different Media Types
1. **Primary Storage**: RAID-Z pools with redundancy
2. **Backup Storage**: Different pool/location with different hardware

#### 1 Off-site Copy
- Remote replication via ZFS send/receive
- Cloud storage integration (optional)
- Physical media rotation (optional)

### Recovery Procedures

#### Full Pool Recovery
```bash
# 1. Replace failed hardware
# 2. Import backup pool
zpool import backup

# 3. Restore from latest backup
zfs send backup/tank/data@latest | zfs receive tank/data

# 4. Verify data integrity
zpool scrub tank
```

#### Single Dataset Recovery
```bash
# 1. Find latest good snapshot
zfs list -t snapshot | grep dataset_name

# 2. Rollback to snapshot
zfs rollback tank/data@snapshot_name

# 3. Or restore from backup
zfs send backup/tank/data@snapshot | zfs receive tank/data_restored
```

#### Emergency Boot Recovery
```bash
# 1. Boot from rescue media
# 2. Import pools
zpool import -f -R /mnt tank

# 3. Mount root filesystem
mount -t zfs tank/ROOT/pve-1 /mnt

# 4. Chroot and repair
chroot /mnt
```

## Performance Optimization

### Monitoring Performance
```bash
# Pool I/O statistics
zpool iostat -v 1

# ARC statistics
cat /proc/spl/kstat/zfs/arcstats

# System load and memory
top, htop, iotop

# Disk performance
iostat -x 1
```

### Common Performance Issues

#### High I/O Wait
- Check for failing disks
- Review scrub/resilver impact
- Optimize recordsize for workload
- Consider L2ARC for read-heavy workloads

#### Memory Pressure
- Tune ARC size limits
- Monitor VM memory usage
- Consider increasing system RAM

#### Network Bottlenecks (Replication)
- Check network bandwidth utilization
- Tune TCP parameters
- Consider compression for remote sends

## Configuration Management

### Configuration Files
```
/etc/zfs-protection/
├── monitor-config.conf      # Health monitoring settings
├── backup-config.conf       # Backup and replication settings
├── scrub-config.conf        # Scrub scheduling and settings
├── alert-config.conf        # Notification settings
└── tuning-backups/          # Configuration backups
```

### Making Configuration Changes
1. **Backup Current Config**: Always backup before changes
2. **Test Changes**: Validate configuration syntax
3. **Apply Gradually**: Make incremental changes
4. **Monitor Impact**: Watch for alerts and performance changes
5. **Document Changes**: Update runbook and change log

### Configuration Backup
```bash
# Backup all configurations
tar -czf /root/zfs-config-backup-$(date +%Y%m%d).tar.gz /etc/zfs-protection/

# Restore configuration
tar -xzf /root/zfs-config-backup-YYYYMMDD.tar.gz -C /
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Pool Import Fails
```bash
# Check available pools
zpool import

# Force import
zpool import -f pool_name

# Import with different root
zpool import -f -R /mnt pool_name

# Check for duplicate imports
zpool import -D
```

#### Snapshots Not Created
```bash
# Check service status
systemctl status zfs-snapshot-manager.service

# Manual snapshot creation
zfs snapshot tank/data@manual_$(date +%Y%m%d_%H%M%S)

# Check disk space
zfs list -o space
```

#### Backup Failures
```bash
# Check backup logs
tail -100 /var/log/zfs-protection/backup.log

# Test manual backup
/opt/zfs-protection/scripts/zfs-backup.sh --daily tank/data

# Check remote connectivity (if applicable)
ssh remote_host zpool status
```

#### Alert System Not Working
```bash
# Test alert system
/opt/zfs-protection/scripts/send-alert.sh --test

# Check email configuration
echo "Test" | mail -s "Test" admin@example.com

# Verify service status
systemctl status zfs-health-monitor.service
```

### Log Analysis

#### Important Log Files
```bash
# Health monitoring
/var/log/zfs-protection/health-monitor.log

# Backup operations
/var/log/zfs-protection/backup.log

# Scrub operations
/var/log/zfs-protection/scrub.log

# Alert delivery
/var/log/zfs-protection/alerts.log

# System logs
journalctl -u zfs-health-monitor.service
```

#### Log Analysis Commands
```bash
# Recent errors
grep -i error /var/log/zfs-protection/*.log | tail -20

# Backup success rate
grep -c "completed successfully" /var/log/zfs-protection/backup.log

# Alert frequency
grep -c "CRITICAL\|WARNING" /var/log/zfs-protection/alerts.log
```

## Contact Information

### Emergency Contacts
- **Primary Admin**: admin@example.com, +1-555-0101
- **Secondary Admin**: ops@example.com, +1-555-0102
- **On-call Engineer**: oncall@example.com, +1-555-0103

### Escalation Matrix
1. **Level 1**: System Administrator (Response: 15 minutes)
2. **Level 2**: Senior Operations Engineer (Response: 30 minutes)
3. **Level 3**: Infrastructure Manager (Response: 1 hour)
4. **Level 4**: Technical Director (Response: 2 hours)

### Vendor Contacts
- **Hardware Vendor**: support@vendor.com, +1-800-SUPPORT
- **ZFS Support**: community forums, documentation
- **Network Provider**: isp@provider.com, +1-800-NETWORK

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| $(date +%Y-%m-%d) | 1.0 | Initial runbook creation | ZFS Protection Suite |

## Additional Resources

### Documentation
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Proxmox ZFS Documentation](https://pve.proxmox.com/wiki/ZFS_on_Linux)
- [ZFS Best Practices](https://wiki.freebsd.org/ZFS)

### Training Resources
- ZFS administration courses
- Proxmox certification training
- Disaster recovery workshops

### Tools and Utilities
- ZFS Protection Suite scripts: `/opt/zfs-protection/scripts/`
- System monitoring: Grafana dashboard (if configured)
- Log analysis: ELK stack (if available)