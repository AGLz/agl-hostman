#!/usr/bin/env python3
"""Check OpenClaw Telegram config."""
import json
d = json.load(open("/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"))
tg = d.get("channels", {}).get("telegram", {})
print(json.dumps(tg, indent=2))
