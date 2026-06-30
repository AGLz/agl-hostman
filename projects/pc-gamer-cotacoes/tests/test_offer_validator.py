"""Testes do validador de ofertas (sem rede)."""

from __future__ import annotations

from src.telegram.offer_validator import (
    extract_prices_from_html,
    price_within_tolerance,
    validate_offer_url,
)


def test_price_within_tolerance() -> None:
    assert price_within_tolerance(10000, 10200, 5.0) is True
    assert price_within_tolerance(10000, 12000, 5.0) is False


def test_extract_prices_from_html() -> None:
    html = '<span>R$ 1.299,90</span> <div>R$ 10 OFF</div>'
    prices = extract_prices_from_html(html)
    assert 129990 in prices


def test_validate_unavailable_marker() -> None:
    class FakeResponse:
        status_code = 200
        url = "https://loja.exemplo.com/produto"
        text = "<html>Produto esgotado no momento</html>"

    class FakeClient:
        def get(self, url, follow_redirects=True):
            return FakeResponse()

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return None

    import src.telegram.offer_validator as mod

    original = mod.get_client
    mod.get_client = lambda timeout=25: FakeClient()
    try:
        result = validate_offer_url(
            "https://exemplo.com/produto", expected_price_cents=99900
        )
    finally:
        mod.get_client = original

    assert result.status == "unavailable"


def test_amazon_generic_indisponivel_nao_marca_esgotado() -> None:
    class FakeResponse:
        status_code = 200
        url = "https://www.amazon.com.br/dp/B0TEST"
        text = "<html>Forma de pagamento indisponível para este item</html>"

    class FakeClient:
        def get(self, url, follow_redirects=True):
            return FakeResponse()

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return None

    import src.telegram.offer_validator as mod

    original = mod.get_client
    mod.get_client = lambda timeout=25: FakeClient()
    try:
        result = validate_offer_url(
            "https://www.amazon.com.br/dp/B0TEST", expected_price_cents=99900
        )
    finally:
        mod.get_client = original

    assert result.status in {"needs_manual", "active", "price_changed"}
    assert result.status != "unavailable"
