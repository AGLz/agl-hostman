#!/usr/bin/env python3
"""Test models that appeared in LiteLLM startup log but fail on API."""
import urllib.request, json, time

URL = "http://localhost:4000/v1/chat/completions"
KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"

# Models from startup log that should work
MODELS = [
    "agl-primary-zai-glm-flash",
    "infra-agent", 
    "cursor-glm-5",
    "or-glm-4.5-air-free",
    "or-glm-air-free",  # from test-all
    # Try with different provider routing
    "anthropic/glm-5",  # exact litellm_params.model
    "anthropic/glm-4.7-flash",
]

for m in MODELS:
    payload = json.dumps({
        "model": m,
        "messages": [{"role": "user", "content": "Say OK"}],
        "max_tokens": 10
    }).encode()
    req = urllib.request.Request(URL, data=payload)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {KEY}")
    t = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        c = data["choices"][0]["message"]["content"] if data.get("choices") else "empty"
        lat = int((time.time() - t) * 1000)
        print(f"  PASS  {m:40s}  {lat:5d}ms  {c[:25]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:80]
        lat = int((time.time() - t) * 1000)
        print(f"  FAIL  {m:40s}  {lat:5d}ms  HTTP {e.code}: {body}")
    except Exception as e:
        lat = int((time.time() - t) * 1000)
        print(f"  FAIL  {m:40s}  {lat:5d}ms  {e}")
