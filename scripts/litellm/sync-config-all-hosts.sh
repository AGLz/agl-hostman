#!/usr/bin/env bash
# Sync LiteLLM config: agldv03 (base) → agldv04, agldv12, fgsrv06
# Uso: ./scripts/litellm/sync-config-all-hosts.sh
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -e

AGLDV03_IP="100.94.221.87"
AGLDV03_CONFIG="/opt/litellm/config.yaml"

# Destinos: host:IP
declare -A TARGETS
TARGETS[agldv04]="100.113.9.98"
TARGETS[agldv12]="100.71.217.115"
TARGETS[fgsrv06]="100.83.51.9"

echo "=== Sync LiteLLM config: agldv03 (base) → demais hosts ==="
echo "  Source: root@${AGLDV03_IP}:${AGLDV03_CONFIG}"
echo ""

# Verificar se config existe no agldv03
if ! ssh "root@${AGLDV03_IP}" "test -f ${AGLDV03_CONFIG}" 2>/dev/null; then
  echo "Erro: ${AGLDV03_CONFIG} não encontrado em agldv03"
  echo "  Garanta que LiteLLM está deployado em agldv03 com config em /opt/litellm/"
  exit 1
fi

for host in "${!TARGETS[@]}"; do
  ip="${TARGETS[$host]}"
  echo "  $host ($ip)..."
  ssh "root@${ip}" "cp -a /opt/litellm/config.yaml /opt/litellm/config.yaml.bak.\$(date +%Y%m%d%H%M) 2>/dev/null || true"

  if [[ "$host" == "fgsrv06" ]]; then
    # fgsrv06: variante remota (Ollama via Tailscale, Redis local)
    ssh "root@${AGLDV03_IP}" "cat ${AGLDV03_CONFIG}" | \
      sed -e 's|http://192.168.0.200:11434|http://100.116.57.111:11434|g' \
          -e 's|host: "192.168.0.137"|host: "litellm-redis"|' \
          -e 's|# Redis Cache Configuration (CT137 - aglsrv1)|# Redis Cache Configuration (local - litellm-redis)|' \
          -e '/password: "os.environ\/REDIS_PASSWORD"/d' | \
      ssh "root@${ip}" "cat > /opt/litellm/config.yaml"
  else
    scp -q "root@${AGLDV03_IP}:${AGLDV03_CONFIG}" "root@${ip}:/opt/litellm/config.yaml"
  fi

  ssh "root@${ip}" "cd /opt/litellm && docker compose restart litellm-proxy 2>/dev/null || true"
done

echo ""
echo "=== Concluído ==="
