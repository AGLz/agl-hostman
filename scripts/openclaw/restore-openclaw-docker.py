#!/usr/bin/env python3
"""
Restore OpenClaw config for Docker from agldv03 backup.
Merges original backup (9 providers, correct models/fallbacks) with
current Docker agents list, adapts baseUrls for LiteLLM Docker network.
"""
import json
import datetime
import sys
import os

LITELLM_URL = os.environ.get("LITELLM_GATEWAY_URL", "http://100.125.249.8:4000")
LITELLM_KEY = os.environ.get("LITELLM_MASTER_KEY", "")
BACKUP = "/root/.openclaw.bak.wk45-sync-20260325180822/openclaw.json"
AGENTS_FILE = "/tmp/agents-list.json"
OUTPUT = "/tmp/openclaw-restored.json"
BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")

def main():
    with open(BACKUP) as f:
        cfg = json.load(f)
    with open(AGENTS_FILE) as f:
        agents_list = json.load(f)

    # Update meta
    cfg["meta"]["lastTouchedVersion"] = "2026.4.14"
    cfg["meta"]["lastTouchedAt"] = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

    # Set models mode
    cfg["models"]["mode"] = "merge"

    # Route ALL providers through LiteLLM
    for pname in list(cfg["models"]["providers"].keys()):
        p = cfg["models"]["providers"][pname]
        p["baseUrl"] = LITELLM_URL
        p["apiKey"] = LITELLM_KEY
        p["api"] = "openai-completions"

    # Keep agents list from Docker (47 agents)
    cfg["agents"]["list"] = agents_list
    cfg["agents"]["defaults"]["maxConcurrent"] = 3
    cfg["agents"]["defaults"]["timeoutSeconds"] = 600
    cfg["agents"]["defaults"]["compaction"] = {"mode": "safeguard"}

    # Gateway port for Docker
    cfg["gateway"]["port"] = 18789

    # Fix Telegram - agldv03 bot, pairing policy
    cfg["channels"]["telegram"]["botToken"] = BOT_TOKEN
    cfg["channels"]["telegram"]["dmPolicy"] = "pairing"
    cfg["channels"]["telegram"]["groupPolicy"] = "allowlist"
    cfg["channels"]["telegram"]["streaming"] = {"mode": "partial"}

    # Skills
    cfg["skills"] = {
        "allowBundled": [
            "coding-agent", "gemini", "gh-issues", "github", "healthcheck",
            "node-connect", "openai-image-gen", "openai-whisper-api",
            "session-logs", "skill-creator", "tmux", "weather"
        ],
        "install": {"nodeManager": "npm"}
    }

    # Commands lockdown
    cfg["commands"] = {
        "native": "auto",
        "nativeSkills": "auto",
        "bash": False,
        "config": False,
        "debug": False,
        "restart": False,
        "ownerDisplay": "raw"
    }

    # Plugins
    cfg["plugins"] = {
        "entries": {
            "qwen-portal-auth": {"enabled": True},
            "telegram": {"enabled": True},
            "openrouter": {"enabled": True},
            "anthropic": {"enabled": True},
            "moonshot": {"enabled": True},
            "deepseek": {"enabled": True},
            "openai": {"enabled": True},
            "google": {"enabled": True}
        }
    }

    with open(OUTPUT, "w") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)

    # Summary
    print(f"Providers: {list(cfg['models']['providers'].keys())}")
    print(f"Primary model: {cfg['agents']['defaults']['model']['primary']}")
    print(f"Fallbacks: {len(cfg['agents']['defaults']['model']['fallbacks'])}")
    print(f"Agents: {len(cfg['agents']['list'])}")
    print(f"Gateway port: {cfg['gateway']['port']}")
    print(f"Telegram dmPolicy: {cfg['channels']['telegram']['dmPolicy']}")
    print(f"Telegram bot ID: {cfg['channels']['telegram']['botToken'].split(':')[0]}")
    print(f"Skills: {len(cfg['skills']['allowBundled'])}")
    print(f"Model aliases: {len(cfg['agents']['defaults'].get('models', {}))}")
    print(f"WRITTEN OK: {OUTPUT}")

if __name__ == "__main__":
    main()
