#!/usr/bin/env bash
# Replica políticas OpenClaw (memorySearch, compaction, web duckduckgo, brave off,
# Telegram commands.native false, sem gpt-4.1 nos agentes) nos hosts Linux.
#
# Hosts por defeito: agldv03 (Tailscale) + fgsrv06 — mesmo conjunto que fix-openclaw-agldv03-fgsrv06.sh
#
# Uso (a partir da raiz do repo, com SSH por chave):
#   bash scripts/openclaw/apply-openclaw-shared-policy-remotes.sh
#
# Opcional:
#   OPENCLAW_HOSTS="root@100.94.221.87 root@100.83.51.9" bash ...
#   OPENCLAW_JSON="/home/user/.openclaw/openclaw.json" bash ...   # caminho no remoto
#   OPENCLAW_DDG_REGION=pt-pt bash ...
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHER="$REPO_ROOT/scripts/openclaw/patch-openclaw-shared-policy.py"
REMOTE_JSON="${OPENCLAW_JSON:-/root/.openclaw/openclaw.json}"

read -r -a HOSTS <<<"${OPENCLAW_HOSTS:-root@100.94.221.87 root@100.83.51.9}"

[[ -f "$PATCHER" ]] || { echo "Falta $PATCHER" >&2; exit 1; }

DDG_REGION="${OPENCLAW_DDG_REGION:-pt-pt}"

for host in "${HOSTS[@]}"; do
  echo ""
  echo "========== $host =========="
  scp -q "$PATCHER" "${host}:/tmp/patch-openclaw-shared-policy.py"
  # Reason: no remoto inferimos LITELLM /v1/ e master a partir do próprio openclaw.json
  ssh -o BatchMode=yes -o ConnectTimeout=30 "$host" bash -s -- "$REMOTE_JSON" "$DDG_REGION" <<'REMOTE'
set -euo pipefail
REMOTE_JSON="${1:?}"
export OPENCLAW_DDG_REGION="${2:-pt-pt}"
if [[ ! -f "$REMOTE_JSON" ]]; then
  echo "ERRO: falta $REMOTE_JSON" >&2
  exit 1
fi
python3 /tmp/patch-openclaw-shared-policy.py "$REMOTE_JSON"
chmod 600 "$REMOTE_JSON" || true
systemctl --user daemon-reload 2>/dev/null || true
if systemctl --user cat openclaw-gateway >/dev/null 2>&1; then
  systemctl --user restart openclaw-gateway
  sleep 2
  systemctl --user is-active openclaw-gateway || true
fi
REMOTE
done

echo ""
echo "Concluído. Ver journalctl --user -u openclaw-gateway nos hosts."
