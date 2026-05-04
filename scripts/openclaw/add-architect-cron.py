#!/usr/bin/env python3
"""Add openclaw-architect-check cron job."""
import json
import os
import time

CRON_PATH = os.environ.get(
    "OPENCLAW_CRON_PATH",
    "/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json",
)
LITELLM_GATEWAY_URL = os.environ.get("LITELLM_GATEWAY_URL", "http://100.125.249.8:4000")

with open(CRON_PATH) as f:
    cron = json.load(f)

# Check if already exists
exists = any(j["name"] == "openclaw-architect-check" for j in cron["jobs"])
if exists:
    print("Cron job already exists")
    exit(0)

new_job = {
    "id": "b2c3d4e5-f6a7-b8c9-d0e1-f2a3b4c5d6e7",
    "agentId": "openclaw-architect",
    "name": "openclaw-architect-check",
    "enabled": True,
    "createdAtMs": int(time.time() * 1000),
    "updatedAtMs": int(time.time() * 1000),
    "schedule": {
        "kind": "every",
        "everyMs": 21600000,  # 6 hours
        "anchorMs": int(time.time() * 1000)
    },
    "sessionTarget": "isolated",
    "wakeMode": "now",
    "payload": {
        "kind": "agentTurn",
        "message": """**SYSTEM AUDIT - OpenClaw Architect**

Execute comprehensive system analysis:

### 1. Agent Health Check
```bash
# List all agents and their session counts
ls /home/node/.openclaw/agents/*/sessions/*.jsonl 2>/dev/null | cut -d/ -f6 | sort | uniq -c | sort -rn
```
- Identify agents with zero sessions (potential orphans)
- Check for agents with stale sessions (>7 days)

### 2. Cron Job Status
```bash
cat /home/node/.openclaw/cron/jobs.json | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'{j[\"name\"]}: errors={j[\"state\"][\"consecutiveErrors\"]}, status={j[\"state\"][\"lastRunStatus\"]}') for j in d['jobs']]"
```
- Report any job with consecutiveErrors > 0
- Identify jobs with status=error

### 3. LiteLLM Model Health
```bash
# Reachability check. HTTP 200 or 401 means the CT186 gateway is alive.
code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 """ + LITELLM_GATEWAY_URL + """/v1/models || true)
case "$code" in
  200|401) echo "LiteLLM CT186: reachable ($code)" ;;
  *) echo "LiteLLM CT186: FAIL ($code)" ;;
esac
```

### 4. Workspace Audit
```bash
# Find orphan workspaces. Historical backup/memory/log paths are intentionally excluded.
ls -d /home/node/.openclaw/workspace-* 2>/dev/null | while read d; do
  name=$(basename "$d" | sed 's/workspace-//')
  grep -q "\"id\": \"$name\"" /home/node/.openclaw/openclaw.json || echo "ORPHAN: $d"
done
```

### 5. Generate Report
If any issues found:
- Document each issue with severity (P0/P1/P2)
- Propose specific fix for each
- Create structured proposal for Telegram
- Request approval before any changes

If all healthy:
- Respond HEARTBEAT_OK (silent, no notification)

### Safety
- This is AUDIT ONLY - do not apply changes
- All changes require explicit approval via Telegram
- Log all findings to operations.log"""
    },
    "delivery": {
        "mode": "announce",
        "channel": "telegram",
        "to": "1272190248"
    },
    "state": {
        "consecutiveErrors": 0,
        "lastRunStatus": "pending",
        "lastStatus": "pending"
    }
}

cron["jobs"].append(new_job)

with open(CRON_PATH, "w") as f:
    json.dump(cron, f, indent=2, ensure_ascii=False)

print(f"Added openclaw-architect-check cron job")
print(f"Schedule: every 6 hours")
print(f"Total jobs: {len(cron['jobs'])}")
