#!/usr/bin/env python3
"""Define modelos default no .env EvoNexus e comenta DASHSCOPE_API_KEY."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: patch-evonexus-env-models.py <model> <env-path>", file=sys.stderr)
        return 2

    model = sys.argv[1].strip()
    path = Path(sys.argv[2])
    if not path.is_file():
        print(f"SKIP missing {path}")
        return 0

    text = path.read_text(encoding="utf-8")
    for key in (
        "OPENAI_MODEL",
        "ANTHROPIC_MODEL",
        "EVONEXUS_ANTHROPIC_MODEL",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    ):
        pat = rf"^{re.escape(key)}=.*$"
        line = f"{key}={model}"
        text = re.sub(pat, line, text, flags=re.M) if re.search(pat, text, flags=re.M) else text.rstrip() + "\n" + line + "\n"

    text = re.sub(
        r"^(?!# )(DASHSCOPE_API_KEY=.*)$",
        r"# DISABLED dashscope 2026-05 \1",
        text,
        flags=re.M,
    )
    path.write_text(text, encoding="utf-8")
    print(f"OK {path} -> {model}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
