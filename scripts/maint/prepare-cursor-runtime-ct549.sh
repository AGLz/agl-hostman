#!/usr/bin/env bash
# Pré-aquece runtime Cursor no CT549: npm ci do vtd, smoke MCP filesystem.
#
# Uso (no CT, após install-node20-ct549.sh):
#   FG_LEGACY_ROOT=/var/www/fg_antigo bash scripts/maint/prepare-cursor-runtime-ct549.sh
set -euo pipefail

FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
NPX="${NPX:-/usr/local/bin/npx20}"
FAIL=0

log() { printf '[cursor-runtime] %s\n' "$*"; }

if [[ ! -x "$NPX" ]]; then
  NPX="$(command -v npx20 || command -v npx || true)"
fi
[[ -n "$NPX" ]] || { log "npx20 em falta — correr install-node20-ct549.sh"; exit 1; }

log "npx: $NPX ($($NPX --version 2>/dev/null || echo '?'))"

VTD="${FG_LEGACY_ROOT}/.cursor/skills/video-transcript-downloader"
if [[ -f "$VTD/package.json" ]]; then
  log "npm ci video-transcript-downloader"
  (cd "$VTD" && npm ci --silent) || { log "WARN vtd npm ci falhou"; FAIL=1; }
else
  log "SKIP vtd (sem package.json)"
fi

log "smoke MCP @modelcontextprotocol/server-filesystem (dry fetch)"
TMP="$(mktemp -d)"
timeout 45 "$NPX" -y @modelcontextprotocol/server-filesystem "$TMP" </dev/null &
PID=$!
sleep 8
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  log "OK MCP server arrancou (stdio)"
else
  log "WARN MCP process terminou cedo"
  FAIL=1
fi
rm -rf "$TMP"

[[ "$FAIL" -eq 0 ]]
