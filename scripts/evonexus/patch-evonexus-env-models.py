#!/usr/bin/env python3
"""Define modelos default no .env EvoNexus e comenta DASHSCOPE_API_KEY."""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Política AGL 2026-06: Ollama → Z.AI → OpenAI → Anthropic
AGL_TIER_2026: dict[str, str] = {
    "ANTHROPIC_MODEL": "agl-primary",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-7",
    "EVONEXUS_ANTHROPIC_MODEL": "agl-primary",
    "OPENAI_MODEL": "agl-primary",
    "OPENAI_FALLBACK_MODEL": "zai-glm-5",
    "ZAI_MODEL": "glm-5",
    "ZAI_CODING_MODEL": "zai-coding-glm-4.7",
    "EVONEXUS_LONG_CONTEXT_MODEL": "agl-primary",
}


def upsert_env_key(text: str, key: str, value: str) -> str:
    pat = rf"^{re.escape(key)}=.*$"
    line = f"{key}={value}"
    if re.search(pat, text, flags=re.M):
        return re.sub(pat, line, text, flags=re.M)
    return text.rstrip() + "\n" + line + "\n"


def apply_tier(text: str, tier: dict[str, str]) -> str:
    for key, value in tier.items():
        text = upsert_env_key(text, key, value)
    return text


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: patch-evonexus-env-models.py <model|--agl-tier-2026> <env-path>", file=sys.stderr)
        return 2

    mode = sys.argv[1].strip()
    path = Path(sys.argv[2])
    if not path.is_file():
        print(f"SKIP missing {path}")
        return 0

    text = path.read_text(encoding="utf-8")

    if mode == "--agl-tier-2026":
        text = apply_tier(text, AGL_TIER_2026)
        summary = "agl-tier-2026"
    else:
        model = mode
        for key in (
            "OPENAI_MODEL",
            "ANTHROPIC_MODEL",
            "EVONEXUS_ANTHROPIC_MODEL",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        ):
            text = upsert_env_key(text, key, model)
        summary = model

    text = re.sub(
        r"^(?!# )(DASHSCOPE_API_KEY=.*)$",
        r"# DISABLED dashscope 2026-05 \1",
        text,
        flags=re.M,
    )
    path.write_text(text, encoding="utf-8")
    print(f"OK {path} -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
