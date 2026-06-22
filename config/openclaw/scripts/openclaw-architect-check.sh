#!/bin/sh
# Auditoria OpenClaw CT187 — compatível com cron store SQLite (2026.6.6+).
set -eu
BASE=/home/node/.openclaw
fail=0
issues=""

litellm=$(curl -s -o /dev/null -w '%{http_code}' http://100.125.249.8:4000/health/liveliness -m 10 || echo curl_failed)
case "$litellm" in 200) : ;; *) fail=1; issues="$issues
- litellm_ct186_http: $litellm" ;; esac

health=$(curl -s http://127.0.0.1:18789/healthz -m 5 || true)
echo "$health" | grep -q '"ok":true' || { fail=1; issues="$issues
- openclaw_health: $health"; }

primary=$(python3 - <<'PY' 2>/dev/null || echo unknown
import json
d = json.load(open("/home/node/.openclaw/openclaw.json"))
print(d.get("agents", {}).get("defaults", {}).get("model", {}).get("primary", "unknown"))
PY
)
case "$primary" in
  openai/gpt-5.4-nano|openai/agl-primary|agl-primary) ;;
  *)
    fail=1
    issues="$issues
- primary_model: $primary"
    ;;
esac

cron_summary=$(python3 <<'PY'
import json, subprocess
r = subprocess.run(
    ["openclaw", "cron", "list", "--json", "--all"],
    capture_output=True,
    text=True,
    timeout=60,
)
if r.returncode != 0:
    print(f"cron_cli_error: {r.stderr.strip()[:120]}")
    raise SystemExit(1)
data = json.loads(r.stdout)
jobs = data if isinstance(data, list) else data.get("jobs", data.get("items", []))
enabled = [j for j in jobs if j.get("enabled", True)]
errors = [j for j in enabled if (j.get("state") or {}).get("lastRunStatus") == "error"]
print(f"cron_jobs_total={len(jobs)} enabled={len(enabled)} last_error={len(errors)}")
for j in errors[:5]:
    name = j.get("name", j.get("id", "?"))
    err = (j.get("state") or {}).get("lastErrorReason") or (j.get("state") or {}).get("lastError") or "error"
    print(f"- cron_error: {name}: {str(err)[:80]}")
PY
) || cron_summary="cron_list_failed"
echo "$cron_summary" | grep -q 'cron_cli_error\|cron_list_failed' && {
  fail=1
  issues="$issues
- cron_list: $cron_summary"
}

active_refs=$(grep -Il "192\.168\.32\." "$BASE/openclaw.json" "$BASE"/workspace/scripts/* 2>/dev/null | grep -v "\.bak" || true)
[ -z "$active_refs" ] || { fail=1; issues="$issues
- active_bridge_refs: $(echo "$active_refs" | tr '\n' ' ')"; }

if [ "$fail" -eq 0 ]; then
  echo HEARTBEAT_OK
else
  echo "SYSTEM AUDIT issue list:$issues"
  exit 1
fi
