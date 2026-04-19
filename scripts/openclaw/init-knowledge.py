#!/usr/bin/env python3
"""
Create all knowledge scripts in the architect workspace.
Since the scripts are in local D: drive, we recreate them from content.
"""
import os
import base64

BASE = "/mnt/overpower/apps/dev/agl/openclaw-repo/config"
WORKSPACE = os.path.join(BASE, "workspace-openclaw-architect")
KNOWLEDGE = os.path.join(WORKSPACE, "knowledge")

os.makedirs(KNOWLEDGE, exist_ok=True)

# We'll create placeholder files that reference the actual scripts
# The actual scripts are in scripts/ directory
README = """# Knowledge Base - OpenClaw Operational Scripts

This directory contains the operational knowledge of the AGL-AI OpenClaw system.

## Scripts

1. **restore.py** - Restore OpenClaw config from backup for Docker
2. **restructure_agency.py** - Apply 4-tier model assignments to all agents
3. **fix_litellm_zai.py** - Fix ZAI provider endpoint format
4. **fix_model_names.py** - Map OpenClaw model names to LiteLLM aliases
5. **restructure_cron.py** - Optimize cron jobs, remove redundancies
6. **test_jarvis.py** - Functional tests for Jarvis (main agent)
7. **test_litellm.py** - Comprehensive model testing across providers
8. **validate_workspaces.py** - Audit agent workspaces and identity files

## Location

The actual scripts are in:
`/mnt/overpower/apps/dev/agl/openclaw-repo/config/scripts/`

This directory contains:
- Documentation of what each script does
- When to use each script
- Expected outcomes

## Usage

These scripts are referenced by the architect-engine skill.
Do not manually execute - use the skill's capabilities instead.
"""

with open(os.path.join(KNOWLEDGE, "README.md"), "w") as f:
    f.write(README)

# Create metadata for each script
METADATA = {
    "restore.py": {
        "purpose": "Rebuild openclaw.json from backup, adapt for Docker/LiteLLM",
        "when_to_use": "Config corruption, migration, fresh install",
        "inputs": ["backup path", "LiteLLM URL", "agents list"],
        "outputs": ["restored openclaw.json"],
        "safety": "Creates new file, does not overwrite without confirmation"
    },
    "restructure_agency.py": {
        "purpose": "Apply tiered model assignments (STRONG/MEDIUM/FAST/CREATIVE)",
        "when_to_use": "New agents added, model performance issues, cost optimization",
        "inputs": ["openclaw.json"],
        "outputs": ["updated agent models and fallbacks"],
        "safety": "Modifies all agents - backup required"
    },
    "fix_litellm_zai.py": {
        "purpose": "Change ZAI from Anthropic to OpenAI-compatible endpoint",
        "when_to_use": "ZAI models failing health checks",
        "inputs": ["/opt/litellm/config.yaml"],
        "outputs": ["fixed config.yaml"],
        "safety": "Creates backup before modification"
    },
    "fix_model_names.py": {
        "purpose": "Map OpenClaw model names to LiteLLM aliases",
        "when_to_use": "Model routing errors, invalid model names",
        "inputs": ["openclaw.json"],
        "outputs": ["updated model references"],
        "safety": "Uses mapping table, preserves structure"
    },
    "restructure_cron.py": {
        "purpose": "Remove redundant jobs, fix payloads, setup self-improving",
        "when_to_use": "Overlapping schedules, job failures, new requirements",
        "inputs": ["cron/jobs.json"],
        "outputs": ["optimized cron jobs"],
        "safety": "Resets error states, removes sessionKey issues"
    },
    "test_jarvis.py": {
        "purpose": "Functional tests for main agent via HTTP API",
        "when_to_use": "After config changes, periodic validation",
        "inputs": ["gateway URL", "token"],
        "outputs": ["test results (5 checks)"],
        "safety": "Read-only, does not modify system"
    },
    "test_litellm.py": {
        "purpose": "Test all 40 models across 11 providers",
        "when_to_use": "Model health audit, performance baseline",
        "inputs": ["LiteLLM URL", "key"],
        "outputs": ["latency and success rates per model"],
        "safety": "Read-only, generates report only"
    },
    "validate_workspaces.py": {
        "purpose": "Audit agent workspaces for identity files",
        "when_to_use": "Self-improving setup, workspace cleanup",
        "inputs": ["openclaw.json"],
        "outputs": ["workspace health report"],
        "safety": "Read-only, identifies orphans"
    }
}

import json
for script, meta in METADATA.items():
    with open(os.path.join(KNOWLEDGE, f"{script}.meta.json"), "w") as f:
        json.dump(meta, f, indent=2)
    print(f"Created: {script}.meta.json")

print(f"\nKnowledge base initialized in: {KNOWLEDGE}")
print(f"Total files: {len(METADATA) + 1}")
