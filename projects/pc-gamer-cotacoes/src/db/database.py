"""Acesso SQLite e inicialização do schema."""

from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Generator

from src.config import DATABASE_PATH, PROJECT_ROOT


def ensure_data_dir() -> None:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)


def init_db() -> None:
    ensure_data_dir()
    schema_path = PROJECT_ROOT / "src" / "db" / "schema.sql"
    sql = schema_path.read_text(encoding="utf-8")
    with connect() as conn:
        conn.executescript(sql)

    from src.catalog.repository import seed_build_presets

    seed_build_presets()


@contextmanager
def connect() -> Generator[sqlite3.Connection, None, None]:
    ensure_data_dir()
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def row_to_dict(row: sqlite3.Row | None) -> dict | None:
    if row is None:
        return None
    return dict(row)
