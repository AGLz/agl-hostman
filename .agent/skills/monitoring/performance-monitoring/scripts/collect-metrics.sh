#!/usr/bin/env bash
##
# Performance Metrics Collection Script
#
# Collects performance metrics from Proxmox servers and LXC containers
# Stores metrics in the performance_trends table
#
# Usage: ./collect-metrics.sh [options]
#   --resource-type=TYPE    Resource type (server, container, storage)
#   --resource-id=ID        Specific resource ID
#   --metric-type=TYPE      Metric type (cpu, memory, disk, network)
#   --dry-run               Show what would be collected without storing
#
# Examples:
#   ./collect-metrics.sh --resource-type=server --metric-type=cpu
#   ./collect-metrics.sh --resource-type=container --resource-id=vm-105
##

set -euo pipefail

# Configuration
API_BASE="${PROXMOX_API_URL:-https://proxmox.aglz.io:8006}"
API_TOKEN="${PROXMOX_API_TOKEN}"
RESOURCE_TYPE="${RESOURCE_TYPE:-all}"
METRIC_TYPE="${METRIC_TYPE:-all}"
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --resource-type=*)  RESOURCE_TYPE="${arg#*=}" ;;
        --resource-id=*)    RESOURCE_ID="${arg#*=}" ;;
        --metric-type=*)    METRIC_TYPE="${arg#*=}" ;;
        --dry-run)          DRY_RUN=true ;;
        *) echo "Unknown argument: $arg" && exit 1 ;;
    esac
done

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Collect metrics from Proxmox API
collect_proxmox_metrics() {
    local resource_id="$1"

    log_info "Collecting metrics for $resource_id"

    # Get node status
    local status
    status=$(curl -s -H "Authorization: PVEAPIToken=$API_TOKEN" \
        "$API_BASE/api2/json/nodes/$resource_id/status" | jq -r '.')

    # Extract metrics
    local cpu memory load
    cpu=$(echo "$status" | jq -r '.cpu // 0')
    memory=$(echo "$status" | jq -r '.memory // 0 / .max_memory * 100')
    load=$(echo "$status" | jq -r '.loadavg // [0,0,0] | .[0]')

    # Store metrics (via Laravel or direct DB insert)
    if [[ "$DRY_RUN" == false ]]; then
        php artisan performance:record \
            --resource-type=server \
            --resource-id="$resource_id" \
            --metric-type=cpu \
            --value="$cpu" \
            --unit=%

        php artisan performance:record \
            --resource-type=server \
            --resource-id="$resource_id" \
            --metric-type=memory \
            --value="$memory" \
            --unit=%

        php artisan performance:record \
            --resource-type=server \
            --resource-id="$resource_id" \
            --metric-type=load \
            --value="$load" \
            --unit=number
    else
        log_info "[DRY-RUN] Would store: CPU=$cpu%, Memory=$memory%, Load=$load"
    fi
}

# Collect container metrics
collect_container_metrics() {
    local vmid="$1"

    log_info "Collecting metrics for container $vmid"

    # Get container status
    local status
    status=$(curl -s -H "Authorization: PVEAPIToken=$API_TOKEN" \
        "$API_BASE/api2/json/nodes/proxmox/lxc/$vmid/status/current" | jq -r '.')

    local cpu memory disk
    cpu=$(echo "$status" | jq -r '.cpu // 0 * 100')
    memory=$(echo "$status" | jq -r '.mem // 0 / .maxmem * 100')
    disk=$(echo "$status" | jq -r '.disk // 0 / .maxdisk * 100')

    if [[ "$DRY_RUN" == false ]]; then
        php artisan performance:record \
            --resource-type=container \
            --resource-id="$vmid" \
            --metric-type=cpu \
            --value="$cpu" \
            --unit=%

        php artisan performance:record \
            --resource-type=container \
            --resource-id="$vmid" \
            --metric-type=memory \
            --value="$memory" \
            --unit=%

        php artisan performance:record \
            --resource-type=container \
            --resource-id="$vmid" \
            --metric-type=disk \
            --value="$disk" \
            --unit=%
    else
        log_info "[DRY-RUN] Would store: CPU=$cpu%, Memory=$memory%, Disk=$disk%"
    fi
}

# Main collection logic
main() {
    log_info "Starting metrics collection..."
    log_info "Resource type: $RESOURCE_TYPE"
    log_info "Metric type: $METRIC_TYPE"

    if [[ "$RESOURCE_TYPE" == "all" || "$RESOURCE_TYPE" == "server" ]]; then
        # Get all nodes
        local nodes
        nodes=$(curl -s -H "Authorization: PVEAPIToken=$API_TOKEN" \
            "$API_BASE/api2/json/nodes" | jq -r '.[].node')

        for node in $nodes; do
            collect_proxmox_metrics "$node"
        done
    fi

    if [[ "$RESOURCE_TYPE" == "all" || "$RESOURCE_TYPE" == "container" ]]; then
        if [[ -n "${RESOURCE_ID:-}" ]]; then
            collect_container_metrics "$RESOURCE_ID"
        else
            # Get all containers
            local containers
            containers=$(curl -s -H "Authorization: PVEAPIToken=$API_TOKEN" \
                "$API_BASE/api2json/nodes/proxmox/lxc" | jq -r '.[].vmid')

            for vmid in $containers; do
                collect_container_metrics "$vmid"
            done
        fi
    fi

    log_info "Metrics collection complete"
}

main
