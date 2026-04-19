#!/usr/bin/env python3
"""Remove duplicate weekly-self-reflection entries from cron jobs."""
import json, os

CRON_PATH = "/home/node/.openclaw/cron/jobs.json"

with open(CRON_PATH) as f:
    cron = json.load(f)

seen = set()
deduped = []
for job in cron["jobs"]:
    name = job["name"]
    if name in seen:
        print(f"  Removed duplicate: {name}")
        continue
    seen.add(name)
    deduped.append(job)

cron["jobs"] = deduped

with open(CRON_PATH, "w") as f:
    json.dump(cron, f, indent=2, ensure_ascii=False)

print(f"\nFinal job count: {len(deduped)}")
for job in deduped:
    enabled = "ON" if job["enabled"] else "OFF"
    ms = job["schedule"]["everyMs"]
    intervals = {600000:"10min", 900000:"15min", 14400000:"4h", 43200000:"12h", 86400000:"24h", 604800000:"7d"}
    interval = intervals.get(ms, f"{ms//60000}min")
    print(f"  [{enabled}] {job['name']:<30} every {interval}")
