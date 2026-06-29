#!/usr/bin/env bash
# Cron curator-maintenance (llm-wiki, cada 6h) no perfil curator.
#
# Uso (root no CT188):
#   bash setup-hermes-curator-crons-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
CURATOR_DIR="${HERMES_ROOT}/profiles/curator"
JOBS="${CURATOR_DIR}/cron/jobs.json"
HERMES_UID="${HERMES_UID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
JOB_ID="${CURATOR_CRON_JOB_ID:-e54ffa964a1f}"
CRON_MODEL="${CURATOR_CRON_MODEL:-or-nemotron-super-free}"
CRON_EXPR="${CURATOR_CRON_EXPR:-0 4,10,16,22 * * *}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_UID}" "${CURATOR_DIR}/cron"

read -r -d '' PROMPT <<'PROMPT' || true
# Curator Maintenance Job (runs every 6h)

Use the **llm-wiki** skill (no shell `llm-wiki` CLI). WIKI_PATH=/opt/llm-wiki/wiki (flat AGLz structure).

## 1. Orient (skill: Resuming an Existing Wiki)
Read SCHEMA.md, index.md, and recent log.md under WIKI_PATH when present.

## 2. Ensure directories
mkdir -p /opt/data/logs/wiki-lint /opt/data/wiki-ingest

## 3. Ingest (skill ingest workflow)
Process new sources in /opt/data/wiki-ingest/ per llm-wiki skill. Write/update pages under WIKI_PATH.

Also process **Cursor stubs** at `/opt/llm-wiki/raw/wiki-ingest/cursor/` (pipeline `wiki-curator-optimize.py` em agl-hostman). Synthesize problem/decision/solution — never paste full transcripts.

Check latest lint under `/opt/llm-wiki/raw/logs/wiki-lint/` when present.

## 4. Lint (skill lint workflow)
Run the wiki lint procedure from the skill. Save summary to:
/opt/data/logs/wiki-lint/curator-$(date +%Y%m%d-%H%M%S).log

## 5. Report issues
Include any pages with confidence: low or contested: true in your report (cron delivers automatically — do not call send_message).

## 6. Git commit + push (llm-wiki)
Repo em `/opt/llm-wiki`. Usar `HOME=/opt/data` (`.gitconfig` no perfil).
Após ingest/lint: `git add -A`, commit datado, `git push origin main` se houver alterações.

If nothing to ingest and no lint findings, respond with exactly [SILENT].
PROMPT

python3 - "${JOBS}" "${JOB_ID}" "${CRON_MODEL}" "${TELEGRAM_CHAT}" "${PROMPT}" "${CRON_EXPR}" <<'PY'
import json
import sys
from datetime import datetime
from pathlib import Path

path, job_id, model, chat, prompt, cron_expr = sys.argv[1:7]

def load():
    if Path(path).is_file():
        data = json.loads(Path(path).read_text())
        return data if isinstance(data, dict) else {"jobs": data}
    return {"jobs": []}

def save(data):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

data = load()
jobs = data.setdefault("jobs", [])

for j in jobs:
    if j.get("id") == job_id or j.get("name") == "curator-maintenance":
        j.update({
            "id": job_id,
            "name": "curator-maintenance",
            "prompt": prompt,
            "skills": ["llm-wiki"],
            "skill": "llm-wiki",
            "model": model,
            "provider": "custom",
            "script": None,
            "no_agent": False,
            "schedule": {"kind": "cron", "expr": cron_expr, "display": cron_expr},
            "schedule_display": cron_expr,
            "enabled": True,
            "state": "scheduled",
            "deliver": f"telegram:{chat}",
            "enabled_toolsets": [],
        })
        save(data)
        print(f"OK update curator-maintenance ({job_id})")
        sys.exit(0)

jobs.append({
    "id": job_id,
    "name": "curator-maintenance",
    "prompt": prompt,
    "skills": ["llm-wiki"],
    "skill": "llm-wiki",
    "model": model,
    "provider": "custom",
    "base_url": None,
    "script": None,
    "no_agent": False,
    "context_from": None,
    "schedule": {"kind": "cron", "expr": cron_expr, "display": cron_expr},
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
    "enabled_toolsets": [],
    "workdir": None,
    "profile": None,
})
save(data)
print(f"OK create curator-maintenance ({job_id})")
PY

chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}" 2>/dev/null || true
chmod 644 "${JOBS}" 2>/dev/null || true
echo "OK Curator crons → ${JOBS}"
