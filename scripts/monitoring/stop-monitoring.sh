#!/bin/bash
# Stop Monitoring Stack - AGL Hostman
# This script stops the monitoring and observability stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MONITORING_DIR="${PROJECT_ROOT}/docker/monitoring"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check which Docker Compose to use
get_docker_compose() {
    if command_exists docker-compose; then
        echo "docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        print_error "Docker Compose is not installed"
        exit 1
    fi
}

# Function to stop monitoring stack
stop_monitoring() {
    local docker_compose=$(get_docker_compose)

    print_info "Stopping monitoring stack..."

    cd "$MONITORING_DIR"

    if [ "$1" == "--volumes" ]; then
        print_warning "Removing volumes as well..."
        $docker_compose -f docker-compose.monitoring.yml down -v
    else
        $docker_compose -f docker-compose.monitoring.yml down
    fi

    print_info "Monitoring stack stopped"
}

# Function to show status
show_status() {
    local docker_compose=$(get_docker_compose)

    print_info "Checking status..."

    cd "$MONITORING_DIR"

    local running=$($docker_compose -f docker-compose.monitoring.yml ps -q | wc -l)

    if [ "$running" -eq 0 ]; then
        print_info "No monitoring services are running"
    else
        print_warning "Some monitoring services are still running:"
        $docker_compose -f docker-compose.monitoring.yml ps
    fi
}

# Main execution
main() {
    print_info "AGL Hostman - Monitoring Stack Shutdown"
    echo ""

    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        echo "Usage: $0 [--volumes]"
        echo ""
        echo "Options:"
        echo "  --volumes    Remove volumes as well (WARNING: This will delete all monitoring data)"
        echo "  --help       Show this help message"
        exit 0
    fi

    stop_monitoring "$1"
    show_status

    echo ""
    print_info "Done!"
}

# Run main function
main "$@"
