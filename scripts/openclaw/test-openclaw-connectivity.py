#!/usr/bin/env python3
"""Test LiteLLM models and OpenClaw gateway connectivity."""
import urllib.request
import json
import sys

LITELLM_URL = "http://localhost:4000"
LITELLM_KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"
GATEWAY_URL = "http://localhost:28789"
GATEWAY_TOKEN = "5b3f1c9612b577ae6117de9b72597c63d1692d57ad5d8bc0"

def test_litellm_health():
    try:
        req = urllib.request.Request(f"{LITELLM_URL}/health/liveliness")
        resp = urllib.request.urlopen(req, timeout=5)
        print(f"LiteLLM health: {resp.read().decode()}")
        return True
    except Exception as e:
        print(f"LiteLLM health FAIL: {e}")
        return False

def test_litellm_models():
    try:
        req = urllib.request.Request(f"{LITELLM_URL}/v1/models")
        req.add_header("Authorization", f"Bearer {LITELLM_KEY}")
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        models = [m["id"] for m in data.get("data", [])]
        print(f"LiteLLM models ({len(models)}): {models[:10]}...")
        return models
    except Exception as e:
        print(f"LiteLLM models FAIL: {e}")
        return []

def test_litellm_chat(model="zai/glm-5"):
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
        print(f"LiteLLM chat ({model}): OK - response: {content[:50]}")
        return True
    except Exception as e:
        print(f"LiteLLM chat ({model}): FAIL - {e}")
        return False

def test_gateway_health():
    try:
        req = urllib.request.Request(f"{GATEWAY_URL}/healthz")
        resp = urllib.request.urlopen(req, timeout=5)
        data = json.loads(resp.read())
        print(f"Gateway health: {data}")
        return data.get("ok", False)
    except Exception as e:
        print(f"Gateway health FAIL: {e}")
        return False

print("=" * 50)
print("OpenClaw + LiteLLM Connectivity Tests")
print("=" * 50)

results = {}

print("\n--- 1. Gateway Health ---")
results["gateway_health"] = test_gateway_health()

print("\n--- 2. LiteLLM Health ---")
results["litellm_health"] = test_litellm_health()

print("\n--- 3. LiteLLM Models ---")
models = test_litellm_models()
results["litellm_models"] = len(models) > 0

print("\n--- 4. LiteLLM Chat (zai/glm-5) ---")
results["chat_glm5"] = test_litellm_chat("zai/glm-5")

print("\n--- 5. LiteLLM Chat (deepseek/deepseek-chat) ---")
results["chat_deepseek"] = test_litellm_chat("deepseek/deepseek-chat")

print("\n--- 6. LiteLLM Chat (openrouter/z-ai/glm-4.5-air:free) ---")
results["chat_openrouter"] = test_litellm_chat("openrouter/z-ai/glm-4.5-air:free")

print("\n" + "=" * 50)
print("RESULTS SUMMARY")
print("=" * 50)
for k, v in results.items():
    status = "PASS" if v else "FAIL"
    print(f"  {k}: {status}")

failed = [k for k, v in results.items() if not v]
if failed:
    print(f"\nFAILED: {', '.join(failed)}")
    sys.exit(1)
else:
    print("\nALL TESTS PASSED")
