#!/usr/bin/env bash
# Instala systemd agl-cursor-worker-pool (My Machines / Pro+) no host AGLDV*.
#
# Uso:
#   sudo bash scripts/cursor/install-cursor-worker-pool.sh
#   sudo bash scripts/cursor/install-cursor-worker-pool.sh --dry-run
#   sudo bash scripts/cursor/install-cursor-worker-pool.sh --no-start
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
DRY_RUN=0
NO_START=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --no-start) NO_START=1; shift ;;
    -h|--help)
      sed -n '2,9p' "$0"
      exit 0
      ;;
    *) echo "Uso: $0 [--dry-run] [--no-start]" >&2; exit 2 ;;
  esac
done

HOST_SHORT="$(hostname -s 2>/dev/null || hostname)"
SERVICE_SRC="$REPO/config/systemd/agl-cursor-worker-pool.service"
LABELS_EXAMPLE="$REPO/config/cursor/labels.example.json"
LABELS_DST="/etc/cursor/worker-labels.json"

if [[ ! -f "$SERVICE_SRC" ]] || [[ ! -f "$LABELS_EXAMPLE" ]]; then
  echo "[FAIL] ficheiros config em falta em $REPO/config/" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] install CLI + labels host=$HOST_SHORT + systemd unit"
  exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[FAIL] correr com sudo" >&2
  exit 1
fi

bash "$REPO/scripts/cursor/install-cursor-agent-cli.sh"

mkdir -p /etc/cursor
chmod 700 /etc/cursor

TMP_LABELS="$(mktemp)"
sed "s/HOSTNAME_PLACEHOLDER/$HOST_SHORT/" "$LABELS_EXAMPLE" >"$TMP_LABELS"
install -m 0644 -o root -g root "$TMP_LABELS" "$LABELS_DST"
rm -f "$TMP_LABELS"

TMP_SERVICE="$(mktemp)"
sed \
  -e "s|Environment=AGL_HOSTMAN_DIR=.*|Environment=AGL_HOSTMAN_DIR=$REPO|" \
  -e "s|/mnt/overpower/apps/dev/agl/agl-hostman|$REPO|g" \
  -e "s|WORKER_NAME_PLACEHOLDER|$HOST_SHORT|g" \
  "$SERVICE_SRC" >"$TMP_SERVICE"

install -m 0644 "$TMP_SERVICE" /etc/systemd/system/agl-cursor-worker-pool.service
rm -f "$TMP_SERVICE"

if [[ ! -f /etc/cursor/worker-pool.env ]]; then
  install -m 0600 -o root -g root "$REPO/config/cursor/worker-pool.env.example" /etc/cursor/worker-pool.env
  echo "[WARN] /etc/cursor/worker-pool.env criado — User API Key (Dashboard) ou agent login"
fi

systemctl daemon-reload

if [[ "$NO_START" -eq 1 ]]; then
  echo "[OK] unit instalada (sem start) host=$HOST_SHORT"
  exit 0
fi

if bash "$REPO/scripts/cursor/ensure-cursor-worker-pool-ready.sh" 2>/dev/null; then
  systemctl enable agl-cursor-worker-pool.service
  systemctl restart agl-cursor-worker-pool.service || warn "restart falhou — ver journalctl -u agl-cursor-worker-pool"
  echo "[OK] agl-cursor-worker-pool activo (host=$HOST_SHORT)"
  systemctl status agl-cursor-worker-pool.service --no-pager || true
else
  systemctl disable agl-cursor-worker-pool.service 2>/dev/null || true
  systemctl stop agl-cursor-worker-pool.service 2>/dev/null || true
  echo "[WARN] sem auth — unit instalada mas disabled (User API Key ou agent login)"
fi
