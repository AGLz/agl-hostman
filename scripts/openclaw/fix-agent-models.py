#!/usr/bin/env python3
"""Fix remaining openai/ prefix in per-agent models and clean up."""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    cfg = json.load(f)

# Fix per-agent models: openai/X -> X (LiteLLM names)
PREFIX_MAP = {
    "openai/qwen3.5-flash": "qwen3.5-flash",
    "openai/qwen-flash": "qwen-flash",
    "openai/qwen3.5-plus": "qwen3.5-plus",
}

fixed = 0
for agent in cfg["agents"].get("list", []):
    if "model" in agent:
        m = agent["model"]
        if isinstance(m, dict):
            if m["primary"] in PREFIX_MAP:
                m["primary"] = PREFIX_MAP[m["primary"]]
                fixed += 1
            if "fallbacks" in m:
                m["fallbacks"] = [PREFIX_MAP.get(f, f) for f in m["fallbacks"]]
        elif isinstance(m, str) and m in PREFIX_MAP:
            agent["model"] = PREFIX_MAP[m]
            fixed += 1

# Also fix defaults imageModel if it has openai/ prefix
defaults = cfg["agents"]["defaults"]
if isinstance(defaults.get("imageModel"), str) and defaults["imageModel"] in PREFIX_MAP:
    defaults["imageModel"] = PREFIX_MAP[defaults["imageModel"]]

with open(PATH, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(f"Fixed {fixed} agent model references")
print(f"Default primary: {defaults['model']['primary']}")
print(f"Default imageModel: {defaults.get('imageModel')}")
# Show unique per-agent models
unique = set()
for agent in cfg["agents"].get("list", []):
    if "model" in agent:
        m = agent["model"]
        if isinstance(m, dict):
            unique.add(m["primary"])
        else:
            unique.add(m)
print(f"Unique per-agent models: {unique}")
