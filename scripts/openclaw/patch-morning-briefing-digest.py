#!/usr/bin/env python3
"""Atualiza payload do cron morning-briefing para entregar digest mesmo em OK."""
from __future__ import annotations

import json
import sys
from pathlib import Path

CRON_PATH = Path(sys.argv[1] if len(sys.argv) > 1 else "/home/node/.openclaw/cron/jobs.json")

MESSAGE = """MODEL LOCK: run with openai/gpt-5.4-nano only. Do not switch models or use fallbacks. Always return non-empty text.

morning-briefing — digest mode (sempre notificar no Telegram).

Run exactly this command and do not run additional exploration:
/home/node/.openclaw/workspace/scripts/morning-briefing-check.sh

Tool rules:
- Use one exec call only.
- When calling exec, omit host and security fields; use the gateway default exec configuration.
- Do not use node host, sandbox host, or security=allowlist.
- If stdout starts with MORNING_BRIEFING (without _ISSUES), reply with the full stdout verbatim (trim only if over 3500 chars).
- If stdout starts with MORNING_BRIEFING_ISSUES, reply with the full stdout verbatim.
- Never reply HEARTBEAT_OK for this job.
- Never return empty text."""


def main() -> int:
    data = json.loads(CRON_PATH.read_text(encoding="utf-8"))
    updated = False
    for job in data.get("jobs", []):
        if job.get("name") != "morning-briefing":
            continue
        job["payload"]["message"] = MESSAGE
        updated = True
        print(f"Updated morning-briefing in {CRON_PATH}")
        break
    if not updated:
        print("morning-briefing job not found", file=sys.stderr)
        return 1
    CRON_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
