#!/usr/bin/env bash
# Deploy no agldv03 (CT179): git pull no agl-hostman + sync OpenClaw direct + glm-4.7-flash + restart gateway.
# Executar a partir de uma máquina com SSH ao host (ex. Tailscale root@100.94.221.87).
#
# Uso:
#   bash scripts/openclaw/deploy-agldv03-openclaw-direct.sh
#   AGLDV03=root@100.94.221.87 AGL_HOSTMAN_REPO=/caminho/para/agl-hostman bash scripts/openclaw/deploy-agldv03-openclaw-direct.sh
set -euo pipefail
HOST="${AGLDV03:-root@100.94.221.87}"
REPO="${AGL_HOSTMAN_REPO:-/mnt/overpower/apps/dev/agl/agl-hostman}"
OCJSON="${OPENCLAW_JSON:-}"

ssh -o BatchMode=yes -o ConnectTimeout=30 "$HOST" bash -s -- "$REPO" "$OCJSON" <<'REMOTE'
set -euo pipefail
REPO="$1"
OCJSON="$2"
cd "$REPO"
if [[ ! -d .git ]]; then
  echo "ERRO: nao e repo git: $REPO" >&2
  exit 1
fi
git pull --rebase
export OPENCLAW_JSON="${OCJSON:-$HOME/.openclaw/openclaw.json}"
bash scripts/openclaw/sync-openclaw-direct-host.sh
systemctl --user restart openclaw-gateway || true
sleep 2
systemctl --user is-active openclaw-gateway || true
echo "OK deploy agldv-openclaw-direct"
REMOTE
