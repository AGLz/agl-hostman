#!/bin/sh
# Relatório semanal — cron state via CLI (SQLite store 2026.6.6+).
set -eu
BASE=/home/node/.openclaw
WS="$BASE/workspace"
REPORTDIR="$WS/reports"
mkdir -p "$REPORTDIR"
REPORT="$REPORTDIR/weekly-self-reflection-$(date +%F).md"
{
  echo "# Weekly Self Reflection - $(date '+%F %T %z')"
  echo
  echo "## Runtime"
  echo "- OpenClaw: CT187 / 100.123.184.125"
  echo "- LiteLLM: CT186 / 100.125.249.8:4000"
  echo "- Version: $(openclaw --version 2>/dev/null || echo unknown)"
  echo
  echo "## Cron State"
  python3 - <<'PY' 2>/dev/null || echo '- cron state unavailable'
import json, subprocess
r = subprocess.run(
    ["openclaw", "cron", "list", "--json", "--all"],
    capture_output=True,
    text=True,
    timeout=60,
)
if r.returncode != 0:
    print(f"- cron_cli_error: {r.stderr.strip()[:120]}")
    raise SystemExit(0)
data = json.loads(r.stdout)
jobs = data if isinstance(data, list) else data.get("jobs", data.get("items", []))
for j in sorted(jobs, key=lambda x: x.get("name") or ""):
    if not j.get("enabled", True):
        continue
    st = j.get("state") or {}
    name = j.get("name", j.get("id", "?"))
    status = st.get("lastRunStatus", "?")
    errors = st.get("consecutiveErrors", 0)
    print(f"- {name}: lastRunStatus={status} consecutiveErrors={errors}")
PY
  echo
  echo "## Active Drift"
  grep -Il "192\.168\.32\." "$BASE/openclaw.json" "$WS"/scripts/* 2>/dev/null | grep -v "\.bak" || echo "- None"
  echo
  echo "## Memory Files"
  for f in "$WS/skills/self-improving/memory.md" "$WS/skills/self-improving/corrections.md" "$WS/skills/self-improving/reflections.md" "$WS/MEMORY.md"; do
    if [ -f "$f" ]; then echo "- OK: $f"; else echo "- MISSING_OPTIONAL: $f"; fi
  done
} > "$REPORT"

if grep -Eq 'consecutiveErrors=[1-9]|lastRunStatus=error|192[.]168[.]32[.]|cron_cli_error' "$REPORT"; then
  echo "WEEKLY_REFLECTION_FINDINGS"
  echo "Report: $REPORT"
  grep -E 'consecutiveErrors=[1-9]|lastRunStatus=error|192[.]168[.]32[.]|cron_cli_error' "$REPORT" | head -12 || true
else
  echo "HEARTBEAT_OK"
fi
