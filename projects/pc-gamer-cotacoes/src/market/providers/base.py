"""Provider base para busca de preços."""

from __future__ import annotations

from abc import ABC, abstractmethod

from src.market.models import MarketListing


class MarketProvider(ABC):
    slug: str
    retailer_slug: str

    @abstractmethod
    def search(self, query: str, category_slug: str, limit: int = 5) -> list[MarketListing]:
        """Busca produtos e devolve listagens normalizadas."""
