#!/usr/bin/env python3
"""Disable memory embeddings or switch to working model."""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    cfg = json.load(f)

# Option 1: Disable memory embeddings by setting to empty/null
# Option 2: Change to a working embedding model

# Check if there's an embeddings config
if "embeddings" not in cfg:
    cfg["embeddings"] = {}

# Disable memory search embeddings (will fall back to keyword search)
cfg["embeddings"]["enabled"] = False

# Or configure to use a local/no-op embedding
# cfg["embeddings"]["provider"] = "none"

with open(PATH, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("Disabled embeddings (memory will use keyword search only)")
print("This removes the text-embedding-3-small dependency")
