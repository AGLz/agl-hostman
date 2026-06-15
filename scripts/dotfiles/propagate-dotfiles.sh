#!/usr/bin/env bash
# Propaga dotfiles + live sync para hosts agldv* (SSH).
#
# Uso:
#   ./scripts/dotfiles/propagate-dotfiles.sh --host agldv04
#   ./scripts/dotfiles/propagate-dotfiles.sh --host agldv-all --dry-run
#   ./scripts/dotfiles/propagate-dotfiles.sh --host all --with-six-repos

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AGLDV03_HOST="${AGLDV03_HOST:-root@100.94.221.87}"
AGLDV04_HOST="${AGLDV04_HOST:-root@100.113.9.98}"
AGLDV05_HOST="${AGLDV05_HOST:-root@100.119.41.63}"
AGLDV06_HOST="${AGLDV06_HOST:-root@100.71.229.12}"
AGLDV07_HOST="${AGLDV07_HOST:-root@100.64.139.79}"
AGLDV12_HOST="${AGLDV12_HOST:-root@100.71.217.115}"
AGLWK45_VMID="${AGLWK45_VMID:-104}"

DRY_RUN=0
HOST=""
WITH_SIX_REPOS=0

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

usage() {
  sed -n '2,10p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --with-six-repos) WITH_SIX_REPOS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$HOST" ]] || { usage; exit 1; }

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

propagate_aglwk45() {
  log "=== aglwk45 (VM${AGLWK45_VMID:-104} via AGLSRV1 guest agent) ==="
  local qemu="$HOSTMAN_ROOT/scripts/dotfiles/propagate-dotfiles-wk45-qemu.sh"
  if [[ ! -x "$qemu" ]]; then
    chmod +x "$qemu" 2>/dev/null || true
  fi
  if [[ ! -f "$qemu" ]]; then
    warn "propagate-dotfiles-wk45-qemu.sh em falta"
    return 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] $qemu"
    return 0
  fi
  bash "$qemu" || { warn "aglwk45 qemu propagate falhou"; return 1; }
  ok "aglwk45 propagate via qm guest exec"
}

propagate_one() {
  local name="$1"
  local target="$2"
  log "=== $name ($target) ==="

  local local_short
  local_short="$(hostname -s 2>/dev/null || hostname)"

  run_install() {
    local cmd="cd '$HOSTMAN_ROOT' && (git pull --ff-only || echo '[WARN] git pull falhou') && \
      ./scripts/dotfiles/install-agl-home-sync.sh && \
      ./scripts/dotfiles/verify-agl-home-sync.sh"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] ssh $target: install+verify"
      return 0
    fi
    if [[ "$target" == "local" ]]; then
      bash -lc "$cmd" || warn "$name: verify falhou parcialmente"
    else
      "${SSH[@]}" "$target" "bash -lc $(printf '%q' "$cmd")" || warn "$name: SSH/install falhou (host offline?)"
    fi
  }

  if [[ "$name" == "$local_short" || "$target" == "local" ]]; then
    run_install local
  else
    run_install "$target"
  fi

  if [[ "$WITH_SIX_REPOS" -eq 1 ]]; then
    local six="$HOSTMAN_ROOT/scripts/skills/propagate-six-repos.sh --host $name"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] $six"
    elif [[ "$target" != "local" ]]; then
      "$HOSTMAN_ROOT/scripts/skills/propagate-six-repos.sh" --host "$name" 2>/dev/null || warn "six-repos falhou para $name"
    fi
  fi
  ok "$name done"
}

case "$HOST" in
  agldv03) propagate_one agldv03 "$AGLDV03_HOST" ;;
  agldv04) propagate_one agldv04 "$AGLDV04_HOST" ;;
  agldv05) propagate_one agldv05 "$AGLDV05_HOST" ;;
  agldv06) propagate_one agldv06 "$AGLDV06_HOST" ;;
  agldv07) propagate_one agldv07 "$AGLDV07_HOST" ;;
  agldv12) propagate_one agldv12 "$AGLDV12_HOST" ;;
  aglwk45) propagate_aglwk45 ;;
  local) propagate_one "$(hostname -s)" local ;;
  agldv-all)
    propagate_one agldv03 "$AGLDV03_HOST" || warn "agldv03 skip"
    propagate_one agldv04 "$AGLDV04_HOST" || warn "agldv04 skip"
    propagate_one agldv05 "$AGLDV05_HOST" || warn "agldv05 skip"
    propagate_one agldv06 "$AGLDV06_HOST" || warn "agldv06 skip"
    propagate_one agldv07 "$AGLDV07_HOST" || warn "agldv07 skip"
    propagate_one agldv12 "$AGLDV12_HOST" || warn "agldv12 skip"
    ;;
  all)
    propagate_one "$(hostname -s)" local
    for h in agldv03 agldv04 agldv05 agldv06 agldv07 agldv12; do
      var="${h^^}_HOST"
      var="${var//AGLDV/AGLDV}"
      # bash indirection: use case
      case "$h" in
        agldv03) propagate_one agldv03 "$AGLDV03_HOST" || true ;;
        agldv04) propagate_one agldv04 "$AGLDV04_HOST" || true ;;
        agldv05) propagate_one agldv05 "$AGLDV05_HOST" || true ;;
        agldv06) propagate_one agldv06 "$AGLDV06_HOST" || true ;;
        agldv07) propagate_one agldv07 "$AGLDV07_HOST" || true ;;
        agldv12) propagate_one agldv12 "$AGLDV12_HOST" || true ;;
      esac
    done
    propagate_aglwk45 || warn "aglwk45 skip"
    ;;
  *)
    echo "Host desconhecido: $HOST" >&2
    exit 1
    ;;
esac

ok "propagate-dotfiles host=$HOST dry_run=$DRY_RUN"
