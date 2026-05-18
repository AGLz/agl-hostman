#!/bin/bash

###############################################################################
# TCP Optimization Script
# Optimizes TCP parameters for better network performance
#
# Usage: net-optimize-tcp.sh [options]
#   -p, --profile PROFILE       Optimization profile (default, vpn, high-latency, datacenter)
#   -c, --congestion ALGO       Congestion control algorithm (bbr, cubic, reno, vegas)
#   -w, --window-size SIZE      TCP window size (format: min default max)
#   -b, --buffer-size SIZE      Socket buffer size (in bytes)
#   -s, --show                  Show current TCP settings
#   -r, --reset                 Reset to default kernel settings
#   -a, --apply                 Apply optimization (default: dry-run)
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
BOLD='\033[1m'
NC='\033[0m'

# Default values
PROFILE=""
CONGESTION=""
WINDOW_SIZE=""
BUFFER_SIZE=""
SHOW_CURRENT=false
RESET_TO_DEFAULT=false
APPLY_CHANGES=false
VERBOSE=false

# Backup file
BACKUP_FILE="/tmp/tcp-optimize-backup-$(date +%Y%m%d-%H%M%S).conf"

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

# Show current TCP settings
show_current_settings() {
    log_info "Current TCP Settings"
    echo ""

    echo -e "${BOLD}General TCP Parameters:${NC}"
    echo "────────────────────────────────────────"
    sysctl net.ipv4.tcp_window_scaling net.ipv4.tcp_sack net.ipv4.tcp_timestamps | \
        while read -r key value; do
            printf "%-45s %s\n" "$key:" "$value"
        done

    echo ""
    echo -e "${BOLD}TCP Timeouts:${NC}"
    echo "────────────────────────────────────────"
    sysctl net.ipv4.tcp_fin_timeout net.ipv4.tcp_keepalive_time \
        net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes | \
        while read -r key value; do
            printf "%-45s %s\n" "$key:" "$value"
        done

    echo ""
    echo -e "${BOLD}TCP Buffers (read/write):${NC}"
    echo "────────────────────────────────────────"
    sysctl net.ipv4.tcp_rmem net.ipv4.tcp_wmem net.core.rmem_max net.core.wmem_max | \
        while read -r key value; do
            printf "%-45s %s\n" "$key:" "$value"
        done

    echo ""
    echo -e "${BOLD}Congestion Control:${NC}"
    echo "────────────────────────────────────────"
    sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc | \
        while read -r key value; do
            printf "%-45s %s\n" "$key:" "$value"
        done

    # Show available congestion control algorithms
    echo ""
    echo -e "${BOLD}Available Congestion Control Algorithms:${NC}"
    echo "────────────────────────────────────────"
    if [ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]; then
        cat /proc/sys/net/ipv4/tcp_available_congestion_control | tr ' ' '\n' | sed 's/^/  /'
    fi

    echo ""
    echo -e "${BOLD}Available Qdisc:${NC}"
    echo "────────────────────────────────────────"
    if [ -f /proc/sys/net/core/default_qdisc ]; then
        cat /proc/sys/net/core/default_qdisc
    fi

    echo ""
    echo -e "${BOLD}Connection Tracking:${NC}"
    echo "────────────────────────────────────────"
    sysctl net.netfilter.nf_conntrack_max | while read -r key value; do
        local current=$(cat /proc/net/nf_conntrack 2>/dev/null | wc -l || echo "0")
        printf "%-45s %s (current: %s)\n" "$key:" "$value" "$current"
    done
}

# Backup current settings
backup_settings() {
    log_info "Backing up current settings to $BACKUP_FILE"
    sysctl -a | grep -E 'net\.(ipv4|core)\.(tcp_|rmem|wmem|default_qdisc|netfilter)' > "$BACKUP_FILE"
    log_success "Settings backed up"
}

# Apply profile settings
apply_profile() {
    local profile=$1

    log_info "Applying profile: $profile"

    case $profile in
        default)
            # Default kernel-optimized settings
            set_sysctl "net.ipv4.tcp_window_scaling" "1"
            set_sysctl "net.ipv4.tcp_sack" "1"
            set_sysctl "net.ipv4.tcp_timestamps" "1"
            set_sysctl "net.ipv4.tcp_fin_timeout" "30"
            set_sysctl "net.ipv4.tcp_keepalive_time" "120"
            set_sysctl "net.ipv4.tcp_keepalive_intvl" "10"
            set_sysctl "net.ipv4.tcp_keepalive_probes" "3"
            set_sysctl "net.ipv4.tcp_rmem" "4096 131072 16777216"
            set_sysctl "net.ipv4.tcp_wmem" "4096 65536 16777216"
            set_sysctl "net.core.rmem_max" "16777216"
            set_sysctl "net.core.wmem_max" "16777216"
            set_sysctl "net.core.netdev_max_backlog" "5000"
            set_sysctl "net.core.default_qdisc" "fq"
            set_sysctl "net.ipv4.tcp_congestion_control" "bbr"
            ;;

        vpn)
            # Optimized for VPN/encrypted traffic
            log_info "Optimizing for VPN traffic (WireGuard)"
            set_sysctl "net.ipv4.tcp_window_scaling" "1"
            set_sysctl "net.ipv4.tcp_sack" "1"
            set_sysctl "net.ipv4.tcp_timestamps" "1"
            set_sysctl "net.ipv4.tcp_fin_timeout" "45"
            set_sysctl "net.ipv4.tcp_keepalive_time" "60"
            set_sysctl "net.ipv4.tcp_keepalive_intvl" "15"
            set_sysctl "net.ipv4.tcp_keepalive_probes" "5"
            set_sysctl "net.ipv4.tcp_rmem" "4096 131072 67108864"
            set_sysctl "net.ipv4.tcp_wmem" "4096 65536 67108864"
            set_sysctl "net.core.rmem_max" "67108864"
            set_sysctl "net.core.wmem_max" "67108864"
            set_sysctl "net.core.netdev_max_backlog" "10000"
            set_sysctl "net.core.default_qdisc" "fq"
            set_sysctl "net.ipv4.tcp_congestion_control" "bbr"
            log_success "VPN profile applied"
            ;;

        high-latency)
            # Optimized for high-latency connections
            log_info "Optimizing for high-latency connections"
            set_sysctl "net.ipv4.tcp_window_scaling" "1"
            set_sysctl "net.ipv4.tcp_sack" "1"
            set_sysctl "net.ipv4.tcp_timestamps" "1"
            set_sysctl "net.ipv4.tcp_fin_timeout" "60"
            set_sysctl "net.ipv4.tcp_keepalive_time" "300"
            set_sysctl "net.ipv4.tcp_keepalive_intvl" "30"
            set_sysctl "net.ipv4.tcp_keepalive_probes" "3"
            set_sysctl "net.ipv4.tcp_rmem" "4096 131072 134217728"
            set_sysctl "net.ipv4.tcp_wmem" "4096 65536 134217728"
            set_sysctl "net.core.rmem_max" "134217728"
            set_sysctl "net.core.wmem_max" "134217728"
            set_sysctl "net.core.netdev_max_backlog" "10000"
            set_sysctl "net.core.default_qdisc" "fq"
            set_sysctl "net.ipv4.tcp_congestion_control" "bbr"
            log_success "High-latency profile applied"
            ;;

        datacenter)
            # Optimized for datacenter/LAN traffic
            log_info "Optimizing for datacenter/LAN traffic"
            set_sysctl "net.ipv4.tcp_window_scaling" "1"
            set_sysctl "net.ipv4.tcp_sack" "1"
            set_sysctl "net.ipv4.tcp_timestamps" "0"
            set_sysctl "net.ipv4.tcp_fin_timeout" "15"
            set_sysctl "net.ipv4.tcp_keepalive_time" "600"
            set_sysctl "net.ipv4.tcp_keepalive_intvl" "30"
            set_sysctl "net.ipv4.tcp_keepalive_probes" "3"
            set_sysctl "net.ipv4.tcp_rmem" "4096 87380 16777216"
            set_sysctl "net.ipv4.tcp_wmem" "4096 65536 16777216"
            set_sysctl "net.core.rmem_max" "16777216"
            set_sysctl "net.core.wmem_max" "16777216"
            set_sysctl "net.core.netdev_max_backlog" "3000"
            set_sysctl "net.core.default_qdisc" "fq"
            set_sysctl "net.ipv4.tcp_congestion_control" "cubic"
            log_success "Datacenter profile applied"
            ;;

        *)
            log_error "Unknown profile: $profile"
            log_info "Available profiles: default, vpn, high-latency, datacenter"
            exit 1
            ;;
    esac
}

# Set sysctl value
set_sysctl() {
    local key=$1
    local value=$2

    if [ "$APPLY_CHANGES" = "true" ]; then
        sysctl -w "$key=$value" > /dev/null
        log_verbose "Set $key = $value"
    else
        log_info "Would set: $key = $value (dry-run)"
    fi
}

# Reset to default settings
reset_to_default() {
    log_warning "Resetting to kernel default settings"

    # Reset TCP parameters
    sysctl -w "net.ipv4.tcp_window_scaling=1" > /dev/null
    sysctl -w "net.ipv4.tcp_sack=1" > /dev/null
    sysctl -w "net.ipv4.tcp_timestamps=1" > /dev/null
    sysctl -w "net.ipv4.tcp_fin_timeout=60" > /dev/null
    sysctl -w "net.ipv4.tcp_keepalive_time=7200" > /dev/null
    sysctl -w "net.ipv4.tcp_keepalive_intvl=75" > /dev/null
    sysctl -w "net.ipv4.tcp_keepalive_probes=9" > /dev/null
    sysctl -w "net.ipv4.tcp_rmem=4096 131072 6291456" > /dev/null
    sysctl -w "net.ipv4.tcp_wmem=4096 16384 4194304" > /dev/null
    sysctl -w "net.core.rmem_max=12582912" > /dev/null
    sysctl -w "net.core.wmem_max=12582912" > /dev/null
    sysctl -w "net.core.netdev_max_backlog=1000" > /dev/null
    sysctl -w "net.ipv4.tcp_congestion_control=cubic" > /dev/null

    log_success "Settings reset to defaults"
}

# Generate persistent configuration
generate_persistent_config() {
    local config_file="/etc/sysctl.d/99-tcp-optimization.conf"

    log_info "Generating persistent configuration: $config_file"

    if [ "$APPLY_CHANGES" = "true" ]; then
        cat > "$config_file" <<EOF
# TCP Optimization - Generated by net-optimize-tcp.sh
# Date: $(date)

# General TCP Parameters
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1

# TCP Timeouts
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3

# TCP Buffers
net.ipv4.tcp_rmem = 4096 131072 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000

# Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

        log_success "Persistent configuration saved"
        log_info "Load with: sysctl -p $config_file"
    else
        log_info "Would create: $config_file (dry-run)"
    fi
}

# Main execution
main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -c|--congestion)
                CONGESTION="$2"
                shift 2
                ;;
            -w|--window-size)
                WINDOW_SIZE="$2"
                shift 2
                ;;
            -b|--buffer-size)
                BUFFER_SIZE="$2"
                shift 2
                ;;
            -s|--show)
                SHOW_CURRENT=true
                shift
                ;;
            -r|--reset)
                RESET_TO_DEFAULT=true
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
                echo "TCP optimization for improved network performance"
                echo ""
                echo "Options:"
                echo "  -p, --profile PROFILE       Optimization profile (default, vpn, high-latency, datacenter)"
                echo "  -c, --congestion ALGO       Congestion control algorithm (bbr, cubic, reno, vegas)"
                echo "  -w, --window-size SIZE      TCP window size (format: min default max)"
                echo "  -b, --buffer-size SIZE      Socket buffer size (in bytes)"
                echo "  -s, --show                  Show current TCP settings"
                echo "  -r, --reset                 Reset to default kernel settings"
                echo "  -a, --apply                 Apply optimization (default: dry-run)"
                echo "  -v, --verbose               Verbose output"
                echo "  -h, --help                  Show this help"
                echo ""
                echo "Profiles:"
                echo "  default       Default kernel-optimized settings"
                echo "  vpn           Optimized for VPN/encrypted traffic (WireGuard)"
                echo "  high-latency  Optimized for high-latency connections"
                echo "  datacenter    Optimized for datacenter/LAN traffic"
                echo ""
                echo "Examples:"
                echo "  $0 -s                           # Show current settings"
                echo "  $0 -p vpn -a                    # Apply VPN profile"
                echo "  $0 -c bbr -a                    # Set congestion control to BBR"
                echo "  $0 -r -a                        # Reset to defaults"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Check root
    check_root

    # Show current settings
    if [ "$SHOW_CURRENT" = "true" ]; then
        show_current_settings
        exit 0
    fi

    # Reset to defaults
    if [ "$RESET_TO_DEFAULT" = "true" ]; then
        if [ "$APPLY_CHANGES" = "true" ]; then
            backup_settings
        fi
        reset_to_default
        exit 0
    fi

    # Apply profile
    if [ -n "$PROFILE" ]; then
        if [ "$APPLY_CHANGES" = "true" ]; then
            backup_settings
        fi
        apply_profile "$PROFILE"
        generate_persistent_config
        exit 0
    fi

    # Set individual congestion control
    if [ -n "$CONGESTION" ]; then
        if [ "$APPLY_CHANGES" = "true" ]; then
            backup_settings
            sysctl -w "net.ipv4.tcp_congestion_control=$CONGESTION"
            log_success "Congestion control set to: $CONGESTION"
        else
            log_info "Would set congestion control to: $CONGESTION (dry-run)"
        fi
        exit 0
    fi

    # Set window size
    if [ -n "$WINDOW_SIZE" ]; then
        if [ "$APPLY_CHANGES" = "true" ]; then
            backup_settings
            sysctl -w "net.ipv4.tcp_rmem='$WINDOW_SIZE'"
            sysctl -w "net.ipv4.tcp_wmem='$WINDOW_SIZE'"
            log_success "TCP window size set to: $WINDOW_SIZE"
        else
            log_info "Would set TCP window size to: $WINDOW_SIZE (dry-run)"
        fi
        exit 0
    fi

    # Set buffer size
    if [ -n "$BUFFER_SIZE" ]; then
        if [ "$APPLY_CHANGES" = "true" ]; then
            backup_settings
            sysctl -w "net.core.rmem_max=$BUFFER_SIZE"
            sysctl -w "net.core.wmem_max=$BUFFER_SIZE"
            log_success "Socket buffer size set to: $BUFFER_SIZE"
        else
            log_info "Would set socket buffer size to: $BUFFER_SIZE (dry-run)"
        fi
        exit 0
    fi

    # No options specified, show help
    log_warning "No options specified"
    log_info "Use -h for help or -s to show current settings"
    show_current_settings
}

# Run main function
main "$@"
