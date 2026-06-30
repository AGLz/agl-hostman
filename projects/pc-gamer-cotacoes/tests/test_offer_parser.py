"""Testes do parser de ofertas."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.telegram.parsers.offer_parser import extract_price, parse_offer  # noqa: E402


def test_extract_price_brl() -> None:
    text = "RTX 5070 por R$ 4.299,90 na promo"
    assert extract_price(text) == 429990


def test_extract_price_sem_separador_milhar() -> None:
    text = "Placa RTX 5090\nR$ 21299\nhttps://exemplo.com"
    assert extract_price(text) == 2129900


def test_extract_price_prefere_preco_produto_sobre_cupom() -> None:
    text = "Cupom R$ 10 OFF\nProduto R$ 829\nhttps://shopee.com.br/x"
    assert extract_price(text) == 82900


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


def test_parse_offer_aliexpress_moedas_cupom() -> None:
    text = """
    GPU RX 5600 6GB
    R$ 815,30
    Cupom: FAFASUPER01 + PCDOFAFA5 + 211 moedas no APP
    Somente no APP Com Moedas
    https://a.aliexpress.com/_c4T1OVCL
    """
    parsed = parse_offer(text)
    assert parsed.price_cents == 81530
    assert parsed.requirements.requires_coins is True
    assert parsed.requirements.requires_app is True
    assert "FAFASUPER01" in parsed.requirements.coupon_codes
    assert parsed.requirements.retailer == "aliexpress"


def test_parse_offer_pix() -> None:
    text = "Monitor R$ 999 — pagamento PIX only https://kabum.com.br/p/1"
    parsed = parse_offer(text)
    assert parsed.requirements.requires_pix is True
