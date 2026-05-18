#!/bin/bash
################################################################################
# Docker Diagnostics
#
# Description: Check Docker containers and images
# Output: JSON report with findings and recommendations
# Usage: ./diag-docker.sh [--container name]
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_FILTER="${1:-}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# JSON output structure
json_output='{
  "scan_info": {
    "timestamp": "'"$TIMESTAMP"'",
    "scan_version": "1.0.0"
  },
  "checks": {}
}'

# Helper functions
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

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found. This script requires Docker to be installed." >&2
    exit 1
fi

################################################################################
# Docker Daemon Check
################################################################################
check_docker_daemon() {
    echo "Checking Docker daemon..."

    if ! docker info &>/dev/null; then
        echo "  ERROR: Docker daemon is not running"
        add_finding "daemon" "status" "critical" "Docker daemon is not running" "Start Docker: systemctl start docker"
        return 1
    fi

    echo "  Docker daemon is running"
    add_finding "daemon" "status" "pass" "Docker daemon is running" ""

    # Get Docker info
    local docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    local containers_total=$(docker info --format '{{.Containers}}' 2>/dev/null || echo "0")
    local containers_running=$(docker info --format '{{.ContainersRunning}}' 2>/dev/null || echo "0")
    local containers_paused=$(docker info --format '{{.ContainersPaused}}' 2>/dev/null || echo "0")
    local containers_stopped=$(docker info --format '{{.ContainersStopped}}' 2>/dev/null || echo "0")

    echo "  Version: $docker_version"
    echo "  Containers: $containers_running running, $containers_paused paused, $containers_stopped stopped"

    add_finding "daemon" "version" "pass" "Docker version: $docker_version" ""
    add_finding "daemon" "counts" "pass" "Containers: $containers_running running, $containers_stopped stopped" ""
}

################################################################################
# Container Status Check
################################################################################
check_container_status() {
    echo "Checking containers..."

    # Get container list
    local container_filter_arg=""
    if [ -n "$CONTAINER_FILTER" ]; then
        container_filter_arg="--filter name=$CONTAINER_FILTER"
    fi

    local containers_output
    containers_output=$(docker ps -a $container_filter_arg --format "json" 2>/dev/null || echo "[]")

    local total_containers=$(echo "$containers_output" | jq 'length')
    local running_containers=$(echo "$containers_output" | jq '[.[] | select(.State == "running")] | length')
    local exited_containers=$(echo "$containers_output" | jq '[.[] | select(.State == "exited")] | length')
    local paused_containers=$(echo "$containers_output" | jq '[.[] | select(.State == "paused")] | length')

    echo "  Total: $total_containers"
    echo "  Running: $running_containers"
    echo "  Exited: $exited_containers"
    echo "  Paused: $paused_containers"

    if [ "$running_containers" -eq "$total_containers" ]; then
        add_finding "containers" "overall" "pass" "All containers running ($running_containers/$total_containers)" ""
    else
        add_finding "containers" "overall" "warning" "$exited_containers container(s) not running" "Check logs for exited containers"
    fi

    # Check for restart loops
    echo "$containers_output" | jq -r '.[] | select(.State != "running") | "\(.Names) \(.State) \(.Status)"' | while read -r name state status; do
        if [[ "$status" == *"Restarting"* ]]; then
            echo "  WARNING: Container $name is in restart loop"
            add_finding "containers" "$name" "warning" "Container in restart loop" "Check logs: docker logs $name"
        fi
    done
}

################################################################################
# Container Resource Check
################################################################################
check_container_resources() {
    echo "Checking container resources..."

    local stats_output
    stats_output=$(docker stats --no-stream --format "json" 2>/dev/null || echo "[]")

    local high_cpu_containers=0
    local high_memory_containers=0
    local cpu_threshold=80
    local memory_threshold=85

    echo "$stats_output" | jq -r '.[] | "\(.Name) \(.CPUPerc) \(.MemPerc)"' | while read -r name cpu mem; do
        local cpu_value=$(echo "$cpu" | tr -d '%')
        local mem_value=$(echo "$mem" | tr -d '%')

        if [ -n "$cpu_value" ] && [ "$cpu_value" != "%"] && [ "$cpu_value" != "0.00%" ]; then
            if (( $(echo "$cpu_value > $cpu_threshold" | bc -l 2>/dev/null || echo "0") )); then
                echo "  WARNING: $name - CPU: $cpu"
                add_finding "resources" "${name}_cpu" "warning" "High CPU usage: $cpu" "Check process in container"
                high_cpu_containers=$((high_cpu_containers + 1))
            fi
        fi

        if [ -n "$mem_value" ] && [ "$mem_value" != "%"] && [ "$mem_value" != "0.00%" ]; then
            if (( $(echo "$mem_value > $memory_threshold" | bc -l 2>/dev/null || echo "0") )); then
                echo "  WARNING: $name - Memory: $mem"
                add_finding "resources" "${name}_memory" "warning" "High memory usage: $mem" "Check memory leaks or increase limits"
                high_memory_containers=$((high_memory_containers + 1))
            fi
        fi
    done

    if [ "$high_cpu_containers" -eq 0 ] && [ "$high_memory_containers" -eq 0 ]; then
        add_finding "resources" "high_usage" "pass" "No containers with excessive resource usage" ""
    fi
}

################################################################################
# Container Health Check
################################################################################
check_container_health() {
    echo "Checking container health..."

    # Get containers with health status
    local health_output
    health_output=$(docker ps --format "json" 2>/dev/null | jq -r '[.[] | select(.Health != "")]' || echo "[]")

    local unhealthy_count=$(echo "$health_output" | jq '[.[] | select(.Health == "unhealthy")] | length')

    if [ "$unhealthy_count" -gt 0 ]; then
        echo "$health_output" | jq -r '.[] | select(.Health == "unhealthy") | "\(.Names) \(.Health)"' | while read -r name health; do
            echo "  ERROR: Container $name is unhealthy"
            add_finding "health" "$name" "critical" "Container is unhealthy" "Check logs and health check configuration"
        done
    else
        echo "  All containers with health checks are healthy"
        add_finding "health" "overall" "pass" "All containers healthy" ""
    fi
}

################################################################################
# Image Check
################################################################################
check_images() {
    echo "Checking images..."

    local dangling_images=$(docker images -f "dangling=true" --format "{{.ID}}" | wc -l)
    local total_images=$(docker images --format "{{.ID}}" | wc -l)

    echo "  Total images: $total_images"
    echo "  Dangling images: $dangling_images"

    if [ "$dangling_images" -gt 0 ]; then
        add_finding "images" "dangling" "warning" "$dangling_images dangling image(s) found" "Clean with: docker image prune"
    else
        add_finding "images" "dangling" "pass" "No dangling images" ""
    fi

    # Check for old images (not used by any container)
    local used_images=$(docker ps -a --format "{{.Image}}" | sort -u)
    local unused_count=0

    # This is a simplified check - in reality, you'd need to track image usage more carefully
    add_finding "images" "total" "pass" "Total images: $total_images" ""
}

################################################################################
# Network Check
################################################################################
check_networks() {
    echo "Checking networks..."

    local network_count=$(docker network ls --format "{{.Name}}" | wc -l)
    echo "  Networks: $network_count"

    add_finding "networks" "count" "pass" "Total networks: $network_count" ""

    # Check for custom networks
    local custom_networks=$(docker network ls --filter "type=custom" --format "{{.Name}}" | wc -l)
    echo "  Custom networks: $custom_networks"

    if [ "$custom_networks" -eq 0 ]; then
        add_finding "networks" "custom" "info" "No custom networks defined" "Consider creating custom networks for isolation"
    fi
}

################################################################################
# Volume Check
################################################################################
check_volumes() {
    echo "Checking volumes..."

    local volume_count=$(docker volume ls --format "{{.Name}}" | wc -l)
    echo "  Volumes: $volume_count"

    add_finding "volumes" "count" "pass" "Total volumes: $volume_count" ""

    # Check for unused volumes
    local dangling_volumes=$(docker volume ls -f "dangling=true" --format "{{.Name}}" | wc -l)
    echo "  Unused volumes: $dangling_volumes"

    if [ "$dangling_volumes" -gt 0 ]; then
        add_finding "volumes" "unused" "warning" "$dangling_volumes unused volume(s)" "Clean with: docker volume prune"
    else
        add_finding "volumes" "unused" "pass" "No unused volumes" ""
    fi
}

################################################################################
# Recent Errors Check
################################################################################
check_recent_errors() {
    echo "Checking for recent errors..."

    local error_count=0

    # Get running containers
    local running_containers=$(docker ps --format "{{.Names}}")

    for container in $running_containers; do
        # Check last 50 lines for errors
        local errors=$(docker logs --tail 50 "$container" 2>&1 | grep -i "error" | wc -l)
        if [ "$errors" -gt 0 ]; then
            echo "  WARNING: $container - $errors error(s) in recent logs"
            add_finding "logs" "${container}_errors" "warning" "$errors error(s) in recent logs" "Review logs: docker logs $container"
            error_count=$((error_count + 1))
        fi
    done

    if [ "$error_count" -eq 0 ]; then
        add_finding "logs" "recent_errors" "pass" "No errors in recent container logs" ""
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    echo "=== Docker Diagnostic Scan ==="
    echo "Timestamp: $TIMESTAMP"
    if [ -n "$CONTAINER_FILTER" ]; then
        echo "Container filter: $CONTAINER_FILTER"
    fi
    echo ""

    # Run all checks
    check_docker_daemon || exit 1
    check_container_status
    check_container_resources
    check_container_health
    check_images
    check_networks
    check_volumes
    check_recent_errors

    # Output JSON report
    echo ""
    echo "=== JSON Report ==="
    echo "$json_output" | jq '.'

    # Check for critical issues
    local critical=$(echo "$json_output" | jq '[.checks[][] | select(.status == "critical")] | length')
    if [ "$critical" -gt 0 ]; then
        exit 1
    fi

    exit 0
}

main "$@"
