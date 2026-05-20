#!/usr/bin/env bash
# Deploy morning-briefing digest script + cron payload to OpenClaw CT187.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="${REPO_ROOT}/config/openclaw/scripts/morning-briefing-check.sh"
PATCH_PY="${REPO_ROOT}/scripts/openclaw/patch-morning-briefing-digest.py"
REMOTE_HOST="${AGLSRV1_HOST:-AGLSRV1}"
CTID="${OPENCLAW_CTID:-187}"
CONTAINER="${OPENCLAW_CONTAINER:-agl-openclaw-openclaw-gateway-1}"

if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "Missing $SCRIPT_SRC" >&2
  exit 1
fi

scp -o BatchMode=yes "$SCRIPT_SRC" "$PATCH_PY" "${REMOTE_HOST}:/tmp/"

ssh -o BatchMode=yes "$REMOTE_HOST" bash -s -- "$CTID" "$CONTAINER" <<'REMOTE'
set -euo pipefail
CTID="$1"
CONTAINER="$2"
pct push "$CTID" /tmp/morning-briefing-check.sh /tmp/morning-briefing-check.sh
pct push "$CTID" /tmp/patch-morning-briefing-digest.py /tmp/patch-morning-briefing-digest.py
pct exec "$CTID" -- docker cp /tmp/morning-briefing-check.sh "${CONTAINER}:/home/node/.openclaw/workspace/scripts/morning-briefing-check.sh"
pct exec "$CTID" -- docker cp /tmp/patch-morning-briefing-digest.py "${CONTAINER}:/tmp/patch-morning-briefing-digest.py"
pct exec "$CTID" -- docker exec -u root "$CONTAINER" sh -c \
  "chown node:node /home/node/.openclaw/workspace/scripts/morning-briefing-check.sh && chmod +x /home/node/.openclaw/workspace/scripts/morning-briefing-check.sh && sed -i 's/\r$//' /home/node/.openclaw/workspace/scripts/morning-briefing-check.sh"
pct exec "$CTID" -- docker exec "$CONTAINER" python3 /tmp/patch-morning-briefing-digest.py /home/node/.openclaw/cron/jobs.json
echo "--- script dry-run ---"
pct exec "$CTID" -- docker exec "$CONTAINER" /home/node/.openclaw/workspace/scripts/morning-briefing-check.sh
REMOTE

echo "Deploy concluído."
