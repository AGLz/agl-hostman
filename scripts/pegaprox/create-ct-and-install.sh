#!/bin/bash
#
# PegaProx - Criação de CT e instalação no aglsrv1
# Plataforma de gerenciamento multi-cluster para Proxmox VE
# https://pegaprox.com
#
# Executar NO HOST aglsrv1 (Proxmox)
# Uso: ./create-ct-and-install.sh
#

set -e

# Configuração do container
CTID=210
HOSTNAME="pegaprox"
STORAGE="local-lvm"
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
DISK_SIZE="32"
MEMORY=2048
SWAP=512
CORES=2
BRIDGE="vmbr0"
IP_ADDRESS="192.168.0.210/24"
GATEWAY="192.168.0.1"
DNS="192.168.0.102"
PEGAPROX_PORT=5000

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERRO]${NC} $*"; }

# Verificar se está no Proxmox
if ! command -v pct &>/dev/null; then
    log_err "Execute este script no host Proxmox (aglsrv1)"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  PegaProx - Instalação em LXC no aglsrv1${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Verificar se CT já existe
SKIP_CREATE=0
if pct status $CTID &>/dev/null 2>&1; then
    log_warn "CT$CTID já existe. Use-o ou destrua antes."
    read -p "Destruir e recriar? (yes/no): " -r
    if [[ $REPLY == "yes" ]]; then
        pct stop $CTID 2>/dev/null || true
        pct destroy $CTID
    else
        log_info "Pulando criação. Instalando PegaProx no CT existente..."
        pct start $CTID 2>/dev/null || true
        sleep 5
        SKIP_CREATE=1
    fi
fi

if [ "$SKIP_CREATE" = "0" ]; then
    # Verificar template Debian
    if ! ls /var/lib/vz/template/cache/ 2>/dev/null | grep -qE "debian-(11|12|13)"; then
        log_info "Baixando template Debian 12..."
        pveam update
        pveam download local debian-12-standard_12.7-1_amd64.tar.zst || \
        pveam download local debian-12-standard_12.6-1_amd64.tar.zst || true
    fi
    # Usar template disponível
    DEB_FILE=$(ls /var/lib/vz/template/cache/debian-12*.tar.zst 2>/dev/null | head -1)
    [ -n "$DEB_FILE" ] && TEMPLATE="local:vztmpl/$(basename "$DEB_FILE")"

    # Fallback para storage se local-lvm não existir
    if ! pvesm status 2>/dev/null | grep -q "local-lvm"; then
        STORAGE="local-zfs"
        log_warn "Usando storage: $STORAGE"
    fi

    log_info "Criando CT$CTID ($HOSTNAME)..."
    pct create "$CTID" "$TEMPLATE" \
        --hostname "$HOSTNAME" \
        --storage "$STORAGE" \
        --rootfs "${STORAGE}:${DISK_SIZE}" \
        --memory "$MEMORY" \
        --swap "$SWAP" \
        --cores "$CORES" \
        --net0 "name=eth0,bridge=${BRIDGE},ip=${IP_ADDRESS},gw=${GATEWAY}" \
        --nameserver "$DNS" \
        --unprivileged 0 \
        --onboot 1 \
        --description "PegaProx - Proxmox VE Multi-Cluster Management"

    log_ok "CT criado. Iniciando..."
    pct start $CTID
    sleep 8
fi

# Instalar PegaProx dentro do CT
log_info "Instalando PegaProx no CT$CTID..."
pct exec $CTID -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl sudo

# Executar deploy oficial PegaProx (porta 5000, não interativo)
curl -sSL https://raw.githubusercontent.com/PegaProx/project-pegaprox/refs/heads/main/deploy.sh | sudo bash -s -- --port=5000 --no-interactive
'

log_ok "PegaProx instalado!"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Instalação concluída!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Web UI:    ${BLUE}https://192.168.0.210:5000${NC}"
echo -e "  Tailscale: ${BLUE}https://<tailscale-ip>:5000${NC} (se CT tiver Tailscale)"
echo ""
echo -e "  Próximos passos:"
echo -e "  1. Acesse a interface e adicione o cluster Proxmox (API)"
echo -e "  2. Host: 192.168.0.245  Porta: 8006"
echo -e "  3. Use token ou usuário Proxmox para autenticação"
echo ""
echo -e "  Comandos:"
echo -e "    pct exec $CTID -- systemctl status pegaprox"
echo -e "    pct exec $CTID -- journalctl -u pegaprox -f"
echo ""
