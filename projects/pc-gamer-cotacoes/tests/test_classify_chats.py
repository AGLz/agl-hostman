"""Testes do parser de username de scripts/classify_chats.py (sem rede)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from classify_chats import parse_username  # noqa: E402


def test_parse_username_aceita_formatos_publicos() -> None:
    assert parse_username("@canal_ofertas") == "canal_ofertas"
    assert parse_username("canal_ofertas") == "canal_ofertas"
    assert parse_username("t.me/canal_ofertas") == "canal_ofertas"
    assert parse_username("https://t.me/canal_ofertas") == "canal_ofertas"
    assert parse_username("https://t.me/canal_ofertas/") == "canal_ofertas"
    assert parse_username(
        "https://telegram.me/canal_ofertas") == "canal_ofertas"


def test_parse_username_rejeita_convites_privados() -> None:
    assert parse_username("https://t.me/+AbCdEfGhIj") is None
    assert parse_username("t.me/joinchat/AbCdEfGhIj") is None
    assert parse_username("+AbCdEfGhIj") is None
    assert parse_username("") is None
    assert parse_username("   ") is None
