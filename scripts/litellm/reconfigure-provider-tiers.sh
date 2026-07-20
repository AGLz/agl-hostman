#!/usr/bin/env bash
# Reconfigura tiers de providers no LiteLLM (repo → CT186 + satélites) e env Claude Code.
# Política 2026-06: claude-* → Z.AI Anthropic; OpenAI/Anthropic direct só quando quota OK.
#
# Uso:
#   bash scripts/litellm/reconfigure-provider-tiers.sh
#   bash scripts/litellm/reconfigure-provider-tiers.sh --dry-run
#   bash scripts/litellm/reconfigure-provider-tiers.sh --skip-deploy

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRY_RUN=0
SKIP_DEPLOY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-deploy) SKIP_DEPLOY=1; shift ;;
    -h|--help)
      echo "Uso: $0 [--dry-run] [--skip-deploy]"
      exit 0
      ;;
    *) echo "Flag desconhecida: $1" >&2; exit 1 ;;
  esac
done

echo "=== Reconfigure provider tiers (agl-hostman) ==="

if [[ "$DRY_RUN" -eq 1 ]]; then
  python3 "$REPO_ROOT/scripts/litellm/reconfigure-claude-tier-a.py" 2>/dev/null || true
  git -C "$REPO_ROOT" diff --stat config/litellm/config.yaml || true
  echo "(dry-run — sem escrita/deploy)"
  exit 0
fi

python3 "$REPO_ROOT/scripts/litellm/reconfigure-claude-tier-a.py"

if [[ "$SKIP_DEPLOY" -eq 1 ]]; then
  echo "Skip deploy (--skip-deploy)"
  exit 0
fi

echo ""
echo "=== Sync config → CT186 + agldv04/12/fgsrv06 ==="
bash "$REPO_ROOT/scripts/litellm/sync-config-all-hosts.sh"

echo ""
echo "=== Deploy OpenClaw/LiteLLM env (zshrc + gateway) ==="
bash "$REPO_ROOT/scripts/deploy-openclaw-config.sh"

echo ""
echo "=== Smoke: claude-sonnet-5 no CT186 ==="
ssh -o BatchMode=yes -o ConnectTimeout=20 root@100.125.249.8 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/agl-litellm
# shellcheck disable=SC1091
source .env
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:4000/health/readiness || echo 000)"
echo "readiness: HTTP $code"
curl -sS --max-time 45 -X POST http://127.0.0.1:4000/v1/messages \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-5","max_tokens":24,"messages":[{"role":"user","content":"ok"}]}' \
  | head -c 400
echo ""
REMOTE

echo ""
echo "OK — tiers aplicados. Teste nos dev hosts:"
echo "  source ~/.zshrc && ccs 'olá'"
