#!/bin/bash
#
# Batch Fix Tailscale SSH Flag for Multiple Hosts
# Corrige a flag --ssh faltando em múltiplos containers Tailscale
#
# Usage: ./scripts/batch-fix-tailscale-ssh.sh
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hosts to fix - format: "hostname|container_path|tailscale_ip"
HOSTS_TO_FIX=(
    "agldv04|pct exec 181 --|100.113.9.98"
    "archon|pct exec 179 --|100.94.221.87"
    "aglfs1|pct exec 178 --|100.69.187.105"
)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix a single host
fix_host() {
    local hostname="$1"
    local container_cmd="$2"
    local expected_ip="$3"

    log_info "Fixing $hostname..."

    # Get the actual Tailscale IP
    local actual_ip=$(ssh AGLSRV1 "$container_cmd tailscale ip -4 2>/dev/null" | tr -d '\n')

    if [[ -z "$actual_ip" ]]; then
        log_warn "Could not get Tailscale IP for $hostname"
        return 1
    fi

    # Check if IP matches expected
    if [[ "$actual_ip" == "$expected_ip" ]]; then
        log_success "$hostname IP matches: $actual_ip"
    else
        log_warn "$hostname IP changed: $expected_ip → $actual_ip"
    fi

    # Reconnect with --ssh flag
    log_info "Reconnecting $hostname with --ssh..."
    ssh AGLSRV1 "$container_cmd bash -c '
        echo \"Disconnecting Tailscale...\"
        tailscale down 2>/dev/null || true
        sleep 1
        echo \"Reconnecting with --ssh...\"
        tailscale up --ssh 2>/dev/null || tailscale up --ssh --reset
        sleep 2
        echo \"Status:\"
        tailscale status --peers=false | head -2
        echo \"\"
        echo \"Tailscale IP: \$(tailscale ip -4)\"
        echo \"✅ Flag --ssh activated!\"
    '"

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "$hostname configured with --ssh flag"

        # Show new IP
        local new_ip=$(ssh AGLSRV1 "$container_cmd tailscale ip -4 2>/dev/null" | tr -d '\n')
        echo -e "      ${GREEN}New IP: $new_ip${NC}"
    else
        log_error "Failed to configure $hostname (exit code: $exit_code)"
        return 1
    fi

    echo ""
}

# Test connection to a host
test_host() {
    local hostname="$1"
    local ip="$2"

    log_info "Testing $hostname ($ip)..."

    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$ip "hostname &>/dev/null" 2>/dev/null; then
        log_success "$hostname is accessible"
        return 0
    else
        log_error "$hostname is NOT accessible"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo " Batch Fix Tailscale SSH Flag"
    echo "=========================================="
    echo -e "${NC}"
    echo "This script will:"
    echo "  1. Fix Tailscale SSH flag on AGLSRV1 containers"
    echo "  2. Verify connectivity"
    echo "  3. Report new IPs if changed"
    echo ""

    # Counter
    local fixed=0
    local failed=0
    local skipped=0

    # Process each host
    for host_spec in "${HOSTS_TO_FIX[@]}"; do
        IFS='|' read -r hostname container_cmd expected_ip <<< "$host_spec"

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # First test connectivity
        if ! test_host "$hostname" "$expected_ip"; then
            log_warn "Skipping $hostname - not accessible"
            ((skipped++))
            echo ""
            continue
        fi

        # Fix the host
        if fix_host "$hostname" "$container_cmd" "$expected_ip"; then
            ((fixed++))
        else
            ((failed++))
        fi
    done

    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}SUMMARY${NC}"
    echo "=========================================="
    echo -e "  ${GREEN}Fixed:   $fixed${NC} hosts"
    echo -e "  ${RED}Failed:   $failed${NC} hosts"
    echo -e "  ${YELLOW}Skipped: $skipped${NC} hosts (not accessible)"
    echo ""
    echo "=========================================="

    # Final status
    if [[ $fixed -gt 0 ]]; then
        log_success "Tailscale SSH batch fix completed!"
        echo ""
        echo "Next steps:"
        echo "  1. Configure ACLs in Tailscale Admin Console:"
        echo "     https://login.tailscale.com/admin/acls"
        echo ""
        echo "  2. Add SSH access rule:"
        echo '     {"ssh": [{"action": "accept", "src": ["tag:admin", "autogroup:member"], "dst": ["tag:servers"], "users": ["root"]}]}'
        echo ""
        echo "  3. Test connections:"
        echo "     ssh root@agldv04"
        echo "     ssh root@archon"
        echo "     ssh root@aglfs1"
    fi
}

# Run main
main "$@"
