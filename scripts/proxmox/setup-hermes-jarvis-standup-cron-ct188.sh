#!/usr/bin/env bash
# Cron "stand-up" do Jarvis (Manager) — cada 2h varre a equipa e surfaca pendências.
# LLM job no perfil Jarvis (usa read_agent_context/list_team + review-queue).
#
# Uso (root no CT188):
#   bash setup-hermes-jarvis-standup-cron-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
JOBS="${HERMES_ROOT}/data/cron/jobs.json"
HERMES_UID="${HERMES_UID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
SCHEDULE="${STANDUP_SCHEDULE:-0 */2 * * *}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_UID}" "${HERMES_ROOT}/data/cron"

read -r -d '' PROMPT <<'TXT' || true
[CRON — STAND-UP MANAGER 2h]
És o Jarvis (Manager). Faz um stand-up curto da agência, SEM micro-gerir.

1. list_team — confirma agentes ativos.
2. Para cada agente (elon, satya, werner, orion, curator, argus, verifier): read_agent_context para ver o que está a fazer / fez desde o último ciclo.
3. Lê a review-queue: bash /opt/agl-hostman/scripts/proxmox/hermes-review-queue.sh list
4. Resume em pt-BR (máx 1200 caracteres):
   - 🟢 progresso relevante por agente (1 linha cada, só se houver)
   - 🟡 itens em to_review/verifying à espera do Verifier
   - 🔴 bloqueios/falhas (failed/blocked) que precisam de decisão humana
5. Se houver bloqueio que exija decisão, indica a pergunta objetiva. Caso contrário, termina com "sem ações humanas necessárias".
Responde só com o resumo (sem invocar mais ferramentas além das indicadas).
TXT

python3 - "${JOBS}" "${TELEGRAM_CHAT}" "${SCHEDULE}" "${PROMPT}" <<'PY'
import json, sys
from datetime import datetime
from pathlib import Path

path, chat, schedule, prompt = sys.argv[1:5]
p = Path(path)
data = json.loads(p.read_text()) if p.is_file() else {"jobs": []}
if isinstance(data, list):
    data = {"jobs": data}
jobs = data.setdefault("jobs", [])
by_name = {j.get("name"): j for j in jobs}

NAME = "jarvis-standup-2h"
JOB_ID = "ja5774d0e1a0"
now = datetime.now().astimezone().isoformat()

job = by_name.get(NAME) or {"id": JOB_ID}
job.update({
    "id": job.get("id", JOB_ID),
    "name": NAME,
    "prompt": prompt,
    "skills": [], "skill": None,
    "model": None, "provider": None, "base_url": None,
    "script": None, "no_agent": False,
    "context_from": None,
    "schedule": {"kind": "cron", "expr": schedule, "display": schedule},
    "schedule_display": schedule,
    "repeat": {"times": None, "completed": 0},
    "enabled": True, "state": "scheduled",
    "paused_at": None, "paused_reason": None,
    "created_at": job.get("created_at", now),
    "next_run_at": None, "last_run_at": None,
    "last_status": None, "last_error": None, "last_delivery_error": None,
    "deliver": f"telegram:{chat}",
    "origin": None, "enabled_toolsets": None, "workdir": None, "profile": None,
})
if NAME not in by_name:
    jobs.append(job)
    print(f"OK create {NAME} [{schedule}]")
else:
    print(f"OK update {NAME} [{schedule}]")

p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
chmod 644 "${JOBS}" 2>/dev/null || true
echo "OK stand-up cron → ${JOBS}"
