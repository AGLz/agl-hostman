#!/usr/bin/env bash
# Pull / refresh symlinks live após mudar de máquina — Cursor FECHADO.
#
# Uso:
#   ./scripts/dotfiles/cursor-sync-pull.sh
#   ./scripts/dotfiles/cursor-sync-pull.sh --reinstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reinstall) REINSTALL=1; shift ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--reinstall]"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

if pgrep -x cursor >/dev/null 2>&1 || pgrep -f "Cursor" >/dev/null 2>&1; then
  echo "[FAIL] Cursor parece estar a correr — fechar antes de pull" >&2
  exit 1
fi

AGL_HOME_SYNC_ROOT="${AGL_HOME_SYNC_ROOT:-/mnt/overpower/apps/dev/agl/agl-home-sync}"
AGL_HOME_USER="${AGL_HOME_USER:-linux-root}"
LIVE_ROOT="$AGL_HOME_SYNC_ROOT/$AGL_HOME_USER"
LATEST="$(ls -t "$LIVE_ROOT"/.sync-push-* 2>/dev/null | head -1 || true)"

if [[ -n "$LATEST" ]]; then
  echo "[INFO] último push: $LATEST"
else
  echo "[WARN] nenhum stamp .sync-push encontrado — dados NFS podem estar desactualizados"
fi

if [[ "$REINSTALL" -eq 1 ]]; then
  exec "$SCRIPT_DIR/install-agl-home-sync.sh" --skip-migrate
fi

"$SCRIPT_DIR/verify-agl-home-sync.sh"
