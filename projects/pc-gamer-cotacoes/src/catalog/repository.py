"""Repositório SQLite para catálogo, montagens e ofertas."""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from typing import Any

from src.catalog.models import BUILD_TEMPLATE_AMD_GAMER, BuildStatus, BuildSummary
from src.db.database import connect, row_to_dict


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def list_categories() -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            "SELECT slug, name, sort_order FROM component_categories ORDER BY sort_order"
        ).fetchall()
    return [dict(row) for row in rows]


def add_component(
    *,
    category_slug: str,
    model: str,
    brand: str | None = None,
    sku: str | None = None,
    specs: dict[str, Any] | None = None,
    notes: str | None = None,
) -> int:
    specs_json = json.dumps(specs or {}, ensure_ascii=False)
    with connect() as conn:
        category = conn.execute(
            "SELECT id FROM component_categories WHERE slug = ?",
            (category_slug,),
        ).fetchone()
        if category is None:
            raise ValueError(f"Categoria desconhecida: {category_slug}")

        cursor = conn.execute(
            """
            INSERT INTO components (category_id, sku, brand, model, specs_json, notes)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (category["id"], sku, brand, model, specs_json, notes),
        )
        return int(cursor.lastrowid)


def list_components(category_slug: str | None = None) -> list[dict[str, Any]]:
    query = """
        SELECT c.id, cc.slug AS category_slug, cc.name AS category_name,
               c.brand, c.model, c.sku, c.specs_json, c.notes, c.active
        FROM components c
        JOIN component_categories cc ON cc.id = c.category_id
    """
    params: tuple[Any, ...] = ()
    if category_slug:
        query += " WHERE cc.slug = ?"
        params = (category_slug,)
    query += " ORDER BY cc.sort_order, c.brand, c.model"

    with connect() as conn:
        rows = conn.execute(query, params).fetchall()
    result = []
    for row in rows:
        item = dict(row)
        item["specs"] = json.loads(item.pop("specs_json") or "{}")
        result.append(item)
    return result


def _next_build_code(conn: sqlite3.Connection) -> str:
    year = datetime.now().year
    prefix = f"PC-{year}-"
    row = conn.execute(
        "SELECT code FROM builds WHERE code LIKE ? ORDER BY code DESC LIMIT 1",
        (f"{prefix}%",),
    ).fetchone()
    if row is None:
        return f"{prefix}001"
    last_num = int(str(row["code"]).split("-")[-1])
    return f"{prefix}{last_num + 1:03d}"


def create_build(
    *,
    title: str,
    customer_name: str | None = None,
    customer_contact: str | None = None,
    platform: str = "amd",
    margin_percent: float = 15.0,
    notes: str | None = None,
    use_template: bool = True,
) -> dict[str, Any]:
    with connect() as conn:
        code = _next_build_code(conn)
        cursor = conn.execute(
            """
            INSERT INTO builds (code, title, customer_name, customer_contact,
                                platform, margin_percent, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (code, title, customer_name, customer_contact,
             platform, margin_percent, notes),
        )
        build_id = int(cursor.lastrowid)
        conn.execute(
            """
            INSERT INTO build_events (build_id, event_type, to_status, notes)
            VALUES (?, 'created', ?, ?)
            """,
            (build_id, BuildStatus.DRAFT.value, "Montagem criada"),
        )

        if use_template:
            for index, slot in enumerate(BUILD_TEMPLATE_AMD_GAMER):
                conn.execute(
                    """
                    INSERT INTO build_items
                        (build_id, category_slug, label, sort_order, source)
                    VALUES (?, ?, ?, ?, 'template')
                    """,
                    (build_id, slot["category_slug"],
                     slot["label"], index * 10),
                )

    build = get_build(build_id)
    assert build is not None
    return build


def get_build(build_id: int) -> dict[str, Any] | None:
    with connect() as conn:
        build = row_to_dict(
            conn.execute("SELECT * FROM builds WHERE id = ?",
                         (build_id,)).fetchone()
        )
        if build is None:
            return None
        items = conn.execute(
            """
            SELECT bi.*, c.brand, c.model AS component_model
            FROM build_items bi
            LEFT JOIN components c ON c.id = bi.component_id
            WHERE bi.build_id = ?
            ORDER BY bi.sort_order, bi.id
            """,
            (build_id,),
        ).fetchall()
        events = conn.execute(
            """
            SELECT event_type, from_status, to_status, notes, created_at
            FROM build_events
            WHERE build_id = ?
            ORDER BY id
            """,
            (build_id,),
        ).fetchall()

    build["items"] = [dict(row) for row in items]
    build["events"] = [dict(row) for row in events]
    build["cost_cents"] = sum(
        int(item["unit_cost_cents"]) * int(item["quantity"]) for item in build["items"]
    )
    margin = float(build["margin_percent"])
    build["quote_cents"] = int(round(build["cost_cents"] * (1 + margin / 100)))
    return build


def list_builds(status: str | None = None) -> list[BuildSummary]:
    query = "SELECT id, code, title, status, customer_name, margin_percent FROM builds"
    params: tuple[Any, ...] = ()
    if status:
        query += " WHERE status = ?"
        params = (status,)
    query += " ORDER BY updated_at DESC, id DESC"

    summaries: list[BuildSummary] = []
    with connect() as conn:
        builds = conn.execute(query, params).fetchall()
        for build in builds:
            row = conn.execute(
                """
                SELECT COUNT(*) AS item_count,
                       COALESCE(SUM(unit_cost_cents * quantity), 0) AS cost_cents
                FROM build_items WHERE build_id = ?
                """,
                (build["id"],),
            ).fetchone()
            cost = int(row["cost_cents"])
            margin = float(build["margin_percent"])
            summaries.append(
                BuildSummary(
                    id=int(build["id"]),
                    code=str(build["code"]),
                    title=str(build["title"]),
                    status=str(build["status"]),
                    customer_name=build["customer_name"],
                    cost_cents=cost,
                    quote_cents=int(round(cost * (1 + margin / 100))),
                    margin_percent=margin,
                    item_count=int(row["item_count"]),
                )
            )
    return summaries


def set_build_item(
    *,
    build_id: int,
    item_id: int,
    label: str | None = None,
    unit_cost_cents: int | None = None,
    component_id: int | None = None,
    offer_id: int | None = None,
    quantity: int | None = None,
    notes: str | None = None,
) -> None:
    fields: list[str] = []
    values: list[Any] = []
    mapping = {
        "label": label,
        "unit_cost_cents": unit_cost_cents,
        "component_id": component_id,
        "offer_id": offer_id,
        "quantity": quantity,
        "notes": notes,
    }
    for key, value in mapping.items():
        if value is not None:
            fields.append(f"{key} = ?")
            values.append(value)

    if not fields:
        return

    values.extend([build_id, item_id])
    with connect() as conn:
        conn.execute(
            f"UPDATE build_items SET {', '.join(fields)} WHERE build_id = ? AND id = ?",
            values,
        )
        conn.execute(
            "UPDATE builds SET updated_at = ? WHERE id = ?",
            (_now_iso(), build_id),
        )


def transition_build_status(
    *,
    build_id: int,
    to_status: BuildStatus,
    notes: str | None = None,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    with connect() as conn:
        current = conn.execute(
            "SELECT status FROM builds WHERE id = ?", (build_id,)
        ).fetchone()
        if current is None:
            raise ValueError(f"Montagem {build_id} não encontrada")

        from_status = str(current["status"])
        conn.execute(
            "UPDATE builds SET status = ?, updated_at = ? WHERE id = ?",
            (to_status.value, _now_iso(), build_id),
        )
        conn.execute(
            """
            INSERT INTO build_events
                (build_id, event_type, from_status, to_status, payload_json, notes)
            VALUES (?, 'status_change', ?, ?, ?, ?)
            """,
            (
                build_id,
                from_status,
                to_status.value,
                json.dumps(payload or {}, ensure_ascii=False),
                notes,
            ),
        )

    build = get_build(build_id)
    assert build is not None
    return build


def upsert_telegram_source(chat_key: str, title: str | None = None) -> int:
    with connect() as conn:
        row = conn.execute(
            "SELECT id FROM telegram_sources WHERE chat_key = ?", (chat_key,)
        ).fetchone()
        if row:
            if title:
                conn.execute(
                    "UPDATE telegram_sources SET title = ? WHERE id = ?",
                    (title, row["id"]),
                )
            return int(row["id"])

        cursor = conn.execute(
            "INSERT INTO telegram_sources (chat_key, title) VALUES (?, ?)",
            (chat_key, title),
        )
        return int(cursor.lastrowid)


def save_telegram_offer(
    *,
    source_id: int,
    message_id: int,
    message_hash: str,
    raw_text: str,
    posted_at: str | None,
    parsed: dict[str, Any],
) -> int | None:
    with connect() as conn:
        try:
            cursor = conn.execute(
                """
                INSERT INTO telegram_offers
                    (source_id, message_id, message_hash, posted_at, raw_text,
                     parsed_json, product_name, price_cents, currency, url,
                     matched_category_slug, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'new')
                """,
                (
                    source_id,
                    message_id,
                    message_hash,
                    posted_at,
                    raw_text,
                    json.dumps(parsed, ensure_ascii=False),
                    parsed.get("product_name"),
                    parsed.get("price_cents"),
                    parsed.get("currency", "BRL"),
                    parsed.get("url"),
                    parsed.get("matched_category_slug"),
                ),
            )
            return int(cursor.lastrowid)
        except sqlite3.IntegrityError:
            return None


def list_recent_offers(
    *,
    category_slug: str | None = None,
    limit: int = 20,
) -> list[dict[str, Any]]:
    query = """
        SELECT o.id, s.chat_key, s.title AS source_title, o.product_name,
               o.price_cents, o.currency, o.url, o.matched_category_slug,
               o.posted_at, o.raw_text
        FROM telegram_offers o
        JOIN telegram_sources s ON s.id = o.source_id
    """
    params: list[Any] = []
    if category_slug:
        query += " WHERE o.matched_category_slug = ?"
        params.append(category_slug)
    query += " ORDER BY o.posted_at DESC, o.id DESC LIMIT ?"
    params.append(limit)

    with connect() as conn:
        rows = conn.execute(query, params).fetchall()
    return [dict(row) for row in rows]


def update_source_sync_cursor(source_id: int, message_id: int) -> None:
    with connect() as conn:
        conn.execute(
            """
            UPDATE telegram_sources
            SET last_synced_message_id = ?
            WHERE id = ?
            """,
            (message_id, source_id),
        )


def list_retailers() -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT slug, name, website, configurator_url, is_aggregator, notes
            FROM retailers ORDER BY is_aggregator DESC, name
            """
        ).fetchall()
    return [dict(row) for row in rows]


def get_retailer_id(slug: str) -> int | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT id FROM retailers WHERE slug = ?", (slug,)
        ).fetchone()
    return int(row["id"]) if row else None


def add_market_price(
    *,
    retailer_slug: str,
    category_slug: str,
    product_name: str,
    price_cents: int,
    url: str | None = None,
    source: str = "manual",
    notes: str | None = None,
) -> int:
    retailer_id = get_retailer_id(retailer_slug)
    if retailer_id is None:
        raise ValueError(f"Loja desconhecida: {retailer_slug}")

    with connect() as conn:
        cursor = conn.execute(
            """
            INSERT INTO market_prices
                (retailer_id, category_slug, product_name, price_cents, url, source, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (retailer_id, category_slug, product_name,
             price_cents, url, source, notes),
        )
        return int(cursor.lastrowid)


def list_market_prices(
    *,
    category_slug: str | None = None,
    retailer_slug: str | None = None,
    limit: int = 50,
) -> list[dict[str, Any]]:
    query = """
        SELECT mp.id, r.slug AS retailer_slug, r.name AS retailer_name,
               mp.category_slug, mp.product_name, mp.price_cents, mp.url,
               mp.recorded_at, mp.source, mp.notes
        FROM market_prices mp
        JOIN retailers r ON r.id = mp.retailer_id
        WHERE 1=1
    """
    params: list[Any] = []
    if category_slug:
        query += " AND mp.category_slug = ?"
        params.append(category_slug)
    if retailer_slug:
        query += " AND r.slug = ?"
        params.append(retailer_slug)
    query += " ORDER BY mp.category_slug, mp.price_cents ASC LIMIT ?"
    params.append(limit)

    with connect() as conn:
        rows = conn.execute(query, params).fetchall()
    return [dict(row) for row in rows]


def seed_build_presets() -> int:
    from src.catalog.presets import presets_as_json_rows

    inserted = 0
    with connect() as conn:
        for row in presets_as_json_rows():
            existing = conn.execute(
                "SELECT id FROM build_presets WHERE slug = ?", (row["slug"],)
            ).fetchone()
            if existing:
                conn.execute(
                    """
                    UPDATE build_presets
                    SET name = ?, tier = ?, platform = ?, reference_site = ?,
                        description = ?, total_reference_cents = ?, items_json = ?,
                        updated_at = ?
                    WHERE slug = ?
                    """,
                    (
                        row["name"],
                        row["tier"],
                        row["platform"],
                        row["reference_site"],
                        row["description"],
                        row["total_reference_cents"],
                        row["items_json"],
                        _now_iso(),
                        row["slug"],
                    ),
                )
            else:
                conn.execute(
                    """
                    INSERT INTO build_presets
                        (slug, name, tier, platform, reference_site, description,
                         total_reference_cents, items_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        row["slug"],
                        row["name"],
                        row["tier"],
                        row["platform"],
                        row["reference_site"],
                        row["description"],
                        row["total_reference_cents"],
                        row["items_json"],
                    ),
                )
                inserted += 1
    return inserted


def seed_market_from_presets(retailer_slug: str = "meupc") -> int:
    """Importa preços de referência dos presets como baseline de mercado."""
    from src.catalog.presets import BUILD_PRESETS

    count = 0
    for preset in BUILD_PRESETS:
        for item in preset["items"]:
            add_market_price(
                retailer_slug=retailer_slug,
                category_slug=item["category_slug"],
                product_name=f"[{preset['slug']}] {item['label']}",
                price_cents=int(item["reference_cents"]),
                source="preset_reference",
                notes=f"Referência indicativa tier {preset['tier']}",
            )
            count += 1
    return count


def list_build_presets(tier: str | None = None) -> list[dict[str, Any]]:
    query = """
        SELECT slug, name, tier, platform, reference_site, description,
               total_reference_cents, items_json, updated_at
        FROM build_presets
    """
    params: tuple[Any, ...] = ()
    if tier:
        query += " WHERE tier = ?"
        params = (tier,)
    query += " ORDER BY total_reference_cents ASC"

    with connect() as conn:
        rows = conn.execute(query, params).fetchall()

    result = []
    for row in rows:
        item = dict(row)
        item["items"] = json.loads(item.pop("items_json") or "[]")
        result.append(item)
    return result


def get_build_preset(slug: str) -> dict[str, Any] | None:
    presets = list_build_presets()
    for preset in presets:
        if preset["slug"] == slug:
            return preset
    return None


def create_build_from_preset(
    *,
    preset_slug: str,
    title: str | None = None,
    customer_name: str | None = None,
    customer_contact: str | None = None,
    margin_percent: float = 15.0,
    use_reference_prices: bool = True,
) -> dict[str, Any]:
    preset = get_build_preset(preset_slug)
    if preset is None:
        raise ValueError(f"Preset desconhecido: {preset_slug}")

    build = create_build(
        title=title or preset["name"],
        customer_name=customer_name,
        customer_contact=customer_contact,
        platform="amd",
        margin_percent=margin_percent,
        notes=f"Base preset: {preset_slug} ({preset['reference_site']})",
        use_template=False,
    )

    with connect() as conn:
        for index, item in enumerate(preset["items"]):
            cost = int(item.get("reference_cents", 0)
                       ) if use_reference_prices else 0
            conn.execute(
                """
                INSERT INTO build_items
                    (build_id, category_slug, label, unit_cost_cents, sort_order, source)
                VALUES (?, ?, ?, ?, ?, 'preset')
                """,
                (
                    build["id"],
                    item["category_slug"],
                    item["label"],
                    cost,
                    index * 10,
                ),
            )
        conn.execute(
            "UPDATE builds SET updated_at = ? WHERE id = ?",
            (_now_iso(), build["id"]),
        )

    refreshed = get_build(int(build["id"]))
    assert refreshed is not None
    return refreshed
