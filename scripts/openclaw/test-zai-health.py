#!/usr/bin/env python3
"""Diagnose why ZAI models get removed - test API endpoints LiteLLM uses for health."""
import urllib.request, json, subprocess

# Get ZAI key
result = subprocess.run(["grep", "ZAI_API_KEY", "/opt/litellm/.env"], capture_output=True, text=True)
ZAI_KEY = result.stdout.strip().split("=", 1)[1]

# Test endpoints LiteLLM might use for health checks
TESTS = [
    ("ZAI OpenAI /models", "https://api.z.ai/api/openai/v1/models", f"Bearer {ZAI_KEY}"),
    ("ZAI OpenAI /chat", "https://api.z.ai/api/openai/v1/chat/completions", f"Bearer {ZAI_KEY}"),
    ("DashScope /models", "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models", None),
]

for label, url, auth in TESTS:
    req = urllib.request.Request(url)
    req.add_header("Content-Type", "application/json")
    if auth:
        req.add_header("Authorization", auth)
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        body = resp.read().decode()[:100]
        print(f"  {label}: HTTP {resp.status} - {body}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:100]
        print(f"  {label}: HTTP {e.code} - {body}")
    except Exception as e:
        print(f"  {label}: {e}")

# Check if there's a cooldown or model group issue
print("\n--- LiteLLM model groups ---")
req = urllib.request.Request("http://localhost:4000/model/info")
req.add_header("Authorization", "Bearer sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0")
resp = urllib.request.urlopen(req, timeout=10)
data = json.loads(resp.read())
models = data.get("data", [])
# Show model details for working models to compare
for m in models:
    name = m.get("model_name", "")
    if name in ["qwen-turbo", "agl-primary", "deepseek"]:
        info = m.get("model_info", {})
        lp = m.get("litellm_params", {})
        print(f"\n  {name}:")
        print(f"    model: {lp.get('model')}")
        print(f"    api_base: {lp.get('api_base', 'default')}")
        print(f"    mode: {info.get('mode', 'N/A')}")
        print(f"    id: {info.get('id', 'N/A')}")
