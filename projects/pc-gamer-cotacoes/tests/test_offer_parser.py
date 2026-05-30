"""Testes unitários do parser de ofertas."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.telegram.parsers.offer_parser import extract_price, parse_offer  # noqa: E402


def test_extract_price_brl() -> None:
    text = "RTX 5070 por R$ 4.299,90 na promo"
    assert extract_price(text) == 429990


def test_parse_offer_categorizes_gpu() -> None:
    text = """
    Placa de vídeo RTX 4060 Ti 8GB
    R$ 2.199,00
    https://exemplo.com/produto
    """
    parsed = parse_offer(text)
    assert parsed.matched_category_slug == "placa_video"
    assert parsed.price_cents == 219900
    assert parsed.url == "https://exemplo.com/produto"


def test_parse_offer_ddr5() -> None:
    text = "Memória DDR5 32GB 6000MHz R$ 899,99"
    parsed = parse_offer(text)
    assert parsed.matched_category_slug == "memoria_ddr5"
    assert parsed.price_cents == 89999
