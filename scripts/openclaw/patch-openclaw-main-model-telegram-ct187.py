#!/usr/bin/env python3
"""Corrige agente main (Telegram DM): gpt-5.4-nano streaming falha → groq-llama-31-8b."""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

CONFIG = Path("/home/node/.openclaw/openclaw.json")

# Reason: streaming + thinking medium → LiteLLM mid-stream fallback glm-flash (max_tokens ilegal).
TELEGRAM_PRIMARY = "openai/groq-llama-31-8b"
TELEGRAM_FALLBACKS = [
    "openai/or-nemotron-super-free",
    "openai/or-llama-3.3-70b-free",
]

BROKEN_PRIMARY = "openai/gpt-5.4-nano"


def main() -> None:
    data = json.loads(CONFIG.read_text(encoding="utf-8"))

    defaults_models = data.setdefault("agents", {}).setdefault("defaults", {}).setdefault(
        "models", {}
    )
    defaults_models.setdefault(
        "openai/groq-llama-31-8b", {"alias": "groq-fast", "maxTokens": 4096}
    )
    defaults_models.setdefault(
        "openai/or-nemotron-super-free", {"alias": "or-nemotron-free"}
    )
    defaults_models.setdefault(
        "openai/or-llama-3.3-70b-free", {"alias": "or-llama-free"}
    )

    agents_defaults = data.setdefault("agents", {}).setdefault("defaults", {})
    agents_defaults["thinkingDefault"] = "off"

    tg = data.setdefault("channels", {}).setdefault("telegram", {})
    tg_stream = tg.get("streaming")
    if isinstance(tg_stream, dict):
        tg_stream["mode"] = "off"
    else:
        tg["streaming"] = {"mode": "off"}
    tg.pop("streamMode", None)

    patched: list[str] = []
    for agent in data.get("agents", {}).get("list") or []:
        model = agent.setdefault("model", {})
        primary = model.get("primary")
        fallbacks = model.get("fallbacks") or []
        agent_id = agent.get("id", "?")

        if agent_id == "main" or primary in (BROKEN_PRIMARY, TELEGRAM_PRIMARY):
            model["primary"] = TELEGRAM_PRIMARY
            model["fallbacks"] = list(TELEGRAM_FALLBACKS)
            patched.append(str(agent_id))

    if not patched:
        print("WARN: nenhum agente patchado", file=sys.stderr)
        sys.exit(1)

    backup = CONFIG.with_suffix(".json.bak.telegram-model-fix")
    shutil.copy2(CONFIG, backup)
    CONFIG.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(
        f"OK model primary={TELEGRAM_PRIMARY} thinking=off telegram_stream=off agents={patched}")
    print(f"Backup: {backup}")


if __name__ == "__main__":
    main()
