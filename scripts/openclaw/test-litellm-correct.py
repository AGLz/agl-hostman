#!/usr/bin/env python3
"""Test LiteLLM models with correct names."""
import urllib.request
import json

LITELLM_URL = "http://localhost:4000"
LITELLM_KEY = "${LITELLM_MASTER_KEY}"

# Test only models that should work (correct LiteLLM names)
MODELS = [
    "agl-primary",
    "qwen3.5-flash",
    "qwen-plus",
    "deepseek",
    "or-glm-air-free",
    "claude-sonnet-4-6",
    "gemini-lite",
    "qwen-coder",
    "ollama-nemotron-3-nano-4b",
]

passed = 0
failed = 0
for model in MODELS:
    try:
        payload = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": "Say OK"}],
            "max_tokens": 10
        }).encode()
        req = urllib.request.Request(f"{LITELLM_URL}/v1/chat/completions", data=payload)
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {LITELLM_KEY}")
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        content = data["choices"][0]["message"]["content"]
        print(f"  PASS  {model}: {content[:40]}")
        passed += 1
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:150]
        print(f"  FAIL  {model}: HTTP {e.code} - {body}")
        failed += 1
    except Exception as e:
        print(f"  FAIL  {model}: {type(e).__name__}: {str(e)[:100]}")
        failed += 1

print(f"\nResults: {passed} passed, {failed} failed out of {len(MODELS)}")
