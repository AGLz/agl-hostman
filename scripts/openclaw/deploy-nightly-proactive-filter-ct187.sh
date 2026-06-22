#!/usr/bin/env bash
# Deploy nightly-proactive-check.sh filtrado + reset offset log (CT187).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_HOST="${AGLSRV1_HOST:-AGLSRV1}"
CTID="${OPENCLAW_CTID:-187}"
CONTAINER="${OPENCLAW_CONTAINER:-agl-openclaw-openclaw-gateway-1}"
SCRIPT_SRC="${REPO_ROOT}/config/openclaw/scripts/nightly-proactive-check.sh"

[[ -f "$SCRIPT_SRC" ]] || { echo "Missing $SCRIPT_SRC" >&2; exit 1; }

scp -o BatchMode=yes "$SCRIPT_SRC" "${REMOTE_HOST}:/tmp/nightly-proactive-check.sh"

ssh -o BatchMode=yes "$REMOTE_HOST" bash -s -- "$CTID" "$CONTAINER" <<'REMOTE'
set -euo pipefail
CTID="$1"
CONTAINER="$2"
pct push "$CTID" /tmp/nightly-proactive-check.sh /tmp/nightly-proactive-check.sh
pct exec "$CTID" -- docker cp /tmp/nightly-proactive-check.sh \
  "${CONTAINER}:/home/node/.openclaw/workspace/scripts/nightly-proactive-check.sh"
pct exec "$CTID" -- docker exec -u root "$CONTAINER" sh -c \
  "chown node:node /home/node/.openclaw/workspace/scripts/nightly-proactive-check.sh && chmod +x /home/node/.openclaw/workspace/scripts/nightly-proactive-check.sh && sed -i 's/\r$//' /home/node/.openclaw/workspace/scripts/nightly-proactive-check.sh"

# Avançar offset para fim do log de hoje — não reprocessar erros LLM legados
pct exec "$CTID" -- docker exec "$CONTAINER" sh -c '
LOG="/tmp/openclaw/openclaw-$(date +%F).log"
OFF="/home/node/.openclaw/workspace/proactivity/state/nightly-proactive-check.log.offset"
mkdir -p "$(dirname "$OFF")"
if [ -f "$LOG" ]; then wc -c < "$LOG" | tr -d " " > "$OFF"; else echo 0 > "$OFF"; fi
: > /home/node/.openclaw/workspace/proactivity/state/nightly-proactive-check.last-warnings
'

echo "--- dry-run ---"
pct exec "$CTID" -- docker exec "$CONTAINER" /home/node/.openclaw/workspace/scripts/nightly-proactive-check.sh || true

echo "--- cron run ---"
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron run 8f9a4b3c-2d1e-4f5a-6b7c-8d9e0f1a2b3c --wait --wait-timeout 2m 2>&1 | grep -E '"status"|summary|deliveryStatus' | head -6
REMOTE

echo "Deploy nightly-proactive filter concluído."
