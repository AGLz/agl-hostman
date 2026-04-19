#!/usr/bin/env python3
"""
Substitui IDs Gemini :free inválidos no OpenClaw por zai/glm-4.7-flash em todo o JSON.

Reason: OpenRouter devolve 404 "No endpoints found" para estes IDs; o gateway por vezes
expõe o slug como google/gemini-2.5-flash-lite:free (sem prefixo openrouter/). GLM 4.7 Flash
via Z.AI costuma estar disponível no stack AGL.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

NEW = "zai/glm-4.7-flash"
# Ordem: variantes mais longas primeiro se algum dia houver prefixos sobrepostos
OLD_MODELS: tuple[str, ...] = (
    "openrouter/google/gemini-2.5-flash-lite:free",
    "google/gemini-2.5-flash-lite:free",
)


def patch_obj(o: object) -> int:
    n = 0
    if isinstance(o, dict):
        for k, v in list(o.items()):
            if isinstance(v, str) and v in OLD_MODELS:
                o[k] = NEW
                n += 1
            else:
                n += patch_obj(v)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            if isinstance(v, str) and v in OLD_MODELS:
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
    print(f"OK: substituídos {count} valores -> {NEW} em {path} (modelos: {', '.join(OLD_MODELS)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
