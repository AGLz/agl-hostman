#!/usr/bin/env python3
"""Enable HTTP chat endpoint in OpenClaw config and prepare for testing."""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    cfg = json.load(f)

# Enable HTTP endpoints for testing
if "http" not in cfg.get("gateway", {}):
    cfg["gateway"]["http"] = {}

cfg["gateway"]["http"]["endpoints"] = {
    "chatCompletions": {"enabled": True}
}

with open(PATH, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("Enabled gateway.http.endpoints.chatCompletions")
print(f"Gateway config: {json.dumps(cfg['gateway'], indent=2)}")
