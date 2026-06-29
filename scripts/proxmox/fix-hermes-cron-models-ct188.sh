#!/usr/bin/env bash
# Crons LLM: modelo free/cloud; fallback local (evita quota paga).
#
# Uso (root no CT188):
#   bash fix-hermes-cron-models-ct188.sh
#   CRON_MODEL=or-owl-alpha CRON_FALLBACK=groq-llama-31-8b bash fix-hermes-cron-models-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
JOBS="${HERMES_ROOT}/data/cron/jobs.json"
CFG="${HERMES_ROOT}/data/config.yaml"
HERMES_UID="${HERMES_UID:-10000}"
CRON_MODEL="${CRON_MODEL:-or-owl-alpha}"
CRON_FALLBACK="${CRON_FALLBACK:-groq-llama-31-8b}"

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

python3 - "${HERMES_ROOT}" "${CRON_FALLBACK}" <<'PY'
import sys
from pathlib import Path
import yaml

root, fallback = Path(sys.argv[1]), sys.argv[2]
paths = [root / "data" / "config.yaml", *sorted((root / "profiles").glob("*/config.yaml"))]
for path in paths:
    if not path.is_file():
        continue
    cfg = yaml.safe_load(path.read_text()) or {}
    m = cfg.setdefault("model", {})
    m["fallback"] = fallback
    fb = cfg.setdefault("fallback_model", {})
    fb["model"] = fallback
    fb["provider"] = fb.get("provider") or "custom"
    if m.get("api_key"):
        fb["api_key"] = m["api_key"]
    path.write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
    print(f"OK fallback {fallback} → {path.relative_to(root)}")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" "${CFG}" 2>/dev/null || true
chmod 644 "${JOBS}"
chmod 600 "${CFG}" 2>/dev/null || true

docker restart agl-hermes-jarvis
sleep 20
echo "OK cron models + jarvis restart"
