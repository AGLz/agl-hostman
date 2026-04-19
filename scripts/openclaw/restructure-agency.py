#!/usr/bin/env python3
"""
AGL-AI Agency Restructuring — applies all recommendations:
1. Tiered model assignments by agent role
2. Fallback chains for ALL agents
3. Activate orphan agents in main's allowAgents
4. Fix workspace collision (infra-manager)
5. Add groupChat mentionPatterns for ops agents
"""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    cfg = json.load(f)

# =============================================
# MODEL TIERS (using LiteLLM-verified models)
# =============================================
TIER_STRONG = {
    "primary": "openai/agl-primary",
    "fallbacks": [
        "openai/claude-sonnet-4-6",
        "openai/deepseek",
        "openai/qwen-plus",
        "openai/kimi",
        "openai/gpt",
        "openai/gemini-lite",
        "openai/or-gemma-3-4b-free"
    ]
}

TIER_MEDIUM = {
    "primary": "openai/qwen-plus",
    "fallbacks": [
        "openai/deepseek",
        "openai/agl-primary",
        "openai/qwen-coder",
        "openai/kimi",
        "openai/gemini-lite",
        "openai/or-gemma-3-4b-free"
    ]
}

TIER_FAST = {
    "primary": "openai/qwen3.5-flash",
    "fallbacks": [
        "openai/qwen-turbo",
        "openai/groq-llama-33",
        "openai/qwen-coder",
        "openai/agl-primary",
        "openai/or-gemma-3-4b-free"
    ]
}

TIER_CREATIVE = {
    "primary": "openai/claude-sonnet-4-6",
    "fallbacks": [
        "openai/agl-primary",
        "openai/qwen-plus",
        "openai/deepseek",
        "openai/kimi",
        "openai/gpt",
        "openai/gemini-lite"
    ]
}

# =============================================
# AGENT -> TIER ASSIGNMENT
# =============================================
AGENT_TIERS = {
    # ORCHESTRATOR - needs strong reasoning
    "main": TIER_STRONG,

    # STRATEGIC / REASONING - strong model
    "cto": TIER_STRONG,
    "researcher": TIER_STRONG,
    "planner": TIER_STRONG,
    "repo-architect": TIER_STRONG,
    "queen-coordinator": TIER_STRONG,
    "openclaw-expert": TIER_STRONG,

    # CODE & REVIEW - medium (balanced)
    "coder": TIER_MEDIUM,
    "reviewer": TIER_MEDIUM,
    "tester": TIER_MEDIUM,
    "pr-manager": TIER_MEDIUM,
    "security": TIER_MEDIUM,
    "release-manager": TIER_MEDIUM,

    # OPS / INFRA - medium
    "devops": TIER_MEDIUM,
    "infra-manager": TIER_MEDIUM,
    "sre-team": TIER_MEDIUM,
    "infra": TIER_MEDIUM,
    "storage": TIER_MEDIUM,
    "harbor": TIER_MEDIUM,
    "net": TIER_MEDIUM,

    # SWARM WORKERS - fast (high volume, simple tasks)
    "collective-intelligence": TIER_FAST,
    "scout-explorer": TIER_FAST,
    "worker-specialist": TIER_FAST,
    "swarm-memory-manager": TIER_FAST,
    "sync-coordinator": TIER_FAST,

    # REPO SCRAPERS - fast
    "scr-agl-hostman": TIER_FAST,
    "scr-api8": TIER_FAST,
    "scr-api9": TIER_FAST,
    "scr-aldsys8": TIER_FAST,
    "scr-ald-sys7": TIER_FAST,
    "scr-crowbar": TIER_FAST,
    "scr-fg-antigo": TIER_FAST,
    "scr-crowbar-demo": TIER_FAST,

    # PERSONAS - creative (need personality + reasoning)
    "musk": TIER_CREATIVE,
    "bezos": TIER_CREATIVE,
    "gates": TIER_CREATIVE,
    "altman": TIER_CREATIVE,
    "pichai": TIER_CREATIVE,
    "hassabis": TIER_CREATIVE,
    "nadella": TIER_CREATIVE,
    "hinton": TIER_CREATIVE,
    "karpathy": TIER_CREATIVE,
    "li": TIER_CREATIVE,
    "norvig": TIER_CREATIVE,
    "ogilvy": TIER_CREATIVE,
    "dean": TIER_CREATIVE,
    "cheskin": TIER_CREATIVE,
}

# =============================================
# APPLY CHANGES
# =============================================
changes = 0

for agent in cfg["agents"]["list"]:
    aid = agent["id"]

    # 1. Apply model tier
    if aid in AGENT_TIERS:
        tier = AGENT_TIERS[aid]
        old_model = agent.get("model", {})
        agent["model"] = dict(tier)  # deep copy
        if old_model != agent["model"]:
            changes += 1

    # 2. Fix workspace collision: infra-manager
    if aid == "infra-manager" and agent.get("workspace", "").endswith("workspace-sre"):
        agent["workspace"] = "~/.openclaw/workspace-infra-manager"
        changes += 1
        print(f"  Fixed workspace: infra-manager -> workspace-infra-manager")

    # 3. Add groupChat mentionPatterns for ops agents
    if aid in ["infra", "storage", "harbor", "net", "security", "devops", "sre-team"]:
        if "groupChat" not in agent:
            patterns = {
                "infra": ["@infra", "\\binfra\\b"],
                "storage": ["@storage", "\\bstorage\\b", "\\bpool\\b", "\\bzfs\\b"],
                "harbor": ["@harbor", "\\bregistry\\b", "\\bharbor\\b"],
                "net": ["@net", "\\bwg\\b", "\\btailscale\\b"],
                "security": ["@security", "\\bsecurity\\b", "\\baudit\\b"],
                "devops": ["@devops", "\\bdevops\\b", "\\bdeploy\\b", "\\bci\\b"],
                "sre-team": ["@sre", "\\bsre\\b", "\\bmonitoring\\b"],
            }
            if aid in patterns:
                agent["groupChat"] = {"mentionPatterns": patterns[aid]}
                changes += 1

# 4. Activate orphan agents in main's allowAgents
main_agent = next(a for a in cfg["agents"]["list"] if a["id"] == "main")
current_allowed = set(main_agent.get("subagents", {}).get("allowAgents", []))
all_agent_ids = {a["id"] for a in cfg["agents"]["list"] if a["id"] != "main"}

orphans = all_agent_ids - current_allowed
if orphans:
    main_agent["subagents"]["allowAgents"] = sorted(all_agent_ids)
    changes += 1
    print(f"  Activated {len(orphans)} orphan agents: {sorted(orphans)}")

# 5. Update defaults to match the strong tier
cfg["agents"]["defaults"]["model"] = dict(TIER_STRONG)

# =============================================
# WRITE & REPORT
# =============================================
with open(PATH, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(f"\n{'='*60}")
print(f"Changes applied: {changes}")
print(f"{'='*60}")

# Report tier distribution
tier_counts = {"STRONG": 0, "MEDIUM": 0, "FAST": 0, "CREATIVE": 0, "DEFAULT": 0}
for agent in cfg["agents"]["list"]:
    aid = agent["id"]
    m = agent.get("model", {})
    if isinstance(m, dict):
        p = m.get("primary", "")
        if p == TIER_STRONG["primary"]:
            tier_counts["STRONG"] += 1
        elif p == TIER_MEDIUM["primary"]:
            tier_counts["MEDIUM"] += 1
        elif p == TIER_FAST["primary"]:
            tier_counts["FAST"] += 1
        elif p == TIER_CREATIVE["primary"]:
            tier_counts["CREATIVE"] += 1
        else:
            tier_counts["DEFAULT"] += 1

print(f"\nModel tiers:")
for tier, count in tier_counts.items():
    print(f"  {tier}: {count} agents")

# Verify all agents have fallbacks
no_fb = [a["id"] for a in cfg["agents"]["list"]
         if isinstance(a.get("model"), dict) and not a["model"].get("fallbacks")]
print(f"\nAgents without fallbacks: {len(no_fb)}")
if no_fb:
    print(f"  {no_fb}")

# Verify main's allowAgents covers all
allowed = set(main_agent.get("subagents", {}).get("allowAgents", []))
missing = all_agent_ids - allowed
print(f"\nMain allowAgents: {len(allowed)}/{len(all_agent_ids)}")
if missing:
    print(f"  Still missing: {missing}")
else:
    print("  All agents reachable from main")
