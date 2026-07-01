#!/usr/bin/env bash
# Propaga pack AGL para ald-sys8 (NFS local ou SSH agldv12).
#
# Uso:
#   bash scripts/skills/propagate-agl-pack-ald-sys8.sh
#   bash scripts/skills/propagate-agl-pack-ald-sys8.sh --remote
#   bash scripts/skills/propagate-agl-pack-ald-sys8.sh --dry-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALD_SYS8_ROOT="${ALD_SYS8_ROOT:-/mnt/overpower/apps/dev/ald/ald-sys8}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
AGLDV12_HOST="${AGLDV12_HOST:-root@100.71.217.115}"
REMOTE=0
DRY_RUN=0

log() { echo "[propagate-ald-sys8] $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) REMOTE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--remote] [--dry-run]"
      exit 0
      ;;
    *) echo "Opção: $1" >&2; exit 2 ;;
  esac
done

run_install() {
  ALD_SYS8_ROOT="$ALD_SYS8_ROOT" LLM_WIKI_DIR="$LLM_WIKI_DIR" AGL_SOURCE="$HOSTMAN_ROOT" \
    bash "$HOSTMAN_ROOT/scripts/skills/install-agl-pack-ald-sys8.sh"
  ALD_SYS8_ROOT="$ALD_SYS8_ROOT" LLM_WIKI_DIR="$LLM_WIKI_DIR" \
    bash "$HOSTMAN_ROOT/scripts/skills/verify-ald-sys8-pack.sh"
}

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] install + verify em $ALD_SYS8_ROOT (remote=$REMOTE)"
  exit 0
fi

if [[ "$REMOTE" == "1" ]]; then
  log "SSH $AGLDV12_HOST"
  ssh -o BatchMode=yes -o ConnectTimeout=30 "$AGLDV12_HOST" \
    "ALD_SYS8_ROOT='$ALD_SYS8_ROOT' LLM_WIKI_DIR='$LLM_WIKI_DIR' AGL_SOURCE='$HOSTMAN_ROOT' \
     bash '$HOSTMAN_ROOT/scripts/skills/install-agl-pack-ald-sys8.sh' && \
     ALD_SYS8_ROOT='$ALD_SYS8_ROOT' LLM_WIKI_DIR='$LLM_WIKI_DIR' \
     bash '$HOSTMAN_ROOT/scripts/skills/verify-ald-sys8-pack.sh'"
else
  run_install
fi

log "concluído"
