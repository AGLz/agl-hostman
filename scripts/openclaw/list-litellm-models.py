#!/usr/bin/env python3
"""List LiteLLM models."""
import urllib.request, json
req = urllib.request.Request("http://localhost:4000/v1/models")
req.add_header("Authorization", "Bearer sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0")
resp = urllib.request.urlopen(req, timeout=10)
data = json.loads(resp.read())
for m in sorted(data.get("data", []), key=lambda x: x["id"]):
    print(m["id"])
