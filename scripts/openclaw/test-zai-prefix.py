#!/usr/bin/env python3
"""Test ZAI models with zai/ prefix and check Ollama + Gemini issues."""
import urllib.request
import json
import time

LITELLM_URL = "http://localhost:4000"
LITELLM_KEY = "${LITELLM_MASTER_KEY}"

TESTS = [
    # ZAI with prefix
    "zai/glm-5",
    "zai/glm-4.7-flash",
    "zai/glm-4.7",
    "zai/glm-4.5-flash",
    # Ollama - check which models are pulled
    "agl-primary",
    # Quick re-test of qwen3.5-flash and or-glm-air-free
    "qwen3.5-flash",
    "or-glm-air-free",
]

for model in TESTS:
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": "Say OK"}],
        "max_tokens": 10
    }).encode()
    start = time.time()
    try:
        req = urllib.request.Request(f"{LITELLM_URL}/v1/chat/completions", data=payload)
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {LITELLM_KEY}")
        resp = urllib.request.urlopen(req, timeout=30)
        lat = int((time.time() - start) * 1000)
        data = json.loads(resp.read())
        c = data["choices"][0]["message"]["content"] if data.get("choices") else "empty"
        print(f"  PASS  {model:35s}  {lat:5d}ms  {c[:30]}")
    except urllib.error.HTTPError as e:
        lat = int((time.time() - start) * 1000)
        body = e.read().decode()[:120]
        print(f"  FAIL  {model:35s}  {lat:5d}ms  HTTP {e.code}: {body}")
    except Exception as e:
        lat = int((time.time() - start) * 1000)
        print(f"  FAIL  {model:35s}  {lat:5d}ms  {type(e).__name__}: {e}")
