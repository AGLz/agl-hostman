#!/bin/bash
# Ollama Stack Monitoring Script
# Real-time monitoring of GPU, containers, and services

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
STACK_DIR="/opt/ollama-stack"
REFRESH_INTERVAL=2
LOG_FILE="/var/log/ollama-monitor.log"

# Check if running
if [[ ! -d "$STACK_DIR" ]]; then
    echo "❌ Ollama stack not found in $STACK_DIR"
    exit 1
fi

cd "$STACK_DIR"

# Functions
check_service() {
    local name=$1
    local url=$2

    if curl -sf "$url" &> /dev/null; then
        echo -e "${GREEN}●${NC} $name"
    else
        echo -e "${RED}●${NC} $name"
    fi
}

get_gpu_stats() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw \
            --format=csv,noheader,nounits 2>/dev/null
    else
        echo "N/A,N/A,N/A,N/A,N/A,N/A"
    fi
}

get_container_stats() {
    local container=$1
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        docker stats "$container" --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null
    else
        echo "N/A,N/A"
    fi
}

get_ollama_models() {
    if curl -sf http://localhost:11434/api/ps &> /dev/null; then
        curl -s http://localhost:11434/api/ps | jq -r '.models[] | "\(.name) (\(.size_vram/1024/1024/1024 | floor)GB)"' 2>/dev/null || echo "None"
    else
        echo "API Unavailable"
    fi
}

print_header() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Ollama Stack Monitor - CT200                           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') | Press Ctrl+C to exit | Refresh: ${REFRESH_INTERVAL}s"
    echo ""
}

print_services() {
    echo -e "${YELLOW}━━━ Services ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    check_service "Ollama API      " "http://localhost:11434/api/tags"
    check_service "Open WebUI      " "http://localhost:3000"
    check_service "LiteLLM Proxy   " "http://localhost:4000/health"

    echo ""
}

print_gpu() {
    echo -e "${YELLOW}━━━ GPU Status ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    IFS=',' read -r gpu_name mem_used mem_total gpu_util temp power <<< "$(get_gpu_stats)"

    if [[ "$gpu_name" != "N/A" ]]; then
        mem_percent=$(awk "BEGIN {printf \"%.1f\", ($mem_used/$mem_total)*100}")

        echo -e "${BLUE}GPU:${NC}         $gpu_name"
        echo -e "${BLUE}Memory:${NC}      ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"
        echo -e "${BLUE}Utilization:${NC} ${gpu_util}%"
        echo -e "${BLUE}Temperature:${NC} ${temp}°C"
        echo -e "${BLUE}Power:${NC}       ${power}W"
    else
        echo -e "${RED}GPU not available${NC}"
    fi

    echo ""
}

print_containers() {
    echo -e "${YELLOW}━━━ Containers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    for container in ollama open-webui litellm; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            status=$(docker ps --filter "name=^${container}$" --format "{{.Status}}")
            IFS=',' read -r cpu mem <<< "$(get_container_stats "$container")"

            echo -e "${GREEN}●${NC} ${BLUE}${container}${NC}"
            echo -e "  Status: ${status}"
            echo -e "  CPU: ${cpu}  Memory: ${mem}"
        else
            echo -e "${RED}●${NC} ${BLUE}${container}${NC}"
            echo -e "  Status: ${RED}Not running${NC}"
        fi
        echo ""
    done
}

print_models() {
    echo -e "${YELLOW}━━━ Loaded Models ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    models=$(get_ollama_models)
    if [[ "$models" == "None" ]] || [[ "$models" == "API Unavailable" ]]; then
        echo -e "${MAGENTA}No models currently loaded${NC}"
    else
        echo "$models" | while read -r model; do
            echo -e "${MAGENTA}→${NC} $model"
        done
    fi

    echo ""
}

print_stats() {
    echo -e "${YELLOW}━━━ Statistics ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Available models
    total_models=$(ollama list 2>/dev/null | tail -n +2 | wc -l)
    echo -e "${BLUE}Available Models:${NC} $total_models"

    # Disk usage
    if [[ -d "$STACK_DIR/data" ]]; then
        disk_usage=$(du -sh "$STACK_DIR/data" | cut -f1)
        echo -e "${BLUE}Data Directory:${NC}   $disk_usage"
    fi

    # Uptime
    if docker ps --filter "name=^ollama$" --format "{{.Status}}" | grep -q "Up"; then
        uptime=$(docker ps --filter "name=^ollama$" --format "{{.Status}}" | grep -oP 'Up \K[^(]+')
        echo -e "${BLUE}Ollama Uptime:${NC}    $uptime"
    fi

    echo ""
}

print_quick_actions() {
    echo -e "${YELLOW}━━━ Quick Actions ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}1.${NC} View Logs        : $STACK_DIR/logs.sh"
    echo -e "${CYAN}2.${NC} Restart Stack    : $STACK_DIR/restart.sh"
    echo -e "${CYAN}3.${NC} Check Health     : $STACK_DIR/status.sh"
    echo ""
}

# Main monitoring loop
main() {
    trap 'echo -e "\n\n${CYAN}Monitoring stopped${NC}"; exit 0' INT TERM

    while true; do
        print_header
        print_services
        print_gpu
        print_containers
        print_models
        print_stats
        print_quick_actions

        # Log to file
        {
            echo "=== $(date) ==="
            echo "GPU: $(get_gpu_stats)"
            echo "Loaded Models: $(get_ollama_models)"
            echo ""
        } >> "$LOG_FILE"

        sleep "$REFRESH_INTERVAL"
    done
}

# Show help
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Ollama Stack Monitor"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -i SECONDS     Set refresh interval (default: $REFRESH_INTERVAL)"
    echo ""
    echo "Examples:"
    echo "  $0              # Monitor with default settings"
    echo "  $0 -i 5         # Monitor with 5 second refresh"
    exit 0
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i)
            REFRESH_INTERVAL=$2
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check dependencies
for cmd in docker nvidia-smi curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Required command not found: $cmd"
        exit 1
    fi
done

# Run monitor
main
