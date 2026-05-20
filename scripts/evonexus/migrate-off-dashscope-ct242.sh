#!/usr/bin/env bash
# Atualiza CT242 EvoNexus: modelos .env + providers.json sem DashScope.
# Uso: bash scripts/evonexus/migrate-off-dashscope-ct242.sh

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST="${EVONEXUS_SSH_HOST:-root@191.252.93.227}"
CTID="${EVONEXUS_CTID:-242}"
DEFAULT_MODEL="${EVONEXUS_DEFAULT_MODEL:-glm-4.7-flash}"
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
ssh "$HOST" "pct exec $CTID -- docker exec evonexus-scheduler sh -c 'grep -E \"^(OPENAI_MODEL|ANTHROPIC_MODEL|EVONEXUS)=\" $ENV_FILE'"

echo "Done. Reload LiteLLM no gateway com config/litellm/config.yaml actualizado."
