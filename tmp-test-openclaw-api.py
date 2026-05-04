#!/usr/bin/env python3
"""Test OpenClaw Telegram bot by sending a chat message via the gateway API."""
import urllib.request
import json
import sys

url = "http://192.168.0.179:28789/api/v1/chat"
data = json.dumps({"message": "status", "agent": "main"}).encode()
req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        print(f"HTTP {resp.status}")
        print(resp.read().decode()[:2000])
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
