#!/usr/bin/env bash
# Propaga Cursor My Machines worker (Pro+, sem --pool) para hosts AGLDV*.
#
# Uso:
#   bash scripts/cursor/propagate-cursor-worker-pool.sh --host agldv-all
#   bash scripts/cursor/propagate-cursor-worker-pool.sh --host agldv03 --sync-env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

declare -A HOST_IPS=(
  [agldv02]=100.95.204.85
  [agldv03]=100.94.221.87
  [agldv04]=100.113.9.98
  [agldv05]=100.82.71.49
  [agldv06]=100.71.229.12
  [agldv07]=100.64.175.89
  [agldv12]=100.71.217.115
)

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
SCP=(scp -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
DRY_RUN=0
HOST=""
SYNC_ENV=0

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") --host <agldv02|...|agldv12|agldv-all> [--dry-run] [--sync-env]

  --sync-env  Copia /etc/cursor/worker-pool.env do host actual para remotos
USAGE
}

has_api_key_locally() {
  [[ -f /etc/cursor/worker-pool.env ]] || return 1
  python3 - <<'PY'
import re
from pathlib import Path
p = Path("/etc/cursor/worker-pool.env")
if not p.exists():
    raise SystemExit(1)
for ln in p.read_text().splitlines():
    m = re.match(r'^CURSOR_API_KEY=(.+)$', ln.strip())
    if m and len(m.group(1).strip()) >= 20:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

propagate_env_to() {
  local ssh_target="$1"
  [[ "$SYNC_ENV" -eq 1 ]] || return 0
  has_api_key_locally || { warn "Sem CURSOR_API_KEY local — skip sync $ssh_target"; return 0; }
  [[ "$DRY_RUN" -eq 1 ]] && { echo "  [dry-run] scp env → $ssh_target"; return 0; }
  "${SSH[@]}" "$ssh_target" "mkdir -p /etc/cursor && chmod 700 /etc/cursor"
  "${SCP[@]}" /etc/cursor/worker-pool.env "$ssh_target:/etc/cursor/worker-pool.env"
  "${SSH[@]}" "$ssh_target" "chmod 600 /etc/cursor/worker-pool.env"
}

propagate_one() {
  local name="$1" ip="$2"
  local ssh_target="root@$ip"
  local local_short
  local_short="$(hostname -s 2>/dev/null || hostname)"
  local install_cmd="cd '$HOSTMAN_ROOT' && (test -d .git && git pull --ff-only || true) && sudo AGL_HOSTMAN_DIR='$HOSTMAN_ROOT' bash scripts/cursor/install-cursor-worker-pool.sh"

  log "=== cursor-worker $name ==="

  if [[ "$name" == "$local_short" ]]; then
    [[ "$DRY_RUN" -eq 1 ]] && { echo "  [dry-run] local install"; return 0; }
    [[ -n "${CURSOR_API_KEY:-}" ]] && sudo bash "$HOSTMAN_ROOT/scripts/cursor/sync-cursor-worker-pool-env.sh" || true
    sudo AGL_HOSTMAN_DIR="$HOSTMAN_ROOT" bash "$HOSTMAN_ROOT/scripts/cursor/install-cursor-worker-pool.sh"
  else
    [[ "$DRY_RUN" -eq 1 ]] && { echo "  [dry-run] ssh $name"; return 0; }
    "${SSH[@]}" "$ssh_target" "echo ok" >/dev/null 2>&1 || { warn "$name UNREACHABLE"; return 1; }
    "${SSH[@]}" "$ssh_target" "test -f '$HOSTMAN_ROOT/scripts/cursor/install-cursor-worker-pool.sh'" 2>/dev/null || {
      warn "$name: NFS agl-hostman em falta — skip"; return 0;
    }
    propagate_env_to "$ssh_target" || warn "$name: sync env falhou"
    "${SSH[@]}" "$ssh_target" "git config --global --add safe.directory '$HOSTMAN_ROOT' 2>/dev/null || true; $install_cmd" \
      || { warn "$name: install falhou"; return 1; }
    if [[ "$SYNC_ENV" -eq 1 ]] && has_api_key_locally; then
      "${SSH[@]}" "$ssh_target" "sudo AGL_HOSTMAN_DIR='$HOSTMAN_ROOT' bash '$HOSTMAN_ROOT/scripts/cursor/enable-cursor-worker.sh'" \
        || warn "$name: enable falhou"
    fi
  fi
  ok "$name concluído"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --sync-env) SYNC_ENV=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$HOST" ]] || { usage; exit 2; }

run_all() {
  local FAIL=0 n
  for n in agldv02 agldv03 agldv04 agldv05 agldv06 agldv07 agldv12; do
    propagate_one "$n" "${HOST_IPS[$n]}" || { warn "$n"; FAIL=1; }
  done
  [[ "$FAIL" -eq 0 ]]
}

case "$HOST" in
  agldv02|agldv03|agldv04|agldv05|agldv06|agldv07|agldv12) propagate_one "$HOST" "${HOST_IPS[$HOST]}" ;;
  agldv-all) run_all ;;
  *) echo "Host desconhecido: $HOST" >&2; usage; exit 2 ;;
esac
