#!/usr/bin/env python3
"""Atualiza models.providers.openai.baseUrl (e opcionalmente apiKey) em openclaw.json."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        print("Uso: patch-openclaw-litellm-baseurl.py <openclaw.json> <baseUrl> [apiKey]", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    base_url = sys.argv[2].rstrip("/")
    api_key = sys.argv[3] if len(sys.argv) > 3 else None

    data = json.loads(path.read_text(encoding="utf-8"))
    providers = data.setdefault("models", {}).setdefault("providers", {})
    openai = providers.setdefault("openai", {})
    openai["baseUrl"] = base_url
    if api_key is not None:
        openai["apiKey"] = api_key

    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"OK: baseUrl openai = {base_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
