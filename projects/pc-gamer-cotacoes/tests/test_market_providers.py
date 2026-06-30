"""Testes dos providers de mercado (mock httpx)."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.market.providers.mercadolivre import MercadoLivreProvider  # noqa: E402
from src.market.providers.aliexpress import AliExpressProvider  # noqa: E402
from src.market.providers.pichau import PichauProvider  # noqa: E402


def _mock_get_client(response: MagicMock) -> MagicMock:
    client = MagicMock()
    client.__enter__ = MagicMock(return_value=client)
    client.__exit__ = MagicMock(return_value=False)
    client.get.return_value = response
    client.post.return_value = response
    return client


def test_mercadolivre_api_parsing() -> None:
    payload = {
        "results": [
            {
                "id": "MLB123",
                "title": "Placa RTX 4060 8GB",
                "price": 2199.90,
                "permalink": "https://produto.mercadolivre.com.br/MLB123",
                "official_store_id": 42,
                "seller": {"nickname": "TERABYTE_OFICIAL"},
                "seller_address": {"country": {"id": "BR"}},
                "shipping": {"logistic_type": "fulfillment"},
            }
        ]
    }
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = payload
    mock_response.raise_for_status = MagicMock()

    with patch(
        "src.market.providers.mercadolivre.get_client",
        return_value=_mock_get_client(mock_response),
    ):
        listings = MercadoLivreProvider().search("RTX 4060", "placa_video", limit=3)

    assert len(listings) == 1
    assert listings[0].price_cents == 219990
    assert listings[0].provider == "mercadolivre"
    # vendedores BR: nota deve marcar envio BR e vendedor
    assert "ship:BR" in listings[0].notes
    assert "vendedor:TERABYTE_OFICIAL" in listings[0].notes


def test_mercadolivre_skips_non_br_seller() -> None:
    payload = {
        "results": [
            {
                "id": "MLA999",
                "title": "RTX 4060 importada",
                "price": 1500.0,
                "seller_address": {"country": {"id": "AR"}},
            }
        ]
    }
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = payload
    mock_response.raise_for_status = MagicMock()
    mock_response.text = ""  # fallback HTML sem resultados

    with patch(
        "src.market.providers.mercadolivre.get_client",
        return_value=_mock_get_client(mock_response),
    ):
        listings = MercadoLivreProvider().search("RTX 4060", "placa_video", limit=3)

    assert listings == []


def test_pichau_graphql_parsing() -> None:
    payload = {
        "data": {
            "products": {
                "items": [
                    {
                        "name": "Placa de Video RTX 4060 Pichau",
                        "sku": "PG-RTX4060",
                        "url_key": "placa-de-video-rtx-4060",
                        "price_range": {
                            "minimum_price": {
                                "final_price": {"value": 2099.0, "currency": "BRL"}
                            }
                        },
                    }
                ]
            }
        }
    }
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = payload

    with patch(
        "src.market.providers.pichau.get_client",
        return_value=_mock_get_client(mock_response),
    ):
        listings = PichauProvider().search("RTX 4060", "placa_video", limit=3)

    assert len(listings) == 1
    assert listings[0].price_cents == 209900
    assert listings[0].provider == "pichau"
    assert listings[0].url.endswith("placa-de-video-rtx-4060")


def test_aliexpress_brl_parser() -> None:
    assert AliExpressProvider._parse_brl("1.299,90") == 129990
    assert AliExpressProvider._parse_brl("899,00") == 89900
