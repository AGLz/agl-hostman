"""Comparação de cotações vs mercado (lojas + Telegram)."""

from __future__ import annotations

from typing import Any

from src.catalog.repository import get_build, list_recent_offers
from src.telegram.parsers.offer_parser import format_price


def _best_market_by_category(limit_per_category: int = 5) -> dict[str, list[dict[str, Any]]]:
    from src.catalog.repository import list_market_prices

    by_category: dict[str, list[dict[str, Any]]] = {}
    for row in list_market_prices(limit=500):
        slug = row["category_slug"]
        by_category.setdefault(slug, []).append(row)
    for slug in by_category:
        by_category[slug].sort(key=lambda r: r["price_cents"])
        by_category[slug] = by_category[slug][:limit_per_category]
    return by_category


def _best_telegram_by_category(limit: int = 3) -> dict[str, dict[str, Any] | None]:
    result: dict[str, dict[str, Any] | None] = {}
    categories = (
        "processador",
        "motherboard",
        "memoria_ddr5",
        "placa_video",
        "nvme",
        "gabinete",
        "fonte",
        "water_cooler",
        "fan",
        "suporte_vga",
    )
    for slug in categories:
        offers = list_recent_offers(category_slug=slug, limit=limit)
        valid = [o for o in offers if o.get("price_cents")]
        result[slug] = min(
            valid, key=lambda o: o["price_cents"]) if valid else None
    return result


def compare_build(build_id: int) -> dict[str, Any]:
    build = get_build(build_id)
    if build is None:
        raise ValueError(f"Montagem #{build_id} não encontrada")

    market = _best_market_by_category()
    telegram = _best_telegram_by_category()
    lines: list[dict[str, Any]] = []
    reference_total = 0
    market_best_total = 0
    our_cost_total = build["cost_cents"]

    for item in build["items"]:
        slug = item["category_slug"]
        our_cents = int(item["unit_cost_cents"]) * int(item["quantity"])

        market_rows = market.get(slug, [])
        market_best = market_rows[0] if market_rows else None
        tg_best = telegram.get(slug)

        candidates: list[tuple[str, int, str | None]] = []
        if market_best:
            candidates.append(
                ("mercado", int(market_best["price_cents"]), market_best.get(
                    "retailer_name"))
            )
        if tg_best and tg_best.get("price_cents"):
            candidates.append(
                ("telegram", int(tg_best["price_cents"]), "Telegram"))

        best_source = None
        best_cents = None
        if candidates:
            best_source, best_cents, _ = min(candidates, key=lambda c: c[1])
            market_best_total += best_cents * int(item["quantity"])

        if our_cents > 0:
            reference_total += our_cents
        elif best_cents:
            reference_total += best_cents * int(item["quantity"])

        delta = None
        if our_cents and best_cents:
            delta = our_cents - best_cents

        lines.append(
            {
                "item_id": item["id"],
                "category_slug": slug,
                "label": item["label"],
                "our_cents": our_cents,
                "market_best_cents": best_cents,
                "market_best_source": best_source,
                "market_product": (
                    market_best["product_name"] if market_best else None
                ),
                "telegram_product": (
                    tg_best.get("product_name") if tg_best else None
                ),
                "delta_cents": delta,
            }
        )

    return {
        "build_id": build_id,
        "code": build["code"],
        "title": build["title"],
        "our_cost_cents": our_cost_total,
        "our_quote_cents": build["quote_cents"],
        "reference_market_total_cents": market_best_total or reference_total,
        "lines": lines,
    }


def format_comparison_report(data: dict[str, Any]) -> str:
    lines_out = [
        f"Comparativo {data['code']} — {data['title']}",
        f"Sua cotação (custo): {format_price(data['our_cost_cents'])} | "
        f"Cliente: {format_price(data['our_quote_cents'])}",
        f"Referência mercado (melhor por slot): "
        f"{format_price(data['reference_market_total_cents'])}",
        "",
        f"{'Slot':<18} {'Seu preço':>12} {'Mercado':>12} {'Δ':>10}  Fonte",
        "-" * 72,
    ]
    for line in data["lines"]:
        delta = line["delta_cents"]
        delta_str = format_price(delta) if delta is not None else "—"
        if delta is not None and delta > 0:
            delta_str = f"+{delta_str}"
        source = line["market_best_source"] or "—"
        lines_out.append(
            f"{line['category_slug']:<18} "
            f"{format_price(line['our_cents']):>12} "
            f"{format_price(line['market_best_cents']):>12} "
            f"{delta_str:>10}  {source}"
        )
    return "\n".join(lines_out)
