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


def test_mercadolivre_api_parsing() -> None:
    payload = {
        "results": [
            {
                "id": "MLB123",
                "title": "Placa RTX 4060 8GB",
                "price": 2199.90,
                "permalink": "https://produto.mercadolivre.com.br/MLB123",
            }
        ]
    }
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = payload
    mock_response.raise_for_status = MagicMock()

    mock_client = MagicMock()
    mock_client.__enter__ = MagicMock(return_value=mock_client)
    mock_client.__exit__ = MagicMock(return_value=False)
    mock_client.get.return_value = mock_response

    with patch("src.market.providers.mercadolivre.get_client", return_value=mock_client):
        listings = MercadoLivreProvider().search("RTX 4060", "placa_video", limit=3)

    assert len(listings) == 1
    assert listings[0].price_cents == 219990
    assert listings[0].provider == "mercadolivre"


def test_aliexpress_brl_parser() -> None:
    assert AliExpressProvider._parse_brl("1.299,90") == 129990
    assert AliExpressProvider._parse_brl("899,00") == 89900
