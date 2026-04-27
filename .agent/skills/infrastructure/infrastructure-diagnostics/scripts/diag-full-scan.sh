#!/bin/bash
################################################################################
# Infrastructure Full Diagnostic Scan
#
# Description: Run comprehensive diagnostic across all systems
# Output: JSON report with findings and recommendations
# Usage: ./diag-full-scan.sh [--output-file report.json]
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${1:-}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname)

# Colors for terminal output (when not using JSON)
if [ -z "${OUTPUT_FILE}" ]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# JSON output structure
json_output='{
  "scan_info": {
    "hostname": "'"$HOSTNAME"'",
    "timestamp": "'"$TIMESTAMP"'",
    "scan_version": "1.0.0"
  },
  "checks": {}
}'

# Helper functions
log_info() {
    if [ -z "${OUTPUT_FILE}" ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_warn() {
    if [ -z "${OUTPUT_FILE}" ]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if [ -z "${OUTPUT_FILE}" ]; then
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

log_success() {
    if [ -z "${OUTPUT_FILE}" ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    fi
}

# Add finding to JSON
add_finding() {
    local category="$1"
    local check="$2"
    local status="$3"
    local message="$4"
    local recommendation="${5:-}"

    json_output=$(echo "$json_output" | jq --arg cat "$category" --arg chk "$check" --arg st "$status" --arg msg "$message" --arg rec "$recommendation" '
        .checks[$cat] |= . + {
            $chk: {
                "status": $st,
                "message": $msg,
                "recommendation": $rec
            }
        }
    ')
}

################################################################################
# System Reachability Check
################################################################################
check_system_reachability() {
    log_info "Checking system reachability..."

    local status="pass"
    local message="System is reachable"
    local recommendation=""

    # Check if we can ping the gateway
    local gateway=$(ip route | grep default | awk '{print $3}')
    if [ -n "$gateway" ]; then
        if ping -c 1 -W 2 "$gateway" &>/dev/null; then
            log_success "Gateway reachable: $gateway"
        else
            status="fail"
            message="Cannot reach gateway: $gateway"
            recommendation="Check network connectivity and firewall rules"
            log_error "$message"
        fi
    else
        status="warn"
        message="No default gateway found"
        recommendation="Configure network gateway"
        log_warn "$message"
    fi

    add_finding "system" "reachability" "$status" "$message" "$recommendation"
}

################################################################################
# System Resources Check
################################################################################
check_system_resources() {
    log_info "Checking system resources..."

    # CPU check
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_status="pass"
    local cpu_message="CPU usage: ${cpu_usage}%"
    local_cpu_recommendation=""

    if (( $(echo "$cpu_usage > 85" | bc -l) )); then
        cpu_status="critical"
        cpu_recommendation="Identify high CPU processes and optimize or scale"
        log_error "CPU CRITICAL: $cpu_message"
    elif (( $(echo "$cpu_usage > 70" | bc -l) )); then
        cpu_status="warning"
        cpu_recommendation="Monitor CPU usage closely"
        log_warn "CPU WARNING: $cpu_message"
    else
        log_success "$cpu_message"
    fi

    add_finding "resources" "cpu" "$cpu_status" "$cpu_message" "$cpu_recommendation"

    # Memory check
    local mem_total=$(free -m | awk '/^Mem:/{print $2}')
    local mem_used=$(free -m | awk '/^Mem:/{print $3}')
    local mem_percent=$(awk "BEGIN {printf \"%.0f\", ($mem_used / $mem_total) * 100}")
    local mem_status="pass"
    local mem_message="Memory: ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"
    local mem_recommendation=""

    if [ "$mem_percent" -gt 90 ]; then
        mem_status="critical"
        mem_recommendation="Free memory or add more RAM"
        log_error "MEMORY CRITICAL: $mem_message"
    elif [ "$mem_percent" -gt 80 ]; then
        mem_status="warning"
        mem_recommendation="Monitor memory usage"
        log_warn "MEMORY WARNING: $mem_message"
    else
        log_success "$mem_message"
    fi

    add_finding "resources" "memory" "$mem_status" "$mem_message" "$mem_recommendation"

    # Disk check
    local disk_status="pass"
    local disk_message=""
    local disk_recommendation=""
    local has_disk_issue=false

    while read -r mount used avail; do
        local used_percent=${used%\%}
        if [ "$used_percent" -gt 90 ]; then
            disk_status="critical"
            disk_message="Mount $mount is ${used} full"
            disk_recommendation="Clean up or expand storage"
            log_error "DISK CRITICAL: $disk_message"
            has_disk_issue=true
        elif [ "$used_percent" -gt 80 ]; then
            if [ "$disk_status" != "critical" ]; then
                disk_status="warning"
            fi
            if [ -z "$disk_message" ]; then
                disk_message="Mount $mount is ${used} full"
            else
                disk_message="$disk_message, $mount is ${used} full"
            fi
            disk_recommendation="Monitor disk usage"
            log_warn "DISK WARNING: $mount is ${used} full"
            has_disk_issue=true
        fi
    done < <(df -h | grep -E '^/dev/' | awk '{print $6, $5, $4}')

    if [ "$has_disk_issue" = false ]; then
        disk_message="All mounts have adequate space"
        log_success "$disk_message"
    fi

    add_finding "resources" "disk" "$disk_status" "$disk_message" "$disk_recommendation"
}

################################################################################
# Docker Health Check
################################################################################
check_docker() {
    log_info "Checking Docker..."

    local status="pass"
    local message="Docker is healthy"
    local recommendation=""

    # Check if Docker is running
    if ! systemctl is-active --quiet docker; then
        status="critical"
        message="Docker daemon is not running"
        recommendation="Start Docker: systemctl start docker"
        log_error "$message"
        add_finding "docker" "daemon" "$status" "$message" "$recommendation"
        return
    fi

    log_success "Docker daemon is running"

    # Check container status
    local total_containers=$(docker ps -a --format '{{.Names}}' | wc -l)
    local running_containers=$(docker ps --format '{{.Names}}' | wc -l)
    local exited_containers=$(docker ps -f "status=exited" --format '{{.Names}}' | wc -l)

    local container_message="Containers: $running_containers running, $exited_containers exited, $total_containers total"

    if [ "$exited_containers" -gt 0 ]; then
        status="warning"
        message="$container_message (some containers are not running)"
        recommendation="Check logs for exited containers"
        log_warn "$message"
    else
        log_success "$container_message"
    fi

    add_finding "docker" "containers" "$status" "$container_message" "$recommendation"

    # Check for resource issues
    local high_cpu_containers=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" | tail -n +2 | awk -F'%' '$1 > 80' | wc -l)
    local high_mem_containers=$(docker stats --no-stream --format "table {{.Name}}\t{{.MemPerc}}" | tail -n +2 | awk -F'%' '$1 > 85' | wc -l)

    if [ "$high_cpu_containers" -gt 0 ]; then
        status="warning"
        message="$high_cpu_containers container(s) with high CPU usage"
        recommendation="Check docker stats for details"
        log_warn "$message"
        add_finding "docker" "high_cpu" "$status" "$message" "$recommendation"
    fi

    if [ "$high_mem_containers" -gt 0 ]; then
        status="warning"
        message="$high_mem_containers container(s) with high memory usage"
        recommendation="Check docker stats for details"
        log_warn "$message"
        add_finding "docker" "high_memory" "$status" "$message" "$recommendation"
    fi
}

################################################################################
# Proxmox Health Check
################################################################################
check_proxmox() {
    log_info "Checking Proxmox..."

    local status="pass"
    local message="Proxmox is not accessible from this host"
    local recommendation="This check requires a Proxmox node"

    # Check if pvesh command is available
    if ! command -v pvesh &> /dev/null; then
        add_finding "proxmox" "cli" "skip" "$message" "$recommendation"
        return
    fi

    log_success "Proxmox CLI found"

    # Check cluster status
    local cluster_output=$(pvesh get /cluster/status 2>/dev/null || echo "")
    if [ -z "$cluster_output" ]; then
        status="critical"
        message="Cannot connect to Proxmox cluster"
        recommendation="Check Proxmox API connectivity"
        log_error "$message"
        add_finding "proxmox" "cluster" "$status" "$message" "$recommendation"
        return
    fi

    log_success "Proxmox cluster is accessible"

    # Check node status
    local nodename=$(hostname)
    local node_status=$(echo "$cluster_output" | jq -r ".[] | select(.name == \"$nodename\") | .status // \"online\"")

    if [ "$node_status" = "online" ]; then
        log_success "Proxmox node is online"
        add_finding "proxmox" "node" "pass" "Node is online" ""
    else
        status="critical"
        message="Proxmox node status: $node_status"
        recommendation="Check Proxmox node health"
        log_error "$message"
        add_finding "proxmox" "node" "$status" "$message" "$recommendation"
    fi

    # Check quorum
    local quorum=$(echo "$cluster_output" | jq -r '.[] | select(.type == "cluster") | .quorate // "1"')
    if [ "$quorum" = "1" ]; then
        log_success "Cluster has quorum"
        add_finding "proxmox" "quorum" "pass" "Cluster has quorum" ""
    else
        status="critical"
        message="Cluster does NOT have quorum"
        recommendation="Check cluster connectivity or use pvecm expected 1 for single node"
        log_error "$message"
        add_finding "proxmox" "quorum" "$status" "$message" "$recommendation"
    fi
}

################################################################################
# Network Health Check
################################################################################
check_network() {
    log_info "Checking network..."

    # DNS check
    local dns_status="pass"
    local dns_message=""
    local dns_recommendation=""

    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        if ping -c 1 -W 2 google.com &>/dev/null; then
            dns_message="DNS resolution working"
            log_success "$dns_message"
        else
            dns_status="warning"
            dns_message="Cannot resolve DNS (IP connectivity works)"
            dns_recommendation="Check /etc/resolv.conf"
            log_warn "$dns_message"
        fi
    else
        dns_status="critical"
        dns_message="Cannot reach external network (8.8.8.8)"
        dns_recommendation="Check network connectivity and routing"
        log_error "$dns_message"
    fi

    add_finding "network" "dns" "$dns_status" "$dns_message" "$dns_recommendation"

    # VPN checks
    if command -v wg &> /dev/null; then
        local wg_status="pass"
        local wg_message=""
        local wg_recommendation=""

        if wg show wg0 &>/dev/null; then
            local wg_peers=$(wg show wg0 peers | wc -l)
            wg_message="WireGuard active with $wg_peers peer(s)"
            log_success "$wg_message"
        else
            wg_status="warning"
            wg_message="WireGuard interface not found"
            wg_recommendation="Check WireGuard configuration"
            log_warn "$wg_message"
        fi

        add_finding "network" "wireguard" "$wg_status" "$wg_message" "$wg_recommendation"
    fi

    if command -v tailscale &> /dev/null; then
        local ts_status="pass"
        local ts_message=""
        local ts_recommendation=""

        if tailscale status &>/dev/null; then
            local ts_peers=$(tailscale status --peers 2>/dev/null | grep -c "-" || echo "0")
            ts_message="Tailscale active with $ts_peers peer(s)"
            log_success "$ts_message"
        else
            ts_status="warning"
            ts_message="Tailscale not connected"
            ts_recommendation="Check Tailscale login and connectivity"
            log_warn "$ts_message"
        fi

        add_finding "network" "tailscale" "$ts_status" "$ts_message" "$ts_recommendation"
    fi
}

################################################################################
# Service Health Check
################################################################################
check_services() {
    log_info "Checking services..."

    # Check common services
    local services=("nginx" "mysql" "redis" "horizon")

    for service in "${services[@]}"; do
        local status="pass"
        local message=""
        local recommendation=""

        if systemctl is-active --quiet "$service"; then
            message="$service is running"
            log_success "$message"
        else
            if systemctl list-unit-files | grep -q "^$service.service"; then
                status="critical"
                message="$service is not running"
                recommendation="Start service: systemctl start $service"
                log_error "$message"
            else
                status="skip"
                message="$service is not installed"
                recommendation=""
            fi
        fi

        add_finding "services" "$service" "$status" "$message" "$recommendation"
    done
}

################################################################################
# Queue Health Check
################################################################################
check_queues() {
    log_info "Checking queue status..."

    if ! command -v redis-cli &> /dev/null; then
        add_finding "queues" "redis" "skip" "Redis CLI not found" ""
        return
    fi

    # Check Redis connection
    if ! redis-cli ping &>/dev/null; then
        add_finding "queues" "redis" "critical" "Cannot connect to Redis" "Start Redis service"
        return
    fi

    log_success "Redis is responding"

    # Check queue sizes
    local queues=("default" "high" "low")
    local total_pending=0
    local queue_status="pass"
    local queue_message=""
    local queue_recommendation=""

    for queue in "${queues[@]}"; do
        local size=$(redis-cli -n 1 llen "queues:$queue" 2>/dev/null || echo "0")
        total_pending=$((total_pending + size))

        if [ "$size" -gt 1000 ]; then
            queue_status="warning"
            queue_message="Queue $queue has $size pending jobs"
            queue_recommendation="Check if workers are processing"
            log_warn "$queue_message"
        fi
    done

    if [ "$queue_status" = "pass" ]; then
        queue_message="Queues healthy: $total_pending total pending jobs"
        log_success "$queue_message"
    fi

    add_finding "queues" "pending" "$queue_status" "$queue_message" "$queue_recommendation"

    # Check failed jobs
    local failed_jobs=$(redis-cli -n 1 llen "queues:failed" 2>/dev/null || echo "0")
    if [ "$failed_jobs" -gt 0 ]; then
        add_finding "queues" "failed" "warning" "$failed_jobs failed jobs" "Review and retry failed jobs"
    else
        add_finding "queues" "failed" "pass" "No failed jobs" ""
    fi
}

################################################################################
# Generate Summary
################################################################################
generate_summary() {
    local critical=$(echo "$json_output" | jq '[.checks[][] | select(.status == "critical")] | length')
    local warning=$(echo "$json_output" | jq '[.checks[][] | select(.status == "warning")] | length')
    local passed=$(echo "$json_output" | jq '[.checks[][] | select(.status == "pass")] | length')

    json_output=$(echo "$json_output" | jq --argjson critical "$critical" --argjson warning "$warning" --argjson passed "$passed" '
        .summary = {
            "critical": $critical,
            "warning": $warning,
            "passed": $passed,
            "total_issues": ($critical + $warning)
        }
    ')

    if [ -z "${OUTPUT_FILE}" ]; then
        echo ""
        echo "=== Diagnostic Summary ==="
        echo "Critical: $critical"
        echo "Warning: $warning"
        echo "Passed: $passed"
        echo "Total Issues: $((critical + warning))"
        echo ""
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    log_info "Starting infrastructure diagnostic scan..."
    log_info "Timestamp: $TIMESTAMP"
    log_info "Hostname: $HOSTNAME"
    echo ""

    # Run all checks
    check_system_reachability
    check_system_resources
    check_docker
    check_proxmox
    check_network
    check_services
    check_queues

    # Generate summary
    generate_summary

    # Output results
    if [ -n "${OUTPUT_FILE}" ]; then
        echo "$json_output" | jq '.' > "$OUTPUT_FILE"
        log_info "Report saved to: $OUTPUT_FILE"
    else
        echo ""
        echo "=== Full Report ==="
        echo "$json_output" | jq '.'
    fi

    # Exit with error code if critical issues found
    local critical=$(echo "$json_output" | jq '.summary.critical')
    if [ "$critical" -gt 0 ]; then
        exit 1
    fi

    exit 0
}

# Run main function
main "$@"
