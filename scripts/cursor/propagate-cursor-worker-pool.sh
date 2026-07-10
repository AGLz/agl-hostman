#!/usr/bin/env bash
# Propaga Cursor My Machines worker (Pro+, sem --pool) para hosts AGLDV*.
#
# Uso:
#   bash scripts/cursor/propagate-cursor-worker-pool.sh --host agldv03
#   bash scripts/cursor/propagate-cursor-worker-pool.sh --host agldv-all
#   bash scripts/cursor/propagate-cursor-worker-pool.sh --host agldv-all --dry-run
#
# Pré-requisito: User API Key em /etc/cursor/worker-pool.env ou CURSOR_API_KEY no ambiente
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

declare -A HOST_IPS
HOST_IPS[agldv02]="100.95.204.85"
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.82.71.49"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.64.175.89"
HOST_IPS[agldv12]="100.71.217.115"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
SCP=(scp -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
DRY_RUN=0
HOST=""
SYNC_ENV=1

usage() {
  cat <<USAGE
Usage: $(basename "$0") --host <agldv02|agldv03|...|agldv12|agldv-all> [--dry-run] [--no-sync-env]

Em cada host AGLDV:
  1. git pull agl-hostman (NFS)
  2. instalar/atualizar Cursor Agent CLI
  3. copiar /etc/cursor/worker-pool.env (se existir no origem)
  4. instalar/activar agl-cursor-worker-pool.service
USAGE
}

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

has_api_key_locally() {
  [[ -f /etc/cursor/worker-pool.env ]] || return 1
  grep -q '^CURSOR_API_KEY=.\+' /etc/cursor/worker-pool.env 2>/dev/null
}

propagate_env_to() {
  local ssh_target="$1"
  if [[ "$SYNC_ENV" -ne 1 ]]; then
    return 0
  fi
  if ! has_api_key_locally; then
    warn "Sem CURSOR_API_KEY local — saltar sync env para $ssh_target"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] scp /etc/cursor/worker-pool.env → $ssh_target:/etc/cursor/"
    return 0
  fi
  "${SSH[@]}" "$ssh_target" "mkdir -p /etc/cursor && chmod 700 /etc/cursor"
  "${SCP[@]}" /etc/cursor/worker-pool.env "$ssh_target:/etc/cursor/worker-pool.env"
  "${SSH[@]}" "$ssh_target" "chmod 600 /etc/cursor/worker-pool.env"
}

propagate_one() {
  local name="$1"
  local ip="$2"
  local ssh_target="root@$ip"
  local local_short
  local_short="$(hostname -s 2>/dev/null || hostname)"

  log "=== cursor-worker-pool $name ==="

  local install_cmd="cd '$HOSTMAN_ROOT' && \
    (test -d .git && git pull --ff-only || true) && \
    sudo AGL_HOSTMAN_DIR='$HOSTMAN_ROOT' bash scripts/cursor/install-cursor-worker-pool.sh"

  if [[ "$name" == "$local_short" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] local install-cursor-worker-pool.sh"
      return 0
    fi
    if [[ "$SYNC_ENV" -eq 1 ]] && [[ -n "${CURSOR_API_KEY:-}" ]]; then
      sudo bash "$HOSTMAN_ROOT/scripts/cursor/sync-cursor-worker-pool-env.sh" || true
    fi
    if command -v sudo >/dev/null 2>&1; then
      sudo AGL_HOSTMAN_DIR="$HOSTMAN_ROOT" bash "$HOSTMAN_ROOT/scripts/cursor/install-cursor-worker-pool.sh" || {
        warn "$name: install local falhou"
        return 1
      }
    else
      warn "$name: sudo ausente"
      return 1
    fi
  else
    if ! "${SSH[@]}" "$ssh_target" "test -f '$HOSTMAN_ROOT/scripts/cursor/install-cursor-worker-pool.sh'"; then
      warn "$name: agl-hostman NFS em falta — skip"
      return 0
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] ssh $ssh_target install"
      return 0
    fi
    if ! "${SSH[@]}" "$ssh_target" "echo ok" >/dev/null 2>&1; then
      warn "$name UNREACHABLE — skip"
      return 1
    fi
    propagate_env_to "$ssh_target" || warn "$name: sync env falhou"
    "${SSH[@]}" "$ssh_target" \
      "git config --global --add safe.directory '$HOSTMAN_ROOT' 2>/dev/null || true; $install_cmd" \
      || { warn "$name: propagate falhou"; return 1; }
  fi
  ok "$name cursor-worker-pool propagate concluído"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-sync-env) SYNC_ENV=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$HOST" ]] || { usage; exit 2; }

run_all() {
  local FAIL=0
  for name in agldv02 agldv03 agldv04 agldv05 agldv06 agldv07 agldv12; do
    propagate_one "$name" "${HOST_IPS[$name]}" || { warn "$name"; FAIL=1; }
  done
  [[ "$FAIL" -eq 0 ]]
}

case "$HOST" in
  agldv02|agldv03|agldv04|agldv05|agldv06|agldv07|agldv12)
    propagate_one "$HOST" "${HOST_IPS[$HOST]}"
    ;;
  agldv-all)
    run_all
    ;;
  *)
    echo "Host desconhecido: $HOST" >&2
    usage
    exit 2
    ;;
esac
