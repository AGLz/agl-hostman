#!/usr/bin/env bash
# Mescla channels.telegram + plugins.entries.telegram a partir de um backup openclaw.json.
# Uso: ./merge-telegram-from-backup.sh [caminho-backup]
# Default: ~/.openclaw/openclaw.json.bak.20260301
set -euo pipefail

BACKUP="${1:-$HOME/.openclaw/openclaw.json.bak.20260301}"
CFG="$HOME/.openclaw/openclaw.json"

if [[ ! -f "$BACKUP" ]]; then
  echo "Erro: backup não encontrado: $BACKUP" >&2
  exit 1
fi
if [[ ! -f "$CFG" ]]; then
  echo "Erro: config não encontrado: $CFG" >&2
  exit 1
fi

if ! jq -e '.channels.telegram.botToken' "$BACKUP" >/dev/null 2>&1; then
  echo "Erro: $BACKUP não contém channels.telegram.botToken" >&2
  exit 1
fi

cp "$CFG" "${CFG}.bak.pre-telegram-$(date +%Y%m%d%H%M%S)"

jq --slurpfile b "$BACKUP" '
  .channels.telegram = $b[0].channels.telegram |
  .plugins = (.plugins // {}) |
  .plugins.entries = (.plugins.entries // {}) |
  .plugins.entries.telegram = ($b[0].plugins.entries.telegram // .plugins.entries.telegram // {enabled: true})
' "$CFG" > /tmp/oc-telegram-merge.json

mv /tmp/oc-telegram-merge.json "$CFG"
echo "OK: Telegram aplicado a partir de $BACKUP"
