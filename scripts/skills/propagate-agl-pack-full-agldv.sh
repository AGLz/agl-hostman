#!/usr/bin/env bash
# Propaga pack AGL completo (Six Repos + delivery + self-improve) para todos os AGLDV alcançáveis.
#
# Uso:
#   bash scripts/skills/propagate-agl-pack-full-agldv.sh
#   bash scripts/skills/propagate-agl-pack-full-agldv.sh --host agldv12
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
ONLY_HOST="${ONLY_HOST:-}"

declare -A HOST_IPS
HOST_IPS[agldv02]="100.95.204.85"
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.82.71.49"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.64.175.89"
HOST_IPS[agldv12]="100.71.217.115"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new)

log() { echo "[propagate-full] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

read -r -d '' REMOTE_INSTALL <<'REMOTE' || true
set -euo pipefail
HOSTMAN="/mnt/overpower/apps/dev/agl/agl-hostman"
LLM="/mnt/overpower/apps/dev/agl/llm-wiki"
export LLM_WIKI_DIR="$LLM"
export SKIP_PROMPT_IMPROVER_PLUGIN=1
cd "$HOSTMAN"
for repo in obsidian superpowers content-skills karpathy; do
  echo "[sync] $repo"
  ./scripts/skills/sync-six-repos.sh --repo "$repo"
done
./scripts/agl/sync-harness-skills.sh 2>/dev/null || echo "[WARN] harness sync skip"
./scripts/skills/install-global-delivery-rules.sh
./scripts/skills/install-cursor-agent-rules.sh
./scripts/skills/verify-six-repos.sh || echo "[WARN] verify-six-repos com FAIL/WARN (open-design/ecc opcionais)"
REMOTE

install_local() {
  local name="$1"
  log "=== $name (local) ==="
  bash -c "$REMOTE_INSTALL" || { warn "$name local falhou"; return 1; }
  ok "$name local"
}

install_remote() {
  local name="$1" ip="$2"
  log "=== $name ($ip) ==="
  if ! "${SSH[@]}" "root@$ip" "echo ok" >/dev/null 2>&1; then
    warn "$name UNREACHABLE — saltar"
    return 1
  fi
  "${SSH[@]}" "root@$ip" "bash -s" <<<"$REMOTE_INSTALL" || { warn "$name install falhou"; return 1; }
  ok "$name"
}

run_host() {
  local name="$1"
  local ip="${HOST_IPS[$name]}"
  local local_short
  local_short="$(hostname -s 2>/dev/null || hostname)"
  if [[ "$local_short" == "$name" ]]; then
    install_local "$name"
  else
    install_remote "$name" "$ip"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) ONLY_HOST="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--host agldvNN]"
      exit 0
      ;;
    *) echo "Opção: $1" >&2; exit 2 ;;
  esac
done

FAIL=0
if [[ -n "$ONLY_HOST" ]]; then
  run_host "$ONLY_HOST" || FAIL=1
else
  for name in agldv02 agldv03 agldv04 agldv05 agldv06 agldv07 agldv12; do
    run_host "$name" || FAIL=1
  done
fi
[[ "$FAIL" -eq 0 ]]
