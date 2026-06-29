#!/usr/bin/env bash
# Sincroniza outputs dos crons Hermes → makemoney01 (canónico no mount NFS).
# Após sync: arquiva no mount e remove cópia local Hermes.
set -euo pipefail

MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
CRON_OUTPUT="${HERMES_CRON_OUTPUT:-/opt/data/cron/output}"
DATE="$(date '+%Y-%m-%d')"

JOB_RESEARCH="${MAKEMONEY_JOB_RESEARCH:-708fe1021f93}"
JOB_DEEP="${MAKEMONEY_JOB_DEEP:-052baa2c84ec}"
JOB_IMPL="${MAKEMONEY_JOB_IMPL:-397353f649f0}"

ensure_dirs() {
  mkdir -p \
    "${MAKEMONEY_DIR}/data/cron-sync" \
    "${MAKEMONEY_DIR}/data/opportunities" \
    "${MAKEMONEY_DIR}/data/pipeline" \
    "${MAKEMONEY_DIR}/data/hermes-archive" \
    "${MAKEMONEY_DIR}/wiki-ingest"
}

latest_output() {
  local job_id="$1"
  local dir="${CRON_OUTPUT}/${job_id}"
  [[ -d "${dir}" ]] || return 1
  find "${dir}" -name '*.md' -type f 2>/dev/null | sort | tail -1
}

archive_hermes_file() {
  local job_id="$1" src="$2"
  local arch="${MAKEMONEY_DIR}/data/hermes-archive/${job_id}"
  mkdir -p "${arch}"
  cp -f "${src}" "${arch}/$(basename "${src}")"
}

write_opportunity_json() {
  local md_path="$1" date="$2" label="$3"
  MAKEMONEY_DIR="${MAKEMONEY_DIR}" python3 - "${md_path}" "${date}" "${label}" <<'PY'
import json, os, re, sys
from datetime import datetime, timezone
from pathlib import Path

md_path, date, label = sys.argv[1:4]
root = Path(os.environ["MAKEMONEY_DIR"])
text = Path(md_path).read_text(encoding="utf-8", errors="replace")
m = re.search(r"^## Response\s*\n+(.*)", text, re.DOTALL | re.MULTILINE)
body = m.group(1).strip() if m else ""
if not body or body == "[SILENT]":
    sys.exit(0)
out = root / "data" / "opportunities" / f"{date}-{label}.json"
out.write_text(json.dumps({
    "date": date, "type": label,
    "synced_at": datetime.now(timezone.utc).isoformat(),
    "source_md": str(md_path), "content": body,
}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"OK json {out.name}")
PY
}

sync_job() {
  local job_id="$1" label="$2"
  local src
  src="$(latest_output "${job_id}")" || return 0
  archive_hermes_file "${job_id}" "${src}"
  local dst="${MAKEMONEY_DIR}/data/cron-sync/${DATE}-${label}.md"
  cp -f "${src}" "${dst}"
  echo "OK sync ${label}: $(basename "${src}") → ${dst}"

  local py="${MAKEMONEY_DIR}/scripts/parse_cron_output.py"
  if [[ -f "${py}" ]]; then
    local body
    body="$(python3 "${py}" "${dst}" 2>/dev/null || true)"
    if [[ -n "${body}" && "${body}" != "SILENT" ]]; then
      write_opportunity_json "${dst}" "${DATE}" "${label}" || true
    fi
  fi

  # Canónico no mount — remover cópia Hermes após sync
  rm -f "${src}" 2>/dev/null || true
}

main() {
  if [[ ! -d "${MAKEMONEY_DIR}" ]]; then
    echo "ERRO: makemoney01 inexistente em ${MAKEMONEY_DIR}" >&2
    exit 1
  fi
  ensure_dirs
  sync_job "${JOB_RESEARCH}" "research"
  sync_job "${JOB_DEEP}" "deep-dive"
  sync_job "${JOB_IMPL}" "impl-sprint"

  local upd="${MAKEMONEY_DIR}/scripts/update_pipeline.py"
  local research_md="${MAKEMONEY_DIR}/data/cron-sync/${DATE}-research.md"
  if [[ -f "${upd}" && -f "${research_md}" ]]; then
    python3 "${upd}" "${research_md}" "${DATE}" || true
  fi
  echo "OK makemoney-sync ${DATE} (canónico: ${MAKEMONEY_DIR})"
}

main "$@"
