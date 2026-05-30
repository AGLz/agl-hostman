"""Orquestra fetch de mercado e gravação no SQLite."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from src.catalog.repository import add_market_price, get_build
from src.market.models import MarketListing
from src.market.providers import PROVIDERS
from src.market.queries import queries_for_category


@dataclass
class FetchResult:
    provider: str
    category_slug: str
    query: str
    stored: int
    skipped: int
    listings: list[MarketListing]
    errors: list[str]


def fetch_category(
    *,
    category_slug: str,
    query: str | None = None,
    providers: list[str] | None = None,
    limit: int = 3,
    persist: bool = True,
) -> list[FetchResult]:
    provider_slugs = providers or list(PROVIDERS.keys())
    results: list[FetchResult] = []
    search_queries = queries_for_category(category_slug, query)[:1]

    for provider_slug in provider_slugs:
        provider = PROVIDERS.get(provider_slug)
        if provider is None:
            continue

        for search_query in search_queries:
            result = FetchResult(
                provider=provider_slug,
                category_slug=category_slug,
                query=search_query,
                stored=0,
                skipped=0,
                listings=[],
                errors=[],
            )
            try:
                listings = provider.search(
                    search_query, category_slug, limit=limit)
            except Exception as exc:
                result.errors.append(str(exc))
                results.append(result)
                continue

            result.listings = listings
            if persist:
                for listing in listings:
                    if listing.price_cents <= 0:
                        result.skipped += 1
                        continue
                    add_market_price(
                        retailer_slug=provider.retailer_slug,
                        category_slug=listing.category_slug,
                        product_name=listing.product_name,
                        price_cents=listing.price_cents,
                        url=listing.url,
                        source=f"fetch:{provider_slug}",
                        notes=listing.notes,
                    )
                    result.stored += 1
            results.append(result)
    return results


def fetch_build(
    build_id: int,
    *,
    providers: list[str] | None = None,
    limit: int = 2,
    persist: bool = True,
) -> list[FetchResult]:
    build = get_build(build_id)
    if build is None:
        raise ValueError(f"Montagem #{build_id} não encontrada")

    all_results: list[FetchResult] = []
    for item in build["items"]:
        query = item["label"]
        results = fetch_category(
            category_slug=item["category_slug"],
            query=query,
            providers=providers,
            limit=limit,
            persist=persist,
        )
        all_results.extend(results)
    return all_results


def fetch_all_preset_categories(
    *,
    providers: list[str] | None = None,
    limit: int = 2,
    persist: bool = True,
) -> list[FetchResult]:
    from src.catalog.models import ComponentCategory

    all_results: list[FetchResult] = []
    for category in ComponentCategory:
        results = fetch_category(
            category_slug=category.value,
            providers=providers,
            limit=limit,
            persist=persist,
        )
        all_results.extend(results)
    return all_results


def summarize_results(results: list[FetchResult]) -> dict[str, Any]:
    return {
        "runs": len(results),
        "stored": sum(r.stored for r in results),
        "skipped": sum(r.skipped for r in results),
        "errors": [e for r in results for e in r.errors],
    }
