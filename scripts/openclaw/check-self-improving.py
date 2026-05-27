#!/usr/bin/env python3
"""Check self-improving configuration across all agent workspaces."""
import os, json

BASE = "/home/node/.openclaw"

with open(os.path.join(BASE, "openclaw.json")) as f:
    cfg = json.load(f)

agents = cfg["agents"]["list"]

print(f"{'Agent':<28} {'SOUL':<6} {'HBEAT':<6} {'SELF-IMP':<10} {'MEMORY':<8} {'GOALS':<6}")
print("-" * 70)

for agent in agents:
    aid = agent["id"]
    ws = agent.get("workspace", "").replace("~/.openclaw/", BASE + "/")
    if not ws or not os.path.isdir(ws):
        print(f"  {aid:<28} {'--':<6} {'--':<6} {'--':<10} {'--':<8} {'--':<6} (no workspace)")
        continue
    
    soul = "Y" if os.path.exists(os.path.join(ws, "SOUL.md")) else "-"
    hbeat = "Y" if os.path.exists(os.path.join(ws, "HEARTBEAT.md")) else "-"
    
    # Check for self-improving skill
    si_dir = os.path.join(ws, "skills", "self-improving")
    si_home = os.path.expanduser("~/self-improving")
    si = "Y" if os.path.isdir(si_dir) else ("-" if not os.path.isdir(si_home) else "~")
    
    # Check for memory files
    mem_dir = os.path.join(ws, "memory")
    mem = str(len(os.listdir(mem_dir))) if os.path.isdir(mem_dir) else "-"
    
    # Check for GOALS
    goals = "Y" if os.path.exists(os.path.join(ws, "GOALS.md")) else "-"
    
    print(f"  {aid:<28} {soul:<6} {hbeat:<6} {si:<10} {mem:<8} {goals:<6}")

# Check main workspace self-improving setup
print(f"\n{'='*70}")
print("Self-improving setup in main workspace:")
si_path = os.path.join(BASE, "workspace", "skills", "self-improving")
if os.path.isdir(si_path):
    files = os.listdir(si_path)
    print(f"  Files: {len(files)}")
    for f in sorted(files):
        size = os.path.getsize(os.path.join(si_path, f))
        print(f"    {f}: {size} bytes")
else:
    print("  NOT FOUND")

# Check ~/self-improving (global)
si_global = os.path.expanduser("~/self-improving")
print(f"\nGlobal ~/self-improving:")
if os.path.isdir(si_global):
    for f in sorted(os.listdir(si_global)):
        print(f"  {f}")
else:
    print("  NOT SET UP")
