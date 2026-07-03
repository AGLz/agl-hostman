#!/usr/bin/env bash
# Actualiza modelos LLM em crons de perfis (curator, elon, …).
set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
CRON_MODEL="${CRON_MODEL:-agl-primary-zai-glm-flash}"

python3 - "${HERMES_ROOT}" "${CRON_MODEL}" <<'PY'
import json, sys
from pathlib import Path

root, model = Path(sys.argv[1]), sys.argv[2]
paths = sorted(root.glob("profiles/*/cron/jobs.json"))
for path in paths:
    raw = json.loads(path.read_text())
    jobs = raw if isinstance(raw, list) else raw.get("jobs", [])
    changed = 0
    for j in jobs:
        if j.get("no_agent") or j.get("script"):
            continue
        if j.get("model") != model:
            j["model"] = model
            j["provider"] = "custom"
            j["base_url"] = None
            changed += 1
    if isinstance(raw, list):
        path.write_text(json.dumps(jobs, indent=2) + "\n")
    else:
        raw["jobs"] = jobs
        path.write_text(json.dumps(raw, indent=2) + "\n")
    if changed:
        print(f"OK {path.relative_to(root)}: {changed} job(s) → {model}")
PY
