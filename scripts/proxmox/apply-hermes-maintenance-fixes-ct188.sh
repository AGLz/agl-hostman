#!/usr/bin/env bash
# Aplica correções pós-auditoria Hermes CT188: curator, composio, cron, studio health.
#
# Uso (root no CT188):
#   bash apply-hermes-maintenance-fixes-ct188.sh
#   bash apply-hermes-maintenance-fixes-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
SCRIPTS="${AGL_HOSTMAN}/scripts/proxmox"
CFG="${HERMES_ROOT}/data/config.yaml"

test -d "${SCRIPTS}" || { echo "ERRO: falta ${SCRIPTS}" >&2; exit 1; }

echo "=== 1/4 Composio MCP: enabled false (até OAuth) ==="
python3 - "${CFG}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
cfg = yaml.safe_load(path.read_text()) or {}
mcp = cfg.get("mcp_servers")
if isinstance(mcp, list):
    fixed = {}
    for entry in mcp:
        if isinstance(entry, dict) and "name" in entry:
            e = dict(entry)
            name = e.pop("name")
            fixed[name] = e
    mcp = fixed
if not isinstance(mcp, dict):
    mcp = {}
comp = mcp.setdefault("composio", {})
if isinstance(comp, dict):
    comp.setdefault("url", "https://connect.composio.dev/mcp")
    comp.setdefault("auth", "oauth")
    comp["enabled"] = False
cfg["mcp_servers"] = mcp
path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print("OK composio.enabled=false")
PY

echo "=== 2/5 Curator profile ==="
bash "${SCRIPTS}/bootstrap-hermes-curator-profile-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 3/5 Curator llm-wiki skill + cron prompt ==="
bash "${SCRIPTS}/fix-curator-llm-wiki-skill-ct188.sh"

echo "=== 3b/5 Orion profile + media crons ==="
bash "${SCRIPTS}/bootstrap-hermes-orion-profile-ct188.sh" "${AGL_HOSTMAN}" || true
if [[ -x "${SCRIPTS}/configure-hermes-curator-orion-ct188.sh" ]]; then
  bash "${SCRIPTS}/configure-hermes-curator-orion-ct188.sh" "${AGL_HOSTMAN}" || true
fi

echo "=== 4/5 Cron permissions (+ cron.d 15min) ==="
bash "${SCRIPTS}/fix-hermes-cron-perms-ct188.sh" --install-cron

echo "=== 5/5 Studio healthcheck (compose sync + recreate) ==="
bash "${SCRIPTS}/bootstrap-hermes-claw3d-studio-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 6/7 Corrigir erros de log (SSH ro, Langfuse, venv) ==="
if [[ -f "${SCRIPTS}/fix-hermes-log-errors-ct188.sh" ]]; then
  bash "${SCRIPTS}/fix-hermes-log-errors-ct188.sh" "${AGL_HOSTMAN}" || echo "WARN: fix-hermes-log-errors falhou parcialmente" >&2
else
  echo "=== Restart jarvis (reload config + curator gateway) ==="
  docker restart agl-hermes-jarvis
  sleep 20
fi

echo "=== 7/7 Activar serviços de voz ==="
if [[ -f "${SCRIPTS}/enable-hermes-voice-ct188.sh" ]]; then
  bash "${SCRIPTS}/enable-hermes-voice-ct188.sh" "${AGL_HOSTMAN}"
else
  echo "WARN: enable-hermes-voice-ct188.sh em falta" >&2
fi

curl -sf -m 15 http://127.0.0.1:8642/health | grep -q hermes-agent && echo "OK jarvis health" || echo "WARN jarvis health pendente"

echo ""
echo "Concluído. Correr: bash ${SCRIPTS}/smoke-hermes-aglz-quartet.sh"
