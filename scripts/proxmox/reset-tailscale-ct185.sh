#!/usr/bin/env bash
# =============================================================================
# Resetar Tailscale no CT185 (agldv12)
# Obrigatório após clone do CT179 — o clone herda a identidade do agldv03.
# Remove estado e reconecta com novo hostname/IP.
# Nota: o reset é executado dentro do CT via SSH.
#
# Uso: ./scripts/proxmox/reset-tailscale-ct185.sh [authkey]
# =============================================================================
set -euo pipefail

CT185_IP="${CT185_IP:-192.168.0.185}"
HOSTNAME="${HOSTNAME:-aglsrv1-agldv12}"
AUTHKEY="${1:-}"

echo "=== Reset Tailscale no CT185 (agldv12) ==="
echo "Host: root@$CT185_IP"
echo ""

# Resetar estado
echo "[1/3] Parando tailscaled e removendo estado..."
ssh "root@$CT185_IP" "systemctl stop tailscaled 2>/dev/null || true && rm -rf /var/lib/tailscale/tailscaled.state && systemctl start tailscaled"

echo "[2/3] Aguardando tailscaled iniciar..."
sleep 3

# Reconectar
echo "[3/3] Reconectando Tailscale..."
if [[ -n "$AUTHKEY" ]]; then
  ssh "root@$CT185_IP" "tailscale up --authkey=$AUTHKEY --accept-dns=false --accept-routes=false --hostname=$HOSTNAME --ssh"
else
  echo "Execute dentro do CT185 (ou copie o link para o browser):"
  echo "  ssh root@$CT185_IP"
  echo "  tailscale up --accept-dns=false --accept-routes=false --hostname=$HOSTNAME --ssh"
  ssh "root@$CT185_IP" "tailscale up --accept-dns=false --accept-routes=false --hostname=$HOSTNAME --ssh"
fi

echo ""
echo "=== Tailscale resetado ==="
ssh "root@$CT185_IP" "tailscale status"
