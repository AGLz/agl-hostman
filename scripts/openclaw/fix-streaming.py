#!/usr/bin/env python3
"""
Fix OpenClaw config compatibility issues for container version 2026.3.27.
- streaming: true (not "partial" object)
- Remove stale streamMode field
- Add gateway.controlUi for non-loopback binding
- Remove stale qwen-portal-auth plugin
- Fix meta version to match container
"""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    d = json.load(f)

# 1. Fix streaming - version 2026.3.27 wants bool or simple string
d["channels"]["telegram"]["streaming"] = True
# Remove legacy streamMode if present
d["channels"]["telegram"].pop("streamMode", None)

# 2. Fix gateway - add controlUi for non-loopback
d["gateway"]["controlUi"] = {
    "dangerouslyAllowHostHeaderOriginFallback": True
}

# 3. Remove stale plugin
d["plugins"]["entries"].pop("qwen-portal-auth", None)

# 4. Fix meta version to match container
d["meta"]["lastTouchedVersion"] = "2026.3.27"

with open(PATH, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)

print("=== Fixes applied ===")
print(f"streaming: {d['channels']['telegram']['streaming']}")
print(f"controlUi: {d['gateway'].get('controlUi')}")
print(f"plugins: {list(d['plugins']['entries'].keys())}")
print(f"meta version: {d['meta']['lastTouchedVersion']}")
