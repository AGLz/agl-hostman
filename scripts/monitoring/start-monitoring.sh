#!/bin/bash
# Start Monitoring Stack - AGL Hostman
# This script starts the complete monitoring and observability stack

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

# Function to check if Docker is running
check_docker() {
    if ! command_exists docker; then
        print_error "Docker is not installed"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi

    print_info "Docker is running"
}

# Function to check if Docker Compose is available
check_docker_compose() {
    if command_exists docker-compose; then
        DOCKER_COMPOSE="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    else
        print_error "Docker Compose is not installed"
        exit 1
    fi

    print_info "Using Docker Compose: $DOCKER_COMPOSE"
}

# Function to create .env file if it doesn't exist
setup_env_file() {
    local env_file="${MONITORING_DIR}/.env"

    if [ ! -f "$env_file" ]; then
        print_info "Creating .env file from template"
        cp "${MONITORING_DIR}/.env.example" "$env_file"

        # Generate random passwords
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
        GRAFANA_DB_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

        # Update .env file
        sed -i "s/changeme/${GRAFANA_ADMIN_PASSWORD}/g" "$env_file"
        sed -i "s/changeme_db_password/${GRAFANA_DB_PASSWORD}/g" "$env_file"

        print_warning "Generated random passwords. Please update .env file with your configuration."
        print_warning "Grafana admin password: ${GRAFANA_ADMIN_PASSWORD}"
    else
        print_info ".env file already exists"
    fi
}

# Function to create necessary directories
create_directories() {
    print_info "Creating monitoring directories"

    mkdir -p "${MONITORING_DIR}/prometheus/data"
    mkdir -p "${MONITORING_DIR}/grafana/data"
    mkdir -p "${MONITORING_DIR}/alertmanager/data"
    mkdir -p "${MONITORING_DIR}/loki/data"
    mkdir -p "${MONITORING_DIR}/jaeger/data"
    mkdir -p "${MONITORING_DIR}/node-exporter/textfile"

    # Set permissions for Grafana data
    chmod 777 "${MONITORING_DIR}/grafana/data"

    print_info "Directories created"
}

# Function to check if ports are available
check_ports() {
    local ports=(9090 3000 9093 3100 16686 9100 8080)
    local occupied_ports=()

    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            occupied_ports+=($port)
        fi
    done

    if [ ${#occupied_ports[@]} -gt 0 ]; then
        print_warning "The following ports are already in use: ${occupied_ports[*]}"
        print_warning "Please stop the services using these ports or modify the port mappings in docker-compose.monitoring.yml"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to start monitoring stack
start_monitoring() {
    print_info "Starting monitoring stack..."

    cd "$MONITORING_DIR"

    $DOCKER_COMPOSE -f docker-compose.monitoring.yml up -d

    print_info "Monitoring stack started"
}

# Function to wait for services to be healthy
wait_for_services() {
    print_info "Waiting for services to be ready..."

    local services=(
        "prometheus:9090"
        "grafana:3000"
        "alertmanager:9093"
        "loki:3100"
        "jaeger:16686"
    )

    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        local max_attempts=30
        local attempt=1

        while [ $attempt -le $max_attempts ]; do
            if curl -s "http://localhost:$port" >/dev/null 2>&1; then
                print_info "$name is ready"
                break
            fi

            if [ $attempt -eq $max_attempts ]; then
                print_warning "$name did not become ready in time"
            fi

            sleep 2
            ((attempt++))
        done
    done
}

# Function to display service URLs
display_urls() {
    print_info "Monitoring stack is ready!"
    echo ""
    echo "Service URLs:"
    echo "  Prometheus:  http://localhost:9090"
    echo "  Grafana:     http://localhost:3000 (admin/PASSWORD from .env)"
    echo "  Alertmanager: http://localhost:9093"
    echo "  Loki:        http://localhost:3100"
    echo "  Jaeger:      http://localhost:16686"
    echo "  Node Exporter: http://localhost:9100/metrics"
    echo "  cAdvisor:    http://localhost:8080"
    echo ""
}

# Function to run health checks
run_health_checks() {
    print_info "Running health checks..."

    # Check Prometheus targets
    print_info "Checking Prometheus targets..."
    local targets=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health=="up") | .labels.job' | wc -l)
    print_info "Active Prometheus targets: $targets"

    # Check Grafana datasources
    print_info "Checking Grafana datasources..."
    local datasources=$(curl -s http://admin:$(grep GRAFANA_ADMIN_PASSWORD ${MONITORING_DIR}/.env | cut -d= -f2)@localhost:3000/api/datasources | jq -r '.[] | .name' | wc -l)
    print_info "Configured Grafana datasources: $datasources"

    print_info "Health checks complete"
}

# Function to display logs
show_logs() {
    print_info "Showing logs (Ctrl+C to exit)..."
    cd "$MONITORING_DIR"
    $DOCKER_COMPOSE -f docker-compose.monitoring.yml logs -f
}

# Main execution
main() {
    print_info "AGL Hostman - Monitoring Stack Startup"
    echo ""

    check_docker
    check_docker_compose
    setup_env_file
    create_directories
    check_ports
    start_monitoring
    wait_for_services
    display_urls
    run_health_checks

    # Ask if user wants to see logs
    echo ""
    read -p "View logs? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        show_logs
    fi
}

# Run main function
main
