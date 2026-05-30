"""4Gamers — busca em categorias do site."""

from __future__ import annotations

import json
import re
from urllib.parse import quote_plus, urljoin

from src.market.http import get_client
from src.market.models import MarketListing
from src.market.providers.base import MarketProvider

BASE_URL = "https://www.4gamers.com.br"

CATEGORY_PATHS: dict[str, list[str]] = {
    "processador": ["/processador", "/hardware/processador"],
    "motherboard": ["/placa-mae", "/hardware/placa-mae"],
    "memoria_ddr5": ["/memoria-ram", "/hardware/memoria-ram"],
    "placa_video": ["/placa-de-video", "/hardware/placa-de-video"],
    "nvme": ["/ssd-e-hd", "/hardware/ssd-e-hd", "/armazenamento"],
    "gabinete": ["/gabinete-gamer", "/hardware/gabinete-gamer"],
    "fonte": ["/fonte", "/hardware/fonte"],
    "water_cooler": ["/water-cooler-e-air-cooler", "/cooler"],
    "fan": ["/cooler-de-gabinete", "/fan"],
    "suporte_vga": ["/hardware"],
}


class FourGamersProvider(MarketProvider):
    slug = "4gamers"
    retailer_slug = "4gamers"

    def search(self, query: str, category_slug: str, limit: int = 5) -> list[MarketListing]:
        api_results = self._search_nuvemshop_api(query, category_slug, limit)
        if api_results:
            return api_results

        html_results = self._search_category_html(query, category_slug, limit)
        if html_results:
            return html_results

        return [
            MarketListing(
                provider=self.slug,
                category_slug=category_slug,
                product_name=f"[manual] {query}",
                price_cents=0,
                url=f"{BASE_URL}/monte-seu-computador",
                query=query,
                notes="blocked:waf — consultar monte-seu-computador no browser",
                confidence=0.0,
            )
        ]

    def _search_nuvemshop_api(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        endpoints = [
            f"{BASE_URL}/api/catalog_system/pub/products/search?q={quote_plus(query)}",
            "https://www.4gamerslojaoficial.com.br/api/catalog_system/pub/products/search"
            f"?q={quote_plus(query)}",
        ]
        for endpoint in endpoints:
            try:
                with get_client() as client:
                    response = client.get(endpoint)
                    if response.status_code != 200:
                        continue
                    payload = response.json()
            except Exception:
                continue

            products = payload.get("results", payload)
            if not isinstance(products, list):
                continue

            listings: list[MarketListing] = []
            for product in products[:limit]:
                name = product.get("name") or query
                price_info = product.get("price") or product.get(
                    "price_with_discount")
                if price_info is None:
                    continue
                price_cents = int(round(float(price_info) * 100))
                canonical = product.get("canonical_url") or product.get("url")
                url = urljoin(BASE_URL, canonical) if canonical else BASE_URL
                listings.append(
                    MarketListing(
                        provider=self.slug,
                        category_slug=category_slug,
                        product_name=str(name)[:240],
                        price_cents=price_cents,
                        url=url,
                        external_id=str(product.get("id", "")),
                        query=query,
                        notes="api:nuvemshop",
                    )
                )
            if listings:
                return listings
        return []

    def _search_category_html(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        paths = CATEGORY_PATHS.get(category_slug, ["/hardware"])
        query_lower = query.lower()

        for path in paths:
            url = urljoin(BASE_URL, path)
            try:
                with get_client() as client:
                    response = client.get(url)
                    if response.status_code != 200:
                        continue
                    html = response.text
            except Exception:
                continue

            listings = self._parse_product_cards(
                html, url, category_slug, query_lower, limit)
            if listings:
                return listings
        return []

    def _parse_product_cards(
        self,
        html: str,
        base_url: str,
        category_slug: str,
        query_lower: str,
        limit: int,
    ) -> list[MarketListing]:
        listings: list[MarketListing] = []

        for block in re.finditer(
            r'<script type="application/ld\+json">(.*?)</script>', html, re.S
        ):
            try:
                data = json.loads(block.group(1))
            except json.JSONDecodeError:
                continue
            items = data if isinstance(data, list) else [data]
            for item in items:
                if item.get("@type") not in {"Product", "Offer"}:
                    continue
                name = str(item.get("name", ""))
                if query_lower and query_lower not in name.lower():
                    continue
                offers = item.get("offers") or {}
                if isinstance(offers, list):
                    offers = offers[0] if offers else {}
                price_raw = offers.get("price") or offers.get("lowPrice")
                if price_raw is None:
                    continue
                price_cents = int(round(float(price_raw) * 100))
                listings.append(
                    MarketListing(
                        provider=self.slug,
                        category_slug=category_slug,
                        product_name=name[:240],
                        price_cents=price_cents,
                        url=offers.get("url") or base_url,
                        query=query_lower,
                        notes="html:json-ld",
                        confidence=0.75,
                    )
                )
                if len(listings) >= limit:
                    return listings

        for match in re.finditer(
            r'itemprop="name"[^>]*content="([^"]+)"[^>]*>.*?'
            r'itemprop="price"[^>]*content="([0-9.]+)"',
            html,
            re.S | re.I,
        ):
            name = match.group(1)
            if query_lower and query_lower not in name.lower():
                continue
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=name[:240],
                    price_cents=int(round(float(match.group(2)) * 100)),
                    url=base_url,
                    query=query_lower,
                    notes="html:microdata",
                    confidence=0.65,
                )
            )
            if len(listings) >= limit:
                break

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
                    product_name=query_lower[:240] or "Produto 4Gamers",
                    price_cents=price_cents,
                    url=base_url,
                    query=query_lower,
                    notes="html:price-scan",
                    confidence=0.4,
                )
            )
            if len(listings) >= limit:
                break
        return listings
