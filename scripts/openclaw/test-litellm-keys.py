#!/usr/bin/env python3
"""Check LiteLLM key access and model availability."""
import urllib.request
import json
import subprocess

# Get master key
result = subprocess.run(["grep", "LITELLM_MASTER_KEY", "/opt/litellm/.env"],
                       capture_output=True, text=True)
MASTER_KEY = result.stdout.strip().split("=", 1)[1] if result.returncode == 0 else ""
API_KEY = "${LITELLM_MASTER_KEY}"

def get_models(key, label):
    req = urllib.request.Request("http://localhost:4000/v1/models")
    req.add_header("Authorization", f"Bearer {key}")
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        models = [m["id"] for m in data.get("data", [])]
        print(f"\n{label}: {len(models)} models")
        glm = [m for m in models if "glm" in m.lower()]
        print(f"  GLM models: {glm}")
        return models
    except Exception as e:
        print(f"\n{label}: FAIL - {e}")
        return []

def test_chat(key, model, label):
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": "Say OK"}],
        "max_tokens": 10
    }).encode()
    req = urllib.request.Request("http://localhost:4000/v1/chat/completions", data=payload)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {key}")
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        c = data["choices"][0]["message"]["content"]
        print(f"  PASS {label} -> {model}: {c[:20]}")
        return True
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:100]
        print(f"  FAIL {label} -> {model}: HTTP {e.code} {body}")
        return False

print("=" * 60)
print("LiteLLM Key & Model Access Diagnostic")
print("=" * 60)

print(f"\nAPI Key: {API_KEY[:20]}...")
print(f"Master Key: {MASTER_KEY[:20]}...")
print(f"Keys match: {API_KEY == MASTER_KEY}")

api_models = get_models(API_KEY, "API Key")
master_models = get_models(MASTER_KEY, "Master Key")

# Check difference
if api_models and master_models:
    only_master = set(master_models) - set(api_models)
    only_api = set(api_models) - set(master_models)
    if only_master:
        print(f"\n  Only in Master Key ({len(only_master)}): {sorted(only_master)[:10]}")
    if only_api:
        print(f"\n  Only in API Key ({len(only_api)}): {sorted(only_api)[:10]}")

# Test ZAI models with master key
print("\n--- Test ZAI models with Master Key ---")
for m in ["glm-5", "glm-4.7-flash", "zai/glm-5", "zai/glm-4.7-flash"]:
    test_chat(MASTER_KEY, m, "master")

print("\n--- Test ZAI models with API Key ---")
for m in ["glm-5", "glm-4.7-flash"]:
    test_chat(API_KEY, m, "api")

# Check Ollama
print("\n--- Ollama status ---")
try:
    req = urllib.request.Request("http://192.168.0.200:11434/api/tags")
    resp = urllib.request.urlopen(req, timeout=5)
    data = json.loads(resp.read())
    models = [m["name"] for m in data.get("models", [])]
    print(f"  Ollama models on CT200: {models}")
except Exception as e:
    print(f"  Ollama FAIL: {e}")
