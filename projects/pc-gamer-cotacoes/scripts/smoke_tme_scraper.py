#!/usr/bin/env python3
"""Smoke test: scraper t.me/s/ + parser de ofertas (sem Telethon).

Uso:
    python scripts/smoke_tme_scraper.py
    python scripts/smoke_tme_scraper.py --limit 10 --persist
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.catalog.repository import (  # noqa: E402
    save_telegram_offer,
    upsert_telegram_source,
)
from src.config import monitor_chats  # noqa: E402
from src.db.database import init_db  # noqa: E402
from src.telegram.parsers.offer_parser import (  # noqa: E402
    format_price,
    message_hash,
    parse_offer,
)
from src.telegram.scraper_tme import fetch_channel_posts, iso_now  # noqa: E402


def run_smoke(*, limit: int, persist: bool) -> int:
    chats = monitor_chats()
    if not chats:
        print("ERRO: TELEGRAM_MONITOR_CHATS vazio (copie .env.example → .env)")
        return 1

    if persist:
        init_db()

    total_posts = 0
    total_offers = 0
    total_saved = 0
    errors = 0

    print(
        f"Smoke test t.me/s/ — {len(chats)} canais, limit={limit}, persist={persist}\n")

    for chat_key in chats:
        print(f"=== {chat_key} ===")
        try:
            posts = fetch_channel_posts(chat_key, limit=limit)
        except Exception as exc:  # noqa: BLE001
            print(f"  FALHA fetch: {exc!r}")
            errors += 1
            continue

        total_posts += len(posts)
        channel_offers = 0
        channel_saved = 0

        source_id = upsert_telegram_source(
            chat_key, chat_key) if persist else 0

        for post in posts:
            parsed = parse_offer(post.text)
            is_offer = parsed.price_cents is not None or parsed.matched_category_slug
            if not is_offer:
                continue
            channel_offers += 1
            total_offers += 1

            if channel_offers <= 2:
                price = format_price(parsed.price_cents)
                cat = parsed.matched_category_slug or "—"
                name = (parsed.product_name or post.text.splitlines()[0])[:60]
                print(f"  [{post.message_id}] {price} | {cat} | {name}")

            if persist and source_id:
                offer_id = save_telegram_offer(
                    source_id=source_id,
                    message_id=post.message_id,
                    message_hash=message_hash(
                        post.text, post.chat_key, post.message_id),
                    raw_text=post.text,
                    posted_at=iso_now(),
                    parsed=parsed.model_dump(),
                )
                if offer_id:
                    channel_saved += 1
                    total_saved += 1

        print(
            f"  posts={len(posts)} ofertas_parse={channel_offers}"
            + (f" gravadas={channel_saved}" if persist else "")
        )
        print()

    print("--- RESUMO ---")
    print(
        f"Canais: {len(chats)} | posts: {total_posts} | ofertas: {total_offers} | erros: {errors}")
    if persist:
        print(f"Gravadas em telegram_offers: {total_saved}")
    return 1 if errors else 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Smoke test scraper t.me/s/")
    parser.add_argument("--limit", type=int, default=15,
                        help="Mensagens por canal")
    parser.add_argument(
        "--persist",
        action="store_true",
        help="Gravar ofertas parseadas em SQLite (init_db)",
    )
    args = parser.parse_args()
    raise SystemExit(run_smoke(limit=args.limit, persist=args.persist))


if __name__ == "__main__":
    main()
