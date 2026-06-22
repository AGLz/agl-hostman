#!/usr/bin/env bash
# Corrige cron jobs (command sem LLM) + Telegram dmPolicy no CT187.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_HOST="${AGLSRV1_HOST:-AGLSRV1}"
CTID="${OPENCLAW_CTID:-187}"
CONTAINER="${OPENCLAW_CONTAINER:-agl-openclaw-openclaw-gateway-1}"
TELEGRAM_USER="${OPENCLAW_TELEGRAM_USER:-1272190248}"

scp -o BatchMode=yes \
  "${REPO_ROOT}/config/openclaw/scripts/openclaw-architect-check.sh" \
  "${REPO_ROOT}/config/openclaw/scripts/weekly-self-reflection-check.sh" \
  "${REPO_ROOT}/scripts/openclaw/patch-openclaw-telegram-allow-ct187.py" \
  "${REMOTE_HOST}:/tmp/"

ssh -o BatchMode=yes "$REMOTE_HOST" bash -s -- "$CTID" "$CONTAINER" "$TELEGRAM_USER" <<'REMOTE'
set -euo pipefail
CTID="$1"
CONTAINER="$2"
TG_USER="$3"

for s in openclaw-architect-check.sh weekly-self-reflection-check.sh; do
  pct push "$CTID" "/tmp/${s}" "/tmp/${s}"
  pct exec "$CTID" -- docker cp "/tmp/${s}" "${CONTAINER}:/home/node/.openclaw/workspace/scripts/${s}"
  pct exec "$CTID" -- docker exec -u root "$CONTAINER" sh -c \
    "chown node:node /home/node/.openclaw/workspace/scripts/${s} && chmod +x /home/node/.openclaw/workspace/scripts/${s} && sed -i 's/\r$//' /home/node/.openclaw/workspace/scripts/${s}"
done

pct push "$CTID" /tmp/patch-openclaw-telegram-allow-ct187.py /tmp/patch-openclaw-telegram-allow-ct187.py
pct exec "$CTID" -- docker cp /tmp/patch-openclaw-telegram-allow-ct187.py "${CONTAINER}:/tmp/patch-openclaw-telegram-allow-ct187.py"
pct exec "$CTID" -- docker exec "$CONTAINER" python3 /tmp/patch-openclaw-telegram-allow-ct187.py "$TG_USER"

# Cron: command payload (sem LLM). Monitores silenciosos em OK; briefing entrega stdout.
declare -A SILENT=(
  ["9a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d"]="/home/node/.openclaw/workspace/scripts/critical-services-monitor.sh"
  ["2a3c57b1-0558-4ab7-8eae-34692e9d72e9"]="/home/node/.openclaw/workspace/scripts/storage-health-check.sh"
  ["6f8b2a1c-4d3e-5f6a-7b8c-9d0e1f2a3b4c"]="/home/node/.openclaw/workspace/scripts/daily-maintenance-check.sh"
  ["b2c3d4e5-f6a7-b8c9-d0e1-f2a3b4c5d6e7"]="/home/node/.openclaw/workspace/scripts/openclaw-architect-check.sh"
  ["8f9a4b3c-2d1e-4f5a-6b7c-8d9e0f1a2b3c"]="/home/node/.openclaw/workspace/scripts/nightly-proactive-check.sh"
  ["a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d"]="/home/node/.openclaw/workspace/scripts/weekly-self-reflection-check.sh"
)

for id in "${!SILENT[@]}"; do
  script="${SILENT[$id]}"
  echo "--- cron command (silent) $id ---"
  pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron edit "$id" \
    --command "$script" \
    --no-deliver \
    --failure-alert \
    --failure-alert-after 1 \
    --failure-alert-to "$TG_USER" \
    --failure-alert-mode announce \
    --failure-alert-cooldown 1h \
    --best-effort-deliver \
    --timeout-seconds 120 >/dev/null
done

echo "--- cron command (announce) morning-briefing ---"
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron edit 523d219f-3fea-4855-9bb9-1886acd14658 \
  --command "/home/node/.openclaw/workspace/scripts/morning-briefing-check.sh" \
  --announce \
  --to "$TG_USER" \
  --channel telegram \
  --no-failure-alert \
  --timeout-seconds 120 >/dev/null

echo "--- cron command (silent) daily-backup ---"
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron edit 7a9c3b2d-5e4f-6a7b-8c9d-0e1f2a3b4c5d \
  --command "/home/node/.openclaw/workspace/scripts/daily-backup.sh" \
  --no-deliver \
  --failure-alert \
  --failure-alert-after 1 \
  --failure-alert-to "$TG_USER" \
  --failure-alert-mode announce \
  --failure-alert-cooldown 1h \
  --best-effort-deliver \
  --timeout-seconds 300 >/dev/null

# Reset intervalo critical-services (every 10m)
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron edit 9a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d \
  --every 10m >/dev/null

echo "--- restart gateway ---"
pct exec "$CTID" -- docker restart "$CONTAINER"
sleep 18
pct exec "$CTID" -- curl -sf http://127.0.0.1:28789/healthz

echo "--- test critical-services ---"
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron run 9a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d --wait --wait-timeout 2m 2>&1 | tail -8

echo "--- cron list ---"
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw cron list

echo "--- telegram ---"
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw channels status 2>&1 | tail -5
REMOTE

echo "Fix cron+telegram CT187 concluído."
