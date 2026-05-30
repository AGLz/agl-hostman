"""Mercado Livre — API pública MLB + fallback HTML."""

from __future__ import annotations

import json
import re
from urllib.parse import quote_plus

from src.config import MERCADOLIVRE_ACCESS_TOKEN
from src.market.http import get_client
from src.market.models import MarketListing
from src.market.providers.base import MarketProvider


class MercadoLivreProvider(MarketProvider):
    slug = "mercadolivre"
    retailer_slug = "mercadolivre"

    API_URL = "https://api.mercadolibre.com/sites/MLB/search"

    def search(self, query: str, category_slug: str, limit: int = 5) -> list[MarketListing]:
        api_results = self._search_api(query, category_slug, limit)
        if api_results:
            return api_results
        return self._search_html_fallback(query, category_slug, limit)

    def _search_api(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        params: dict[str, str | int] = {
            "q": query,
            "sort": "price_asc",
            "limit": min(limit, 50),
        }
        headers: dict[str, str] = {}
        if MERCADOLIVRE_ACCESS_TOKEN:
            headers["Authorization"] = f"Bearer {MERCADOLIVRE_ACCESS_TOKEN}"

        try:
            with get_client() as client:
                response = client.get(
                    self.API_URL, params=params, headers=headers)
                if response.status_code == 403:
                    return []
                response.raise_for_status()
                payload = response.json()
        except Exception:
            return []

        listings: list[MarketListing] = []
        for item in payload.get("results", [])[:limit]:
            price = item.get("price")
            if price is None:
                continue
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=str(item.get("title", query))[:240],
                    price_cents=int(round(float(price) * 100)),
                    url=item.get("permalink"),
                    external_id=str(item.get("id", "")),
                    query=query,
                    notes="api:mercadolibre",
                )
            )
        return listings

    def _search_html_fallback(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        slug = quote_plus(query.lower().replace(" ", "-"))
        url = f"https://lista.mercadolivre.com.br/{slug}"
        try:
            with get_client() as client:
                response = client.get(url)
                response.raise_for_status()
                html = response.text
        except Exception:
            return []

        # JSON-LD ou blocos com preço embutido
        listings: list[MarketListing] = []
        for match in re.finditer(
            r'"price"\s*:\s*([0-9]+(?:\.[0-9]{1,2})?)', html
        ):
            price = float(match.group(1))
            if price < 10:
                continue
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=query[:240],
                    price_cents=int(round(price * 100)),
                    url=url,
                    query=query,
                    notes="html:fallback",
                    confidence=0.6,
                )
            )
            if len(listings) >= limit:
                break

        if listings:
            return listings[:1]

        title_matches = re.findall(r'"title"\s*:\s*"([^"]{8,200})"', html)
        price_matches = re.findall(
            r'"price"\s*:\s*([0-9]+(?:\.[0-9]{1,2})?)', html
        )
        for title, price_raw in zip(title_matches, price_matches):
            price = float(price_raw)
            if price < 10:
                continue
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=title[:240],
                    price_cents=int(round(price * 100)),
                    url=url,
                    query=query,
                    notes="html:paired",
                    confidence=0.7,
                )
            )
            if len(listings) >= limit:
                break
        return listings
