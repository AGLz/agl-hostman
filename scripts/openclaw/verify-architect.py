#!/usr/bin/env python3
"""Verify openclaw-architect installation."""
import json
import os

BASE = "/home/node/.openclaw"

# Check openclaw.json
with open(os.path.join(BASE, "openclaw.json")) as f:
    cfg = json.load(f)

agents = cfg["agents"]["list"]
print(f"Total agents: {len(agents)}")

architect = next((a for a in agents if a["id"] == "openclaw-architect"), None)
if architect:
    print(f"  openclaw-architect: FOUND")
    print(f"    Model: {architect['model']['primary']}")
    print(f"    Workspace: {architect['workspace']}")
else:
    print(f"  openclaw-architect: NOT FOUND")

main = next(a for a in agents if a["id"] == "main")
print(f"  Main allowAgents: {len(main['subagents']['allowAgents'])}")
if "openclaw-architect" in main["subagents"]["allowAgents"]:
    print(f"    openclaw-architect: IN allowAgents")
else:
    print(f"    openclaw-architect: NOT IN allowAgents")

# Check cron
with open(os.path.join(BASE, "cron", "jobs.json")) as f:
    cron = json.load(f)

print(f"\nCron jobs: {len(cron['jobs'])}")
architect_cron = next((j for j in cron["jobs"] if j["name"] == "openclaw-architect-check"), None)
if architect_cron:
    print(f"  openclaw-architect-check: FOUND")
    print(f"    Agent: {architect_cron['agentId']}")
    print(f"    Enabled: {architect_cron['enabled']}")
else:
    print(f"  openclaw-architect-check: NOT FOUND")

# Check workspace
ws = os.path.join(BASE, "workspace-openclaw-architect")
print(f"\nWorkspace: {ws}")
if os.path.isdir(ws):
    print(f"  Exists: YES")
    files = os.listdir(ws)
    print(f"  Files: {files}")
    
    knowledge = os.path.join(ws, "knowledge")
    if os.path.isdir(knowledge):
        scripts = os.listdir(knowledge)
        print(f"  Knowledge scripts: {len(scripts)}")
    
    skill = os.path.join(ws, "skills", "architect-engine")
    if os.path.isdir(skill):
        print(f"  Skill: architect-engine/ exists")
else:
    print(f"  Exists: NO")
