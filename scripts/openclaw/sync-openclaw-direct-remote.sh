#!/usr/bin/env bash
# Aplica no remoto o mesmo fluxo que sync-openclaw-direct-host.sh (local):
# merge openclaw-patch.json → openclaw.json, catálogo direct providers, systemd env, restart gateway.
#
# Uso (a partir da raiz do repo, com SSH por chave):
#   bash scripts/openclaw/sync-openclaw-direct-remote.sh
#   OPENCLAW_SSH_HOST=root@100.83.51.9 bash scripts/openclaw/sync-openclaw-direct-remote.sh
#
# Opções:
#   OPENCLAW_SSH_HOST   — destino SSH (predef.: root@100.83.51.9 = fgsrv06)
#   OPENCLAW_JSON       — caminho no remoto (predef.: /root/.openclaw/openclaw.json)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST="${OPENCLAW_SSH_HOST:-root@100.83.51.9}"
REMOTE_JSON="${OPENCLAW_JSON:-/root/.openclaw/openclaw.json}"

MERGE="$REPO_ROOT/scripts/openclaw/merge-openclaw-json-patch.py"
APPLY="$REPO_ROOT/scripts/openclaw/apply-openclaw-direct-providers.py"
SYNC_ENV="$REPO_ROOT/scripts/openclaw/sync-systemd-openclaw-env.sh"
PATCH_JSON="$REPO_ROOT/config/openclaw/openclaw-patch.json"
TPL_JSON="$REPO_ROOT/config/openclaw/openclaw-models-direct.providers.json"

for f in "$MERGE" "$APPLY" "$SYNC_ENV" "$PATCH_JSON" "$TPL_JSON"; do
  [[ -f "$f" ]] || { echo "Falta: $f" >&2; exit 1; }
done

echo "=== Destino: $HOST ==="
scp -o BatchMode=yes -o ConnectTimeout=30 -q \
  "$MERGE" "$APPLY" "$SYNC_ENV" "$PATCH_JSON" "$TPL_JSON" \
  "${HOST}:/tmp/"

ssh -o BatchMode=yes -o ConnectTimeout=30 "$HOST" bash -s -- "$REMOTE_JSON" <<'REMOTE'
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
TARGET="${1:?}"
[[ -f "$TARGET" ]] || { echo "ERRO: falta $TARGET no remoto" >&2; exit 1; }
python3 /tmp/merge-openclaw-json-patch.py --target "$TARGET" --patch /tmp/openclaw-patch.json
python3 /tmp/apply-openclaw-direct-providers.py \
  --openclaw-json "$TARGET" \
  --template /tmp/openclaw-models-direct.providers.json \
  --all-agents
chmod +x /tmp/sync-systemd-openclaw-env.sh
bash /tmp/sync-systemd-openclaw-env.sh
chmod 600 "$TARGET" || true
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
sleep 2
systemctl --user is-active openclaw-gateway
echo "--- fallbacks default ---"
jq -r '.agents.defaults.model.fallbacks[]?' "$TARGET" || true
echo "--- providers (chaves) ---"
jq -r '.models.providers | keys[]' "$TARGET" | sort || true
REMOTE

echo "OK: $HOST — ver journalctl --user -u openclaw-gateway -n 50"
