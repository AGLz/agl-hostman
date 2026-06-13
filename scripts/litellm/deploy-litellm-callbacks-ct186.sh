#!/usr/bin/env bash
# Copia config.yaml + custom_callbacks para CT186, garante volume no compose e recria proxy.
set -euo pipefail
REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
HOST="${LITELLM_SSH_HOST:-root@100.125.249.8}"
REMOTE_DIR="${LITELLM_REMOTE_DIR:-/opt/agl-litellm}"

scp -q "$REPO/config/litellm/config.yaml" "$HOST:$REMOTE_DIR/config.yaml"
scp -rq "$REPO/config/litellm/custom_callbacks" "$HOST:$REMOTE_DIR/"
ssh "$HOST" "mkdir -p $REMOTE_DIR/scripts"
scp -q "$REPO/scripts/litellm/test-ollama-litellm-content.sh" \
  "$REPO/scripts/litellm/_litellm-master-key.sh" \
  "$HOST:$REMOTE_DIR/scripts/"
ssh "$HOST" "chmod +x $REMOTE_DIR/scripts/*.sh"

PATCH="$REPO/scripts/litellm/patch-litellm-compose-callbacks-remote.sh"
scp -q "$PATCH" "$HOST:/tmp/patch-litellm-compose-callbacks.sh"
ssh "$HOST" "LITELLM_COMPOSE=$REMOTE_DIR/docker-compose.yml bash /tmp/patch-litellm-compose-callbacks.sh && rm -f /tmp/patch-litellm-compose-callbacks.sh"
ssh "$HOST" bash -s -- "$REMOTE_DIR" <<'REMOTE'
set -euo pipefail
REMOTE_DIR="$1"
cd "$REMOTE_DIR"
docker compose up -d --force-recreate litellm-proxy
echo "A aguardar readiness..."
for _ in $(seq 1 90); do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:4000/health/readiness 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]]; then
    echo "OK: readiness HTTP $code"
    exit 0
  fi
  sleep 1
done
echo "Aviso: readiness timeout — ver docker logs litellm-proxy --tail 50"
exit 1
REMOTE

echo "OK: config + custom_callbacks + scripts/smoke em $HOST:$REMOTE_DIR"
echo "Smoke no CT186: LITELLM_ENV_FILE=$REMOTE_DIR/.env LITELLM_URL=http://127.0.0.1:4000 bash $REMOTE_DIR/scripts/test-ollama-litellm-content.sh agl-primary"
echo "Smoke strong: ... test-ollama-litellm-content.sh agl-primary-strong"
