#!/bin/bash

################################################################################
# Hive Mind Docker Runner
# Quick script to build and run Hive Mind Worker Pool in Docker
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="${PROJECT_ROOT}/docker/hive-mind"

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi

    log_success "Docker is installed and running"
}

check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi

    log_success "Docker Compose found: ${COMPOSE_CMD}"
}

################################################################################
# Main Functions
################################################################################

build_container() {
    log_info "Building Hive Mind container..."

    cd "${PROJECT_ROOT}"

    if [ "${COMPOSE_CMD:-}" ]; then
        ${COMPOSE_CMD} -f "${DOCKER_DIR}/docker-compose.yml" build
    else
        docker build -t agl-hive-mind:latest -f "${DOCKER_DIR}/Dockerfile" .
    fi

    log_success "Container built successfully"
}

start_container() {
    log_info "Starting Hive Mind container..."

    cd "${PROJECT_ROOT}"

    ${COMPOSE_CMD} -f "${DOCKER_DIR}/docker-compose.yml" up -d

    log_success "Container started successfully"

    # Wait for health check
    log_info "Waiting for container to be healthy..."
    sleep 5

    local health_status
    health_status=$(docker inspect agl-hive-mind --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")

    if [ "${health_status}" = "healthy" ]; then
        log_success "Container is healthy and ready"
    else
        log_warning "Container health status: ${health_status}"
    fi
}

stop_container() {
    log_info "Stopping Hive Mind container..."

    ${COMPOSE_CMD} -f "${DOCKER_DIR}/docker-compose.yml" down

    log_success "Container stopped"
}

restart_container() {
    log_info "Restarting Hive Mind container..."

    ${COMPOSE_CMD} -f "${DOCKER_DIR}/docker-compose.yml" restart

    log_success "Container restarted"
}

show_logs() {
    log_info "Showing container logs (Ctrl+C to exit)..."

    ${COMPOSE_CMD} -f "${DOCKER_DIR}/docker-compose.yml" logs -f hive-mind
}

exec_shell() {
    log_info "Opening interactive shell in container..."

    docker exec -it agl-hive-mind sh
}

exec_node() {
    log_info "Opening Node.js REPL with Hive Mind preloaded..."

    docker exec -it agl-hive-mind node -e "
const { HiveMindWorkerPool, AgentTemplates, PerformanceMonitor } = require('./src/hive-mind-integration');
console.log('=== Hive Mind Worker Pool Loaded ===');
console.log('Available:');
console.log('  - HiveMindWorkerPool');
console.log('  - AgentTemplates');
console.log('  - PerformanceMonitor');
console.log('');
console.log('Example:');
console.log('  const pool = new HiveMindWorkerPool();');
console.log('  pool.getAvailableAgentTypes();');
console.log('');
"
}

run_tests() {
    log_info "Running Hive Mind tests in container..."

    docker exec agl-hive-mind node tests/hive-mind/test-hive-mind-integration.js

    log_success "Tests completed"
}

run_example() {
    local example_file="$1"

    log_info "Running example: ${example_file}..."

    if [ -f "${PROJECT_ROOT}/examples/${example_file}" ]; then
        docker exec agl-hive-mind node "examples/${example_file}"
    else
        log_error "Example file not found: ${example_file}"
        exit 1
    fi
}

show_status() {
    log_info "Container status:"

    docker ps -a --filter "name=agl-hive-mind" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"

    echo ""
    log_info "Health status:"

    local health_status
    health_status=$(docker inspect agl-hive-mind --format='{{.State.Health.Status}}' 2>/dev/null || echo "container not found")
    echo "  Health: ${health_status}"

    echo ""
    log_info "Resource usage:"

    docker stats agl-hive-mind --no-stream 2>/dev/null || log_warning "Container is not running"
}

cleanup() {
    log_warning "Cleaning up Hive Mind containers and volumes..."

    read -p "Are you sure? This will remove all data (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${COMPOSE_CMD} -f "${DOCKER_DIR}/docker-compose.yml" down -v
        log_success "Cleanup completed"
    else
        log_info "Cleanup cancelled"
    fi
}

################################################################################
# Usage
################################################################################

show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  build         Build the Hive Mind Docker container
  start         Start the container
  stop          Stop the container
  restart       Restart the container
  logs          Show container logs (follow mode)
  shell         Open interactive shell in container
  node          Open Node.js REPL with Hive Mind loaded
  test          Run test suite
  example FILE  Run example file (e.g., hive-mind-parallel-agents.js)
  status        Show container status and resource usage
  cleanup       Stop container and remove volumes (destructive)

Examples:
  $0 build              # Build container
  $0 start              # Start container
  $0 logs               # View logs
  $0 node               # Interactive Node.js REPL
  $0 test               # Run tests
  $0 example hive-mind-parallel-agents.js

EOF
}

################################################################################
# Main Script
################################################################################

main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    local command="$1"
    shift

    # Check Docker before proceeding
    check_docker

    case "${command}" in
        build)
            check_docker_compose
            build_container
            ;;
        start)
            check_docker_compose
            start_container
            ;;
        stop)
            check_docker_compose
            stop_container
            ;;
        restart)
            check_docker_compose
            restart_container
            ;;
        logs)
            check_docker_compose
            show_logs
            ;;
        shell)
            exec_shell
            ;;
        node)
            exec_node
            ;;
        test)
            run_tests
            ;;
        example)
            if [ $# -eq 0 ]; then
                log_error "Please specify an example file"
                exit 1
            fi
            run_example "$1"
            ;;
        status)
            show_status
            ;;
        cleanup)
            check_docker_compose
            cleanup
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: ${command}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
