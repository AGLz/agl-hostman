"""Pichau — Magento 2 GraphQL + fallback HTML.

A Pichau é loja brasileira (Magento 2). Tentamos a API GraphQL pública
de produtos e, se bloqueada (WAF), caímos para scan de HTML da busca.
"""

from __future__ import annotations

import json
import re
from urllib.parse import quote_plus

from src.market.http import get_client
from src.market.models import MarketListing
from src.market.providers.base import MarketProvider

BASE_URL = "https://www.pichau.com.br"
GRAPHQL_URL = f"{BASE_URL}/graphql"

# Reason: query mínima Magento 2 — preço final + marca + url por produto
_PRODUCTS_QUERY = (
    "query($q:String!,$n:Int!){products(search:$q,pageSize:$n,"
    "sort:{relevance:DESC}){items{name sku url_key "
    "price_range{minimum_price{final_price{value currency}}}}}}"
)


class PichauProvider(MarketProvider):
    slug = "pichau"
    retailer_slug = "pichau"

    def search(self, query: str, category_slug: str, limit: int = 5) -> list[MarketListing]:
        api_results = self._search_graphql(query, category_slug, limit)
        if api_results:
            return api_results

        html_results = self._search_html(query, category_slug, limit)
        if html_results:
            return html_results

        return [
            MarketListing(
                provider=self.slug,
                category_slug=category_slug,
                product_name=f"[manual] {query}",
                price_cents=0,
                url=f"{BASE_URL}/search?q={quote_plus(query)}",
                query=query,
                notes="blocked:waf — abrir busca Pichau no browser",
                confidence=0.0,
            )
        ]

    def _search_graphql(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        payload = {
            "query": _PRODUCTS_QUERY,
            "variables": {"q": query, "n": min(limit, 20)},
        }
        try:
            with get_client() as client:
                response = client.post(
                    GRAPHQL_URL,
                    json=payload,
                    headers={"Content-Type": "application/json"},
                )
                if response.status_code != 200:
                    return []
                data = response.json()
        except Exception:
            return []

        items = (
            data.get("data", {})
            .get("products", {})
            .get("items", [])
        )
        if not isinstance(items, list):
            return []

        listings: list[MarketListing] = []
        for item in items[:limit]:
            final = (
                item.get("price_range", {})
                .get("minimum_price", {})
                .get("final_price", {})
            )
            value = final.get("value")
            if value is None:
                continue
            price_cents = int(round(float(value) * 100))
            if price_cents <= 0:
                continue
            url_key = item.get("url_key")
            url = f"{BASE_URL}/{url_key}" if url_key else BASE_URL
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=str(item.get("name", query))[:240],
                    price_cents=price_cents,
                    currency=str(final.get("currency", "BRL")),
                    url=url,
                    external_id=str(item.get("sku", "")),
                    query=query,
                    notes="api:magento_graphql",
                )
            )
        return listings

    def _search_html(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        url = f"{BASE_URL}/search?q={quote_plus(query)}"
        try:
            with get_client() as client:
                response = client.get(url)
                if response.status_code != 200:
                    return []
                html = response.text
        except Exception:
            return []

        listings: list[MarketListing] = []
        query_lower = query.lower()

        for block in re.finditer(
            r'<script type="application/ld\+json">(.*?)</script>', html, re.S
        ):
            try:
                data = json.loads(block.group(1))
            except json.JSONDecodeError:
                continue
            items = data if isinstance(data, list) else [data]
            for item in items:
                if item.get("@type") != "Product":
                    continue
                name = str(item.get("name", ""))
                offers = item.get("offers") or {}
                if isinstance(offers, list):
                    offers = offers[0] if offers else {}
                price_raw = offers.get("price") or offers.get("lowPrice")
                if price_raw is None:
                    continue
                listings.append(
                    MarketListing(
                        provider=self.slug,
                        category_slug=category_slug,
                        product_name=name[:240],
                        price_cents=int(round(float(price_raw) * 100)),
                        url=offers.get("url") or url,
                        query=query,
                        notes="html:json-ld",
                        confidence=0.7,
                    )
                )
                if len(listings) >= limit:
                    return listings

        price_pattern = re.compile(
            r'R\$\s*([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})'
        )
        for match in price_pattern.finditer(html):
            brl = match.group(1).replace(".", "").replace(",", ".")
            try:
                price_cents = int(round(float(brl) * 100))
            except ValueError:
                continue
            if price_cents < 5000:
                continue
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=query_lower[:240] or "Produto Pichau",
                    price_cents=price_cents,
                    url=url,
                    query=query,
                    notes="html:price-scan",
                    confidence=0.4,
                )
            )
            if len(listings) >= limit:
                break
        return listings
