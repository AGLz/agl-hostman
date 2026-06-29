#!/usr/bin/env bash
# Cronjobs Argus — digest diário de limites/quota (script --no-agent, entrega Telegram).
#
# Uso (root no CT188):
#   bash setup-hermes-argus-monitor-crons-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
ARGUS_DIR="${HERMES_ROOT}/profiles/argus"
JOBS="${ARGUS_DIR}/cron/jobs.json"
DATA_SCRIPTS="${ARGUS_DIR}/scripts"
HERMES_UID="${HERMES_UID:-10000}"
AGL_HOSTMAN="${AGL_HOSTMAN:-/mnt/overpower/apps/dev/agl/agl-hostman}"
MON="${AGL_HOSTMAN}/scripts/monitoring"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_UID}" "${ARGUS_DIR}/cron"
install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_UID}" "${DATA_SCRIPTS}"

src="${MON}/hermes-argus-quota-digest.sh"
dst="${DATA_SCRIPTS}/hermes-argus-quota-digest.sh"
sed 's/\r$//' "${src}" > "${dst}.tmp" && mv "${dst}.tmp" "${dst}"
chmod 0755 "${dst}"
chown "${HERMES_UID}:${HERMES_UID}" "${dst}"

python3 - "${JOBS}" "${TELEGRAM_CHAT}" <<'PY'
import json
import sys
from datetime import datetime
from pathlib import Path

path = Path(sys.argv[1])
chat = sys.argv[2]

def load():
    if path.is_file():
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {"jobs": data}
    return {"jobs": []}

def save(data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

def cron_schedule(expr: str) -> dict:
    return {"kind": "cron", "expr": expr, "display": expr}

def base_script_job(job_id, name, script, cron_expr, prompt=""):
    return {
        "id": job_id,
        "name": name,
        "prompt": prompt,
        "skills": [],
        "skill": None,
        "model": None,
        "provider": None,
        "base_url": None,
        "script": script,
        "no_agent": True,
        "context_from": None,
        "schedule": cron_schedule(cron_expr),
        "schedule_display": cron_expr,
        "repeat": {"times": None, "completed": 0},
        "enabled": True,
        "state": "scheduled",
        "paused_at": None,
        "paused_reason": None,
        "created_at": datetime.now().astimezone().isoformat(),
        "next_run_at": None,
        "last_run_at": None,
        "last_status": None,
        "last_error": None,
        "last_delivery_error": None,
        "deliver": f"telegram:{chat}",
        "origin": None,
        "enabled_toolsets": None,
        "workdir": None,
        "profile": None,
    }

data = load()
jobs = data.setdefault("jobs", [])
by_name = {j.get("name"): j for j in jobs}

def upsert(name, job_id, schedule, script, prompt):
    if name in by_name:
        j = by_name[name]
        j["schedule"] = cron_schedule(schedule)
        j["schedule_display"] = schedule
        j["script"] = script
        j["no_agent"] = True
        j["enabled"] = True
        j["prompt"] = prompt
        j["deliver"] = f"telegram:{chat}"
        j.pop("command", None)
        print(f"OK update {name}")
        return
    jobs.append(base_script_job(job_id, name, script, schedule, prompt))
    print(f"OK create {name}")

upsert(
    "argus-quota-digest-daily",
    "a17b3c9d0e21",
    "30 7 * * *",
    "hermes-argus-quota-digest.sh",
    "# Argus — digest diário de limites/quota dos providers LLM. Entrega via cron Argus.",
)
upsert(
    "argus-limits-watch",
    "a27c4d0e1f32",
    "0 */6 * * *",
    "hermes-argus-quota-digest.sh",
    "# Argus — verificação de limites a cada 6h (5h/semanal/mensal/rate-limit).",
)

save(data)
print(f"OK {len(jobs)} jobs em {path}")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
chmod 644 "${JOBS}" 2>/dev/null || true
echo "OK Argus crons → ${JOBS}"
