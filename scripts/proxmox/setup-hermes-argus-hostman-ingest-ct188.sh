#!/usr/bin/env bash
# Configura ingest Argus → CT134 LLM Monitor (API key + cron).
#
# Uso (root no host com pct → CT188):
#   bash setup-hermes-argus-hostman-ingest-ct188.sh [tokens_env]
#
# tokens_env pode conter HOSTMAN_API_KEY=... ou API_KEY=...
# Se ausente, tenta ler de CT134 /root/.agl-hostman-api-key.generated

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOKENS_ENV="${1:-/root/.aglz-telegram-tokens.env}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
ARGUS_DIR="${HERMES_ROOT}/profiles/argus"
DATA_SCRIPTS="${ARGUS_DIR}/scripts"
JOBS="${ARGUS_DIR}/cron/jobs.json"
HERMES_UID="${HERMES_UID:-10000}"
AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
CT134_VMID="${CT134_VMID:-134}"

HOSTMAN_API_URL="${HOSTMAN_API_URL:-http://192.168.0.134}"

log() { echo "[setup-argus-ingest] $*" >&2; }

if [[ -f "${TOKENS_ENV}" ]]; then
  # shellcheck source=/dev/null
  source "${TOKENS_ENV}" 2>/dev/null || true
fi

API_KEY_VAL="${HOSTMAN_API_KEY:-${API_KEY:-}}"
if [[ -z "${API_KEY_VAL}" ]]; then
  API_KEY_VAL="$(ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct exec ${CT134_VMID} -- cat /root/.agl-hostman-api-key.generated 2>/dev/null" | cut -d= -f2- || true)"
fi

if [[ -z "${API_KEY_VAL}" ]]; then
  log "ERRO: HOSTMAN_API_KEY não encontrada — definir em ${TOKENS_ENV} ou gerar no CT134"
  exit 1
fi

install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_UID}" "${DATA_SCRIPTS}"
src="${REPO_ROOT}/scripts/monitoring/hermes-argus-hostman-ingest.sh"
dst="${DATA_SCRIPTS}/hermes-argus-hostman-ingest.sh"
sed 's/\r$//' "${src}" > "${dst}.tmp" && mv "${dst}.tmp" "${dst}"
chmod 0755 "${dst}"
chown "${HERMES_UID}:${HERMES_UID}" "${dst}"

ENV_FILE="${ARGUS_DIR}/.env.hostman"
cat > "${ENV_FILE}" <<ENV
# Argus → CT134 LLM Monitor (não commitar)
HOSTMAN_API_URL=${HOSTMAN_API_URL}
HOSTMAN_API_KEY=${API_KEY_VAL}
GOVERNOR_STATE_FILE=/var/log/hostman/quota-governor-state.json
ENV
chmod 600 "${ENV_FILE}"
chown "${HERMES_UID}:${HERMES_UID}" "${ENV_FILE}"

python3 - "${JOBS}" <<'PY'
import json
import sys
from datetime import datetime
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
        "deliver": None,
        "origin": None,
        "enabled_toolsets": None,
        "workdir": None,
        "profile": None,
    }

data = load()
jobs = data.setdefault("jobs", [])
by_name = {j.get("name"): j for j in jobs}
name = "argus-hostman-ingest"
if name in by_name:
    j = by_name[name]
    j["schedule"] = cron_schedule("*/15 * * * *")
    j["schedule_display"] = "*/15 * * * *"
    j["script"] = "hermes-argus-hostman-ingest.sh"
    j["no_agent"] = True
    j["enabled"] = True
    print(f"OK update {name}")
else:
    jobs.append(base_script_job(
        "a37d5e0f2g43",
        name,
        "hermes-argus-hostman-ingest.sh",
        "*/15 * * * *",
        "# Argus — ingest governor → CT134 LLM Monitor DB",
    ))
    print(f"OK create {name}")

save(data)
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
log "OK ingest configurado — ${ENV_FILE} (chmod 600)"
log "Cron: argus-hostman-ingest */15 * * * *"
