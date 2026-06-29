#!/usr/bin/env bash
# Briefing operacional diário — sem Twitter/Obsidian (sem LLM).
set -euo pipefail

DATE="$(date '+%Y-%m-%d')"
NOW="$(date '+%H:%M %Z')"
JOBS="/opt/data/cron/jobs.json"

echo "📋 Briefing operacional AGL — ${DATE} ${NOW}"
echo ""

if [[ -f "${JOBS}" ]]; then
  python3 - "${JOBS}" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception as e:
    print(f"• Cron jobs: erro a ler ({e})")
    sys.exit(0)

jobs = data if isinstance(data, list) else data.get("jobs", [])
print("**Crons Hermes**")
for j in sorted(jobs, key=lambda x: x.get("schedule", {}).get("expr", "")):
    name = (j.get("name") or j.get("id", "?"))[:50]
    sched = j.get("schedule", {}).get("expr", "?")
    st = j.get("last_status", "?")
    err = j.get("last_error")
    mode = "script" if j.get("no_agent") else "llm"
    line = f"• {name} [{sched}] — {st} ({mode})"
    if err:
        line += f" — erro recente"
    print(line)
PY
else
  echo "• Cron jobs: ficheiro em falta"
fi

echo ""
echo "**Infra rápida**"
disk_pct="$(df -P / 2>/dev/null | tail -1 | awk '{print $5}')"
echo "• Disco CT188: ${disk_pct}"

if curl -sf -m 5 http://192.168.0.186:4000/health/liveliness >/dev/null 2>&1; then
  echo "• LiteLLM CT186: OK"
else
  echo "• LiteLLM CT186: FAIL"
fi

if [[ -d /mnt/overpower/apps/dev/agl/makemoney01/data/pipeline ]]; then
  mm_prospect="$(python3 -c "import json; b=json.load(open('/mnt/overpower/apps/dev/agl/makemoney01/data/pipeline/board.json')); print(len(b.get('columns',{}).get('prospect',[])))" 2>/dev/null || echo '?')"
  mm_qualify="$(python3 -c "import json; b=json.load(open('/mnt/overpower/apps/dev/agl/makemoney01/data/pipeline/board.json')); print(len(b.get('columns',{}).get('qualify',[])))" 2>/dev/null || echo '?')"
  echo "• makemoney01: prospect=${mm_prospect} qualify=${mm_qualify}"
else
  echo "• makemoney01: mount em falta"
fi

if [[ -f /opt/llm-wiki/wiki/index.md ]]; then
  wiki_age="$(find /opt/llm-wiki/wiki/index.md -printf '%TY-%Tm-%Td' 2>/dev/null || echo '?')"
  echo "• llm-wiki index: atualizado ${wiki_age}"
fi

err_today=0
[[ -f /opt/data/logs/errors.log ]] && err_today="$(grep -c "${DATE}" /opt/data/logs/errors.log 2>/dev/null || echo 0)"
echo "• Erros gateway hoje: ${err_today} (errors.log)"
echo ""
echo "_Briefing automático. Pipeline makemoney01: crons 06:30–08:00 + wiki-ingest._"
