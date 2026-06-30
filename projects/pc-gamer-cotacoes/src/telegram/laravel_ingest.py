"""Envio de ofertas parseadas para a API Laravel (sidecar)."""

from __future__ import annotations

import os
from typing import Any

from src.market.http import get_client


def laravel_ingest_enabled() -> bool:
    return bool(os.getenv("LARAVEL_INGEST_URL", "").strip())


def _ingest_url() -> str:
    base = os.getenv("LARAVEL_INGEST_URL", "").rstrip("/")
    return f"{base}/api/pcgamer/telegram-offers"


def post_offer_to_laravel(
    *,
    chat_key: str,
    message_id: int,
    message_hash: str,
    raw_text: str,
    parsed: dict[str, Any],
    posted_at: str | None = None,
    source_title: str | None = None,
) -> bool:
    """POST oferta ao Laravel. Devolve True se criada, False se duplicada/ignorada."""
    api_key = os.getenv("LARAVEL_API_KEY", "").strip()
    if not api_key:
        return False

    payload = {
        "chat_key": chat_key,
        "message_id": message_id,
        "message_hash": message_hash,
        "raw_text": raw_text,
        "posted_at": posted_at,
        "source_title": source_title or chat_key,
        "parsed": parsed,
    }

    try:
        with get_client(timeout=30.0) as client:
            response = client.post(
                _ingest_url(),
                json=payload,
                headers={"X-API-Key": api_key, "Accept": "application/json"},
            )
            if response.status_code == 201:
                return True
            if response.status_code == 200:
                body = response.json()
                return bool(body.get("created"))
    except Exception:
        return False
    return False
