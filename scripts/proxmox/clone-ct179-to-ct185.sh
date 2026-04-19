#!/usr/bin/env bash
# =============================================================================
# Clone CT179 (agldv03) → CT185 (agldv12)
# Executar no host aglsrv1 (root@100.107.113.33)
#
# Pré-requisito: backup do CT179 deve existir em /var/lib/vz/dump/
#   vzdump 179 --mode snapshot --compress 0 --storage local
#
# Uso: ./scripts/proxmox/clone-ct179-to-ct185.sh [caminho-backup]
# =============================================================================
set -euo pipefail

HOST="${AGLSRV1:-root@100.107.113.33}"
BACKUP_PATTERN="${1:-/var/lib/vz/dump/vzdump-lxc-179-*.tar}"

echo "=== Clone CT179 → CT185 (agldv12) ==="
echo "Host: $HOST"
echo ""

# Encontrar backup mais recente (.tar ou .dat)
BACKUP=$(ssh "$HOST" "ls -t /var/lib/vz/dump/vzdump-lxc-179-*.tar /var/lib/vz/dump/vzdump-lxc-179-*.dat 2>/dev/null | head -1")
if [[ -z "$BACKUP" ]]; then
  echo "ERRO: Nenhum backup encontrado. Execute primeiro:"
  echo "  ssh $HOST 'vzdump 179 --mode snapshot --compress 0 --storage local'"
  exit 1
fi

echo "Backup: $BACKUP"
echo ""

# Restore como CT185
echo "Restaurando backup como CT185..."
ssh "$HOST" "pct restore 185 $BACKUP --storage local-zfs"

# Configurar hostname e rede (IP 192.168.0.185)
echo "Configurando hostname e rede..."
ssh "$HOST" "pct set 185 --hostname agldv12"
ssh "$HOST" "pct set 185 --net0 'name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.185/24,ip6=dhcp,type=veth'"
ssh "$HOST" "pct set 185 --net1 'name=eth1,bridge=vmbr1,gw=192.168.1.1,ip=192.168.1.185/24,type=veth'"

# Limpar hostname/SSH keys dentro do CT (será feito no primeiro boot)
echo "Iniciando CT185..."
ssh "$HOST" "pct start 185"

echo ""
echo "=== CT185 (agldv12) criado com sucesso ==="
echo "  IP LAN: 192.168.0.185"
echo "  IP LAN2: 192.168.1.185"
echo "  SSH: ssh root@192.168.0.185"
echo ""
echo "Próximos passos:"
echo "  1. Resetar Tailscale (obrigatório — clone herda identidade do agldv03):"
echo "     ssh root@192.168.0.185 'systemctl stop tailscaled && rm -rf /var/lib/tailscale/tailscaled.state && systemctl start tailscaled'"
echo "     ssh root@192.168.0.185  # dentro do CT: tailscale up --accept-dns=false --hostname=aglsrv1-agldv12"
echo "  2. Instalar Turbo Flow:"
echo "     ./scripts/proxmox/setup-turbo-flow-ct185.sh"
