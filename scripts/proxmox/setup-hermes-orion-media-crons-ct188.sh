#!/usr/bin/env bash
# Cronjobs Orion — verificação media *arr diária (script --no-agent).
#
# Uso (root no CT188):
#   bash setup-hermes-orion-media-crons-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
ORION_DIR="${HERMES_ROOT}/profiles/orion"
JOBS="${ORION_DIR}/cron/jobs.json"
DATA_SCRIPTS="${ORION_DIR}/scripts"
HERMES_UID="${HERMES_UID:-10000}"
AGL_HOSTMAN="${AGL_HOSTMAN:-/mnt/overpower/apps/dev/agl/agl-hostman}"
MON="${AGL_HOSTMAN}/scripts/monitoring"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_UID}" "${ORION_DIR}/cron"
install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_UID}" "${DATA_SCRIPTS}"

src="${MON}/hermes-orion-media-daily.sh"
dst="${DATA_SCRIPTS}/hermes-orion-media-daily.sh"
sed 's/\r$//' "${src}" > "${dst}.tmp" && mv "${dst}.tmp" "${dst}"
chmod 0755 "${dst}"
chown "${HERMES_UID}:${HERMES_UID}" "${dst}"

python3 - "${JOBS}" <<'PY'
import json
import sys
import uuid
from pathlib import Path

path = Path(sys.argv[1])

def load():
    if path.is_file():
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {"jobs": data}
    return {"jobs": []}

def save(data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

data = load()
jobs = data.setdefault("jobs", [])

def upsert(name, schedule, command, prompt_extra=""):
    for j in jobs:
        if j.get("name") == name:
            j["schedule"] = schedule
            j["no_agent"] = True
            j["command"] = command
            j["enabled"] = True
            print(f"OK update {name}")
            return
    jobs.append({
        "id": uuid.uuid4().hex[:12],
        "name": name,
        "schedule": schedule,
        "no_agent": True,
        "enabled": True,
        "command": command,
        "prompt": prompt_extra or f"# {name}\n",
    })
    print(f"OK create {name}")

upsert(
    "orion-media-daily-verify",
    "0 8 * * *",
    "/opt/data/scripts/hermes-orion-media-daily.sh",
    "# Orion — verifica modo grabs-only (arr-freeze --verify-only). Entrega via cron Orion.",
)
upsert(
    "orion-media-weekly-status",
    "0 9 * * 1",
    "/opt/data/scripts/hermes-orion-media-daily.sh",
    "# Orion — relatório semanal media stack. Revisar docs/MEDIA-ARR-MAINTENANCE.md.",
)

save(data)
print(f"OK {len(jobs)} jobs em {path}")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
chmod 644 "${JOBS}" 2>/dev/null || true
echo "OK Orion crons → ${JOBS}"
