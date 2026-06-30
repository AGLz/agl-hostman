"""Migrações incrementais SQLite (ALTER TABLE idempotente)."""

from __future__ import annotations

import sqlite3

_OFFER_COLUMNS: tuple[tuple[str, str], ...] = (
    ("last_validated_at", "TEXT"),
    ("validated_price_cents", "INTEGER"),
    ("validation_notes", "TEXT"),
)


def apply_migrations(conn: sqlite3.Connection) -> None:
    existing = {
        row[1]
        for row in conn.execute("PRAGMA table_info(telegram_offers)").fetchall()
    }
    for name, col_type in _OFFER_COLUMNS:
        if name in existing:
            continue
        conn.execute(
            f"ALTER TABLE telegram_offers ADD COLUMN {name} {col_type}")
