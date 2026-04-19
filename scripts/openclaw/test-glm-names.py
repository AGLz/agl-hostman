#!/usr/bin/env python3
"""Test ZAI models with the correct config model_name (no prefix)."""
import urllib.request, json, time

URL = "http://localhost:4000/v1/chat/completions"
KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"

# These are the model_name values from config.yaml
MODELS = [
    "glm-5", "glm-4.7-flash", "glm-4.7", "glm-flash", "glm",
    "glm-air", "glm-4.5-flash", "agl-primary-zai-glm-flash",
    "infra-agent", "cursor-glm-5",
    # Working controls
    "agl-primary", "qwen3.5-flash",
]

for m in MODELS:
    payload = json.dumps({"model": m, "messages": [{"role": "user", "content": "Say OK"}], "max_tokens": 10}).encode()
    req = urllib.request.Request(URL, data=payload)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {KEY}")
    t = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        c = data["choices"][0]["message"]["content"] if data.get("choices") else "empty"
        print(f"  PASS  {m:35s}  {int((time.time()-t)*1000):5d}ms  {c[:25]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:100]
        print(f"  FAIL  {m:35s}  {int((time.time()-t)*1000):5d}ms  HTTP {e.code}: {body}")
    except Exception as e:
        print(f"  FAIL  {m:35s}  {int((time.time()-t)*1000):5d}ms  {e}")
