#!/bin/bash
# Helper script for deploying agl-hostman to Dokploy
# This script assists with building, pushing, and deploying the application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-harbor.aglz.io:5000}"
HARBOR_PROJECT="${HARBOR_PROJECT:-dev}"
IMAGE_NAME="${IMAGE_NAME:-agl-hostman}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"

# Function to print status
print_status() {
    echo -e "${YELLOW}➜${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build           Build Docker image"
    echo "  push            Push image to Harbor registry"
    echo "  deploy          Build and push image"
    echo "  info            Show deployment information"
    echo "  check-harbor    Check Harbor registry status"
    echo "  login           Login to Harbor registry"
    echo "  logs            Show application logs in Dokploy"
    echo "  status          Show application status"
    echo "  help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  HARBOR_REGISTRY   Harbor registry URL (default: harbor.aglz.io:5000)"
    echo "  HARBOR_PROJECT    Harbor project name (default: dev)"
    echo "  IMAGE_NAME        Image name (default: agl-hostman)"
    echo "  IMAGE_TAG         Image tag (default: latest)"
    echo ""
    echo "Examples:"
    echo "  $0 build                          # Build image with default tag (latest)"
    echo "  IMAGE_TAG=v1.0.0 $0 deploy        # Build and push with tag v1.0.0"
    echo "  $0 check-harbor                   # Verify Harbor is accessible"
    exit 1
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
}

# Check Harbor registry status
check_harbor() {
    print_status "Checking Harbor registry status..."

    # Check if Harbor is reachable
    if ping -c 1 -W 2 harbor.aglz.io &> /dev/null; then
        print_success "Harbor host is reachable"
    else
        print_error "Cannot reach Harbor host"
        return 1
    fi

    # Check HTTP/HTTPS endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://harbor.aglz.io" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" != "000" ]; then
        print_info "Harbor HTTP status: $HTTP_CODE"
    else
        print_error "Cannot connect to Harbor HTTPS endpoint"
        return 1
    fi

    # Check registry endpoint
    REGISTRY_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://harbor.aglz.io:5000/v2/" 2>/dev/null || echo "000")
    if [ "$REGISTRY_CODE" = "401" ] || [ "$REGISTRY_CODE" = "200" ]; then
        print_success "Harbor registry endpoint is accessible (HTTP $REGISTRY_CODE)"
    else
        print_error "Harbor registry endpoint not accessible (HTTP $REGISTRY_CODE)"
        print_info "Note: HTTP 401 is normal, it means authentication is required"
        return 1
    fi

    print_success "Harbor registry is operational"
    return 0
}

# Login to Harbor registry
harbor_login() {
    print_status "Logging in to Harbor registry..."

    echo -e "${YELLOW}Enter Harbor credentials (or press Ctrl+C to cancel):${NC}"
    read -p "Username [admin]: " HARBOR_USER
    HARBOR_USER=${HARBOR_USER:-admin}

    read -sp "Password: " HARBOR_PASS
    echo ""

    if echo "$HARBOR_PASS" | docker login "$HARBOR_REGISTRY" -u "$HARBOR_USER" --password-stdin; then
        print_success "Successfully logged in to Harbor registry"
    else
        print_error "Failed to login to Harbor registry"
        exit 1
    fi
}

# Build Docker image
build_image() {
    print_status "Building Docker image..."

    if [ ! -f "${PROJECT_ROOT}/Dockerfile" ]; then
        print_error "Dockerfile not found at ${PROJECT_ROOT}/Dockerfile"
        print_info "Please create a Dockerfile before building"
        exit 1
    fi

    cd "$PROJECT_ROOT"

    print_info "Image: ${FULL_IMAGE}"

    if docker build -t "${FULL_IMAGE}" .; then
        print_success "Image built successfully"
        docker images "${FULL_IMAGE}"
    else
        print_error "Failed to build image"
        exit 1
    fi
}

# Push image to Harbor
push_image() {
    print_status "Pushing image to Harbor registry..."

    # Check if image exists locally
    if ! docker images "${FULL_IMAGE}" --format "{{.Repository}}" | grep -q "${IMAGE_NAME}"; then
        print_error "Image ${FULL_IMAGE} not found locally"
        print_info "Run '$0 build' first"
        exit 1
    fi

    # Check if logged in
    if ! grep -q "${HARBOR_REGISTRY}" ~/.docker/config.json 2>/dev/null; then
        print_error "Not logged in to Harbor registry"
        print_info "Run '$0 login' first"
        exit 1
    fi

    print_info "Pushing ${FULL_IMAGE}..."

    if docker push "${FULL_IMAGE}"; then
        print_success "Image pushed successfully"
        print_info "Image available at: ${FULL_IMAGE}"
        echo ""
        print_success "Deployment complete!"
        echo ""
        echo "Next steps:"
        echo "  1. Go to Dokploy UI: https://dok.aglz.io"
        echo "  2. Create/update application"
        echo "  3. Use image: ${FULL_IMAGE}"
        echo "  4. Or wait for webhook to trigger automatic deployment"
    else
        print_error "Failed to push image"
        exit 1
    fi
}

# Show deployment information
show_info() {
    echo -e "${GREEN}=== Deployment Information ===${NC}"
    echo ""
    echo "Project Root: ${PROJECT_ROOT}"
    echo "Harbor Registry: ${HARBOR_REGISTRY}"
    echo "Harbor Project: ${HARBOR_PROJECT}"
    echo "Image Name: ${IMAGE_NAME}"
    echo "Image Tag: ${IMAGE_TAG}"
    echo "Full Image: ${FULL_IMAGE}"
    echo ""
    echo "Dokploy URL: https://dok.aglz.io"
    echo "Harbor URL: https://harbor.aglz.io"
    echo ""
    echo "Docker Compose Files:"
    echo "  Development: ${PROJECT_ROOT}/examples/dokploy/docker-compose.yml"
    echo "  Production: ${PROJECT_ROOT}/examples/dokploy/docker-compose.production.yml"
    echo ""
}

# Show application logs
show_logs() {
    print_status "Showing application logs..."

    CONTAINER_NAME="${CONTAINER_NAME:-agl-hostman-dev}"

    if docker ps --filter name="${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "${CONTAINER_NAME}"; then
        print_success "Container ${CONTAINER_NAME} is running"
        echo ""
        docker logs --tail 50 -f "${CONTAINER_NAME}"
    else
        print_error "Container ${CONTAINER_NAME} not found"
        print_info "Available containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
}

# Show application status
show_status() {
    print_status "Checking application status..."

    CONTAINER_NAME="${CONTAINER_NAME:-agl-hostman-dev}"

    if docker ps --filter name="${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "${CONTAINER_NAME}"; then
        print_success "Container ${CONTAINER_NAME} is running"
        echo ""
        docker ps --filter name="${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        docker stats --no-stream "${CONTAINER_NAME}"
    else
        print_error "Container ${CONTAINER_NAME} not found or not running"
        print_info "All containers:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    fi
}

# Main script
main() {
    check_docker

    case "${1:-}" in
        build)
            build_image
            ;;
        push)
            push_image
            ;;
        deploy)
            build_image
            push_image
            ;;
        info)
            show_info
            ;;
        check-harbor)
            check_harbor
            ;;
        login)
            harbor_login
            ;;
        logs)
            show_logs
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: ${1:-}"
            echo ""
            usage
            ;;
    esac
}

# Run main function
main "$@"
