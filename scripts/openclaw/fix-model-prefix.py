#!/usr/bin/env python3
"""Add openai/ prefix to all model names since we only have openai provider."""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    cfg = json.load(f)

def prefix_model(name):
    if not name:
        return name
    # Already has openai/ prefix
    if name.startswith("openai/"):
        return name
    # Has another known prefix (openrouter/, google/) - keep as-is but prepend openai/
    # Actually all go through the openai provider, so prefix all
    return f"openai/{name}"

# Fix defaults
defaults = cfg["agents"]["defaults"]
defaults["model"]["primary"] = prefix_model(defaults["model"]["primary"])
defaults["model"]["fallbacks"] = [prefix_model(f) for f in defaults["model"]["fallbacks"]]

# Fix imageModel
if isinstance(defaults.get("imageModel"), dict):
    defaults["imageModel"]["primary"] = prefix_model(defaults["imageModel"]["primary"])
    defaults["imageModel"]["fallbacks"] = [prefix_model(f) for f in defaults["imageModel"].get("fallbacks", [])]
elif isinstance(defaults.get("imageModel"), str):
    defaults["imageModel"] = prefix_model(defaults["imageModel"])

# Fix compaction model
if "compaction" in defaults and "model" in defaults.get("compaction", {}):
    defaults["compaction"]["model"] = prefix_model(defaults["compaction"]["model"])

# Fix model aliases
new_models = {}
for key, val in defaults.get("models", {}).items():
    new_models[prefix_model(key)] = val
defaults["models"] = new_models

# Fix per-agent models
for agent in cfg["agents"].get("list", []):
    if "model" in agent:
        m = agent["model"]
        if isinstance(m, dict):
            m["primary"] = prefix_model(m["primary"])
            if "fallbacks" in m:
                m["fallbacks"] = [prefix_model(f) for f in m["fallbacks"]]
        elif isinstance(m, str):
            agent["model"] = prefix_model(m)

with open(PATH, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(f"Primary: {defaults['model']['primary']}")
print(f"Fallbacks: {defaults['model']['fallbacks']}")
print(f"Aliases: {list(defaults.get('models', {}).keys())[:5]}...")
