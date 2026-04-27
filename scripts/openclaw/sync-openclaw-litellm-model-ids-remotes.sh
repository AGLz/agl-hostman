#!/usr/bin/env bash
# Corre sync-openclaw-litellm-model-ids.py (+ fix-main-agent-models) em hosts Linux com OpenClaw.
# Mesmo conjunto de hosts que apply-openclaw-shared-policy-remotes.sh (agldv03 + fgsrv06 por defeito).
#
# Uso (raiz do repo, SSH por chave):
#   bash scripts/openclaw/sync-openclaw-litellm-model-ids-remotes.sh
#
# Opcional:
#   OPENCLAW_HOSTS="root@100.83.51.9" bash ...    # só fgsrv06
#   OPENCLAW_JSON=/root/.openclaw/openclaw.json OPENCLAW_AGENT_MODELS_JSON=... bash ...  # caminhos no remoto
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC="$REPO_ROOT/scripts/openclaw/sync-openclaw-litellm-model-ids.py"
FIX="$REPO_ROOT/scripts/openclaw/fix-main-agent-models-litellm-qualified-ids.py"

REMOTE_JSON="${OPENCLAW_JSON:-/root/.openclaw/openclaw.json}"
REMOTE_MODELS="${OPENCLAW_AGENT_MODELS_JSON:-/root/.openclaw/agents/main/agent/models.json}"

read -r -a HOSTS <<<"${OPENCLAW_HOSTS:-root@100.94.221.87 root@100.83.51.9}"

[[ -f "$SYNC" ]] || { echo "Falta $SYNC" >&2; exit 1; }
[[ -f "$FIX" ]] || { echo "Falta $FIX" >&2; exit 1; }

for host in "${HOSTS[@]}"; do
  echo ""
  echo "========== $host =========="
  scp -q "$SYNC" "${host}:/tmp/sync-openclaw-litellm-model-ids.py"
  scp -q "$FIX" "${host}:/tmp/fix-main-agent-models-litellm-qualified-ids.py"
  ssh -o BatchMode=yes -o ConnectTimeout=30 "$host" bash -s -- "$REMOTE_JSON" "$REMOTE_MODELS" <<'REMOTE'
set -euo pipefail
export OPENCLAW_JSON="${1:?}"
export OPENCLAW_AGENT_MODELS_JSON="${2:?}"
python3 /tmp/sync-openclaw-litellm-model-ids.py
if [[ -f "$OPENCLAW_AGENT_MODELS_JSON" ]]; then
  python3 /tmp/fix-main-agent-models-litellm-qualified-ids.py
else
  echo "SKIP: sem $OPENCLAW_AGENT_MODELS_JSON (só openclaw.json atualizado)."
fi
systemctl --user daemon-reload 2>/dev/null || true
if systemctl --user cat openclaw-gateway >/dev/null 2>&1; then
  systemctl --user restart openclaw-gateway
  sleep 2
  systemctl --user is-active openclaw-gateway || true
fi
REMOTE
done

echo ""
echo "Concluído. Ver backups *.bak.litellm-ids / *.bak.litellm-normalize nos hosts."
