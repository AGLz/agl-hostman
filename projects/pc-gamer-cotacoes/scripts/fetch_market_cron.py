#!/usr/bin/env python3
"""Automação agendável — busca preços ML, Pichau, AliExpress e 4Gamers."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.config import market_fetch_providers  # noqa: E402
from src.db.database import init_db  # noqa: E402
from src.market.orchestrator import fetch_all_preset_categories, summarize_results  # noqa: E402


def main() -> int:
    init_db()
    providers = market_fetch_providers()
    results = fetch_all_preset_categories(
        providers=providers, limit=2, persist=True)
    summary = summarize_results(results)
    print(
        f"fetch-market: stored={summary['stored']} skipped={summary['skipped']} "
        f"errors={len(summary['errors'])}"
    )
    return 0 if not summary["errors"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
