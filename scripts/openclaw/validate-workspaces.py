#!/usr/bin/env python3
"""Validate agent workspaces and identity files."""
import os
import json

BASE = "/home/node/.openclaw"
IDENTITY_FILES = ["SOUL.md", "IDENTITY.md", "HEARTBEAT.md", "USER.md", "AGENTS.md"]

# Get agent list
with open(os.path.join(BASE, "openclaw.json")) as f:
    cfg = json.load(f)

agents = cfg.get("agents", {}).get("list", [])
print(f"Total agents: {len(agents)}\n")

print(f"{'Agent':<30} {'Workspace Exists':<18} {'Identity Files':<16} {'Sessions':<10}")
print("-" * 80)

for agent in agents:
    aid = agent["id"]
    ws = agent.get("workspace", "").replace("~/.openclaw/", BASE + "/")
    
    ws_exists = os.path.isdir(ws) if ws else False
    
    # Count identity files
    id_count = 0
    if ws_exists:
        for f in IDENTITY_FILES:
            if os.path.exists(os.path.join(ws, f)):
                id_count += 1
    
    # Count sessions
    sessions_dir = os.path.join(BASE, "agents", aid, "sessions")
    session_count = 0
    if os.path.isdir(sessions_dir):
        session_count = len([f for f in os.listdir(sessions_dir) if f.endswith(".jsonl")])
    
    status = "OK" if ws_exists else "MISSING"
    print(f"  {aid:<28} {status:<18} {id_count}/{len(IDENTITY_FILES):<14} {session_count}")

# Check for orphan workspaces (exist but no agent)
print(f"\n{'='*80}")
print("Orphan workspaces (exist but no matching agent):")
agent_ids = {a["id"] for a in agents}
for d in sorted(os.listdir(BASE)):
    if d.startswith("workspace-") and os.path.isdir(os.path.join(BASE, d)):
        # Extract potential agent name
        name = d.replace("workspace-", "")
        if name not in agent_ids and d != "workspace":
            print(f"  {d}/")
