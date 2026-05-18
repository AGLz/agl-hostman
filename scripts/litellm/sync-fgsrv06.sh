#!/usr/bin/env bash
# Sync LiteLLM config: agldv03 (base) → fgsrv06
# Uso: ./scripts/litellm/sync-fgsrv06.sh
# Requer: ssh acesso a root@100.94.221.87 e root@100.83.51.9

set -e
AGLDV03_IP="100.94.221.87"
AGLDV03_CONFIG="/opt/litellm/config.yaml"
FGSRV06_IP="100.83.51.9"
FGSRV06_PATH="/opt/litellm/config.yaml"

if ! ssh "root@${AGLDV03_IP}" "test -f ${AGLDV03_CONFIG}" 2>/dev/null; then
  echo "Erro: ${AGLDV03_CONFIG} não encontrado em agldv03"
  exit 1
fi

echo "=== Sync LiteLLM config: agldv03 → fgsrv06 ==="
echo "  Source: root@${AGLDV03_IP}:${AGLDV03_CONFIG}"
echo "  Target: root@${FGSRV06_IP}:${FGSRV06_PATH} (variante remota)"
echo ""

# Backup no destino
ssh "root@${FGSRV06_IP}" "cp -a ${FGSRV06_PATH} ${FGSRV06_PATH}.bak.\$(date +%Y%m%d%H%M) 2>/dev/null || true"

# Copiar e transformar (Ollama via Tailscale, Redis local)
ssh "root@${AGLDV03_IP}" "cat ${AGLDV03_CONFIG}" | \
  sed -e 's|http://192.168.0.200:11434|http://100.116.57.111:11434|g' \
      -e 's|host: "192.168.0.137"|host: "litellm-redis"|' \
      -e 's|# Redis Cache Configuration (CT137 - aglsrv1)|# Redis Cache Configuration (local - litellm-redis)|' \
      -e '/password: "os.environ\/REDIS_PASSWORD"/d' | \
  ssh "root@${FGSRV06_IP}" "cat > ${FGSRV06_PATH}"

# Reiniciar litellm-proxy
echo ""
echo "  Reiniciando litellm-proxy..."
ssh "root@${FGSRV06_IP}" "cd /opt/litellm && docker compose restart litellm-proxy"

echo ""
echo "=== Concluído ==="
echo "  Verificar: ssh root@${FGSRV06_IP} 'docker logs litellm-proxy --tail 20'"
