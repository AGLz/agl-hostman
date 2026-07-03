#!/usr/bin/env bash
# Cron stand-up Jarvis (Manager Verdent) — cada 2h; substitui jarvis-agency-sync.
set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
JOBS="${HERMES_ROOT}/data/cron/jobs.json"
HERMES_UID="${HERMES_UID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
SCHEDULE="${STANDUP_SCHEDULE:-0 */2 * * *}"
CRON_MODEL="${CRON_MODEL:-agl-primary-zai-glm-flash}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_UID}" "${HERMES_ROOT}/data/cron"

read -r -d '' PROMPT <<'TXT' || true
[CRON — STAND-UP MANAGER 2h]
És o Jarvis (Manager Verdent). Stand-up curto — SEM micro-gestão.

Passos (só estas ferramentas):
1. list_team
2. read_agent_context: elon, satya, werner, orion, curator, argus, verifier
3. bash /opt/agl-hostman/scripts/proxmox/hermes-review-queue.sh list

Responde pt-BR, máx 900 caracteres:
- 🟢 1 linha/agente (só se houver progresso)
- 🟡 to_review/verifying (Verifier pendente)
- 🔴 blocked/failed (decisão humana)
Se nada crítico: termina "sem ações humanas necessárias".
TXT

python3 - "${JOBS}" "${TELEGRAM_CHAT}" "${SCHEDULE}" "${PROMPT}" "${CRON_MODEL}" <<'PY'
import json, sys
from datetime import datetime
from pathlib import Path

path, chat, schedule, prompt, model = sys.argv[1:6]
p = Path(path)
raw = json.loads(p.read_text()) if p.is_file() else []
if isinstance(raw, list):
    jobs = raw
    wrap_list = True
else:
    jobs = raw.setdefault("jobs", [])
    wrap_list = False

NAME = "jarvis-standup-2h"
JOB_ID = "ja5774d0e1a0"
now = datetime.now().astimezone().isoformat()

jobs = [j for j in jobs if j.get("name") not in ("jarvis-agency-sync", "jarvis-standup-2h")]

job = {
    "id": JOB_ID,
    "name": NAME,
    "prompt": prompt,
    "skills": [], "skill": None,
    "model": model, "provider": "custom", "base_url": None,
    "script": None, "no_agent": False,
    "context_from": None,
    "schedule": {"kind": "cron", "expr": schedule, "display": schedule},
    "schedule_display": schedule,
    "repeat": {"times": None, "completed": 0},
    "enabled": True, "state": "scheduled",
    "paused_at": None, "paused_reason": None,
    "created_at": now,
    "next_run_at": None, "last_run_at": None,
    "last_status": None, "last_error": None, "last_delivery_error": None,
    "deliver": f"telegram:{chat}",
    "origin": None, "enabled_toolsets": None, "workdir": None, "profile": None,
}
jobs.append(job)

if wrap_list:
    out = jobs
else:
    raw["jobs"] = jobs
    out = raw
p.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"OK {NAME} [{schedule}] model={model} (agency-sync removido)")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
chmod 644 "${JOBS}" 2>/dev/null || true
echo "OK stand-up → ${JOBS}"
