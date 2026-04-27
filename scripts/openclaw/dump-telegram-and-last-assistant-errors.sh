#!/usr/bin/env bash
set -euo pipefail
OC=/root/.openclaw/openclaw.json

echo "======== Telegram channel (pairing / ACL) =========="
jq '.channels.telegram' "$OC" | jq 'del(.botToken)'

echo ""
echo "======== Últimas 5 mensagens assistant (message completo) =========="
SESS=$(grep -l '1272190248' /root/.openclaw/agents/main/sessions/*.jsonl 2>/dev/null | head -1 || true)
if [[ -z "${SESS:-}" ]]; then exit 0; fi
jq -c 'select(.type=="message" and .message.role=="assistant")' "$SESS" | tail -5 | while read -r line; do
  echo "$line" | jq '{model: .message.model, stop: .message.stopReason, err: .message.error, meta: .message}'
done
