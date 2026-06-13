#!/usr/bin/env bash
# P0 OpenClaw CT187: scripts architect/weekly + escalonamento cron diário.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_HOST="${AGLSRV1_HOST:-AGLSRV1}"
CTID="${OPENCLAW_CTID:-187}"
CONTAINER="${OPENCLAW_CONTAINER:-agl-openclaw-openclaw-gateway-1}"

SCRIPTS=(
  openclaw-architect-check.sh
  weekly-self-reflection-check.sh
)

for s in "${SCRIPTS[@]}"; do
  [[ -f "${REPO_ROOT}/config/openclaw/scripts/${s}" ]] || {
    echo "Missing config/openclaw/scripts/${s}" >&2
    exit 1
  }
done

scp -o BatchMode=yes "${SCRIPTS[@]/#/${REPO_ROOT}/config/openclaw/scripts/}" "${REMOTE_HOST}:/tmp/"

ssh -o BatchMode=yes "$REMOTE_HOST" bash -s -- "$CTID" "$CONTAINER" <<'REMOTE'
set -euo pipefail
CTID="$1"
CONTAINER="$2"

for s in openclaw-architect-check.sh weekly-self-reflection-check.sh; do
  pct push "$CTID" "/tmp/${s}" "/tmp/${s}"
  pct exec "$CTID" -- docker cp "/tmp/${s}" "${CONTAINER}:/home/node/.openclaw/workspace/scripts/${s}"
  pct exec "$CTID" -- docker exec -u root "$CONTAINER" sh -c \
    "chown node:node /home/node/.openclaw/workspace/scripts/${s} && chmod +x /home/node/.openclaw/workspace/scripts/${s} && sed -i 's/\r$//' /home/node/.openclaw/workspace/scripts/${s}"
done

# Escalonamento diário (America/Sao_Paulo) — evita burst LLM ~19:44
declare -A CRON_EDITS=(
  ["523d219f-3fea-4855-9bb9-1886acd14658"]="0 8,20 * * *"   # morning-briefing: 08:00 e 20:00
  ["6f8b2a1c-4d3e-5f6a-7b8c-9d0e1f2a3b4c"]="30 8 * * *"    # daily-maintenance
  ["7a9c3b2d-5e4f-6a7b-8c9d-0e1f2a3b4c5d"]="0 9 * * *"      # daily-backup
  ["8f9a4b3c-2d1e-4f5a-6b7c-8d9e0f1a2b3c"]="0 22 * * *"     # nightly-proactive
)

for id in "${!CRON_EDITS[@]}"; do
  expr="${CRON_EDITS[$id]}"
  echo "--- cron edit $id -> $expr ---"
  pct exec "$CTID" -- docker exec "$CONTAINER" \
    openclaw cron edit "$id" --cron "$expr" --tz America/Sao_Paulo --exact >/dev/null
done

echo "--- script dry-runs ---"
for s in openclaw-architect-check.sh weekly-self-reflection-check.sh; do
  echo "== $s =="
  pct exec "$CTID" -- docker exec "$CONTAINER" "/home/node/.openclaw/workspace/scripts/${s}" || true
done

echo "--- cron list (next runs) ---"
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron list
REMOTE

echo "Deploy P0 CT187 concluído."
