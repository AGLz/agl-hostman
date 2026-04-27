#!/bin/bash

# Monitor backup progress and VM health during RPOOL backup
VM_ID=100
VM_IP="10.10.15.80"
SQL_PORT=1433
LOG_FILE="/tmp/backup_monitor.log"

echo "========================================" | tee -a $LOG_FILE
echo "BACKUP MONITOR - $(date)" | tee -a $LOG_FILE
echo "========================================" | tee -a $LOG_FILE

# Function to check VM responsiveness
check_vm_health() {
    # Check QMP socket
    if timeout 2 bash -c "echo 'query-status' | socat - /var/run/qemu-server/100.qmp 2>/dev/null | grep -q running"; then
        echo "✅ QMP: Responsive"
        return 0
    else
        echo "❌ QMP: Not responding"
        return 1
    fi
}

# Function to check SQL Server
check_sql_port() {
    if timeout 3 bash -c "echo > /dev/tcp/$VM_IP/$SQL_PORT" 2>/dev/null; then
        echo "✅ SQL Server: Port $SQL_PORT accessible"
        return 0
    else
        echo "❌ SQL Server: Port $SQL_PORT not accessible"
        return 1
    fi
}

# Function to check backup progress
check_backup_progress() {
    BACKUP_PID=$(ps aux | grep "vzdump 100" | grep -v grep | awk '{print $2}' | head -1)

    if [ -n "$BACKUP_PID" ]; then
        echo "📦 Backup Process: Running (PID: $BACKUP_PID)"

        # Get latest progress from log
        if [ -f "/tmp/backup_virtio_migration.log" ]; then
            PROGRESS=$(tail -1 /tmp/backup_virtio_migration.log | grep "INFO:" | tail -1)
            if [ -n "$PROGRESS" ]; then
                echo "   Progress: $PROGRESS"
            fi
        fi
        return 0
    else
        echo "✅ Backup: Completed or not running"
        return 1
    fi
}

# Function to check system resources
check_system_resources() {
    # CPU Load
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    echo "📊 System Load:$LOAD"

    # Memory
    MEM_USED=$(free -h | grep Mem | awk '{print $3}')
    MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
    echo "💾 Memory: $MEM_USED / $MEM_TOTAL"

    # RPOOL I/O
    RPOOL_IO=$(zpool iostat rpool 1 2 | tail -1 | awk '{print "Read: "$6" Write: "$7}')
    echo "💿 RPOOL I/O: $RPOOL_IO"
}

# Main monitoring loop
echo ""
echo "Starting continuous monitoring during backup..." | tee -a $LOG_FILE
echo "Press Ctrl+C to stop monitoring" | tee -a $LOG_FILE
echo ""

while true; do
    clear
    echo "========================================="
    echo "📅 $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================="
    echo ""
    echo "VM100 HEALTH CHECK:"
    check_vm_health
    check_sql_port
    echo ""
    echo "BACKUP STATUS:"
    check_backup_progress
    BACKUP_RUNNING=$?
    echo ""
    echo "SYSTEM RESOURCES:"
    check_system_resources
    echo ""

    # If backup is not running anymore, exit
    if [ $BACKUP_RUNNING -eq 1 ]; then
        echo "✅ Backup process completed!" | tee -a $LOG_FILE

        # Final check of backup files
        echo ""
        echo "BACKUP FILES:"
        ls -lh /rpool/backup/dump/vzdump-qemu-100-2025_09_28* 2>/dev/null | tail -3

        break
    fi

    # Check for any errors in backup log
    if [ -f "/tmp/backup_virtio_migration.log" ]; then
        ERRORS=$(grep -E "ERROR|FAILED|CRITICAL" /tmp/backup_virtio_migration.log | tail -3)
        if [ -n "$ERRORS" ]; then
            echo "⚠️ BACKUP ERRORS DETECTED:"
            echo "$ERRORS"
        fi
    fi

    # Wait 10 seconds before next check
    sleep 10
done

echo ""
echo "========================================="
echo "Backup monitoring completed at $(date)" | tee -a $LOG_FILE
echo "========================================="

# Show final backup summary
echo ""
echo "FINAL BACKUP SUMMARY:"
if [ -f "/tmp/backup_virtio_migration.log" ]; then
    grep -E "INFO: Backup (finished|failed)" /tmp/backup_virtio_migration.log
    echo ""
    echo "Full backup log: /tmp/backup_virtio_migration.log"
fi