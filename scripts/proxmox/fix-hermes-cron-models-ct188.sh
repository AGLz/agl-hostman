#!/usr/bin/env bash
# Crons LLM: modelo paid/cloud; fallback sem Ollama (evita timeout 90s em agl-primary-vm110).
#
# Uso (root no CT188):
#   bash fix-hermes-cron-models-ct188.sh
#   CRON_MODEL=zai-glm-5 CRON_FALLBACK=gpt-5.4-mini bash fix-hermes-cron-models-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
JOBS="${HERMES_ROOT}/data/cron/jobs.json"
CFG="${HERMES_ROOT}/data/config.yaml"
HERMES_UID="${HERMES_UID:-10000}"
CRON_MODEL="${CRON_MODEL:-zai-glm-5}"
CRON_FALLBACK="${CRON_FALLBACK:-gpt-5.4-mini}"

python3 - "${JOBS}" "${CRON_MODEL}" <<'PY'
import json, sys, re
from pathlib import Path

path = Path(sys.argv[1])
cron_model = sys.argv[2]
data = json.loads(path.read_text())
jobs = data if isinstance(data, list) else data.get("jobs", [])
llm = 0

for j in jobs:
    if j.get("no_agent"):
        continue
    llm += 1
    j["model"] = cron_model
    j["provider"] = "custom"
    j["base_url"] = None
    j["skills"] = []
    j["skill"] = None
    j["enabled_toolsets"] = []
    prompt = j.get("prompt") or ""
    prompt = re.sub(r"(?im)^Model:.*$", f"Model: {cron_model}", prompt)
    prompt = re.sub(r"(?im)^Usar toolsets:.*$", "Usar toolsets: (nenhum)", prompt)
    if "SEM FERRAMENTAS" not in prompt:
        prompt = prompt.rstrip() + "\n\n[SEM FERRAMENTAS] Resposta só texto pt-BR (máx 1200 chars). NÃO usar terminal/tools/skills.\n"
    j["prompt"] = prompt

if isinstance(data, list):
    path.write_text(json.dumps(jobs, indent=2) + "\n")
else:
    data["jobs"] = jobs
    path.write_text(json.dumps(data, indent=2) + "\n")
print(f"OK {llm} jobs LLM → {cron_model} (sem tools)")
PY

python3 - "${CFG}" "${CRON_FALLBACK}" <<'PY'
import sys
from pathlib import Path
import yaml

path, fallback = sys.argv[1:3]
cfg = yaml.safe_load(Path(path).read_text()) or {}
m = cfg.setdefault("model", {})
m["fallback"] = fallback
fb = cfg.setdefault("fallback_model", {})
fb["model"] = fallback
fb["provider"] = fb.get("provider") or "custom"
if m.get("api_key"):
    fb["api_key"] = m["api_key"]
Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK jarvis fallback → {fallback} (evita Ollama em retry de cron)")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" "${CFG}" 2>/dev/null || true
chmod 644 "${JOBS}"
chmod 600 "${CFG}" 2>/dev/null || true

docker restart agl-hermes-jarvis
sleep 20
echo "OK cron models + jarvis restart"
