#!/usr/bin/env bash
# Remove entradas cron do sidecar t.me/s/ (idempotente).
set -euo pipefail

MARKER="pc-gamer-cotacoes-tme-scraper"

if ! crontab -l 2>/dev/null | grep -q "$MARKER"; then
  echo "Nenhum cron $MARKER encontrado."
  exit 0
fi

crontab -l 2>/dev/null | grep -v "$MARKER" | crontab -
echo "Cron sidecar removido ($MARKER). Sync/validação passam a correr no Laravel CT134."
