"""Modelos de listagens de mercado."""

from __future__ import annotations

from pydantic import BaseModel, Field


class MarketListing(BaseModel):
    provider: str
    category_slug: str
    product_name: str
    price_cents: int
    currency: str = "BRL"
    url: str | None = None
    external_id: str | None = None
    query: str | None = None
    notes: str | None = None
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
