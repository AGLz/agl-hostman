#!/usr/bin/env bash
# Crons LLM: glm-5 (output longo); Ollama (agl-primary-vm110) só burst — evitar timeout 90s.
#
# Uso (root no CT188):
#   bash fix-hermes-cron-models-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
JOBS="${HERMES_ROOT}/data/cron/jobs.json"
HERMES_UID="${HERMES_UID:-10000}"
CRON_MODEL="${CRON_MODEL:-glm-5}"

python3 - "${JOBS}" "${CRON_MODEL}" <<'PY'
import json, sys, re
from pathlib import Path

path = Path(sys.argv[1])
cron_model = sys.argv[2]
data = json.loads(path.read_text())
jobs = data if isinstance(data, list) else data.get("jobs", [])

for j in jobs:
    if j.get("no_agent"):
        continue
    j["model"] = cron_model
    j["provider"] = "custom"
    prompt = j.get("prompt") or ""
    prompt = re.sub(r"(?im)^Model:.*$", f"Model: {cron_model}", prompt)
    prompt = re.sub(r"(?im)^Usar toolsets:.*$", "Usar toolsets: terminal", prompt)
    if "Resposta curta" not in prompt:
        prompt = prompt.rstrip() + "\n\n[SEM FERRAMENTAS] Resposta só texto pt-BR (máx 1200 chars). NÃO usar terminal/tools.\n"
    j["prompt"] = prompt
    j["enabled_toolsets"] = []

if isinstance(data, list):
    path.write_text(json.dumps(jobs, indent=2))
else:
    data["jobs"] = jobs
    path.write_text(json.dumps(data, indent=2))
print(f"OK {len(jobs)} jobs LLM → {cron_model}")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
chmod 644 "${JOBS}"

docker restart agl-hermes-jarvis
sleep 15
echo "OK cron models + jarvis restart"
