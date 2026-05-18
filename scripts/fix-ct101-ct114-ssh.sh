#!/bin/bash
#
# Fix Cloned CTs CT101 (cloudflared6) and CT114 (cloudflared6b) - SSH Key Fix
# Este script deve ser executado no AGLSRV6 (100.107.113.33)
#
# Problema: Ambos usam a mesma chave SSH (node key duplicada)
# Solução: Gerar novas chaves únicas para cada CT
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando no host correto
hostnamectl hostname | grep -q "agldv04" || {
    log_error "Este script deve ser executado no AGLSRV6 (100.107.113.33)"
    exit 1
}

# List of CTs to fix
CTS_TO_FIX=(101 114)

# Fix a single CT
fix_ct_ssh() {
    local ctid="$1"
    local ctname="$2"

    log_info "=== Fixing CT${ctid} (${ctname}) ==="

    # Check if container exists
    if ! pct status "$ctid" &>/dev/null; then
        log_error "Container CT${ctid} not found!"
        return 1
    fi

    # Generate new SSH key pair
    log_info "Generating new SSH key pair for CT${ctid}..."

    # Create temp file for new public key
    local tmp_pub="/tmp/${ctid}_new_key.pub"
    pct exec "$ctid" -- bash -c "
        ssh-keygen -t ecdsa -b 4096 -f ${ctid}_nova -N '' >/dev/null 2>&1
        cat ${ctid}_nova.pub
    " > "$tmp_pub"

    # Remove old SSH keys
    pct exec "$ctid" -- bash -c '
        echo "Removing old SSH keys..."
        rm -f ~/.ssh/id_*
        echo "Installing new authorized_keys..."
        # Create new authorized_keys with NEW key
        cat > ~/.ssh/authorized_keys << 'KEYEOF'
        $(cat "$tmp_pub")
        KEYEOF

        # Set correct permissions
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/authorized_keys
        echo "CT${ctid}: New SSH key installed!"
    '
    "

    # Cleanup temp file
    rm -f "$tmp_pub"

    log_success "CT${ctid} (${ctname}): New SSH key installed!"
    log_info "Container hostname: $(pct config "$ctid" | grep hostname | cut -d'=' -f2)"
}

    # Restart Tailscale in container
    log_info "Restarting Tailscale with --ssh..."
    pct exec "$ctid" -- bash -c '
        tailscale down 2>/dev/null || true
        sleep 1
        tailscale up --ssh 2>/dev/null || tailscale up --ssh --reset
        sleep 2
        tailscale status --peers=false | head -2
        echo "Tailscale IP: $(tailscale ip -4)"
    '

    # Wait a moment for Tailscale to connect
    sleep 3

    # Verify Tailscale SSH
    pct exec "$ctid" -- bash -c '
        if tailscale status --json 2>/dev/null | grep -q '"SSH".*true" >/dev/null; then
            echo "✅ Tailscale SSH ATIVO!"
        else
            echo "❌ Tailscale SSH não ativo, ver logs..."
            journalctl -u tailscaled -n 10 --no-pager | tail -20
        fi
    '

    echo ""
    echo "Teste de conexão SSH:"
    echo "  ssh root@$(pct config "$ctid" | grep hostname | cut -d'=' -f2)"
}

# Fix all CTs
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo " Fix CT101 & CT114 - SSH Keys"
    echo "=========================================="
    echo -e "${NC}"
    echo "Host: AGLSRV6 (100.107.113.33)"
    echo ""
    echo "Prerequisites:"
    echo "  1. Deve ser executado em AGLSRV6"
    echo "  2. Containers CT101 e CT114 devem existir"
    echo ""

    # Check host connectivity
    log_info "Checking connectivity to AGLSRV6..."
    if ! ping -c 3 -W 1 100.107.113.33 >/dev/null 2>&1; then
        log_error "AGLSRVV6 não está acessível!"
        exit 1
    fi
    log_success "AGLSRVV6 is reachable!"
    echo ""

    # Process each CT
    for ctid in "${CTS_TO_FIX[@]}"; do
        case "$ctid" in
            101)
                fix_ct_ssh "101" "cloudflared6"
                ;;
            114)
                fix_ct_ssh "114" "cloudflared6b"
                ;;
            *)
                log_error "Unknown CT: $ctid"
                ;;
        esac
    done

    echo ""
    log_success "=== All CTs processed! ==="
    echo "CT101: New SSH key generated"
    echo "CT114: New SSH key generated"
    echo ""
    echo "=========================================="
    echo -e "${NC}Status: Use 'ssh root@<IP>' to test each CT"
    echo "Or access via Tailscale: ssh root@<tailscale-ip>"
    echo ""
    echo "Próximo passo:"
    echo " 1. Execute: ssh root@100.107.113.33 'bash /root/fix-ct101-ct114-ssh.sh'"
    echo "  2. Or execute in AGLSRV6 directly"
}

main "$@"
