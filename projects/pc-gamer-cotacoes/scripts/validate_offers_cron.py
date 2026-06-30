#!/usr/bin/env python3
"""Cron: revalidar ofertas recentes (estoque + preço no link)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.db.database import init_db  # noqa: E402
from src.telegram.validate_offers import validate_pending_offers  # noqa: E402


def main() -> int:
    init_db()
    result = validate_pending_offers()
    print(
        "validate-offers: "
        f"checked={result.checked} active={result.active} "
        f"price_changed={result.price_changed} unavailable={result.unavailable} "
        f"needs_manual={result.needs_manual}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
