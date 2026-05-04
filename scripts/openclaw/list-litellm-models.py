#!/usr/bin/env python3
"""List LiteLLM models."""
import json
import os
import urllib.request

litellm_url = os.environ.get("LITELLM_GATEWAY_URL", "http://100.125.249.8:4000")
litellm_key = os.environ.get("LITELLM_MASTER_KEY", "")

req = urllib.request.Request(f"{litellm_url}/v1/models")
if litellm_key:
    req.add_header("Authorization", f"Bearer {litellm_key}")
resp = urllib.request.urlopen(req, timeout=10)
data = json.loads(resp.read())
for m in sorted(data.get("data", []), key=lambda x: x["id"]):
    print(m["id"])
