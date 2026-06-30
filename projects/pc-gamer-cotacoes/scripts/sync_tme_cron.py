#!/usr/bin/env python3
"""Cron: sincronizar ofertas dos canais via t.me/s/ (sem Telethon)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.config import TME_SYNC_LIMIT  # noqa: E402
from src.db.database import init_db  # noqa: E402
from src.telegram.sync_tme import sync_all_channels  # noqa: E402


def main() -> int:
    init_db()
    results = sync_all_channels(limit=TME_SYNC_LIMIT)
    total_imported = sum(r.imported for r in results)
    total_errors = sum(r.errors for r in results)
    for row in results:
        print(
            f"sync-tme {row.chat_key}: +{row.imported} novas, "
            f"{row.skipped} ignoradas, erros={row.errors}"
        )
    print(f"sync-tme total: imported={total_imported} errors={total_errors}")
    return 1 if total_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
