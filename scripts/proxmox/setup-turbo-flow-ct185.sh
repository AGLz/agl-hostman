#!/usr/bin/env bash
# =============================================================================
# Instalar Turbo Flow v4.0 no CT185 (agldv12)
# https://github.com/marcuspat/turbo-flow
#
# Executar localmente (conecta via SSH ao CT185)
# Uso: ./scripts/proxmox/setup-turbo-flow-ct185.sh
# =============================================================================
set -euo pipefail

CT185_IP="${CT185_IP:-192.168.0.185}"
TURBO_FLOW_DIR="${TURBO_FLOW_DIR:-/opt/turbo-flow}"

echo "=== Turbo Flow v4.0 - Instalação no agldv12 (CT185) ==="
echo "Host: root@$CT185_IP"
echo ""

# 1. Clonar repositório
echo "[1/4] Clonando turbo-flow..."
ssh "root@$CT185_IP" "git clone -b main https://github.com/marcuspat/turbo-flow $TURBO_FLOW_DIR 2>/dev/null || (cd $TURBO_FLOW_DIR && git pull)"

# 2. Executar setup (devpods/setup.sh)
echo "[2/4] Executando setup Turbo Flow..."
ssh "root@$CT185_IP" "cd $TURBO_FLOW_DIR && chmod +x devpods/setup.sh && ./devpods/setup.sh"

# 3. Configurar LiteLLM gateway (apontar para agldv03)
echo "[3/4] Configurando LiteLLM gateway (agldv03:4000)..."
ssh "root@$CT185_IP" "mkdir -p ~/.claude && echo 'LITELLM_GATEWAY_URL=http://100.94.221.87:4000' >> ~/.claude/turbo-flow.env 2>/dev/null || true"

# 4. Post-setup
echo "[4/4] Executando post-setup..."
ssh "root@$CT185_IP" "cd $TURBO_FLOW_DIR && [ -f devpods/post-setup.sh ] && chmod +x devpods/post-setup.sh && ./devpods/post-setup.sh || true"

echo ""
echo "=== Instalação concluída ==="
echo "  Repo: $TURBO_FLOW_DIR"
echo "  Comandos: turbo-status, turbo-help, rf-doctor"
echo "  Gateway LiteLLM: agldv03 (100.94.221.87:4000)"
echo ""
echo "Conectar: ssh root@$CT185_IP"
