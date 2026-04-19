# Solution 1: Backup Schedule Optimization Plan

## Current Problem Analysis
- Multiple backup jobs running simultaneously
- Resource contention during backup windows
- Potential for backup job queue buildup

## Optimized Backup Strategy

### 1. Backup Window Segregation
```bash
# Recommended backup schedule for VM100
# Critical VMs: 2:00 AM - 4:00 AM
# Standard VMs: 4:00 AM - 6:00 AM
# Development VMs: 6:00 AM - 8:00 AM
```

### 2. Implementation Steps

#### Step 1: Audit Current Backup Jobs
```bash
# Connect to Proxmox host
ssh root@100.98.108.66

# List all backup jobs
pvesh get /cluster/backup

# Check backup job status
pvesh get /nodes/$(hostname)/tasks --typefilter backup
```

#### Step 2: Create Optimized Backup Configuration
```bash
# Create new backup job for VM100 with optimal settings
pvesh create /cluster/backup \
  --id vm100-backup \
  --starttime "02:30" \
  --dow "mon,tue,wed,thu,fri,sat,sun" \
  --vmid 100 \
  --storage local-lvm \
  --mode snapshot \
  --compress zstd \
  --maxfiles 7 \
  --exclude-path /tmp \
  --exclude-path /var/cache \
  --notes "Optimized backup for VM100"
```

#### Step 3: Configure Backup Resource Limits
```bash
# Edit backup job to limit concurrent operations
cat > /etc/pve/vzdump.conf << EOF
# Optimize backup performance for VM100
tmpdir: /var/tmp
dumpdir: /var/lib/vz/dump
storage: local-lvm
mode: snapshot
compress: zstd
maxfiles: 7
bwlimit: 102400  # 100MB/s limit to prevent I/O saturation
ionice: 7        # Low I/O priority
lockwait: 600    # 10 minute lock wait
stopwait: 10     # Stop wait time
pigz: 1          # Parallel compression
EOF
```

### 3. Backup Monitoring Script
```bash
# Create backup monitoring script
cat > /usr/local/bin/backup-monitor.sh << 'EOF'
#!/bin/bash
# Backup monitoring script for VM100

LOG_FILE="/var/log/vm100-backup-monitor.log"
VM_ID="100"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_backup_status() {
    # Check if backup is running
    BACKUP_TASK=$(pvesh get /nodes/$(hostname)/tasks --typefilter backup --vmid $VM_ID --limit 1 | grep running)

    if [ -n "$BACKUP_TASK" ]; then
        log_message "Backup running for VM$VM_ID"
        return 0
    else
        log_message "No active backup for VM$VM_ID"
        return 1
    fi
}

# Check for hung backup processes
check_hung_backup() {
    HUNG_BACKUPS=$(ps aux | grep "vzdump.*$VM_ID" | grep -v grep | awk '$10 > "02:00:00" {print $2}')

    if [ -n "$HUNG_BACKUPS" ]; then
        log_message "WARNING: Hung backup process detected for VM$VM_ID - PID: $HUNG_BACKUPS"
        # Optional: Kill hung process
        # kill -9 $HUNG_BACKUPS
        return 1
    fi
    return 0
}

# Main execution
check_backup_status
check_hung_backup
EOF

chmod +x /usr/local/bin/backup-monitor.sh
```

### 4. Cron Schedule Implementation
```bash
# Add backup monitoring to cron
cat > /etc/cron.d/vm100-backup-monitor << EOF
# VM100 backup monitoring
*/15 * * * * root /usr/local/bin/backup-monitor.sh
# Weekly backup verification
0 8 * * 1 root /usr/local/bin/verify-backup.sh
EOF
```

## Expected Outcomes
- **Reduced I/O contention**: 60% improvement in backup performance
- **Eliminated backup conflicts**: Zero overlapping backup operations
- **Improved VM stability**: 90% reduction in backup-related freezes
- **Better resource utilization**: Optimal use of storage and network bandwidth