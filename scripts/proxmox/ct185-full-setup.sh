#!/usr/bin/env bash
# =============================================================================
# Setup completo CT185 (agldv12): aguarda backup + restore + Tailscale + Turbo Flow
#
# 1. Aguarda conclusão do backup do CT179
# 2. Restore como CT185 + configura rede
# 3. Reseta Tailscale (nova identidade)
# 4. Instala Turbo Flow v4.0
#
# Uso: ./scripts/proxmox/ct185-full-setup.sh [--skip-turbo-flow] [--tailscale-authkey KEY]
# =============================================================================
set -euo pipefail

HOST="${AGLSRV1:-root@100.107.113.33}"
CT185_IP="192.168.0.185"
SKIP_TURBO_FLOW=false
TAILSCALE_AUTHKEY=""

for arg in "$@"; do
  case "$arg" in
    --skip-turbo-flow) SKIP_TURBO_FLOW=true ;;
    --tailscale-authkey=*) TAILSCALE_AUTHKEY="${arg#*=}" ;;
  esac
done

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CT185 (agldv12) — Setup Completo                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# FASE 1: Aguardar conclusão do backup
# -----------------------------------------------------------------------------
echo "=== [1/4] Aguardando conclusão do backup CT179 ==="
echo "Monitorando processo vzdump..."
while ssh "$HOST" 'pgrep vzdump' 2>/dev/null; do
  SIZE=$(ssh "$HOST" "ls -lh /var/lib/vz/dump/vzdump-lxc-179-*.dat 2>/dev/null | awk '{print \$5}'" || echo "?")
  echo "  Backup em andamento... ($SIZE)"
  sleep 30
done

echo "  Backup concluído!"
BACKUP=$(ssh "$HOST" "ls -t /var/lib/vz/dump/vzdump-lxc-179-*.tar /var/lib/vz/dump/vzdump-lxc-179-*.dat 2>/dev/null | head -1")
if [[ -z "$BACKUP" ]]; then
  echo "ERRO: Nenhum backup encontrado."
  exit 1
fi
echo "  Arquivo: $BACKUP"
echo ""

# -----------------------------------------------------------------------------
# FASE 2: Restore + configuração
# -----------------------------------------------------------------------------
echo "=== [2/4] Restore e configuração CT185 ==="
ssh "$HOST" "pct restore 185 $BACKUP --storage local-zfs"
ssh "$HOST" "pct set 185 --hostname agldv12"
ssh "$HOST" "pct set 185 --net0 'name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.185/24,ip6=dhcp,type=veth'"
ssh "$HOST" "pct set 185 --net1 'name=eth1,bridge=vmbr1,gw=192.168.1.1,ip=192.168.1.185/24,type=veth'"
echo "  Iniciando CT185..."
ssh "$HOST" "pct start 185"

echo "  Aguardando boot (30s)..."
sleep 30
echo ""

# -----------------------------------------------------------------------------
# FASE 3: Reset Tailscale
# -----------------------------------------------------------------------------
echo "=== [3/4] Reset Tailscale ==="
ssh "root@$CT185_IP" "systemctl stop tailscaled 2>/dev/null || true"
ssh "root@$CT185_IP" "rm -rf /var/lib/tailscale/tailscaled.state"
ssh "root@$CT185_IP" "systemctl start tailscaled"
sleep 3

if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
  ssh "root@$CT185_IP" "tailscale up --authkey=$TAILSCALE_AUTHKEY --accept-dns=false --hostname=aglsrv1-agldv12 --ssh"
else
  echo "  Execute dentro do CT185 para completar auth Tailscale (ou use --tailscale-authkey=tskey-xxx):"
  echo "    tailscale up --accept-dns=false --hostname=aglsrv1-agldv12 --ssh"
  ssh "root@$CT185_IP" "tailscale up --accept-dns=false --hostname=aglsrv1-agldv12 --ssh" || true
fi
echo ""

# -----------------------------------------------------------------------------
# FASE 4: Turbo Flow (opcional)
# -----------------------------------------------------------------------------
if [[ "$SKIP_TURBO_FLOW" == "true" ]]; then
  echo "=== [4/4] Turbo Flow — PULADO (--skip-turbo-flow) ==="
else
  echo "=== [4/4] Instalação Turbo Flow ==="
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "$SCRIPT_DIR/setup-turbo-flow-ct185.sh" || echo "  Aviso: Turbo Flow pode precisar de ajustes manuais."
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CT185 (agldv12) — Setup concluído                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  IP LAN: $CT185_IP"
echo "  SSH: ssh root@$CT185_IP"
echo ""
echo "  Se Tailscale pediu auth, complete em: ssh root@$CT185_IP"
echo ""
