#!/bin/bash

###############################################################################
# Network Traffic Shaping (QoS) Script
# Configure traffic shaping and QoS rules for bandwidth management
#
# Usage: net-qos.sh [options]
#   -i, --interface INTERFACE  Network interface (default: wg0)
#   -l, --limit RATE            Rate limit in Mbps (e.g., 100)
#   -p, --priority PORT         Prioritize specific port (can be used multiple times)
#   -d, --dst IP                Destination IP to prioritize
#   -s, --src IP                Source IP to prioritize
#   -r, --remove                Remove all QoS rules
#   -S, --show                  Show current QoS configuration
#   -a, --apply                 Apply QoS rules (default: dry-run)
#   -v, --verbose               Verbose output
#   -h, --help                  Show this help
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Default values
INTERFACE="${QOS_INTERFACE:-wg0}"
LIMIT=""
PRIORITY_PORTS=()
DEST_IP=""
SOURCE_IP=""
REMOVE_RULES=false
SHOW_CONFIG=false
APPLY_CHANGES=false
VERBOSE=false

# QoS class IDs
ROOT_CLASS="1:"
HIGH_CLASS="1:1"
MEDIUM_CLASS="1:2"
LOW_CLASS="1:3"
DEFAULT_CLASS="1:10"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if interface exists
check_interface() {
    if ! ip link show "$INTERFACE" &> /dev/null; then
        log_error "Interface $INTERFACE does not exist"
        exit 1
    fi
}

# Check if tc is installed
check_tc() {
    if ! command -v tc &> /dev/null; then
        log_error "tc (traffic control) not installed"
        log_info "Install with: apt install iproute2"
        exit 1
    fi
}

# Show current QoS configuration
show_qos_config() {
    log_info "Current QoS Configuration for $INTERFACE"
    echo ""

    echo -e "${BOLD}Queueing Disciplines:${NC}"
    echo "────────────────────────────────────────"
    tc -s qdisc show dev "$INTERFACE"
    echo ""

    echo -e "${BOLD}Traffic Classes:${NC}"
    echo "────────────────────────────────────────"
    tc class show dev "$INTERFACE"
    echo ""

    echo -e "${BOLD}Filters:${NC}"
    echo "────────────────────────────────────────"
    tc filter show dev "$INTERFACE"
    echo ""
}

# Remove all QoS rules
remove_qos_rules() {
    log_warning "Removing all QoS rules from $INTERFACE"

    if [ "$APPLY_CHANGES" = "true" ]; then
        # Remove root qdisc (this removes all child qdiscs, classes, and filters)
        tc qdisc del dev "$INTERFACE" root 2>/dev/null || true
        log_success "QoS rules removed"
    else
        log_info "Would remove QoS rules (dry-run)"
    fi
}

# Create HTB qdisc
create_htb_qdisc() {
    log_info "Creating HTB qdisc on $INTERFACE"

    if [ "$APPLY_CHANGES" = "true" ]; then
        # Create root qdisc
        tc qdisc add dev "$INTERFACE" root handle $ROOT_CLASS htb default $DEFAULT_CLASS

        # Create root class
        if [ -n "$LIMIT" ]; then
            # Convert Mbps to Kbps
            local rate_kbps=$((LIMIT * 1000))
            tc class add dev "$INTERFACE" parent $ROOT_CLASS classid $HIGH_CLASS htb rate "${rate_kbps}kbit" ceil "${rate_kbps}kbit"
        else
            # Get interface speed
            local speed=$(ethtool "$INTERFACE" 2>/dev/null | grep -i 'Speed:' | awk '{print $2}' || echo "1000Mbps")
            local speed_num=$(echo "$speed" | sed 's/[^0-9]//g')
            tc class add dev "$INTERFACE" parent $ROOT_CLASS classid $HIGH_CLASS htb rate "${speed_num}Mbit"
        fi

        log_success "HTB qdisc created"
    else
        log_info "Would create HTB qdisc (dry-run)"
    fi
}

# Create traffic classes
create_classes() {
    log_info "Creating traffic classes"

    if [ "$APPLY_CHANGES" = "true" ]; then
        # Get interface speed for calculations
        local speed=$(ethtool "$INTERFACE" 2>/dev/null | grep -i 'Speed:' | awk '{print $2}' || echo "1000Mbps")
        local speed_num=$(echo "$speed" | sed 's/[^0-9]//g')

        if [ -n "$LIMIT" ]; then
            speed_num=$LIMIT
        fi

        # High priority class (40% bandwidth, can burst to 100%)
        tc class add dev "$INTERFACE" parent $HIGH_CLASS classid 1:10 htb rate "$((speed_num * 40 / 100))Mbit" ceil "${speed_num}Mbit" prio 0

        # Medium priority class (30% bandwidth, can burst to 70%)
        tc class add dev "$INTERFACE" parent $HIGH_CLASS classid 1:20 htb rate "$((speed_num * 30 / 100))Mbit" ceil "$((speed_num * 70 / 100))Mbit" prio 1

        # Low priority class (20% bandwidth, can burst to 50%)
        tc class add dev "$INTERFACE" parent $HIGH_CLASS classid 1:30 htb rate "$((speed_num * 20 / 100))Mbit" ceil "$((speed_num * 50 / 100))Mbit" prio 2

        # Default class (10% bandwidth)
        tc class add dev "$INTERFACE" parent $HIGH_CLASS classid $DEFAULT_CLASS htb rate "$((speed_num * 10 / 100))Mbit" ceil "$((speed_num * 30 / 100))Mbit" prio 3

        log_success "Traffic classes created"
    else
        log_info "Would create traffic classes (dry-run)"
    fi
}

# Add filter for port prioritization
add_port_filter() {
    local port=$1
    local priority=$2

    log_info "Adding filter for port $port (priority $priority)"

    if [ "$APPLY_CHANGES" = "true" ]; then
        # Determine class based on priority
        local class_id=""
        case $priority in
            0) class_id="1:10" ;;  # High
            1) class_id="1:20" ;;  # Medium
            2) class_id="1:30" ;;  # Low
            *) class_id="1:10" ;;  # Default to high
        esac

        # Add filter for both source and destination ports
        tc filter add dev "$INTERFACE" protocol ip parent 1:0 prio 1 u32 \
            match ip dport $port 0xffff flowid $class_id

        tc filter add dev "$INTERFACE" protocol ip parent 1:0 prio 1 u32 \
            match ip sport $port 0xffff flowid $class_id

        log_success "Filter added for port $port"
    else
        log_info "Would add filter for port $port (dry-run)"
    fi
}

# Add filter for IP prioritization
add_ip_filter() {
    local ip=$1
    local direction=$2  # src or dst
    local priority=$3

    log_info "Adding filter for $direction IP $ip (priority $priority)"

    if [ "$APPLY_CHANGES" = "true" ]; then
        # Determine class based on priority
        local class_id=""
        case $priority in
            0) class_id="1:10" ;;  # High
            1) class_id="1:20" ;;  # Medium
            2) class_id="1:30" ;;  # Low
            *) class_id="1:10" ;;  # Default to high
        esac

        # Add filter
        if [ "$direction" = "src" ]; then
            tc filter add dev "$INTERFACE" protocol ip parent 1:0 prio 1 u32 \
                match ip src $ip flowid $class_id
        else
            tc filter add dev "$INTERFACE" protocol ip parent 1:0 prio 1 u32 \
                match ip dst $ip flowid $class_id
        fi

        log_success "Filter added for $direction IP $ip"
    else
        log_info "Would add filter for $direction IP $ip (dry-run)"
    fi
}

# Apply common service priorities
apply_common_priorities() {
    log_info "Applying common service priorities"

    if [ "$APPLY_CHANGES" = "true" ]; then
        # SSH (high priority)
        add_port_filter 22 0

        # DNS (high priority)
        add_port_filter 53 0

        # HTTP/HTTPS (medium priority)
        add_port_filter 80 1
        add_port_filter 443 1

        # NFS (high priority for storage)
        add_port_filter 2049 0

        # Proxmox API (high priority)
        add_port_filter 8006 0

        # WireGuard (high priority for VPN)
        add_port_filter 51823 0

        log_success "Common service priorities applied"
    else
        log_info "Would apply common service priorities (dry-run)"
    fi
}

# Generate summary
show_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}QoS Configuration Summary${NC}"
    echo "────────────────────────────────────────"
    echo "Interface:       $INTERFACE"
    echo "Rate Limit:      ${LIMIT:-None (use interface speed)}"
    echo "Priority Ports:  ${PRIORITY_PORTS[*]:-None}"
    echo "Destination IP:  ${DEST_IP:-None}"
    echo "Source IP:       ${SOURCE_IP:-None}"
    echo ""
    echo "Traffic Classes:"
    echo "  1:10  High Priority    (40% bandwidth)"
    echo "  1:20  Medium Priority  (30% bandwidth)"
    echo "  1:30  Low Priority     (20% bandwidth)"
    echo "  1:99  Default          (10% bandwidth)"
    echo ""

    if [ "$APPLY_CHANGES" = "false" ]; then
        echo -e "${YELLOW}DRY-RUN MODE${NC}: Use -a to apply changes"
    else
        echo -e "${GREEN}APPLY MODE${NC}: Changes will be applied"
    fi
}

# Main execution
main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -i|--interface)
                INTERFACE="$2"
                shift 2
                ;;
            -l|--limit)
                LIMIT="$2"
                shift 2
                ;;
            -p|--priority)
                PRIORITY_PORTS+=("$2")
                shift 2
                ;;
            -d|--dst)
                DEST_IP="$2"
                shift 2
                ;;
            -s|--src)
                SOURCE_IP="$2"
                shift 2
                ;;
            -r|--remove)
                REMOVE_RULES=true
                shift
                ;;
            -S|--show)
                SHOW_CONFIG=true
                shift
                ;;
            -a|--apply)
                APPLY_CHANGES=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Network traffic shaping and QoS configuration"
                echo ""
                echo "Options:"
                echo "  -i, --interface INTERFACE  Network interface (default: wg0)"
                echo "  -l, --limit RATE            Rate limit in Mbps (e.g., 100)"
                echo "  -p, --priority PORT         Prioritize specific port"
                echo "  -d, --dst IP                Prioritize destination IP"
                echo "  -s, --src IP                Prioritize source IP"
                echo "  -r, --remove                Remove all QoS rules"
                echo "  -S, --show                  Show current QoS configuration"
                echo "  -a, --apply                 Apply QoS rules (default: dry-run)"
                echo "  -v, --verbose               Verbose output"
                echo "  -h, --help                  Show this help"
                echo ""
                echo "Examples:"
                echo "  $0 -S                          # Show current QoS config"
                echo "  $0 -i wg0 -l 100 -a            # Rate limit wg0 to 100 Mbps"
                echo "  $0 -p 2049 -a                  # Prioritize NFS traffic"
                echo "  $0 -p 22 -p 53 -a              # Prioritize SSH and DNS"
                echo "  $0 -d 10.6.0.20 -a             # Prioritize traffic to 10.6.0.20"
                echo "  $0 -r -a                       # Remove all QoS rules"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Pre-flight checks
    check_root
    check_tc
    check_interface

    # Show current configuration
    if [ "$SHOW_CONFIG" = "true" ]; then
        show_qos_config
        exit 0
    fi

    # Remove QoS rules
    if [ "$REMOVE_RULES" = "true" ]; then
        remove_qos_rules
        exit 0
    fi

    # Create QoS configuration
    create_htb_qdisc
    create_classes

    # Apply common priorities
    if [ ${#PRIORITY_PORTS[@]} -eq 0 ] && [ -z "$DEST_IP" ] && [ -z "$SOURCE_IP" ]; then
        log_info "No specific priorities specified, applying common services"
        apply_common_priorities
    fi

    # Apply port priorities
    for port in "${PRIORITY_PORTS[@]}"; do
        add_port_filter "$port" 0  # High priority
    done

    # Apply IP priorities
    if [ -n "$DEST_IP" ]; then
        add_ip_filter "$DEST_IP" "dst" 0  # High priority
    fi

    if [ -n "$SOURCE_IP" ]; then
        add_ip_filter "$SOURCE_IP" "src" 0  # High priority
    fi

    # Show summary
    show_summary

    log_success "QoS configuration complete"
    log_info "Use 'net-qos.sh -S' to verify configuration"
}

# Run main function
main "$@"
