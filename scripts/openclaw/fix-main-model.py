#!/usr/bin/env python3
"""
Fix main agent model: agl-primary (Ollama) is unreliable for cold starts.
Change STRONG tier primary to qwen-plus (reliable, 4s) and keep agl-primary as fallback.
"""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    cfg = json.load(f)

# New STRONG tier: qwen-plus primary (reliable 4s), agl-primary as fallback
TIER_STRONG_FIXED = {
    "primary": "openai/qwen-plus",
    "fallbacks": [
        "openai/claude-sonnet-4-6",
        "openai/deepseek",
        "openai/agl-primary",
        "openai/qwen-coder",
        "openai/kimi",
        "openai/gpt",
        "openai/gemini-lite"
    ]
}

STRONG_AGENTS = ["main", "cto", "researcher", "planner", "repo-architect", "queen-coordinator", "openclaw-expert"]

for agent in cfg["agents"]["list"]:
    if agent["id"] in STRONG_AGENTS:
        agent["model"] = dict(TIER_STRONG_FIXED)

# Also update defaults
cfg["agents"]["defaults"]["model"] = dict(TIER_STRONG_FIXED)

with open(PATH, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(f"Fixed STRONG tier: primary={TIER_STRONG_FIXED['primary']}")
print(f"Agents updated: {STRONG_AGENTS}")
print(f"Fallbacks: {TIER_STRONG_FIXED['fallbacks']}")
