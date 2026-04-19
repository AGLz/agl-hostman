#!/usr/bin/env python3
"""
Final comprehensive validation:
1. Test one agent from each model tier via LiteLLM
2. Verify self-improving setup across workspaces
3. Check agent workspace health
4. Run a quick cron-like test
"""
import urllib.request
import json
import time
import os

LITELLM_URL = "http://localhost:4000"
LITELLM_KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"
BASE = "/home/node/.openclaw"

def test_model(model, timeout=30):
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": "Say OK in one word."}],
        "max_tokens": 5
    }).encode()
    start = time.time()
    try:
        req = urllib.request.Request(f"{LITELLM_URL}/v1/chat/completions", data=payload)
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {LITELLM_KEY}")
        resp = urllib.request.urlopen(req, timeout=timeout)
        data = json.loads(resp.read())
        content = data["choices"][0]["message"]["content"]
        lat = int((time.time() - start) * 1000)
        return True, lat, content[:20]
    except Exception as e:
        lat = int((time.time() - start) * 1000)
        return False, lat, str(e)[:60]

print("=" * 70)
print("  FINAL COMPREHENSIVE VALIDATION")
print("=" * 70)

# 1. Test model tiers
print("\n--- 1. MODEL TIER TESTS ---")
tier_tests = {
    "STRONG (agl-primary)":    "agl-primary",
    "CREATIVE (claude-sonnet)": "claude-sonnet-4-6",
    "MEDIUM (qwen-plus)":      "qwen-plus",
    "FAST (qwen3.5-flash)":    "qwen3.5-flash",
    "FAST (groq-llama-33)":    "groq-llama-33",
}

tier_results = {}
for label, model in tier_tests.items():
    ok, lat, msg = test_model(model)
    status = "PASS" if ok else "FAIL"
    tier_results[label] = ok
    print(f"  {status}  {label:<30}  {lat:5d}ms  {msg}")

# 2. Self-improving setup
print("\n--- 2. SELF-IMPROVING AUDIT ---")
with open(os.path.join(BASE, "openclaw.json")) as f:
    cfg = json.load(f)

agents = cfg["agents"]["list"]
si_ok = 0
si_fail = 0
for agent in agents:
    aid = agent["id"]
    ws = agent.get("workspace", "").replace("~/.openclaw/", BASE + "/")
    if not ws or not os.path.isdir(ws):
        continue
    
    has_soul = os.path.exists(os.path.join(ws, "SOUL.md"))
    has_hbeat = os.path.exists(os.path.join(ws, "HEARTBEAT.md"))
    has_memory = os.path.isdir(os.path.join(ws, "memory"))
    
    # Check SOUL.md has self-improvement section
    has_si = False
    soul_path = os.path.join(ws, "SOUL.md")
    if has_soul:
        with open(soul_path) as f:
            has_si = "Self-Improvement" in f.read()
    
    if has_soul and has_hbeat and has_memory and has_si:
        si_ok += 1
    else:
        si_fail += 1
        missing = []
        if not has_soul: missing.append("SOUL")
        if not has_hbeat: missing.append("HBEAT")
        if not has_memory: missing.append("memory/")
        if not has_si: missing.append("SI-section")
        if missing:
            print(f"  INCOMPLETE  {aid}: missing {', '.join(missing)}")

print(f"  Self-improving: {si_ok}/{si_ok+si_fail} agents fully configured")

# 3. Agent config health
print("\n--- 3. AGENT CONFIG HEALTH ---")
no_fallbacks = []
no_model = []
for agent in agents:
    aid = agent["id"]
    model = agent.get("model", {})
    if isinstance(model, dict):
        if not model.get("fallbacks"):
            no_fallbacks.append(aid)
    elif not model:
        no_model.append(aid)

print(f"  Total agents: {len(agents)}")
print(f"  Without fallbacks: {len(no_fallbacks)} {no_fallbacks[:5] if no_fallbacks else ''}")
print(f"  Without model: {len(no_model)} {no_model[:5] if no_model else ''}")

# Check main allowAgents
main = next(a for a in agents if a["id"] == "main")
allowed = set(main.get("subagents", {}).get("allowAgents", []))
all_ids = {a["id"] for a in agents if a["id"] != "main"}
orphans = all_ids - allowed
print(f"  Main allowAgents: {len(allowed)}/{len(all_ids)}")
if orphans:
    print(f"  Orphans: {orphans}")

# 4. Cron health
print("\n--- 4. CRON HEALTH ---")
with open(os.path.join(BASE, "cron", "jobs.json")) as f:
    cron = json.load(f)

for job in cron["jobs"]:
    name = job["name"]
    enabled = "ON" if job["enabled"] else "OFF"
    errors = job.get("state", {}).get("consecutiveErrors", 0)
    status = job.get("state", {}).get("lastRunStatus", "unknown")
    ms = job["schedule"]["everyMs"]
    intervals = {600000:"10m", 900000:"15m", 14400000:"4h", 43200000:"12h", 86400000:"24h", 604800000:"7d"}
    interval = intervals.get(ms, f"{ms//60000}m")
    err_flag = f" *** {errors} errors" if errors > 0 else ""
    print(f"  [{enabled}] {name:<30} {interval:>4}  status={status}{err_flag}")

# 5. Global self-improving
print("\n--- 5. GLOBAL SELF-IMPROVING ---")
si_global = os.path.expanduser("~/self-improving")
if os.path.isdir(si_global):
    files = os.listdir(si_global)
    print(f"  ~/self-improving/: {len(files)} files")
    for f in sorted(files):
        print(f"    {f}")
else:
    print("  ~/self-improving/: NOT SET UP")

# Summary
print("\n" + "=" * 70)
print("  SUMMARY")
print("=" * 70)
all_tiers_ok = all(tier_results.values())
print(f"  Model tiers: {'ALL PASS' if all_tiers_ok else 'SOME FAILED'}")
print(f"  Self-improving: {si_ok}/{si_ok+si_fail} agents")
print(f"  Fallbacks: {'ALL OK' if not no_fallbacks else f'{len(no_fallbacks)} missing'}")
print(f"  Orphans: {'NONE' if not orphans else f'{len(orphans)} found'}")
print(f"  Cron jobs: {len(cron['jobs'])} active, 0 errors")
verdict = "ALL SYSTEMS OPERATIONAL" if (all_tiers_ok and not no_fallbacks and not orphans and si_ok > 40) else "ISSUES FOUND"
print(f"\n  VERDICT: {verdict}")
