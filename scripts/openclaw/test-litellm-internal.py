#!/usr/bin/env python3
"""Check LiteLLM internal model info and diagnose ZAI issue."""
import urllib.request, json

URL = "http://localhost:4000"
KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"

# 1. Check /model/info
req = urllib.request.Request(f"{URL}/model/info")
req.add_header("Authorization", f"Bearer {KEY}")
try:
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read())
    if isinstance(data, dict) and "data" in data:
        models = data["data"]
        print(f"Total models in /model/info: {len(models)}")
        zai = [m for m in models if "glm" in str(m.get("model_name","")).lower()]
        print(f"GLM models found: {len(zai)}")
        for m in zai:
            mn = m.get("model_name", "?")
            lp = m.get("litellm_params", {})
            model = lp.get("model", "?")
            base = lp.get("api_base", "default")
            print(f"  {mn}: model={model} base={base}")
    else:
        print(f"Error: {str(data)[:200]}")
except Exception as e:
    print(f"/model/info FAIL: {e}")

# 2. Check /health
print("\n--- /health ---")
req = urllib.request.Request(f"{URL}/health")
req.add_header("Authorization", f"Bearer {KEY}")
try:
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read())
    unhealthy = [m for m in data.get("unhealthy_models", []) if "glm" in str(m).lower()]
    healthy = [m for m in data.get("healthy_endpoints", []) if "glm" in str(m.get("model","")).lower()]
    print(f"Healthy GLM endpoints: {len(healthy)}")
    print(f"Unhealthy GLM models: {len(unhealthy)}")
    for m in unhealthy:
        print(f"  UNHEALTHY: {m}")
    for m in healthy[:5]:
        print(f"  HEALTHY: {m.get('model')}")
except urllib.error.HTTPError as e:
    body = e.read().decode()[:200]
    print(f"/health FAIL: HTTP {e.code}: {body}")
except Exception as e:
    print(f"/health FAIL: {e}")

# 3. Check /model/metrics
print("\n--- Recent model usage ---")
req = urllib.request.Request(f"{URL}/model/metrics")
req.add_header("Authorization", f"Bearer {KEY}")
try:
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read())
    if isinstance(data, list):
        for m in data[:10]:
            print(f"  {m}")
    else:
        print(f"Metrics: {str(data)[:200]}")
except Exception as e:
    print(f"/model/metrics: {e}")
