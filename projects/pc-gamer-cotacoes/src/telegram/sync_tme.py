"""Sincronização de ofertas via feed público t.me/s/ (sem Telethon)."""

from __future__ import annotations

from dataclasses import dataclass

from src.catalog.repository import (
    save_telegram_offer,
    update_source_sync_cursor,
    upsert_telegram_source,
)
from src.config import monitor_chats
from src.telegram.parsers.offer_parser import message_hash, parse_offer
from src.telegram.scraper_tme import fetch_channel_posts, iso_now


@dataclass
class SyncChannelResult:
    chat_key: str
    imported: int
    skipped: int
    errors: int = 0


def sync_channel(chat_key: str, *, limit: int = 20) -> SyncChannelResult:
    imported = 0
    skipped = 0
    try:
        posts = fetch_channel_posts(chat_key, limit=limit)
    except Exception:
        return SyncChannelResult(chat_key=chat_key, imported=0, skipped=0, errors=1)

    source_id = upsert_telegram_source(chat_key, chat_key)
    last_id = 0

    for post in posts:
        parsed = parse_offer(post.text)
        if parsed.price_cents is None and parsed.matched_category_slug is None:
            skipped += 1
            continue

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
            imported += 1
        else:
            skipped += 1
        last_id = max(last_id, post.message_id)

    if last_id:
        update_source_sync_cursor(source_id, last_id)

    return SyncChannelResult(
        chat_key=chat_key, imported=imported, skipped=skipped, errors=0
    )


def sync_all_channels(*, limit: int = 20) -> list[SyncChannelResult]:
    chats = monitor_chats()
    if not chats:
        raise RuntimeError(
            "Nenhum chat em TELEGRAM_MONITOR_CHATS. "
            "Configure .env ou copie de .env.example."
        )
    return [sync_channel(chat_key, limit=limit) for chat_key in chats]
