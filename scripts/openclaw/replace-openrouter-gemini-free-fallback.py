#!/usr/bin/env python3
"""
Substitui openrouter/google/gemini-2.5-flash-lite:free por zai/glm-4.7-flash em todo o JSON.
Reason: OpenRouter devolve 404 "No endpoints found" para esse ID; GLM 4.7 Flash é gratuito via ZAI no proxy.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

OLD = "openrouter/google/gemini-2.5-flash-lite:free"
NEW = "zai/glm-4.7-flash"


def patch_obj(o: object) -> int:
    n = 0
    if isinstance(o, dict):
        for k, v in list(o.items()):
            if v == OLD:
                o[k] = NEW
                n += 1
            else:
                n += patch_obj(v)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            if v == OLD:
                o[i] = NEW
                n += 1
            else:
                n += patch_obj(v)
    return n


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "/root/.openclaw/openclaw.json")
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    data = json.loads(raw.decode("utf-8"))
    count = patch_obj(data)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"OK: substituições {OLD} -> {NEW}: {count} em {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
