#!/usr/bin/env python3
"""
Test OpenClaw via HTTP API simulating Telegram-like queries.
Monitor logs for responses.
"""
import urllib.request
import json
import time

GATEWAY_URL = "http://localhost:28789"
GATEWAY_TOKEN = "5b3f1c9612b577ae6117de9b72597c63d1692d57ad5d8bc0"

def chat(message, agent_id="main", timeout=60):
    payload = json.dumps({
        "model": f"openclaw/{agent_id}",
        "messages": [{"role": "user", "content": message}],
        "stream": False,
        "max_tokens": 800
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
            return True, elapsed, data["choices"][0]["message"]["content"]
        return False, elapsed, str(data)
    except Exception as e:
        elapsed = int((time.time() - start) * 1000)
        return False, elapsed, str(e)[:100]

TESTS = [
    ("main", "me mostre os detalhes sobre o time de scrum do projeto agl-hostman"),
    ("main", "quais sao os skills do especialista em openclaw"),
    ("main", "liste todos os agentes da AGL-Crew"),
    ("main", "qual o status dos cron jobs"),
    ("openclaw-architect", "façam uma auditoria do sistema"),
]

print("=" * 70)
print("TELEGRAM SIMULATION TESTS")
print("=" * 70)

for agent, msg in TESTS:
    print(f"\n[Agent: {agent}]")
    print(f"Q: {msg[:60]}...")
    ok, lat, resp = chat(msg, agent)
    status = "OK" if ok else "FAIL"
    print(f"Status: {status} ({lat}ms)")
    if ok:
        print(f"A: {resp[:200]}...")
    else:
        print(f"Error: {resp}")
    time.sleep(2)

print("\n" + "=" * 70)
print("Check Telegram @Jarvis3b3Bot for actual message delivery")
print("=" * 70)
