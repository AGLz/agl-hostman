#!/usr/bin/env python3
import json
from pathlib import Path

p = Path("/root/.openclaw/agents/main/agent/models.json")
d = json.loads(p.read_text(encoding="utf-8"))
o = d.get("providers", {}).get("openai", {})
print("openai keys:", sorted(o.keys()))
print("apiKey repr:", repr(o.get("apiKey")))
