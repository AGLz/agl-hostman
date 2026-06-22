#!/usr/bin/env python3
"""Garante Telegram dmPolicy open + allowlist explícito do utilizador AGL."""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

CONFIG = Path("/home/node/.openclaw/openclaw.json")
USER_ID = sys.argv[1] if len(sys.argv) > 1 else "1272190248"


def main() -> None:
    data = json.loads(CONFIG.read_text(encoding="utf-8"))
    tg = data.setdefault("channels", {}).setdefault("telegram", {})
    tg["enabled"] = True
    tg["dmPolicy"] = "open"
    tg["groupPolicy"] = "open"
    allow = set(str(x) for x in tg.get("allowFrom") or [])
    allow.add(str(USER_ID))
    allow.add("*")
    tg["allowFrom"] = sorted(allow, key=lambda x: (x != str(USER_ID), x))
    tg["groupAllowFrom"] = ["*"]
    if tg.get("commands") is None:
        tg["commands"] = {"native": False}

    backup = CONFIG.with_suffix(".json.bak.telegram-fix")
    shutil.copy2(CONFIG, backup)
    CONFIG.write_text(json.dumps(
        data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"OK telegram: dmPolicy={tg['dmPolicy']} allowFrom={tg['allowFrom']}")
    print(f"Backup: {backup}")


if __name__ == "__main__":
    main()
