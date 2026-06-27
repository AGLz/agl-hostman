#!/usr/bin/env bash
# Resiliência Jarvis + Curator quando Z.AI devolve 1302 (rate limit) e respostas vazias.
#
# Acções:
#   1. Fallback fora da Z.AI (or-nemotron-super-free via OpenRouter no LiteLLM CT186)
#   2. Compressão de contexto (jarvis + curator)
#   3. Crons Jarvis com provider openai → custom (LiteLLM)
#   4. Curator maintenance: intervalo 6h, modelo leve, menos carga
#   5. Poda MEMORY.md do Jarvis (libertar quota memory tool)
#
# Uso (root no CT188):
#   bash fix-hermes-jarvis-curator-resilience-ct188.sh
#   bash fix-hermes-jarvis-curator-resilience-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
HERMES_UID="${HERMES_UID:-10000}"
PRIMARY_MODEL="${PRIMARY_MODEL:-gpt-5.4-mini}"
FALLBACK_MODEL="${FALLBACK_MODEL:-or-nemotron-super-free}"
CURATOR_CRON_MODEL="${CURATOR_CRON_MODEL:-or-nemotron-super-free}"
CURATOR_CRON_EXPR="${CURATOR_CRON_EXPR:-0 4,10,16,22 * * *}"
OPT_SNIPPET="${AGL_HOSTMAN}/docker/hermes/config.aglz-optimization-snippet.yaml"

test -f "${OPT_SNIPPET}" || { echo "ERRO: ${OPT_SNIPPET} inexistente" >&2; exit 1; }

profile_cfg() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data/config.yaml"
  else
    echo "${HERMES_ROOT}/profiles/${agent}/config.yaml"
  fi
}

echo "=== 1/5 Fallback ${FALLBACK_MODEL} (Jarvis + Curator) ==="
for agent in jarvis curator; do
  cfg="$(profile_cfg "${agent}")"
  [[ -f "${cfg}" ]] || { echo "WARN: ${cfg} em falta" >&2; continue; }
  python3 - "${cfg}" "${FALLBACK_MODEL}" "${LITELLM_TS}" "${PRIMARY_MODEL}" <<'PY'
import sys
from pathlib import Path
import yaml

path, fallback, litellm, primary = sys.argv[1:5]
cfg = yaml.safe_load(Path(path).read_text()) or {}

m = cfg.setdefault("model", {})
api_key = m.get("api_key")
# Reason: primario Z.AI (zai-glm-5) devolve respostas vazias sob carga;
# gpt-5.4-mini e estavel no LiteLLM CT186.
m["default"] = primary
m["fallback"] = fallback
m["provider"] = m.get("provider") or "custom"
m["base_url"] = litellm.rstrip("/")

fb = cfg.setdefault("fallback_model", {})
fb["model"] = fallback
fb["provider"] = "custom"
fb["base_url"] = litellm.rstrip("/")
if api_key:
    fb["api_key"] = api_key

# Segundo fallback (terciário) — evita cadeia só Z.AI no LiteLLM.
# Reason: provider "custom" exige api_key sk-litellm-...; sem ela o LiteLLM
# devolve 401 (Received=no-key-required) e o Jarvis pára ao acionar fallback.
base = litellm.rstrip("/")
fp = [
    {"provider": "custom", "model": fallback, "base_url": base},
    {"provider": "custom", "model": "gpt-5.4-mini", "base_url": base},
]
if api_key:
    for entry in fp:
        entry["api_key"] = api_key
cfg["fallback_providers"] = fp

# Garante que o provider custom partilha a api_key (qualquer fallback futuro herda)
if api_key:
    custom = cfg.setdefault("providers", {}).setdefault("custom", {})
    custom["api_key"] = api_key
    custom.setdefault("base_url", base)

Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK {path} fallback={fallback}")
PY
  chown "${HERMES_UID}:${HERMES_UID}" "${cfg}" 2>/dev/null || true
done

echo "=== 2/5 Compressão de contexto (Jarvis + Curator) ==="
python3 - "${HERMES_ROOT}" "${OPT_SNIPPET}" <<'PY'
import sys
from pathlib import Path
import yaml

hermes_root, snippet_path = sys.argv[1:3]
snippet = yaml.safe_load(Path(snippet_path).read_text()) or {}
compression = snippet.get("compression") or {}

for agent in ("data", "profiles/curator"):
    path = Path(hermes_root) / agent / "config.yaml"
    if agent == "data":
        path = Path(hermes_root) / "data" / "config.yaml"
    if not path.is_file():
        continue
    cfg = yaml.safe_load(path.read_text()) or {}
    comp = cfg.setdefault("compression", {})
    comp.update(compression)
    comp["enabled"] = True
    comp["threshold"] = 0.55
    comp["target_ratio"] = 0.30
    comp["hygiene_hard_message_limit"] = 45
    comp.setdefault("abort_on_summary_failure", False)
    path.write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
    print(f"OK compression → {path}")
PY

echo "=== 3/5 Crons Jarvis: provider openai → custom ==="
JARVIS_JOBS="${HERMES_ROOT}/data/cron/jobs.json"
if [[ -f "${JARVIS_JOBS}" ]]; then
  python3 - "${JARVIS_JOBS}" "${LITELLM_TS}" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
litellm = sys.argv[2]
data = json.loads(path.read_text())
jobs = data if isinstance(data, list) else data.get("jobs", [])
fixed = 0
for j in jobs:
    if j.get("provider") == "openai" or (
        j.get("provider") == "custom" and not j.get("base_url")
    ):
        j["provider"] = "custom"
        j["base_url"] = litellm.rstrip("/")
        fixed += 1
if isinstance(data, list):
    path.write_text(json.dumps(jobs, indent=2) + "\n")
else:
    data["jobs"] = jobs
    path.write_text(json.dumps(data, indent=2) + "\n")
print(f"OK {fixed} cron(s) openai→custom em {path}")
PY
  chown "${HERMES_UID}:${HERMES_UID}" "${JARVIS_JOBS}" 2>/dev/null || true
fi

echo "=== 4/5 Curator cron: ${CURATOR_CRON_EXPR}, modelo ${CURATOR_CRON_MODEL} ==="
CURATOR_CRON_SCRIPT="${AGL_HOSTMAN}/scripts/proxmox/setup-hermes-curator-crons-ct188.sh"
if [[ -f "${CURATOR_CRON_SCRIPT}" ]]; then
  CURATOR_CRON_MODEL="${CURATOR_CRON_MODEL}" \
    CURATOR_CRON_EXPR="${CURATOR_CRON_EXPR}" \
    bash "${CURATOR_CRON_SCRIPT}" || true
fi
# Forçar schedule + modelo mesmo se job já existia
CURATOR_JOBS="${HERMES_ROOT}/profiles/curator/cron/jobs.json"
if [[ -f "${CURATOR_JOBS}" ]]; then
  python3 - "${CURATOR_JOBS}" "${CURATOR_CRON_MODEL}" "${CURATOR_CRON_EXPR}" <<'PY'
import json, sys
from pathlib import Path

jobs_path, model, expr = sys.argv[1:4]
data = json.loads(Path(jobs_path).read_text())
jobs = data if isinstance(data, list) else data.get("jobs", [])
for j in jobs:
    if j.get("name") == "curator-maintenance" or j.get("id") == "e54ffa964a1f":
        j["model"] = model
        j["provider"] = "custom"
        j["schedule"] = {"kind": "cron", "expr": expr, "display": expr}
        j["schedule_display"] = expr
        j["enabled_toolsets"] = []
        prompt = j.get("prompt") or ""
        if "MAX_TOOL_TURNS" not in prompt:
            j["prompt"] = prompt.rstrip() + "\n\n[MAX_TOOL_TURNS=8] Limite tool calls. Se nada a fazer: [SILENT].\n"
if isinstance(data, list):
    Path(jobs_path).write_text(json.dumps(jobs, indent=2) + "\n")
else:
    data["jobs"] = jobs
    Path(jobs_path).write_text(json.dumps(data, indent=2) + "\n")
print(f"OK curator-maintenance model={model} schedule={expr}")
PY
  chown "${HERMES_UID}:${HERMES_UID}" "${CURATOR_JOBS}" 2>/dev/null || true
fi

echo "=== 5/5 Poda MEMORY.md Jarvis ==="
MEMORY_FILE="${HERMES_ROOT}/data/memories/MEMORY.md"
if [[ -f "${MEMORY_FILE}" ]]; then
  cp -a "${MEMORY_FILE}" "${MEMORY_FILE}.bak-$(date +%Y%m%d-%H%M%S)"
  cat >"${MEMORY_FILE}" <<'MEM'
LINEAR_API_KEY: disponível em terminal (env var) mas NÃO em execute_code. Profiles: /opt/data/profiles/{elon,satya,werner}/.
§
agldv12 (100.71.217.115): gh autenticado aguileraz — GitHub API quando host destino sem gh.
§
CT188 agl-hermes Tailscale 100.81.225.22. LiteLLM CT186: 100.125.249.8:4000. agldv03=100.94.221.87, agldv04=100.113.9.98.
§
Skill company-research-litellm testada (Microsoft 2026-06-26). llm-wiki em /opt/llm-wiki (rw).
§
Fallback Z.AI 1302: usar or-nemotron-super-free ou gpt-5.4-mini via LiteLLM (não glm-flash).
MEM
  chown "${HERMES_UID}:${HERMES_UID}" "${MEMORY_FILE}" 2>/dev/null || true
  echo "OK MEMORY.md podado ($(wc -c <"${MEMORY_FILE}") bytes)"
fi

echo "=== Restart Jarvis + Curator ==="
cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart jarvis curator 2>/dev/null \
  || (docker restart agl-hermes-jarvis agl-hermes-curator)
sleep 18

echo ""
echo "Concluído. Testar com NOVA mensagem Telegram (thread antiga pode ter contexto pesado)."
echo "Smoke: curl -s ${LITELLM_TS}/health/liveliness"
