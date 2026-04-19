#!/bin/bash
# Docker Network Configuration Script
# Configure custom Docker networks with DNS, subnet, and isolation
#
# Usage:
#   ./docker-network-setup.sh create [network-name] [subnet]
#   ./docker-network-setup.sh create frontend 172.20.0.0/24
#   ./docker-network-setup.sh delete [network-name]
#   ./docker-network-setup.sh list

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create custom bridge network
create_bridge_network() {
    local network_name="$1"
    local subnet="${2:-172.20.0.0/16}"
    local gateway="${3:-172.20.0.1}"
    local bridge_name="${network_name}_br"

    log_info "Creating bridge network: $network_name"

    # Check if network already exists
    if docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name already exists"
        return 0
    fi

    # Create network with custom configuration
    docker network create \
        --driver bridge \
        --subnet="$subnet" \
        --gateway="$gateway" \
        --opt "com.docker.network.bridge.name"="$bridge_name" \
        --opt "com.docker.network.bridge.enable_icc"="true" \
        --opt "com.docker.network.bridge.enable_ip_masquerade"="true" \
        "$network_name"

    log_success "Network $network_name created (subnet: $subnet, gateway: $gateway)"
}

# Create isolated network (no external access)
create_isolated_network() {
    local network_name="$1"
    local subnet="${2:-172.21.0.0/16}"

    log_info "Creating isolated network: $network_name"

    if docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name already exists"
        return 0
    fi

    docker network create \
        --driver bridge \
        --subnet="$subnet" \
        --internal \
        "$network_name"

    log_success "Isolated network $network_name created (no external access)"
}

# Create overlay network (Swarm mode)
create_overlay_network() {
    local network_name="$1"
    local subnet="${2:-10.0.0.0/24}"

    log_info "Creating overlay network: $network_name"

    # Check if swarm is initialized
    if ! docker info | grep -q "Swarm: active"; then
        log_warning "Swarm mode is not active. Initialize with: docker swarm init"
        return 1
    fi

    if docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name already exists"
        return 0
    fi

    docker network create \
        --driver overlay \
        --subnet="$subnet" \
        --attachable \
        "$network_name"

    log_success "Overlay network $network_name created"
}

# Configure DNS for network
configure_dns() {
    local network_name="$1"
    local dns_servers="${2:-8.8.8.8 8.8.4.4}"

    log_info "Configuring DNS for network: $network_name"

    if ! docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name does not exist"
        return 1
    fi

    # Note: DNS configuration is typically done per container
    log_info "DNS servers: $dns_servers (configure in docker-compose.yml)"
}

# Create macvlan network (direct host access)
create_macvlan_network() {
    local network_name="$1"
    local subnet="${2:-192.168.1.0/24}"
    local gateway="${3:-192.168.1.1}"
    local interface="${4:-eth0}"

    log_info "Creating macvlan network: $network_name"

    if docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name already exists"
        return 0
    fi

    docker network create \
        --driver macvlan \
        --subnet="$subnet" \
        --gateway="$gateway" \
        -o parent="$interface" \
        "$network_name"

    log_success "Macvlan network $network_name created"
}

# Connect container to network
connect_container() {
    local container_name="$1"
    local network_name="$2"
    local alias="${3:-}"

    log_info "Connecting $container_name to $network_name"

    if ! docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name does not exist"
        return 1
    fi

    if ! docker inspect "$container_name" &> /dev/null; then
        log_warning "Container $container_name does not exist"
        return 1
    fi

    local connect_cmd="docker network connect $network_name $container_name"
    if [[ -n "$alias" ]]; then
        connect_cmd="$connect_cmd --alias $alias"
    fi

    eval "$connect_cmd"

    log_success "Container $container_name connected to $network_name"
}

# Disconnect container from network
disconnect_container() {
    local container_name="$1"
    local network_name="$2"

    log_info "Disconnecting $container_name from $network_name"

    docker network disconnect "$network_name" "$container_name"

    log_success "Container $container_name disconnected"
}

# Delete network
delete_network() {
    local network_name="$1"

    log_info "Deleting network: $network_name"

    if ! docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name does not exist"
        return 0
    fi

    docker network rm "$network_name"

    log_success "Network $network_name deleted"
}

# List all networks
list_networks() {
    log_info "Docker networks:"

    docker network ls

    echo ""
    log_info "Detailed network information:"
    echo ""

    while IFS= read -r network; do
        local network_name
        network_name=$(echo "$network" | awk '{print $2}')

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Network: $network_name"

        docker network inspect "$network_name" --format '  Driver: {{.Driver}}
  Scope: {{.Scope}}
  Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}
  Gateway: {{range .IPAM.Config}}{{.Gateway}}{{end}}
  Internal: {{.Internal}}
  Containers: {{len .Containers}}'

        if [[ $(docker network inspect "$network_name" --format '{{len .Containers}}') -gt 0 ]]; then
            echo "  Connected containers:"
            docker network inspect "$network_name" --format '{{range .Containers}}    - {{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}' | sed 's/$/  /'
        fi

        echo ""
    done < <(docker network ls --format "{{.Name}}")
}

# Inspect network
inspect_network() {
    local network_name="$1"

    if ! docker network inspect "$network_name" &> /dev/null; then
        log_warning "Network $network_name does not exist"
        return 1
    fi

    log_info "Network details for: $network_name"
    docker network inspect "$network_name" --format 'json' | jq -r '.
    '
}

# Prune unused networks
prune_networks() {
    log_info "Pruning unused networks..."

    docker network prune -f

    log_success "Unused networks removed"
}

# Setup complete application network topology
setup_app_networks() {
    local project_name="${1:-myapp}"

    log_info "Setting up application network topology for: $project_name"

    # Frontend network (public-facing)
    create_bridge_network "${project_name}-frontend" "172.20.0.0/24" "172.20.0.1"

    # Backend network (internal services)
    create_isolated_network "${project_name}-backend" "172.20.1.0/24"

    # Database network (highly isolated)
    create_isolated_network "${project_name}-database" "172.20.2.0/24"

    log_success "Application network topology created"
}

# Display usage
usage() {
    cat << EOF
Docker Network Configuration Script

Usage:
  $0 create <network-name> [subnet] [gateway]  Create bridge network
  $0 isolated <network-name> [subnet]           Create isolated network
  $0 overlay <network-name> [subnet]            Create overlay network (Swarm)
  $0 macvlan <network-name> <subnet> <gateway> <interface>  Create macvlan network
  $0 connect <container> <network> [alias]      Connect container to network
  $0 disconnect <container> <network>           Disconnect container from network
  $0 delete <network-name>                      Delete a network
  $0 list                                       List all networks
  $0 inspect <network-name>                     Inspect network details
  $0 prune                                      Remove unused networks
  $0 setup <project-name>                       Setup complete app topology

Examples:
  $0 create frontend 172.20.0.0/24
  $0 isolated backend 172.20.1.0/24
  $0 connect myapp-app frontend
  $0 setup myapp
  $0 list
EOF
}

# Main
case "${1:-}" in
    create)
        create_bridge_network "$2" "${3:-}" "${4:-}"
        ;;
    isolated)
        create_isolated_network "$2" "${3:-}"
        ;;
    overlay)
        create_overlay_network "$2" "${3:-}"
        ;;
    macvlan)
        create_macvlan_network "$2" "${3:-}" "${4:-}" "${5:-}"
        ;;
    connect)
        connect_container "$2" "$3" "${4:-}"
        ;;
    disconnect)
        disconnect_container "$2" "$3"
        ;;
    delete)
        delete_network "$2"
        ;;
    list|"")
        list_networks
        ;;
    inspect)
        inspect_network "$2"
        ;;
    prune)
        prune_networks
        ;;
    setup)
        setup_app_networks "$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac
