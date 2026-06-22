#!/usr/bin/env bash
# Verificação diária stack media (*arr) — modo grabs-only / freeze.
# Uso: hermes-orion-media-daily.sh [--telegram]
set -euo pipefail

REPO="${AGL_HOSTMAN:-/opt/agl-hostman}"
MEDIA="${REPO}/scripts/media/arr-freeze-downloads.sh"
TS="$(date -Iseconds)"

log() { printf '[orion-media] %s %s\n' "$TS" "$*"; }

if [[ ! -x "$MEDIA" ]] && [[ -f "$MEDIA" ]]; then
  chmod +x "$MEDIA" 2>/dev/null || true
fi

if [[ ! -f "$MEDIA" ]]; then
  log "ERRO: falta $MEDIA"
  exit 1
fi

log "=== arr-freeze --verify-only ==="
OUT="$(bash "$MEDIA" --verify-only 2>&1)" || true
echo "$OUT"

if echo "$OUT" | grep -qE 'Radarr: enabled=\[\]'; then
  log "OK modo grabs-only (downloads OFF)"
else
  log "WARN: downloads podem estar ON — rever MEDIA-ARR-MAINTENANCE.md"
fi

log "=== fim ==="
