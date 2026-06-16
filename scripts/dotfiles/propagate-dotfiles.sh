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
AGLDV05_HOST="${AGLDV05_HOST:-root@100.82.71.49}"
AGLDV06_HOST="${AGLDV06_HOST:-root@100.71.229.12}"
AGLDV07_HOST="${AGLDV07_HOST:-root@100.64.175.89}"
AGLDV12_HOST="${AGLDV12_HOST:-root@100.71.217.115}"
AGLWK45_VMID="${AGLWK45_VMID:-104}"

# Path canónico no NFS/ZFS overpower; fallback remoto via rsync bundle
REMOTE_HOSTMAN_DEFAULT="${REMOTE_HOSTMAN_DEFAULT:-/mnt/overpower/apps/dev/agl/agl-hostman}"
REMOTE_HOSTMAN_FALLBACK="${REMOTE_HOSTMAN_FALLBACK:-/opt/agl-hostman}"
REMOTE_SYNC_DEFAULT="${REMOTE_SYNC_DEFAULT:-/mnt/overpower/apps/dev/agl/agl-home-sync}"

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

  bundle_to_remote() {
    local ssh_target="$1"
    local remote_root="$2"
    log "sync dotfiles bundle -> $ssh_target:$remote_root"
    "${SSH[@]}" "$ssh_target" "mkdir -p '$remote_root/config' '$remote_root/scripts/dotfiles'"
    if "${SSH[@]}" "$ssh_target" "command -v rsync >/dev/null 2>&1"; then
      rsync -az --delete \
        "$HOSTMAN_ROOT/config/dotfiles/" \
        "$ssh_target:$remote_root/config/dotfiles/"
      rsync -az --delete \
        "$HOSTMAN_ROOT/scripts/dotfiles/" \
        "$ssh_target:$remote_root/scripts/dotfiles/"
    else
      warn "$ssh_target sem rsync — usar tar over ssh"
      tar -C "$HOSTMAN_ROOT" -czf - config/dotfiles scripts/dotfiles \
        | "${SSH[@]}" "$ssh_target" "tar -xzf - -C '$remote_root'"
    fi
    "${SSH[@]}" "$ssh_target" "chmod +x '$remote_root/scripts/dotfiles/'*.sh 2>/dev/null || true"
  }

  seed_sync_to_remote() {
    local ssh_target="$1"
    local remote_sync="$2"
    if [[ ! -d "$HOSTMAN_ROOT/../agl-home-sync/linux-root" ]]; then
      warn "seed sync: fonte local em falta — live isolado até NFS"
      return 0
    fi
    log "sync agl-home-sync seed -> $ssh_target:$remote_sync (pode demorar)"
    "${SSH[@]}" "$ssh_target" "mkdir -p '$remote_sync'"
    if "${SSH[@]}" "$ssh_target" "command -v rsync >/dev/null 2>&1"; then
      rsync -az \
        "$HOSTMAN_ROOT/../agl-home-sync/" \
        "$ssh_target:$remote_sync/"
    else
      tar -C "$HOSTMAN_ROOT/.." -czf - agl-home-sync \
        | "${SSH[@]}" "$ssh_target" "tar -xzf - -C '$(dirname "$remote_sync")'"
    fi
  }

  run_install() {
    local install_target="$1"
    local remote_hostman="$REMOTE_HOSTMAN_DEFAULT"
    local remote_sync="$REMOTE_SYNC_DEFAULT"
    local prep_out=""

    if [[ "$install_target" != "local" ]]; then
      prep_out="$(
        REMOTE_HOSTMAN_DEFAULT="$REMOTE_HOSTMAN_DEFAULT" \
        REMOTE_HOSTMAN_FALLBACK="$REMOTE_HOSTMAN_FALLBACK" \
        REMOTE_SYNC_DEFAULT="$REMOTE_SYNC_DEFAULT" \
        "${SSH[@]}" "$install_target" 'bash -s' <<'REMOTE_PREP'
set -euo pipefail
HM_DEFAULT="${REMOTE_HOSTMAN_DEFAULT:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HM_FB="${REMOTE_HOSTMAN_FALLBACK:-/opt/agl-hostman}"
SYNC_DEFAULT="${REMOTE_SYNC_DEFAULT:-/mnt/overpower/apps/dev/agl/agl-home-sync}"

if [[ -d "$HM_DEFAULT/config/dotfiles" ]]; then
  echo "HOSTMAN=$HM_DEFAULT"
elif [[ -d "$HM_FB/config/dotfiles" ]]; then
  echo "HOSTMAN=$HM_FB"
else
  echo "HOSTMAN=$HM_FB"
  echo "NEED_BUNDLE=1"
fi

if [[ -d "$SYNC_DEFAULT/linux-root" ]]; then
  echo "SYNC=$SYNC_DEFAULT"
else
  echo "SYNC=$SYNC_DEFAULT"
  echo "NEED_SYNC_SEED=1"
  mkdir -p "$SYNC_DEFAULT"
fi
REMOTE_PREP
      )" || true
      if echo "$prep_out" | grep -q NEED_BUNDLE; then
        bundle_to_remote "$install_target" "$REMOTE_HOSTMAN_FALLBACK"
        remote_hostman="$REMOTE_HOSTMAN_FALLBACK"
      else
        remote_hostman="$(echo "$prep_out" | awk -F= '/^HOSTMAN=/{print $2; exit}')"
        remote_hostman="${remote_hostman:-$REMOTE_HOSTMAN_DEFAULT}"
        if [[ "$remote_hostman" == "$REMOTE_HOSTMAN_FALLBACK" ]]; then
          bundle_to_remote "$install_target" "$REMOTE_HOSTMAN_FALLBACK"
        fi
      fi
      if echo "$prep_out" | grep -q NEED_SYNC_SEED; then
        seed_sync_to_remote "$install_target" "$remote_sync"
      else
        remote_sync="$(echo "$prep_out" | awk -F= '/^SYNC=/{print $2; exit}')"
        remote_sync="${remote_sync:-$REMOTE_SYNC_DEFAULT}"
      fi
    fi

    local cmd="cd '$remote_hostman' && \
      (test -d .git && git pull --ff-only || echo '[WARN] git pull skip (bundle ou sem git)') && \
      AGL_HOME_SYNC_ROOT='$remote_sync' HOSTMAN_ROOT_OVERRIDE='$remote_hostman' \
      ./scripts/dotfiles/install-agl-home-sync.sh && \
      HOSTMAN_ROOT_OVERRIDE='$remote_hostman' AGL_HOME_SYNC_ROOT='$remote_sync' \
      ./scripts/dotfiles/verify-agl-home-sync.sh"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] ssh $install_target: install+verify (HOSTMAN=$remote_hostman SYNC=$remote_sync)"
      return 0
    fi
    if [[ "$install_target" == "local" ]]; then
      bash -lc "$cmd" || warn "$name: verify falhou parcialmente"
    else
      "${SSH[@]}" "$install_target" "bash -lc $(printf '%q' "$cmd")" || warn "$name: SSH/install falhou (host offline?)"
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
