#!/usr/bin/env bash
# Push estado Cursor/Claude live para NFS — usar com Cursor FECHADO (sync-on-close).
#
# Uso antes de mudar de máquina:
#   ./scripts/dotfiles/cursor-sync-push.sh
#
# Na máquina destino (Cursor fechado):
#   ./scripts/dotfiles/cursor-sync-pull.sh

set -euo pipefail

AGL_HOME_SYNC_ROOT="${AGL_HOME_SYNC_ROOT:-/mnt/overpower/apps/dev/agl/agl-home-sync}"
AGL_HOME_USER="${AGL_HOME_USER:-linux-root}"
LIVE_ROOT="$AGL_HOME_SYNC_ROOT/$AGL_HOME_USER"

if pgrep -x cursor >/dev/null 2>&1 || pgrep -f "Cursor" >/dev/null 2>&1; then
  echo "[FAIL] Cursor parece estar a correr — fechar antes de push" >&2
  exit 1
fi

if [[ ! -d "$LIVE_ROOT" ]]; then
  echo "[FAIL] LIVE_ROOT em falta: $LIVE_ROOT" >&2
  exit 1
fi

TS="$(date +%Y%m%d%H%M%S)"
STAMP="$LIVE_ROOT/.sync-push-$TS"

echo "[INFO] push sync stamp -> $STAMP"
touch "$STAMP"

for rel in \
  cursor/globalStorage \
  cursor/dot-cursor/chats \
  cursor/dot-cursor/projects \
  claude/history.jsonl \
  claude/file-history; do
  src="$LIVE_ROOT/$rel"
  if [[ -e "$src" ]]; then
    echo "  OK   $rel ($(du -sh "$src" 2>/dev/null | awk '{print $1}'))"
  else
    echo "  MISS $rel"
  fi
done

echo "[OK] push concluído — dados já estão em NFS (symlinks). Stamp: $STAMP"
