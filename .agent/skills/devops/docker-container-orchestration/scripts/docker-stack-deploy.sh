#!/bin/bash
# Docker Stack Deployment Script
# Deploy multi-container Docker stack with health checks
#
# Usage:
#   ./docker-stack-deploy.sh [environment]
#   ./docker-stack-deploy.sh production
#   ./docker-stack-deploy.sh development

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-development}"
COMPOSE_FILE="docker-compose.yml"
PROJECT_NAME="$(basename "$(pwd)")"
MAX_RETRIES=30
RETRY_INTERVAL=5

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

# Load environment variables
load_env() {
    local env_file=".env.${ENVIRONMENT}"
    if [[ -f "$env_file" ]]; then
        log_info "Loading environment from $env_file"
        set -a
        source "$env_file"
        set +a
    elif [[ -f ".env" ]]; then
        log_info "Loading environment from .env"
        set -a
        source .env
        set +a
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        exit 1
    fi

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Build images
build_images() {
    log_info "Building Docker images for $ENVIRONMENT environment..."

    local compose_files="$COMPOSE_FILE"
    if [[ -f "docker-compose.${ENVIRONMENT}.yml" ]]; then
        compose_files="$compose_files -f docker-compose.${ENVIRONMENT}.yml"
    fi

    # shellcheck disable=SC2086
    docker compose -f $compose_files -p "$PROJECT_NAME" build --no-cache --parallel

    log_success "Images built successfully"
}

# Pull latest images
pull_images() {
    log_info "Pulling latest images..."

    local compose_files="$COMPOSE_FILE"
    if [[ -f "docker-compose.${ENVIRONMENT}.yml" ]]; then
        compose_files="$compose_files -f docker-compose.${ENVIRONMENT}.yml"
    fi

    # shellcheck disable=SC2086
    docker compose -f $compose_files -p "$PROJECT_NAME" pull

    log_success "Images pulled successfully"
}

# Deploy stack
deploy_stack() {
    log_info "Deploying Docker stack..."

    local compose_files="$COMPOSE_FILE"
    if [[ -f "docker-compose.${ENVIRONMENT}.yml" ]]; then
        compose_files="$compose_files -f docker-compose.${ENVIRONMENT}.yml"
    fi

    # Stop existing containers
    # shellcheck disable=SC2086
    docker compose -f $compose_files -p "$PROJECT_NAME" down

    # Start new containers
    # shellcheck disable=SC2086
    docker compose -f $compose_files -p "$PROJECT_NAME" up -d

    log_success "Stack deployed successfully"
}

# Health check for a service
check_service_health() {
    local service="$1"
    local container_name
    container_name=$(docker compose -p "$PROJECT_NAME" ps -q "$service" | xargs docker inspect --format '{{.Name}}' | head -1 | sed 's/\///')

    if [[ -z "$container_name" ]]; then
        log_error "Container for service $service not found"
        return 1
    fi

    log_info "Checking health for $service ($container_name)..."

    local retries=0
    while [[ $retries -lt $MAX_RETRIES ]]; do
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "starting")

        case "$health_status" in
            healthy)
                log_success "$service is healthy"
                return 0
                ;;
            unhealthy)
                log_error "$service is unhealthy"
                docker logs --tail 50 "$container_name"
                return 1
                ;;
            starting|*)
                retries=$((retries + 1))
                log_info "Waiting for $service to be healthy... ($retries/$MAX_RETRIES)"
                sleep "$RETRY_INTERVAL"
                ;;
        esac
    done

    log_error "Health check timed out for $service"
    return 1
}

# Run health checks
run_health_checks() {
    log_info "Running health checks..."

    local compose_files="$COMPOSE_FILE"
    if [[ -f "docker-compose.${ENVIRONMENT}.yml" ]]; then
        compose_files="$compose_files -f docker-compose.${ENVIRONMENT}.yml"
    fi

    # Get list of services with health checks
    local services
    services=$(docker compose -f $compose_files -p "$PROJECT_NAME" config --services)

    local failed_services=()

    for service in $services; do
        if ! check_service_health "$service"; then
            failed_services+=("$service")
        fi
    done

    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_error "Health checks failed for services: ${failed_services[*]}"
        return 1
    fi

    log_success "All services are healthy"
    return 0
}

# Display status
display_status() {
    log_info "Container status:"
    docker compose -p "$PROJECT_NAME" ps
}

# Cleanup old resources
cleanup_old_resources() {
    log_info "Cleaning up old resources..."

    # Remove dangling images
    docker image prune -f

    # Remove unused volumes older than 7 days
    docker volume prune -f --filter "until=168h"

    # Remove unused networks
    docker network prune -f

    log_success "Cleanup completed"
}

# Main deployment flow
main() {
    log_info "Starting Docker stack deployment for $ENVIRONMENT environment..."
    log_info "Project: $PROJECT_NAME"

    check_prerequisites
    load_env

    if [[ "$ENVIRONMENT" == "production" ]]; then
        pull_images
    else
        build_images
    fi

    deploy_stack

    if run_health_checks; then
        display_status
        log_success "Deployment completed successfully!"
        cleanup_old_resources
    else
        log_error "Deployment failed!"
        exit 1
    fi
}

# Run main function
main "$@"
