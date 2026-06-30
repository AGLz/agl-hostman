#!/usr/bin/env bash
# Instala entradas cron para sync t.me/s/ + validação de ofertas (idempotente).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="${PYTHON:-python3}"
MARKER="pc-gamer-cotacoes-tme-scraper"
LOG_DIR="$ROOT/data/logs"
mkdir -p "$LOG_DIR"

SYNC_LINE="*/15 * * * * cd $ROOT && $PYTHON scripts/sync_tme_cron.py >> $LOG_DIR/sync-tme.log 2>&1 # $MARKER-sync"
VALID_LINE="*/30 * * * * cd $ROOT && $PYTHON scripts/validate_offers_cron.py >> $LOG_DIR/validate-offers.log 2>&1 # $MARKER-validate"

if crontab -l 2>/dev/null | grep -q "$MARKER-sync"; then
  echo "Cron já instalado ($MARKER). Nada a fazer."
  exit 0
fi

{
  crontab -l 2>/dev/null || true
  echo "$SYNC_LINE"
  echo "$VALID_LINE"
} | crontab -

echo "Cron instalado:"
echo "  sync:     a cada 15 min → $LOG_DIR/sync-tme.log"
echo "  validate: a cada 30 min → $LOG_DIR/validate-offers.log"
