#!/usr/bin/env python3
"""Add openclaw-architect-check cron job."""
import json
import time

CRON_PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json"

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
# Quick test of primary models
curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen-plus","messages":[{"role":"user","content":"OK"}],"max_tokens":5}' 2>/dev/null | grep -q "choices" && echo "qwen-plus: OK" || echo "qwen-plus: FAIL"
```

### 4. Workspace Audit
```bash
# Find orphan workspaces
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
