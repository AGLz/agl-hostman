#!/usr/bin/env bash
# Evolução dos cronjobs Hermes Jarvis CT188:
# - Permissões jobs.json (hermes pode ler)
# - Briefing / Manutenção / Backup → scripts --no-agent (sem tool calls JSON)
# - AI Opportunity → agl-primary via LiteLLM, sem toolsets
# - approvals.cron_mode=allow para crons LLM restantes
#
# Uso (root no CT188):
#   bash evolve-hermes-crons-ct188.sh
#   bash evolve-hermes-crons-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman --test-run

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
TEST_RUN="${2:-}"
SCRIPTS="${AGL_HOSTMAN}/scripts/proxmox"
MON="${AGL_HOSTMAN}/scripts/monitoring"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
DATA="${HERMES_ROOT}/data"
DATA_SCRIPTS="${DATA}/scripts"
JOBS_FILE="${DATA}/cron/jobs.json"
CFG="${DATA}/config.yaml"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
CONTAINER="${HERMES_JARVIS_CONTAINER:-agl-hermes-jarvis}"

test -d "${MON}" || { echo "ERRO: falta ${MON}" >&2; exit 1; }

fix_cron_perms() {
  install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${DATA}/cron"
  install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_GID}" "${DATA_SCRIPTS}"
  if [[ -f "${JOBS_FILE}" ]]; then
    chmod 644 "${JOBS_FILE}"
  fi
  chown -R "${HERMES_UID}:${HERMES_GID}" "${DATA}/cron/output" 2>/dev/null || true
  chown -R "${HERMES_UID}:${HERMES_GID}" "${DATA}/logs" 2>/dev/null || true
}

install_script() {
  local src_name="$1"
  local src="${MON}/${src_name}"
  local dst="${DATA_SCRIPTS}/${src_name}"
  test -f "${src}" || { echo "ERRO: falta ${src}" >&2; exit 1; }
  sed 's/\r$//' "${src}" > "${dst}.tmp" && mv "${dst}.tmp" "${dst}"
  chmod 0755 "${dst}"
  chown "${HERMES_UID}:${HERMES_GID}" "${dst}"
  echo "OK script ${src_name}"
}

echo "=== 1/6 Permissões cron + scripts ==="
bash "${SCRIPTS}/fix-hermes-cron-perms-ct188.sh" --install-cron 2>/dev/null || fix_cron_perms

for s in \
  hermes-ct188-health-check.sh \
  hermes-ct188-daily-briefing.sh \
  hermes-ct188-daily-maintenance.sh \
  hermes-ct188-daily-backup.sh; do
  install_script "${s}"
done

echo "=== 2/6 Config Jarvis: approvals permissivos ==="
bash "${SCRIPTS}/fix-hermes-approvals-ct188.sh" --no-restart 2>/dev/null || python3 - "${CFG}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
cfg = yaml.safe_load(path.read_text()) or {}
ap = cfg.setdefault("approvals", {})
ap["mode"] = "off"
ap["cron_mode"] = "approve"
ap["timeout"] = max(int(ap.get("timeout") or 60), 300)
cfg.setdefault("delegation", {})["subagent_auto_approve"] = True
path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print("OK approvals mode=off cron_mode=approve")
PY
chown "${HERMES_UID}:${HERMES_GID}" "${CFG}" 2>/dev/null || true

echo "=== 3/6 Reescrever jobs.json ==="
python3 - "${JOBS_FILE}" "${TELEGRAM_CHAT}" <<'PY'
import json, sys
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

path = Path(sys.argv[1])
chat = sys.argv[2]

def load():
    if not path.is_file():
        return {"jobs": []}
    data = json.loads(path.read_text())
    return data if isinstance(data, dict) else {"jobs": data}

def save(data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")

data = load()
old = {j["id"]: j for j in data.get("jobs", []) if j.get("id")}

def base_script_job(job_id, name, script, cron_expr, deliver=None):
    prev = old.get(job_id, {})
    return {
        "id": job_id,
        "name": name,
        "prompt": "",
        "skills": [],
        "skill": None,
        "model": None,
        "provider": None,
        "base_url": None,
        "script": script,
        "no_agent": True,
        "context_from": None,
        "schedule": {"kind": "cron", "expr": cron_expr, "display": cron_expr},
        "schedule_display": cron_expr,
        "repeat": prev.get("repeat") or {"times": None, "completed": 0},
        "enabled": True,
        "state": "scheduled",
        "paused_at": None,
        "paused_reason": None,
        "created_at": prev.get("created_at") or datetime.now().astimezone().isoformat(),
        "next_run_at": prev.get("next_run_at"),
        "last_run_at": prev.get("last_run_at"),
        "last_status": prev.get("last_status"),
        "last_error": None,
        "last_delivery_error": None,
        "deliver": deliver or f"telegram:{chat}",
        "origin": prev.get("origin"),
        "enabled_toolsets": None,
        "workdir": None,
        "profile": None,
    }

def base_llm_job(job_id, name, cron_expr, prompt_body, deliver=None):
    prev = old.get(job_id, {})
    prompt = f"""[CRON — SEM FERRAMENTAS]
Entrega: responde só com texto em pt-BR (máx 1200 caracteres). NÃO invocar tools/terminal/read_file.
Se não houver novidade útil: responde exactamente [SILENT].

{prompt_body}
"""
    return {
        "id": job_id,
        "name": name,
        "prompt": prompt,
        "skills": [],
        "skill": None,
        "model": "agl-primary",
        "provider": "custom",
        "base_url": None,
        "script": None,
        "no_agent": False,
        "context_from": None,
        "schedule": {"kind": "cron", "expr": cron_expr, "display": cron_expr},
        "schedule_display": cron_expr,
        "repeat": prev.get("repeat") or {"times": None, "completed": 0},
        "enabled": True,
        "state": "scheduled",
        "paused_at": None,
        "paused_reason": None,
        "created_at": prev.get("created_at") or datetime.now().astimezone().isoformat(),
        "next_run_at": prev.get("next_run_at"),
        "last_run_at": prev.get("last_run_at"),
        "last_status": None,
        "last_error": None,
        "last_delivery_error": None,
        "deliver": deliver or f"telegram:{chat}",
        "origin": prev.get("origin") or {
            "platform": "telegram",
            "chat_id": chat,
            "chat_name": "Carlos Aguilera",
            "thread_id": None,
        },
        "enabled_toolsets": [],
        "workdir": None,
        "profile": None,
    }

research_prompt = """Pesquisa diária (makemoney01 / oportunidades AI para AGLz):
1. Três nichos com potencial (Brasil/LATAM): problema, cliente, monetização.
2. Para cada um: stack mínima, tempo MVP, risco regulatório.
3. Escolhe 1 prioridade do dia com próximo passo concreto (1 frase acionável).
Sem inventar métricas de mercado — indica quando precisas de validação humana."""

deep_dive_prompt = """Deep dive na oportunidade #1 do scan das 06:30 (ou melhor candidata atual):
- Proposta de valor em 2 frases
- Roadmap 2 semanas (5 bullets)
- KPIs de validação
- Riscos e mitigação
Tom executivo, pt-BR."""

impl_prompt = """Sprint de planeamento de implementação:
Com base nas oportunidades AI AGLz, lista hoje:
- 3 tarefas técnicas (cada uma ≤2h)
- 1 entrega verificável até amanhã
- Dependências (LiteLLM, repo, Linear)
Formato checklist numerada."""

jobs = [
    base_script_job(
        "3081bba799fd",
        "hermes-ct188-daily-maintenance",
        "hermes-ct188-daily-maintenance.sh",
        "0 4 * * *",
    ),
    base_script_job(
        "24e2701fa6c9",
        "hermes-ct188-daily-backup",
        "hermes-ct188-daily-backup.sh",
        "30 4 * * *",
    ),
    base_llm_job(
        "708fe1021f93",
        "AI Opportunity Research — scan diário",
        "30 6 * * *",
        research_prompt,
    ),
    base_script_job(
        "b1afbb4c31ce",
        "hermes-ct188-daily-briefing",
        "hermes-ct188-daily-briefing.sh",
        "0 7 * * *",
    ),
    base_llm_job(
        "052baa2c84ec",
        "AI Opportunity Deep Dive",
        "15 7 * * *",
        deep_dive_prompt,
    ),
    base_llm_job(
        "397353f649f0",
        "AI Implementation Planning Sprint",
        "45 7 * * *",
        impl_prompt,
    ),
    base_script_job(
        "89b6d08634a1",
        "hermes-ct188-health-check",
        "hermes-ct188-health-check.sh",
        "*/30 7-23 * * *",
    ),
]

# Remover lixo legado
legacy_ids = {"5fdb6a3c6674"}
jobs = [j for j in jobs if j["id"] not in legacy_ids]

data["jobs"] = jobs
save(data)
print(f"OK {len(jobs)} jobs reescritos em {path}")
for j in jobs:
    kind = "script" if j.get("no_agent") else "llm"
    print(f"  - {j['id']}: {j['name'][:45]} [{j['schedule']['expr']}] ({kind})")
PY

fix_cron_perms

echo "=== 4/6 Reiniciar Jarvis ==="
docker restart "${CONTAINER}"
sleep 22

echo "=== 5/6 Validar scheduler ==="
docker exec -u hermes -e HERMES_HOME=/opt/data "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron list

if [[ "${TEST_RUN}" == "--test-run" ]]; then
  echo "=== 6/6 Test runs (scripts) ==="
  for job in hermes-ct188-daily-maintenance hermes-ct188-daily-backup hermes-ct188-health-check; do
    echo "--- ${job} ---"
    docker exec -u hermes -e HERMES_HOME=/opt/data "${CONTAINER}" \
      /opt/hermes/.venv/bin/hermes cron run "${job}" || true
    sleep 5
  done
else
  echo "=== 6/6 Skip test-run (usar --test-run para forçar) ==="
fi

fix_cron_perms
echo ""
echo "Concluído. Crons evoluídos: scripts para ops, LLM só texto (agl-primary)."
