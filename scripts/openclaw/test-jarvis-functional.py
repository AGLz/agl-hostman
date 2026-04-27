#!/usr/bin/env python3
"""
Functional tests for OpenClaw Jarvis (main agent).
Tests: basic response, tool use, subagent delegation, self-awareness.
Uses the OpenAI-compatible /v1/chat/completions endpoint.
"""
import urllib.request
import json
import time
import sys

GATEWAY_URL = "http://localhost:28789"
GATEWAY_TOKEN = "5b3f1c9612b577ae6117de9b72597c63d1692d57ad5d8bc0"

def chat(message, agent_id="main", timeout=120):
    """Send a message to an agent and get the response."""
    payload = json.dumps({
        "model": f"openclaw/{agent_id}",
        "messages": [{"role": "user", "content": message}],
        "stream": False,
        "max_tokens": 500
    }).encode()
    
    req = urllib.request.Request(f"{GATEWAY_URL}/v1/chat/completions", data=payload)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {GATEWAY_TOKEN}")
    req.add_header("x-openclaw-agent-id", agent_id)
    
    start = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        data = json.loads(resp.read())
        elapsed = int((time.time() - start) * 1000)
        
        if "choices" in data and len(data["choices"]) > 0:
            content = data["choices"][0]["message"]["content"]
            usage = data.get("usage", {})
            return True, elapsed, content, usage
        elif "error" in data:
            return False, elapsed, data["error"].get("message", str(data["error"])), {}
        else:
            return False, elapsed, f"Unexpected response: {str(data)[:100]}", {}
    except urllib.error.HTTPError as e:
        elapsed = int((time.time() - start) * 1000)
        body = e.read().decode()[:200]
        return False, elapsed, f"HTTP {e.code}: {body}", {}
    except Exception as e:
        elapsed = int((time.time() - start) * 1000)
        return False, elapsed, f"{type(e).__name__}: {str(e)[:100]}", {}

print("=" * 70)
print("  JARVIS (main) FUNCTIONAL TESTS")
print("=" * 70)

tests = []

# =============================================
# TEST 1: Basic response
# =============================================
print("\n--- TEST 1: Basic Response ---")
ok, lat, resp, usage = chat("Responde apenas com 'Jarvis operacional' se consegues processar este pedido.")
status = "PASS" if ok else "FAIL"
tests.append(("Basic Response", ok, lat))
print(f"  {status} ({lat}ms)")
if ok:
    print(f"  Response: {resp[:100]}")
    print(f"  Tokens: {usage}")
else:
    print(f"  Error: {resp[:150]}")

# =============================================
# TEST 2: Self-awareness (knows its config)
# =============================================
print("\n--- TEST 2: Self-Awareness ---")
ok, lat, resp, usage = chat("Qual e o teu modelo primario? E quantos agentes tens disponiveis como subagentes? Responde de forma concisa.")
status = "PASS" if ok else "FAIL"
tests.append(("Self-Awareness", ok, lat))
print(f"  {status} ({lat}ms)")
if ok:
    print(f"  Response: {resp[:200]}")

# =============================================
# TEST 3: Tool use - list files
# =============================================
print("\n--- TEST 3: Tool Use (workspace) ---")
ok, lat, resp, usage = chat("Lista os ficheiros no teu workspace principal (ls ~/.openclaw/workspace/). Mostra apenas os nomes dos ficheiros .md")
status = "PASS" if ok else "FAIL"
tests.append(("Tool Use", ok, lat))
print(f"  {status} ({lat}ms)")
if ok:
    print(f"  Response: {resp[:200]}")

# =============================================
# TEST 4: Infrastructure knowledge
# =============================================
print("\n--- TEST 4: Infrastructure Knowledge ---")
ok, lat, resp, usage = chat("Qual e o IP Tailscale do AGLSRV1? E qual container corre o LiteLLM? Responde de forma directa.")
status = "PASS" if ok else "FAIL"
tests.append(("Infra Knowledge", ok, lat))
print(f"  {status} ({lat}ms)")
if ok:
    print(f"  Response: {resp[:200]}")

# =============================================
# TEST 5: Cron status
# =============================================
print("\n--- TEST 5: Cron Status ---")
ok, lat, resp, usage = chat("Mostra o status dos teus cron jobs. Quantos tens activos e algum com erros?")
status = "PASS" if ok else "FAIL"
tests.append(("Cron Status", ok, lat))
print(f"  {status} ({lat}ms)")
if ok:
    print(f"  Response: {resp[:300]}")

# =============================================
# SUMMARY
# =============================================
print("\n" + "=" * 70)
print("  SUMMARY")
print("=" * 70)
passed = sum(1 for _, ok, _ in tests if ok)
failed = sum(1 for _, ok, _ in tests if not ok)
for name, ok, lat in tests:
    status = "PASS" if ok else "FAIL"
    print(f"  {status}  {name:<25}  {lat:6d}ms")

print(f"\n  Result: {passed}/{len(tests)} passed")
if failed > 0:
    print(f"  Failed: {failed}")
