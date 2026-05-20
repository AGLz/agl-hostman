#!/usr/bin/env python3
"""Patch ADWs/runner.py: repassa ANTHROPIC_* e força provider anthropic nas rotinas ADW."""

from __future__ import annotations

import re
import sys
from pathlib import Path

RUNNER = Path(sys.argv[1] if len(sys.argv) > 1 else "/workspace/ADWs/runner.py")

EXTRA_KEYS = (
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY",
    "API_TIMEOUT_MS",
    "DISABLE_LOGIN_COMMAND",
    "IS_SANDBOX",
)

ENV_MARKER = "# AGLz: anthropic gateway env (patch-adw-runner-provider-env.py)"
ADW_PROVIDER_MARKER = "# AGLz: ADW usa provider anthropic quando gateway configurado"


def patch_allowed_env(text: str) -> str:
    if ENV_MARKER in text:
        return text
    pattern = r"_ALLOWED_ENV_VARS = frozenset\(\{([^}]+)\}\)"
    match = re.search(pattern, text, re.DOTALL)
    if not match:
        raise SystemExit("_ALLOWED_ENV_VARS não encontrado")
    block = match.group(1)
    for key in EXTRA_KEYS:
        if f'"{key}"' not in block:
            block = block.rstrip() + f'\n    "{key}",'
    text = text[: match.start(1)] + block + text[match.end(1) :]
    return text.replace(
        "_ALLOWED_ENV_VARS = frozenset({",
        f"_ALLOWED_ENV_VARS = frozenset({{  {ENV_MARKER}",
        1,
    )


def patch_adw_provider(text: str) -> str:
    if ADW_PROVIDER_MARKER in text:
        return text
    old = (
        "        active = config.get(\"active_provider\", \"anthropic\")\n"
        "        provider = config.get(\"providers\", {}).get(active, {})"
    )
    new = (
        "        active = config.get(\"active_provider\", \"anthropic\")\n"
        f"        {ADW_PROVIDER_MARKER}\n"
        "        _anthropic = config.get(\"providers\", {}).get(\"anthropic\", {})\n"
        "        if (_anthropic.get(\"env_vars\") or {}).get(\"ANTHROPIC_BASE_URL\"):\n"
        "            active = \"anthropic\"\n"
        "        provider = config.get(\"providers\", {}).get(active, {})"
    )
    if old not in text:
        raise SystemExit("_get_provider_config block não encontrado")
    return text.replace(old, new, 1)


def main() -> None:
    if not RUNNER.is_file():
        raise SystemExit(f"runner não encontrado: {RUNNER}")

    text = RUNNER.read_text(encoding="utf-8")
    before = text
    text = patch_allowed_env(text)
    text = patch_adw_provider(text)
    if text == before and ENV_MARKER in text and ADW_PROVIDER_MARKER in text:
        print(f"OK (já aplicado): {RUNNER}")
        return
    RUNNER.write_text(text, encoding="utf-8")
    print(f"OK: patch aplicado em {RUNNER}")


if __name__ == "__main__":
    main()
