#!/usr/bin/env bash
# Instala skill llm-wiki no perfil curator + corrige prompt do cron curator-maintenance.
#
# Causa: curator/skills/ vazio; cron usava `llm-wiki ingest|lint` (CLI inexistente).
# Ref: data/skills/research/llm-wiki/references/curator-maintenance.md
#
# Uso (root no CT188):
#   bash fix-curator-llm-wiki-skill-ct188.sh
#   bash fix-curator-llm-wiki-skill-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
CURATOR_DIR="${HERMES_ROOT}/data/profiles/curator"
CURATOR_SKILLS="${CURATOR_DIR}/skills/research"
JOBS_JSON="${HERMES_ROOT}/data/cron/jobs.json"
JOB_ID="${CURATOR_CRON_JOB_ID:-e54ffa964a1f}"

SKILL_SRC="${HERMES_ROOT}/data/skills/research/llm-wiki"
if [[ ! -f "${SKILL_SRC}/SKILL.md" ]]; then
  echo "ERRO: falta ${SKILL_SRC}/SKILL.md — correr hermes skills install no jarvis primeiro" >&2
  exit 1
fi

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CURATOR_SKILLS}"
ln -sfn "${SKILL_SRC}" "${CURATOR_SKILLS}/llm-wiki"
chown -h "${HERMES_UID}:${HERMES_GID}" "${CURATOR_SKILLS}/llm-wiki" 2>/dev/null || true
echo "OK skill symlink: ${CURATOR_SKILLS}/llm-wiki -> ${SKILL_SRC}"

if [[ -f "${CURATOR_DIR}/config.yaml" ]]; then
  install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CURATOR_DIR}/.hermes"
  cp "${CURATOR_DIR}/config.yaml" "${CURATOR_DIR}/.hermes/config.yaml"
  chown "${HERMES_UID}:${HERMES_GID}" "${CURATOR_DIR}/.hermes/config.yaml"
  chmod 600 "${CURATOR_DIR}/.hermes/config.yaml"
  echo "OK synced ${CURATOR_DIR}/.hermes/config.yaml"
fi

read -r -d '' NEW_PROMPT <<'PROMPT' || true
# Curator Maintenance Job (runs every 2h)

Use the **llm-wiki** skill (no shell `llm-wiki` CLI). WIKI_PATH=/opt/llm-wiki/wiki (flat AGLz structure).

## 1. Orient (skill: Resuming an Existing Wiki)
Read SCHEMA.md, index.md, and recent log.md under WIKI_PATH when present.

## 2. Ensure directories
mkdir -p /opt/data/logs/wiki-lint /opt/data/wiki-ingest

## 3. Ingest (skill ingest workflow)
Process new sources in /opt/data/wiki-ingest/ per llm-wiki skill. Write/update pages under WIKI_PATH.

## 4. Lint (skill lint workflow)
Run the wiki lint procedure from the skill. Save summary to:
/opt/data/logs/wiki-lint/curator-$(date +%Y%m%d-%H%M%S).log

## 5. Report issues
Include any pages with confidence: low or contested: true in your report (cron delivers automatically — do not call send_message).

## 6. Git commit if configured
If /opt/data/wiki-repo exists, commit wiki changes with a dated message.

If nothing to ingest and no lint findings, respond with exactly [SILENT].
PROMPT

python3 - "${JOBS_JSON}" "${JOB_ID}" "${NEW_PROMPT}" <<'PY'
import json
import sys
from pathlib import Path

path, job_id, prompt = sys.argv[1:4]
data = json.loads(Path(path).read_text())
updated = False
for job in data.get("jobs", []):
    if job.get("id") != job_id:
        continue
    job["prompt"] = prompt
    job["skills"] = ["llm-wiki"]
    job["skill"] = "llm-wiki"
    updated = True
    print(f"OK updated cron prompt: {job.get('name')} ({job_id})")
    break
if not updated:
    raise SystemExit(f"job {job_id} não encontrado em {path}")
Path(path).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

chown "${HERMES_UID}:${HERMES_GID}" "${JOBS_JSON}"
chmod 600 "${JOBS_JSON}"
echo "OK ${JOBS_JSON}"
