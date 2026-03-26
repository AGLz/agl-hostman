#!/usr/bin/env python3
"""Remove stale plugins.entries.brave from openclaw.json (default: /root/.openclaw/openclaw.json)."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    p = Path(sys.argv[1] if len(sys.argv) > 1 else "/root/.openclaw/openclaw.json")
    raw = p.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    data = json.loads(raw.decode("utf-8"))
    entries = data.get("plugins", {}).get("entries")
    if isinstance(entries, dict) and "brave" in entries:
        del entries["brave"]
        p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"OK: removed plugins.entries.brave from {p}")
    else:
        print(f"OK: no brave entry in {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
