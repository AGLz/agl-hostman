#!/usr/bin/env python3
"""CLI principal — catálogo, cotações e ofertas."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import click  # noqa: E402

from src.catalog.models import BuildStatus  # noqa: E402
from src.catalog.comparison import compare_build, format_comparison_report  # noqa: E402
from src.catalog.reference_sites import BUILD_WIZARD_STEPS, REFERENCE_SITES  # noqa: E402
from src.catalog.repository import (  # noqa: E402
    add_component,
    add_market_price,
    create_build,
    create_build_from_preset,
    get_build,
    get_build_preset,
    list_build_presets,
    list_builds,
    list_categories,
    list_components,
    list_market_prices,
    list_recent_offers,
    list_retailers,
    seed_market_from_presets,
    set_build_item,
    transition_build_status,
)
from src.db.database import init_db  # noqa: E402
from src.telegram.parsers.offer_parser import format_price  # noqa: E402
from src.config import market_fetch_providers  # noqa: E402
from src.market.orchestrator import (  # noqa: E402
    fetch_all_preset_categories,
    fetch_build,
    fetch_category,
    summarize_results,
)
from src.telegram.sync_history import main as sync_main  # noqa: E402


@click.group()
def cli() -> None:
    """Cotações PC gamer — catálogo, montagens e ofertas Telegram."""
    init_db()


@cli.command("init-db")
def cmd_init_db() -> None:
    """Reaplica schema SQLite (idempotente)."""
    init_db()
    click.echo("Base de dados inicializada.")


@cli.command("categories")
def cmd_categories() -> None:
    for row in list_categories():
        click.echo(f"{row['slug']:16} {row['name']}")


@cli.command("components")
@click.option("--category", "category_slug", default=None, help="Filtrar por slug")
def cmd_components(category_slug: str | None) -> None:
    for item in list_components(category_slug):
        brand = item["brand"] or "—"
        click.echo(
            f"#{item['id']:4} [{item['category_slug']}] {brand} {item['model']}"
        )


@cli.command("add-component")
@click.option("--category", "category_slug", required=True)
@click.option("--model", required=True)
@click.option("--brand", default=None)
@click.option("--sku", default=None)
def cmd_add_component(
    category_slug: str, model: str, brand: str | None, sku: str | None
) -> None:
    component_id = add_component(
        category_slug=category_slug,
        model=model,
        brand=brand,
        sku=sku,
    )
    click.echo(f"Componente criado: #{component_id}")


@cli.command("new-build")
@click.argument("title")
@click.option("--customer", default=None)
@click.option("--contact", default=None)
@click.option("--margin", default=15.0, type=float)
def cmd_new_build(
    title: str, customer: str | None, contact: str | None, margin: float
) -> None:
    build = create_build(
        title=title,
        customer_name=customer,
        customer_contact=contact,
        margin_percent=margin,
    )
    click.echo(
        f"Montagem {build['code']} criada (#{build['id']}) com template AMD gamer.")


@cli.command("builds")
@click.option("--status", default=None)
def cmd_builds(status: str | None) -> None:
    for summary in list_builds(status):
        click.echo(
            f"{summary.code} | {summary.status:10} | "
            f"custo {format_price(summary.cost_cents)} | "
            f"cotação {format_price(summary.quote_cents)} | "
            f"{summary.title}"
        )


@cli.command("show-build")
@click.argument("build_id", type=int)
def cmd_show_build(build_id: int) -> None:
    build = get_build(build_id)
    if build is None:
        raise click.ClickException(f"Montagem #{build_id} não encontrada")

    click.echo(
        f"{build['code']} — {build['title']} [{build['status']}]\n"
        f"Cliente: {build['customer_name'] or '—'} | "
        f"Contato: {build['customer_contact'] or '—'}\n"
        f"Custo: {format_price(build['cost_cents'])} | "
        f"Cotação (+{build['margin_percent']}%): {format_price(build['quote_cents'])}"
    )
    click.echo("\nItens:")
    for item in build["items"]:
        click.echo(
            f"  #{item['id']} [{item['category_slug']}] {item['label']} x{item['quantity']} "
            f"= {format_price(item['unit_cost_cents'])}"
        )

    if build["events"]:
        click.echo("\nHistórico:")
        for event in build["events"]:
            note = event["notes"] or ""
            click.echo(
                f"  {event['created_at']} | {event['event_type']} "
                f"{event['from_status'] or ''} -> {event['to_status'] or ''} {note}"
            )


@cli.command("set-item")
@click.argument("build_id", type=int)
@click.argument("item_id", type=int)
@click.option("--label", default=None)
@click.option("--cost", "cost_reais", type=float, default=None, help="Preço em reais")
@click.option("--component-id", type=int, default=None)
@click.option("--offer-id", type=int, default=None)
@click.option("--qty", type=int, default=None)
@click.option("--notes", default=None)
def cmd_set_item(
    build_id: int,
    item_id: int,
    label: str | None,
    cost_reais: float | None,
    component_id: int | None,
    offer_id: int | None,
    qty: int | None,
    notes: str | None,
) -> None:
    unit_cost_cents = int(round(cost_reais * 100)
                          ) if cost_reais is not None else None
    set_build_item(
        build_id=build_id,
        item_id=item_id,
        label=label,
        unit_cost_cents=unit_cost_cents,
        component_id=component_id,
        offer_id=offer_id,
        quantity=qty,
        notes=notes,
    )
    click.echo("Item atualizado.")


@cli.command("status")
@click.argument("build_id", type=int)
@click.argument(
    "to_status",
    type=click.Choice([s.value for s in BuildStatus], case_sensitive=False),
)
@click.option("--notes", default=None)
def cmd_status(build_id: int, to_status: str, notes: str | None) -> None:
    build = transition_build_status(
        build_id=build_id,
        to_status=BuildStatus(to_status),
        notes=notes,
    )
    click.echo(f"Montagem {build['code']} agora está em: {build['status']}")


@cli.command("offers")
@click.option("--category", default=None)
@click.option("--limit", default=15, type=int)
def cmd_offers(category: str | None, limit: int) -> None:
    for offer in list_recent_offers(category_slug=category, limit=limit):
        click.echo(
            f"#{offer['id']} [{offer['matched_category_slug'] or '?'}] "
            f"{format_price(offer['price_cents'])} | "
            f"{offer['product_name'] or offer['raw_text'][:70]}"
        )


@cli.command("sync-telegram")
@click.option("--limit", default=100, type=int, help="Mensagens por grupo")
def cmd_sync_telegram(limit: int) -> None:
    sync_main(limit=limit)


@cli.command("listen-telegram")
def cmd_listen_telegram() -> None:
    from src.telegram.listener import main as listen_main

    listen_main()


@cli.command("sites")
def cmd_sites() -> None:
    """Sites BR de referência para cotação e comparação."""
    for site in REFERENCE_SITES:
        click.echo(f"{site['slug']:12} {site['name']}")
        click.echo(f"             {site['url']}")
        click.echo(f"             → {site['use_for']}")
        click.echo("")


@cli.command("wizard-steps")
def cmd_wizard_steps() -> None:
    """Ordem de slots inspirada Pichau/KaBuM/Terabyte."""
    for step in BUILD_WIZARD_STEPS:
        req = "obrig." if step.get("required") else "opc."
        click.echo(
            f"{step['order']:2}. [{step['slug']}] {step['label']} ({req})")


@cli.command("presets")
@click.option("--tier", default=None, help="entry, mid, high, enthusiast")
def cmd_presets(tier: str | None) -> None:
    for preset in list_build_presets(tier):
        click.echo(
            f"{preset['slug']:28} {preset['tier']:12} "
            f"{format_price(preset['total_reference_cents'])}  "
            f"ref:{preset['reference_site']}"
        )


@cli.command("preset")
@click.argument("slug")
def cmd_preset(slug: str) -> None:
    preset = get_build_preset(slug)
    if preset is None:
        raise click.ClickException(f"Preset '{slug}' não encontrado")
    click.echo(
        f"{preset['name']} [{preset['tier']}] — {preset['description']}")
    click.echo(
        f"Total referência: {format_price(preset['total_reference_cents'])}")
    for item in preset["items"]:
        click.echo(
            f"  [{item['category_slug']}] {item['label']}: "
            f"{format_price(item['reference_cents'])}"
        )


@cli.command("new-from-preset")
@click.argument("preset_slug")
@click.option("--title", default=None)
@click.option("--customer", default=None)
@click.option("--contact", default=None)
@click.option("--margin", default=15.0, type=float)
@click.option("--no-prices", is_flag=True, help="Criar sem preços de referência")
def cmd_new_from_preset(
    preset_slug: str,
    title: str | None,
    customer: str | None,
    contact: str | None,
    margin: float,
    no_prices: bool,
) -> None:
    build = create_build_from_preset(
        preset_slug=preset_slug,
        title=title,
        customer_name=customer,
        customer_contact=contact,
        margin_percent=margin,
        use_reference_prices=not no_prices,
    )
    click.echo(
        f"Montagem {build['code']} (#{build['id']}) a partir de preset '{preset_slug}'\n"
        f"Custo ref.: {format_price(build['cost_cents'])} | "
        f"Cotação: {format_price(build['quote_cents'])}"
    )


@cli.command("seed-market")
@click.option("--retailer", "retailer_slug", default="meupc")
def cmd_seed_market(retailer_slug: str) -> None:
    """Importa preços indicativos dos presets para comparação."""
    count = seed_market_from_presets(retailer_slug=retailer_slug)
    click.echo(
        f"{count} preços de referência gravados (fonte: preset → {retailer_slug}).")


@cli.command("market-prices")
@click.option("--category", default=None)
@click.option("--retailer", default=None)
@click.option("--limit", default=30, type=int)
def cmd_market_prices(
    category: str | None, retailer: str | None, limit: int
) -> None:
    for row in list_market_prices(
        category_slug=category, retailer_slug=retailer, limit=limit
    ):
        click.echo(
            f"[{row['retailer_slug']}] {row['category_slug']:16} "
            f"{format_price(row['price_cents'])} — {row['product_name'][:50]}"
        )


@cli.command("add-market-price")
@click.option("--retailer", required=True, help="meupc, kabum, pichau, terabyte…")
@click.option("--category", "category_slug", required=True)
@click.option("--product", required=True)
@click.option("--cost", "cost_reais", type=float, required=True)
@click.option("--url", default=None)
@click.option("--notes", default=None)
def cmd_add_market_price(
    retailer: str,
    category_slug: str,
    product: str,
    cost_reais: float,
    url: str | None,
    notes: str | None,
) -> None:
    price_id = add_market_price(
        retailer_slug=retailer,
        category_slug=category_slug,
        product_name=product,
        price_cents=int(round(cost_reais * 100)),
        url=url,
        notes=notes,
    )
    click.echo(f"Preço de mercado #{price_id} registrado.")


@cli.command("compare-build")
@click.argument("build_id", type=int)
def cmd_compare_build(build_id: int) -> None:
    """Compara sua cotação vs melhor preço mercado/Telegram por slot."""
    try:
        data = compare_build(build_id)
    except ValueError as exc:
        raise click.ClickException(str(exc)) from exc
    click.echo(format_comparison_report(data))


@cli.command("retailers")
def cmd_retailers() -> None:
    for row in list_retailers():
        tag = "agregador" if row["is_aggregator"] else "loja"
        click.echo(f"{row['slug']:12} [{tag}] {row['name']}")
        if row["configurator_url"]:
            click.echo(f"             {row['configurator_url']}")


@cli.command("fetch-market")
@click.option("--build", "build_id", type=int, default=None, help="Cotação existente")
@click.option("--category", "category_slug", default=None)
@click.option("--query", default=None, help="Termo de busca")
@click.option(
    "--providers",
    default=None,
    help="mercadolivre,aliexpress,4gamers (default: MARKET_FETCH_PROVIDERS)",
)
@click.option("--limit", default=2, type=int, help="Resultados por provider/query")
@click.option("--all-categories", is_flag=True, help="Buscar todas as categorias padrão")
@click.option("--dry-run", is_flag=True, help="Não gravar no SQLite")
def cmd_fetch_market(
    build_id: int | None,
    category_slug: str | None,
    query: str | None,
    providers: str | None,
    limit: int,
    all_categories: bool,
    dry_run: bool,
) -> None:
    """Automatiza cotações: Mercado Livre, AliExpress e 4Gamers."""
    provider_list = (
        [p.strip() for p in providers.split(",") if p.strip()]
        if providers
        else market_fetch_providers()
    )
    persist = not dry_run

    if build_id:
        results = fetch_build(
            build_id, providers=provider_list, limit=limit, persist=persist
        )
    elif all_categories:
        results = fetch_all_preset_categories(
            providers=provider_list, limit=limit, persist=persist
        )
    elif category_slug:
        results = fetch_category(
            category_slug=category_slug,
            query=query,
            providers=provider_list,
            limit=limit,
            persist=persist,
        )
    else:
        raise click.ClickException(
            "Use --build ID, --category slug ou --all-categories"
        )

    summary = summarize_results(results)
    click.echo(
        f"Fetch concluído: {summary['runs']} consultas, "
        f"{summary['stored']} gravados, {summary['skipped']} ignorados"
    )
    for result in results:
        if result.errors:
            click.echo(
                f"  ! {result.provider}/{result.query}: {result.errors[0]}")
            continue
        for listing in result.listings[:2]:
            price = format_price(
                listing.price_cents) if listing.price_cents else "—"
            click.echo(
                f"  {result.provider:12} [{result.category_slug}] {price} "
                f"{listing.product_name[:55]}"
            )
            if listing.url:
                click.echo(f"               {listing.url}")


if __name__ == "__main__":
    cli()
