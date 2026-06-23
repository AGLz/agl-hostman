#!/usr/bin/env bash
# Propaga sync Cursor → llm-wiki para todos os hosts AGLDV* (timer systemd + smoke export).
#
# Uso:
#   ./scripts/cursor/propagate-cursor-wiki-sync.sh --host agldv04
#   ./scripts/cursor/propagate-cursor-wiki-sync.sh --host agldv-all
#   ./scripts/cursor/propagate-cursor-wiki-sync.sh --host agldv-all --dry-run
#
# Variáveis: AGLDV03_HOST … AGLDV12_HOST (mesmos defaults que propagate-six-repos.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"

AGLDV03_HOST="${AGLDV03_HOST:-root@100.94.221.87}"
AGLDV04_HOST="${AGLDV04_HOST:-root@100.113.9.98}"
AGLDV05_HOST="${AGLDV05_HOST:-root@100.82.71.49}"
AGLDV06_HOST="${AGLDV06_HOST:-root@100.71.229.12}"
AGLDV07_HOST="${AGLDV07_HOST:-root@100.64.175.89}"
AGLDV12_HOST="${AGLDV12_HOST:-root@100.71.217.115}"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
DRY_RUN=0
HOST=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") --host <agldv03|agldv04|agldv05|agldv06|agldv07|agldv12|agldv-all> [--dry-run]

Em cada host AGLDV:
  1. git pull agl-hostman (se NFS)
  2. sync incremental Cursor → llm-wiki
  3. instalar/activar agl-cursor-wiki-sync.timer (systemd)
USAGE
}

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

remote_bash() {
  local target="$1"
  shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] ssh $target bash -lc $(printf '%q ' "$@")"
    return 0
  fi
  "${SSH[@]}" "$target" "bash -lc $(printf '%q ' "$@")"
}

propagate_one() {
  local name="$1"
  local ssh_target="$2"
  local local_short
  local_short="$(hostname -s 2>/dev/null || hostname)"

  log "=== cursor-wiki $name ==="

  local install_cmd="cd '$HOSTMAN_ROOT' && \
    (test -d .git && git pull --ff-only || true) && \
    LLM_WIKI_DIR='$LLM_WIKI_DIR' CURSOR_EXPORT_HOST='$name' CURSOR_EXPORT_ALL_HOSTS=0 \
    bash scripts/cursor/sync-cursor-to-wiki.sh && \
    sudo LLM_WIKI_DIR='$LLM_WIKI_DIR' AGL_HOSTMAN_DIR='$HOSTMAN_ROOT' \
    bash scripts/cursor/install-cursor-wiki-sync-systemd.sh"

  if [[ "$name" == "$local_short" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] local sync + systemd"
      return 0
    fi
    bash -lc "cd '$HOSTMAN_ROOT' && LLM_WIKI_DIR='$LLM_WIKI_DIR' CURSOR_EXPORT_HOST='$name' bash scripts/cursor/sync-cursor-to-wiki.sh"
    if command -v sudo >/dev/null 2>&1; then
      sudo LLM_WIKI_DIR="$LLM_WIKI_DIR" AGL_HOSTMAN_DIR="$HOSTMAN_ROOT" \
        bash "$HOSTMAN_ROOT/scripts/cursor/install-cursor-wiki-sync-systemd.sh" || \
        warn "$name: systemd skip (sem sudo?)"
    else
      warn "$name: sudo ausente — timer não instalado"
    fi
  else
    if ! "${SSH[@]}" "$ssh_target" "test -f '$HOSTMAN_ROOT/scripts/cursor/sync-cursor-to-wiki.sh'"; then
      warn "$name: agl-hostman NFS em falta em $HOSTMAN_ROOT — skip"
      return 0
    fi
    remote_bash "$ssh_target" "git config --global --add safe.directory '$HOSTMAN_ROOT' 2>/dev/null || true; $install_cmd" || warn "$name: propagate falhou (offline?)"
  fi
  ok "$name cursor-wiki propagate concluído"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$HOST" ]] || { usage; exit 2; }

case "$HOST" in
  agldv03) propagate_one agldv03 "$AGLDV03_HOST" ;;
  agldv04) propagate_one agldv04 "$AGLDV04_HOST" ;;
  agldv05) propagate_one agldv05 "$AGLDV05_HOST" ;;
  agldv06) propagate_one agldv06 "$AGLDV06_HOST" ;;
  agldv07) propagate_one agldv07 "$AGLDV07_HOST" ;;
  agldv12) propagate_one agldv12 "$AGLDV12_HOST" ;;
  agldv-all)
    FAIL=0
    propagate_one agldv03 "$AGLDV03_HOST" || { warn agldv03; FAIL=1; }
    propagate_one agldv04 "$AGLDV04_HOST" || { warn agldv04; FAIL=1; }
    propagate_one agldv05 "$AGLDV05_HOST" || { warn agldv05; FAIL=1; }
    propagate_one agldv06 "$AGLDV06_HOST" || { warn agldv06; FAIL=1; }
    propagate_one agldv07 "$AGLDV07_HOST" || { warn agldv07; FAIL=1; }
    propagate_one agldv12 "$AGLDV12_HOST" || { warn agldv12; FAIL=1; }
    [[ "$FAIL" -eq 0 ]] || exit 1
    ;;
  *)
    echo "Host desconhecido: $HOST" >&2
    usage
    exit 2
    ;;
esac
