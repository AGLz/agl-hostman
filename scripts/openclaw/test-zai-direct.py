#!/usr/bin/env python3
"""Test ZAI API directly and via LiteLLM to isolate the issue."""
import urllib.request
import json
import os
import time

# Read ZAI key from env file
with open("/opt/litellm/.env") as f:
    for line in f:
        if line.startswith("ZAI_API_KEY="):
            ZAI_KEY = line.strip().split("=", 1)[1]
            break

print(f"ZAI Key: {ZAI_KEY[:8]}...{ZAI_KEY[-4:]}")

# Test 1: Direct ZAI API call (Anthropic format)
print("\n--- Test 1: Direct ZAI API (Anthropic messages format) ---")
payload = json.dumps({
    "model": "glm-4.7-flash",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "say ok"}]
}).encode()

req = urllib.request.Request("https://api.z.ai/api/anthropic/v1/messages", data=payload)
req.add_header("Content-Type", "application/json")
req.add_header("x-api-key", ZAI_KEY)
req.add_header("anthropic-version", "2023-06-01")

t = time.time()
try:
    resp = urllib.request.urlopen(req, timeout=30)
    data = json.loads(resp.read())
    lat = int((time.time() - t) * 1000)
    print(f"  PASS: {lat}ms - {json.dumps(data)[:150]}")
except urllib.error.HTTPError as e:
    body = e.read().decode()[:200]
    lat = int((time.time() - t) * 1000)
    print(f"  FAIL: HTTP {e.code} {lat}ms - {body}")
except Exception as e:
    lat = int((time.time() - t) * 1000)
    print(f"  FAIL: {lat}ms - {e}")

# Test 2: Direct ZAI API (OpenAI format)
print("\n--- Test 2: Direct ZAI API (OpenAI completions format) ---")
payload2 = json.dumps({
    "model": "glm-4.7-flash",
    "messages": [{"role": "user", "content": "say ok"}],
    "max_tokens": 10
}).encode()

req2 = urllib.request.Request("https://api.z.ai/api/openai/v1/chat/completions", data=payload2)
req2.add_header("Content-Type", "application/json")
req2.add_header("Authorization", f"Bearer {ZAI_KEY}")

t = time.time()
try:
    resp = urllib.request.urlopen(req2, timeout=30)
    data = json.loads(resp.read())
    lat = int((time.time() - t) * 1000)
    c = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    print(f"  PASS: {lat}ms - {c[:50]}")
except urllib.error.HTTPError as e:
    body = e.read().decode()[:200]
    lat = int((time.time() - t) * 1000)
    print(f"  FAIL: HTTP {e.code} {lat}ms - {body}")
except Exception as e:
    lat = int((time.time() - t) * 1000)
    print(f"  FAIL: {lat}ms - {e}")

# Test 3: Check LiteLLM health for ZAI models
print("\n--- Test 3: LiteLLM health check ---")
LITELLM_KEY = "${LITELLM_MASTER_KEY}"
req3 = urllib.request.Request("http://localhost:4000/health")
req3.add_header("Authorization", f"Bearer {LITELLM_KEY}")
try:
    resp = urllib.request.urlopen(req3, timeout=30)
    data = json.loads(resp.read())
    healthy = data.get("healthy_count", 0)
    unhealthy = data.get("unhealthy_count", 0)
    print(f"  Healthy: {healthy}, Unhealthy: {unhealthy}")
    for m in data.get("unhealthy_models", [])[:10]:
        print(f"  UNHEALTHY: {m}")
except Exception as e:
    print(f"  FAIL: {e}")
