"""AliExpress — API afiliados (IOP) opcional + fallback de busca."""

from __future__ import annotations

import hashlib
import json
import re
import time
from urllib.parse import quote_plus, urlencode

from src.config import (
    ALIEXPRESS_APP_KEY,
    ALIEXPRESS_APP_SECRET,
    ALIEXPRESS_SHIP_FROM,
    ALIEXPRESS_TRACKING_ID,
)
from src.market.http import get_client
from src.market.models import MarketListing
from src.market.providers.base import MarketProvider

IOP_URL = "https://api-sg.aliexpress.com/sync"


class AliExpressProvider(MarketProvider):
    slug = "aliexpress"
    retailer_slug = "aliexpress"

    def search(self, query: str, category_slug: str, limit: int = 5) -> list[MarketListing]:
        if ALIEXPRESS_APP_KEY and ALIEXPRESS_APP_SECRET:
            api_results = self._search_affiliate_api(
                query, category_slug, limit)
            if api_results:
                return api_results
        return self._search_page_fallback(query, category_slug, limit)

    def _sign(self, params: dict[str, str]) -> str:
        assert ALIEXPRESS_APP_SECRET
        ordered = "".join(f"{key}{params[key]}" for key in sorted(params))
        digest = hashlib.md5(
            f"{ALIEXPRESS_APP_SECRET}{ordered}{ALIEXPRESS_APP_SECRET}".encode()
        ).hexdigest()
        return digest.upper()

    def _search_affiliate_api(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        timestamp = str(int(time.time() * 1000))
        params: dict[str, str] = {
            "app_key": ALIEXPRESS_APP_KEY,
            "method": "aliexpress.affiliate.product.query",
            "sign_method": "md5",
            "timestamp": timestamp,
            "format": "json",
            "v": "2.0",
            "keywords": query,
            "page_size": str(min(limit, 20)),
            "target_currency": "BRL",
            "target_language": "PT",
            "sort": "SALE_PRICE_ASC",
        }
        if ALIEXPRESS_SHIP_FROM:
            # preço/elegibilidade conforme país de destino (Brasil)
            params["ship_to_country"] = ALIEXPRESS_SHIP_FROM
        if ALIEXPRESS_TRACKING_ID:
            params["tracking_id"] = ALIEXPRESS_TRACKING_ID
        params["sign"] = self._sign(params)

        try:
            with get_client(timeout=30.0) as client:
                response = client.post(IOP_URL, data=params)
                response.raise_for_status()
                payload = response.json()
        except Exception:
            return []

        response_block = payload.get(
            "aliexpress_affiliate_product_query_response", {})
        result = response_block.get("resp_result", {})
        if isinstance(result, str):
            try:
                result = json.loads(result)
            except json.JSONDecodeError:
                return []

        products = result.get("products", {}).get("product", [])
        if isinstance(products, dict):
            products = [products]

        listings: list[MarketListing] = []
        for product in products[:limit]:
            price_raw = product.get(
                "target_sale_price") or product.get("sale_price")
            if price_raw is None:
                continue
            price = float(str(price_raw).replace(",", "."))
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=str(product.get(
                        "product_title", query))[:240],
                    price_cents=int(round(price * 100)),
                    currency=str(product.get(
                        "target_sale_price_currency", "BRL")),
                    url=product.get("promotion_link") or product.get(
                        "product_detail_url"),
                    external_id=str(product.get("product_id", "")),
                    query=query,
                    notes="api:aliexpress_affiliate",
                )
            )
        return listings

    def _search_page_fallback(
        self, query: str, category_slug: str, limit: int
    ) -> list[MarketListing]:
        slug = quote_plus(query.lower().replace(" ", "-"))
        url = f"https://pt.aliexpress.com/w/wholesale-{slug}.html"
        if ALIEXPRESS_SHIP_FROM:
            # filtro "Enviar de" = Brasil (armazém nacional)
            url += f"?shipFromCountry={ALIEXPRESS_SHIP_FROM}"
        ship_note = f"ship_from:{ALIEXPRESS_SHIP_FROM}" if ALIEXPRESS_SHIP_FROM else ""
        try:
            with get_client(timeout=30.0) as client:
                response = client.get(url)
                if "captcha" in response.text.lower() or "punish" in str(response.url):
                    return [
                        MarketListing(
                            provider=self.slug,
                            category_slug=category_slug,
                            product_name=f"[manual] {query}",
                            price_cents=0,
                            url=url,
                            query=query,
                            notes="blocked:captcha — configure ALIEXPRESS_APP_KEY ou abrir URL",
                            confidence=0.0,
                        )
                    ]
                html = response.text
        except Exception:
            return []

        listings: list[MarketListing] = []
        for match in re.finditer(
            r'"formattedPrice"\s*:\s*"R\$\s*([0-9.,]+)"', html
        ):
            price = self._parse_brl(match.group(1))
            if price is None:
                continue
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=query[:240],
                    price_cents=price,
                    url=url,
                    query=query,
                    notes=" ".join(
                        filter(None, ["html:formattedPrice", ship_note])),
                    confidence=0.55,
                )
            )
            if len(listings) >= limit:
                break

        for match in re.finditer(
            r'"minPrice"\s*:\s*([0-9]+)', html
        ):
            cents = int(match.group(1))
            if cents < 1000:
                continue
            listings.append(
                MarketListing(
                    provider=self.slug,
                    category_slug=category_slug,
                    product_name=query[:240],
                    price_cents=cents,
                    currency="BRL",
                    url=url,
                    query=query,
                    notes=" ".join(filter(None, ["html:minPrice", ship_note])),
                    confidence=0.5,
                )
            )
            if len(listings) >= limit:
                break
        return listings[:limit]

    @staticmethod
    def _parse_brl(raw: str) -> int | None:
        cleaned = raw.strip().replace(".", "").replace(",", ".")
        try:
            value = float(cleaned)
        except ValueError:
            return None
        if value <= 0:
            return None
        return int(round(value * 100))
