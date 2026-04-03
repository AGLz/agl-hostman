#!/usr/bin/env bash
# Aplica catálogo direct (sem LiteLLM) + primário zai/glm-4.7-flash no openclaw.json do host.
# Uso no agldv03 (CT179), após git pull no repo:
#   bash scripts/openclaw/sync-openclaw-direct-host.sh
# Opcional: OPENCLAW_JSON=/path/to/openclaw.json
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
TARGET="${OPENCLAW_JSON:-${HOME}/.openclaw/openclaw.json}"
python3 "${ROOT}/scripts/openclaw/merge-openclaw-json-patch.py" --target "${TARGET}"
# Comportamento predefinido: aplicar primário zai/glm-4.7-flash (--no-agl-primary-flash para só providers)
python3 "${ROOT}/scripts/openclaw/apply-openclaw-direct-providers.py" \
  --openclaw-json "${TARGET}" \
  --all-agents
# Reason: o gateway systemd lê ~/.config/environment.d/openclaw.conf (ver drop-in
# config/openclaw/openclaw-gateway.service.d-env.conf); sem isto ZAI_API_KEY só existe no zsh.
bash "${ROOT}/scripts/openclaw/sync-systemd-openclaw-env.sh"
echo "Reinicia o gateway: systemctl --user daemon-reload && systemctl --user restart openclaw-gateway"
