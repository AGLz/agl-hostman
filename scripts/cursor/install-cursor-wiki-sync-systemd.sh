#!/usr/bin/env bash
# Instala timer systemd agl-cursor-wiki-sync no host actual (AGLDV* com NFS llm-wiki).
#
# Uso:
#   sudo bash scripts/cursor/install-cursor-wiki-sync-systemd.sh
#   sudo bash scripts/cursor/install-cursor-wiki-sync-systemd.sh --dry-run
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *) echo "Uso: $0 [--dry-run]" >&2; exit 2 ;;
  esac
done

HOST_SHORT="$(hostname -s 2>/dev/null || hostname)"
SERVICE_SRC="$REPO/config/systemd/agl-cursor-wiki-sync.service"
TIMER_SRC="$REPO/config/systemd/agl-cursor-wiki-sync.timer"

if [[ ! -f "$SERVICE_SRC" ]] || [[ ! -f "$TIMER_SRC" ]]; then
  echo "[FAIL] units systemd em falta em config/systemd/" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] instalar $SERVICE_SRC e $TIMER_SRC"
  echo "[dry-run] CURSOR_EXPORT_HOST=$HOST_SHORT"
  echo "[dry-run] systemctl enable --now agl-cursor-wiki-sync.timer"
  exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[FAIL] correr com sudo para instalar units em /etc/systemd/system" >&2
  exit 1
fi

TMP_SERVICE="$(mktemp)"
sed \
  -e "s|Environment=AGL_HOSTMAN_DIR=.*|Environment=AGL_HOSTMAN_DIR=$REPO|" \
  -e "s|Environment=LLM_WIKI_DIR=.*|Environment=LLM_WIKI_DIR=${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}|" \
  -e "s|Environment=AGL_HOME_SYNC_ROOT=.*|Environment=AGL_HOME_SYNC_ROOT=${AGL_HOME_SYNC_ROOT:-/mnt/overpower/apps/dev/agl/agl-home-sync}|" \
  -e "s|Environment=CURSOR_EXPORT_HOST=.*||" \
  "$SERVICE_SRC" >"$TMP_SERVICE"

if ! grep -q "CURSOR_EXPORT_HOST" "$TMP_SERVICE"; then
  sed -i "/Environment=CURSOR_EXPORT_FILTER/a Environment=CURSOR_EXPORT_HOST=$HOST_SHORT" "$TMP_SERVICE"
fi

install -m 0644 "$TMP_SERVICE" /etc/systemd/system/agl-cursor-wiki-sync.service
install -m 0644 "$TIMER_SRC" /etc/systemd/system/agl-cursor-wiki-sync.timer
rm -f "$TMP_SERVICE"

systemctl daemon-reload
systemctl enable agl-cursor-wiki-sync.timer
systemctl start agl-cursor-wiki-sync.timer
systemctl start agl-cursor-wiki-sync.service || true

echo "[OK] timer agl-cursor-wiki-sync activo (host=$HOST_SHORT)"
systemctl status agl-cursor-wiki-sync.timer --no-pager || true
