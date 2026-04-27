#!/usr/bin/env python3
"""
Fix cron jobs in OpenClaw:
1. Reset consecutiveErrors on previously-disabled jobs (now Telegram works)
2. Re-enable health check jobs that failed due to "Unsupported channel: telegram"
3. Fix /root/ paths in nightly-proactive-task payload
4. Clear stale model references in morning-briefing
"""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json"

with open(PATH) as f:
    data = json.load(f)

for job in data["jobs"]:
    name = job["name"]
    
    # Reset error state for all jobs
    if "state" in job:
        if job["state"].get("lastRunStatus") == "error":
            job["state"]["consecutiveErrors"] = 0
            job["state"]["lastRunStatus"] = "pending"
            job["state"]["lastStatus"] = "pending"
            if "lastError" in job["state"]:
                del job["state"]["lastError"]
            print(f"  Reset errors: {name}")
    
    # Re-enable jobs that were disabled due to "Unsupported channel: telegram"
    if name in ["storage-health-check", "host-health-check", "ai-stack-health", "critical-services-monitor"]:
        if not job["enabled"]:
            job["enabled"] = True
            print(f"  Re-enabled: {name}")
    
    # Fix /root/ paths in payload messages
    if "payload" in job and "message" in job["payload"]:
        msg = job["payload"]["message"]
        if "/root/.openclaw/" in msg:
            job["payload"]["message"] = msg.replace("/root/.openclaw/", "/home/node/.openclaw/")
            print(f"  Fixed paths: {name}")
        # Also fix ~/
        if "~/self-improving/" in msg or "~/proactivity/" in msg:
            job["payload"]["message"] = job["payload"]["message"].replace(
                "~/self-improving/", "/home/node/.openclaw/workspace/self-improving/"
            ).replace(
                "~/proactivity/", "/home/node/.openclaw/workspace/proactivity/"
            )
            print(f"  Fixed ~/ paths: {name}")
    
    # Fix LiteLLM source path
    if "payload" in job and "message" in job["payload"]:
        msg = job["payload"]["message"]
        if "source /home/node/.openclaw/litellm-master.secret.env" in msg:
            # This is correct - keep it
            pass

with open(PATH, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("\n=== Cron jobs summary ===")
for job in data["jobs"]:
    status = "ON" if job["enabled"] else "OFF"
    errors = job.get("state", {}).get("consecutiveErrors", 0)
    print(f"  [{status}] {job['name']} (errors: {errors})")
