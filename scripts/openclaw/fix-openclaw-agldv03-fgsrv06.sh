#!/usr/bin/env bash
# Corrige e reforça OpenClaw em agldv03 + fgsrv06 (SSH a partir do repo):
# - Gera ~/.config/environment.d/openclaw.conf (URLs literais + keys)
# - Permissões 600 em openclaw.json
# - Reinicia openclaw-gateway (user systemd)
#
# Opções:
#   DOCTOR=1      — corre também openclaw doctor --yes (pode demorar; rede/Telegram)
#   DOCTOR_TIMEOUT=90 — timeout em segundos para o doctor (quando DOCTOR=1)
#
# Não atualiza npm global (openclaw update) — fazer manualmente se desejado.
#
# Políticas OpenClaw (memorySearch LiteLLM, web duckduckgo, compaction, etc.):
#   bash scripts/openclaw/apply-openclaw-shared-policy-remotes.sh
#
# Se ~/.openclaw/litellm-gateway.env não tiver LITELLM_MASTER_KEY (só URL), LiteLLM local responde 401:
#   bash scripts/openclaw/ensure-litellm-gateway-env-from-opt.sh
#
# Uso: bash scripts/openclaw/fix-openclaw-agldv03-fgsrv06.sh
#      DOCTOR=1 bash scripts/openclaw/fix-openclaw-agldv03-fgsrv06.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC_ENV="$REPO_ROOT/scripts/openclaw/sync-systemd-openclaw-env.sh"

HOSTS=(
  "root@100.94.221.87"
  "root@100.83.51.9"
)

[[ -f "$SYNC_ENV" ]] || { echo "Falta $SYNC_ENV"; exit 1; }

remote_fix() {
  local host=$1
  local doc="${DOCTOR:-0}"
  local dtimeout="${DOCTOR_TIMEOUT:-90}"
  echo ""
  echo "========== $host =========="
  scp -q "$SYNC_ENV" "${host}:/tmp/sync-systemd-openclaw-env.sh"
  ssh -o BatchMode=yes -o ConnectTimeout=30 "$host" bash -s -- "$doc" "$dtimeout" <<'REMOTE'
set -euo pipefail
DOCTOR_MODE="${1:-0}"
DOCTOR_TIMEOUT="${2:-90}"
chmod +x /tmp/sync-systemd-openclaw-env.sh
bash /tmp/sync-systemd-openclaw-env.sh
if [[ -f /root/.openclaw/openclaw.json ]]; then
  chmod 600 /root/.openclaw/openclaw.json || true
fi
set -a
# shellcheck source=/dev/null
source /root/.config/environment.d/openclaw.conf 2>/dev/null || true
set +a
if [[ "${DOCTOR_MODE}" == "1" ]]; then
  echo "--- openclaw doctor --yes (timeout ${DOCTOR_TIMEOUT}s) ---"
  if command -v timeout >/dev/null 2>&1; then
    timeout "${DOCTOR_TIMEOUT}" openclaw doctor --yes 2>&1 | tail -40 || true
  else
    openclaw doctor --yes 2>&1 | tail -40 || true
  fi
else
  echo "--- doctor omitido (DOCTOR=1 para incluir) ---"
fi
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
sleep 2
systemctl --user is-active openclaw-gateway
openclaw --version
REMOTE
}

for h in "${HOSTS[@]}"; do
  remote_fix "$h" || { echo "Falha em $h"; exit 1; }
done

echo ""
echo "Concluído. Ver: journalctl --user -u openclaw-gateway -n 40 --no-pager (em cada host)"
