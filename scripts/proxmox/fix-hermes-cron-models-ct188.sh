#!/usr/bin/env bash
# Crons LLM restantes: model agl-primary + prompts sem groq (evita truncamento/429).
#
# Uso (root no CT188):
#   bash fix-hermes-cron-models-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
JOBS="${HERMES_ROOT}/data/cron/jobs.json"
HERMES_UID="${HERMES_UID:-10000}"

python3 - "${JOBS}" <<'PY'
import json, sys, re
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
jobs = data if isinstance(data, list) else data.get("jobs", [])

for j in jobs:
    if j.get("no_agent"):
        continue
    j["model"] = "agl-primary"
    j["provider"] = "custom"
    prompt = j.get("prompt") or ""
    prompt = re.sub(r"(?im)^Model:.*$", "Model: agl-primary", prompt)
    prompt = re.sub(r"(?im)^Usar toolsets:.*$", "Usar toolsets: terminal", prompt)
    if "Resposta curta" not in prompt:
        prompt = prompt.rstrip() + "\n\nResposta curta (máx 1500 caracteres). Sem toolsets pesados.\n"
    j["prompt"] = prompt
    j["enabled_toolsets"] = ["terminal"]

if isinstance(data, list):
    path.write_text(json.dumps(jobs, indent=2))
else:
    data["jobs"] = jobs
    path.write_text(json.dumps(data, indent=2))
print(f"OK {len(jobs)} jobs LLM → agl-primary")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
chmod 640 "${JOBS}"

docker restart agl-hermes-jarvis
sleep 15
echo "OK cron models + jarvis restart"
