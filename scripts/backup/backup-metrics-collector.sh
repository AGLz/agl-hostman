#!/bin/bash
# Backup Metrics Collector for Prometheus
# Exports backup metrics to node_exporter textfile collector
#
# Usage: sudo ./backup-metrics-collector.sh
# Schedule: Run every 5 minutes via cron

set -euo pipefail

# Configuration
METRICS_DIR="/var/lib/node_exporter/textfile_collector"
METRICS_FILE="${METRICS_DIR}/backup_status.prom.$$"
FINAL_FILE="${METRICS_DIR}/backup_status.prom"
PBS_SERVER="${PBS_SERVER:-10.6.0.14}"
PBS_PORT="${PBS_PORT:-8007}"
PBS_DATASTORE="${PBS_DATASTORE:-aglsrv6-pbs}"
HOSTNAME="${HOSTNAME:-$(hostname)}"

# Ensure metrics directory exists
mkdir -p "$METRICS_DIR"

# Current timestamp
CURRENT_TIME=$(date +%s)

# Start metrics file
cat > "$METRICS_FILE" << EOF
# HELP backup_last_success_timestamp Unix timestamp of last successful backup
# TYPE backup_last_success_timestamp gauge
# HELP backup_duration_seconds Duration of last backup in seconds
# TYPE backup_duration_seconds gauge
# HELP backup_size_bytes Total size of all backups in bytes
# TYPE backup_size_bytes gauge
# HELP backup_count_total Total number of backups
# TYPE backup_count_total gauge
# HELP backup_retention_compliance_ratio Ratio of backups within retention policy
# TYPE backup_retention_compliance_ratio gauge
# HELP pbs_storage_used_bytes PBS storage used in bytes
# TYPE pbs_storage_used_bytes gauge
# HELP pbs_storage_total_bytes PBS storage total capacity in bytes
# TYPE pbs_storage_total_bytes gauge
# HELP backup_last_status Status of last backup (0=success, 1=failed)
# TYPE backup_last_status gauge
# HELP backup_verification_status Status of last verification (0=success, 1=failed)
# TYPE backup_verification_status gauge
# HELP backup_sync_last_timestamp Unix timestamp of last successful sync to FGSRV07
# TYPE backup_sync_last_timestamp gauge
# HELP backup_gc_last_success_timestamp Unix timestamp of last successful garbage collection
# TYPE backup_gc_last_success_timestamp gauge
EOF

# Function to add metric
add_metric() {
    local metric=$1
    local value=$2
    local labels=${3:-}
    local timestamp=$4

    if [[ -n "$labels" ]]; then
        echo "${metric}{${labels}} ${value} ${timestamp}" >> "$METRICS_FILE"
    else
        echo "${metric} ${value} ${timestamp}" >> "$METRICS_FILE"
    fi
}

# Get last backup timestamp from Proxmox API
get_last_backup_timestamp() {
    local vmid=$1

    # Get backup info from PBS
    local backup_info=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "proxmox-backup-client snapshot list --repository ${PBS_SERVER}:${PBS_DATASTORE} 2>/dev/null | \
         grep \"ct/${vmid}/\" | tail -1" || echo "")

    if [[ -n "$backup_info" ]]; then
        local backup_time=$(echo "$backup_info" | awk '{print $1" "$2}' | tr -d '[]')
        date -d "$backup_time" +%s 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Get last backup duration
get_last_backup_duration() {
    local vmid=$1

    # Parse from Proxmox task log
    local duration=$(pvesh get /nodes/$(hostname)/tasks --typefilter vzdump --vmid "$vmid" --limit 1 \
      --output-format json 2>/dev/null | jq -r '.[0].duration // 0' || echo 0)

    # Convert to seconds (duration is in format "HH:MM:SS")
    if [[ "$duration" =~ ([0-9]+):([0-9]+):([0-9]+) ]]; then
        echo $(( ${BASH_REMATCH[1]} * 3600 + ${BASH_REMATCH[2]} * 60 + ${BASH_REMATCH[3]} ))
    else
        echo 0
    fi
}

# Get backup size from PBS
get_backup_size() {
    local vmid=$1

    local size=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "du -sb /var/lib/proxmox-backup/local-backup/ct/${vmid} 2>/dev/null | cut -f1" || echo 0)

    echo "$size"
}

# Get total backup count
get_backup_count() {
    local count=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "proxmox-backup-manager datastore info --datastore ${PBS_DATASTORE} 2>/dev/null | \
         jq -r '.total_snapshots // 0'" || echo 0)

    echo "$count"
}

# Get PBS storage info
get_pbs_storage_info() {
    local storage_info=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "df -B1 /var/lib/proxmox-backup/local-backup 2>/dev/null | tail -1" || echo "")

    if [[ -n "$storage_info" ]]; then
        local total=$(echo "$storage_info" | awk '{print $2}')
        local used=$(echo "$storage_info" | awk '{print $3}')

        add_metric "pbs_storage_total_bytes" "$total" "datastore=\"${PBS_DATASTORE}\"" "$CURRENT_TIME"
        add_metric "pbs_storage_used_bytes" "$used" "datastore=\"${PBS_DATASTORE}\"" "$CURRENT_TIME"
    fi
}

# Get last backup status (0=success, 1=failed)
get_last_backup_status() {
    local vmid=$1

    # Check last task status
    local status=$(pvesh get /nodes/$(hostname)/tasks --typefilter vzdump --vmid "$vmid" --limit 1 \
      --output-format json 2>/dev/null | jq -r '.[0].status // "unknown"' || echo "unknown")

    if [[ "$status" == "ok" ]]; then
        echo 0
    else
        echo 1
    fi
}

# Collect metrics for each container
collect_container_metrics() {
    for vmid in 173 180 182 183 184; do
        local last_backup=$(get_last_backup_timestamp "$vmid")
        local duration=$(get_last_backup_duration "$vmid")
        local size=$(get_backup_size "$vmid")
        local status=$(get_last_backup_status "$vmid")

        local hostname=""
        case $vmid in
            173) hostname="cacheng" ;;
            180) hostname="dokploy" ;;
            182) hostname="harbor" ;;
            183) hostname="archon" ;;
            184) hostname="supabase" ;;
        esac

        add_metric "backup_last_success_timestamp" "$last_backup" "host=\"${HOSTNAME}\",vmid=\"${vmid}\",container=\"${hostname}\"" "$CURRENT_TIME"
        add_metric "backup_duration_seconds" "$duration" "host=\"${HOSTNAME}\",vmid=\"${vmid}\",container=\"${hostname}\"" "$CURRENT_TIME"
        add_metric "backup_size_bytes" "$size" "host=\"${HOSTNAME}\",vmid=\"${vmid}\",container=\"${hostname}\"" "$CURRENT_TIME"
        add_metric "backup_last_status" "$status" "host=\"${HOSTNAME}\",vmid=\"${vmid}\",container=\"${hostname}\"" "$CURRENT_TIME"
    done
}

# Collect aggregate metrics
collect_aggregate_metrics() {
    local total_count=$(get_backup_count)

    add_metric "backup_count_total" "$total_count" "host=\"${HOSTNAME}\",datastore=\"${PBS_DATASTORE}\"" "$CURRENT_TIME"

    # Calculate retention compliance (expected vs actual)
    local expected_backups=23  # 7 daily + 4 weekly + 12 monthly
    local compliance_ratio=$(echo "scale=2; $total_count / $expected_backups" | bc 2>/dev/null || echo 1)

    if [[ $(echo "$compliance_ratio > 1" | bc) -eq 1 ]]; then
        compliance_ratio=1
    fi

    add_metric "backup_retention_compliance_ratio" "$compliance_ratio" "host=\"${HOSTNAME}\"" "$CURRENT_TIME"
}

# Get verification status
get_verification_status() {
    local state_file="/var/lib/backup-verify/state.json"

    if [[ -f "$state_file" ]]; then
        local last_check=$(jq -r '.last_check // ""' "$state_file" 2>/dev/null || echo "")
        local failures=$(jq -r '.failures | length' "$state_file" 2>/dev/null || echo 0)

        if [[ -n "$last_check" ]]; then
            local check_timestamp=$(date -d "$last_check" +%s 2>/dev/null || echo 0)
            add_metric "backup_verification_last_check" "$check_timestamp" "host=\"${HOSTNAME}\"" "$CURRENT_TIME"
        fi

        if [[ $failures -gt 0 ]]; then
            add_metric "backup_verification_status" "1" "host=\"${HOSTNAME}\"" "$CURRENT_TIME"
        else
            add_metric "backup_verification_status" "0" "host=\"${HOSTNAME}\"" "$CURRENT_TIME"
        fi
    else
        # No verification run yet
        add_metric "backup_verification_status" "0" "host=\"${HOSTNAME}\"" "$CURRENT_TIME"
    fi
}

# Get sync status
get_sync_status() {
    local fgsrv07_ip="100.109.181.93"

    # Try to get last sync timestamp from FGSRV07
    local last_sync=$(ssh -o ConnectTimeout=5 root@"$fgsrv07_ip" \
        "proxmox-backup-manager sync-job list 2>/dev/null | \
         grep 'last-run' | awk '{print \$2}' | head -1" || echo 0)

    if [[ -n "$last_sync" && "$last_sync" != "0" ]]; then
        local sync_timestamp=$(date -d "$last_sync" +%s 2>/dev/null || echo 0)
        add_metric "backup_sync_last_timestamp" "$sync_timestamp" "target=\"fgsrv07\"" "$CURRENT_TIME"
    else
        add_metric "backup_sync_last_timestamp" "0" "target=\"fgsrv07\"" "$CURRENT_TIME"
    fi
}

# Get GC status
get_gc_status() {
    # Get last successful GC time from PBS
    local gc_info=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "journalctl -u proxmox-backup --since '7 days ago' | \
         grep 'Garbage collection' | tail -1" || echo "")

    if [[ -n "$gc_info" ]]; then
        local gc_time=$(echo "$gc_info" | awk '{print $1" "$2}' | tr -d '[]')
        local gc_timestamp=$(date -d "$gc_time" +%s 2>/dev/null || echo 0)
        add_metric "backup_gc_last_success_timestamp" "$gc_timestamp" "datastore=\"${PBS_DATASTORE}\"" "$CURRENT_TIME"
    fi
}

# Main execution
main() {
    # Collect metrics for each container
    collect_container_metrics

    # Collect aggregate metrics
    collect_aggregate_metrics

    # Get PBS storage info
    get_pbs_storage_info

    # Get verification status
    get_verification_status

    # Get sync status
    get_sync_status

    # Get GC status
    get_gc_status

    # Atomically replace the metrics file
    mv "$METRICS_FILE" "$FINAL_FILE"

    # Clean up old metrics files
    find "$METRICS_DIR" -name "backup_status.prom.*" -mtime +1 -delete 2>/dev/null || true
}

# Run main
main "$@"

exit 0
