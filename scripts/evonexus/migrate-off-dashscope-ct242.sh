#!/usr/bin/env bash
# Atualiza CT548 EvoNexus (fgsrv7; antes CT242): modelos .env + providers.json sem DashScope.
# Uso: bash scripts/evonexus/migrate-off-dashscope-ct242.sh

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST="${EVONEXUS_SSH_HOST:-root@100.109.181.93}"
CTID="${EVONEXUS_CTID:-548}"
DEFAULT_MODEL="${EVONEXUS_DEFAULT_MODEL:---agl-tier-2026}"
ENV_FILE="/workspace/config/.env"

scp -q "$REPO_ROOT/scripts/evonexus/sync-providers-anthropic-from-env.py" \
  "$REPO_ROOT/scripts/evonexus/patch-evonexus-env-models.py" \
  "${HOST}:/tmp/"

ssh "$HOST" "pct push $CTID /tmp/sync-providers-anthropic-from-env.py /tmp/sync-providers-anthropic-from-env.py && \
  pct push $CTID /tmp/patch-evonexus-env-models.py /tmp/patch-evonexus-env-models.py"

for c in evonexus-scheduler evonexus-dashboard evonexus-telegram; do
  echo "==> $c"
  ssh "$HOST" "pct exec $CTID -- docker cp /tmp/patch-evonexus-env-models.py ${c}:/tmp/patch-evonexus-env-models.py && \
    pct exec $CTID -- docker cp /tmp/sync-providers-anthropic-from-env.py ${c}:/tmp/sync-providers-anthropic-from-env.py && \
    pct exec $CTID -- docker exec $c python3 /tmp/patch-evonexus-env-models.py '$DEFAULT_MODEL' '$ENV_FILE' && \
    pct exec $CTID -- docker exec $c python3 /tmp/sync-providers-anthropic-from-env.py" || echo "WARN: $c skipped"
done

echo "==> Verificar"
ssh "$HOST" "pct exec $CTID -- docker exec evonexus-scheduler sh -c 'grep -E \"^(OPENAI_MODEL|ANTHROPIC_MODEL|EVONEXUS|ZAI_|OPENAI_FALLBACK)=\" $ENV_FILE'"

echo "==> Reiniciar contentores (providers + .env)"
ssh "$HOST" "pct exec $CTID -- docker compose -f /opt/evonexus/docker-compose.hub.yml restart dashboard scheduler telegram"
