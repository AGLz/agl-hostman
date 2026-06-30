"""Testes do ingest Laravel."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from src.telegram.laravel_ingest import laravel_ingest_enabled, post_offer_to_laravel


def test_laravel_ingest_disabled_without_url(monkeypatch) -> None:
    monkeypatch.delenv("LARAVEL_INGEST_URL", raising=False)
    assert laravel_ingest_enabled() is False


def test_post_offer_to_laravel_created(monkeypatch) -> None:
    monkeypatch.setenv("LARAVEL_INGEST_URL", "https://laravel.test")
    monkeypatch.setenv("LARAVEL_API_KEY", "secret-key")

    mock_response = MagicMock()
    mock_response.status_code = 201
    mock_client = MagicMock()
    mock_client.post.return_value = mock_response
    mock_client.__enter__ = MagicMock(return_value=mock_client)
    mock_client.__exit__ = MagicMock(return_value=False)

    with patch("src.telegram.laravel_ingest.get_client", return_value=mock_client):
        ok = post_offer_to_laravel(
            chat_key="@mmpromo",
            message_id=42,
            message_hash="abc123",
            raw_text="GPU promo",
            parsed={"product_name": "RTX", "price_cents": 100000},
        )

    assert ok is True
    mock_client.post.assert_called_once()
    call_kwargs = mock_client.post.call_args
    assert call_kwargs[0][0] == "https://laravel.test/api/pcgamer/telegram-offers"
    assert call_kwargs[1]["headers"]["X-API-Key"] == "secret-key"
