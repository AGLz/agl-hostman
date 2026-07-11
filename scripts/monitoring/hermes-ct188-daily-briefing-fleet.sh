#!/usr/bin/env bash
# Briefing diário consolidado — todos os agentes + infra + crons com falha.
# Único digest matinal Telegram (substitui OK-spam de monitores individuais).
set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
DATE="$(date '+%Y-%m-%d')"
NOW="$(date '+%H:%M %Z')"

echo "📋 Briefing AGL — ${DATE} ${NOW}"
echo ""

python3 - "${HERMES_ROOT}" "${DATE}" <<'PY'
import json, sys
from pathlib import Path

root = Path(sys.argv[1])
today = sys.argv[2]

def load_jobs(path):
    if not path.is_file():
        return []
    data = json.loads(path.read_text())
    if isinstance(data, list):
        return data
    return data.get("jobs", [])

def agent_label(path: Path) -> str:
    parts = path.parts
    if "profiles" in parts:
        i = parts.index("profiles")
        if i + 1 < len(parts):
            return parts[i + 1]
    return "jarvis"

paths = [root / "data" / "cron" / "jobs.json"]
paths += sorted((root / "profiles").glob("*/cron/jobs.json"))

failed = []
ok_count = 0
disabled = 0
for p in paths:
    agent = agent_label(p)
    for j in load_jobs(p):
        name = (j.get("name") or j.get("id") or "?")[:48]
        if not j.get("enabled", True):
            disabled += 1
            continue
        st = j.get("last_status")
        err = j.get("last_error")
        if st in ("error", "failed") or err:
            failed.append(f"{agent}/{name}: {err or st}")
        elif st == "ok":
            ok_count += 1

print("**Crons (fleet)**")
print(f"• OK recente: {ok_count} | desactivados: {disabled} | falhas: {len(failed)}")
for line in failed[:12]:
    print(f"  🔴 {line}")
if len(failed) > 12:
    print(f"  … +{len(failed) - 12} mais")
PY

echo ""
echo "**Infra CT188**"
disk_pct="$(df -P / 2>/dev/null | tail -1 | awk '{print $5}')"
mem_avail="$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "?")"
load="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "?")"
echo "• Disco: ${disk_pct} | RAM avail: ${mem_avail}Gi | load: ${load}"

gw_ok="FAIL"
curl -sf -m 6 http://127.0.0.1:8642/health >/dev/null 2>&1 && gw_ok="OK"
echo "• Jarvis gateway :8642: ${gw_ok}"

litellm_ok="FAIL"
for url in http://100.125.249.8:4000/health/liveliness http://192.168.0.186:4000/health/liveliness; do
  if curl -sf -m 5 "${url}" >/dev/null 2>&1; then
    litellm_ok="OK"
    break
  fi
done
echo "• LiteLLM: ${litellm_ok}"

if command -v docker >/dev/null 2>&1; then
  running="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c 'agl-hermes-' || true)"
  unhealthy="$(docker ps --filter health=unhealthy --format '{{.Names}}' 2>/dev/null | grep -c 'agl-hermes-' || true)"
  echo "• Gateways Docker: ${running} up, ${unhealthy} unhealthy"
fi

backup_dir="/opt/data/backups/daily"
if [[ -d "${backup_dir}" ]]; then
  last_b="$(find "${backup_dir}" -name 'hermes-ct188-*.tar.gz' -printf '%TY-%Tm-%Td %s\n' 2>/dev/null | sort -r | head -1 || true)"
  if [[ -n "${last_b}" ]]; then
    echo "• Último backup Jarvis: ${last_b%% *} ($(echo "${last_b}" | awk '{printf "%.1fMB", $2/1024/1024}'))"
  else
    echo "• Backup Jarvis: nenhum arquivo em ${backup_dir}"
  fi
fi

if [[ -d /mnt/overpower/apps/dev/agl/makemoney01/data/pipeline ]]; then
  mm="$(python3 -c "
import json
b=json.load(open('/mnt/overpower/apps/dev/agl/makemoney01/data/pipeline/board.json'))
cols=b.get('columns',{})
print('prospect=%s qualify=%s execute=%s' % (
  len(cols.get('prospect',[])), len(cols.get('qualify',[])), len(cols.get('execute',[]))))
" 2>/dev/null || echo '?')"
  echo "• makemoney01 pipeline: ${mm}"
fi

queue="/opt/llm-wiki/raw/hermes/review-queue/queue.json"
if [[ -f "${queue}" ]]; then
  rq="$(python3 -c "
import json
q=json.load(open('${queue}'))
items=q if isinstance(q,list) else q.get('items',[])
from collections import Counter
c=Counter(i.get('status','?') for i in items)
print(', '.join(f'{k}={v}' for k,v in sorted(c.items())))
" 2>/dev/null || echo '?')"
  echo "• Review-queue: ${rq:-vazia}"
fi

if [[ -f /opt/data/logs/errors.log ]]; then
  err_today="$(grep -c "${DATE}" /opt/data/logs/errors.log 2>/dev/null || echo 0)"
  echo "• Erros gateway hoje: ${err_today}"
fi

echo ""
echo "_Digest único 07:00. Monitores silenciosos em OK; alertas pontuais só com falha._"
