"""Sincroniza histórico recente de grupos Telegram configurados."""

from __future__ import annotations

import asyncio
from datetime import timezone

from telethon.tl.types import Message

from src.catalog.repository import (
    save_telegram_offer,
    update_source_sync_cursor,
    upsert_telegram_source,
)
from src.config import monitor_chats
from src.db.database import init_db
from src.telegram.client import create_client
from src.telegram.parsers.offer_parser import message_hash, parse_offer


async def sync_chat(client, chat_key: str, limit: int = 100) -> dict[str, int]:
    entity = await client.get_entity(chat_key)
    title = getattr(entity, "title", None) or getattr(
        entity, "username", chat_key)
    source_id = upsert_telegram_source(chat_key, title)

    imported = 0
    skipped = 0
    last_id = 0

    async for message in client.iter_messages(entity, limit=limit):
        if not isinstance(message, Message) or not message.message:
            skipped += 1
            continue

        text = message.message.strip()
        if len(text) < 12:
            skipped += 1
            continue

        parsed = parse_offer(text)
        if parsed.price_cents is None and parsed.matched_category_slug is None:
            skipped += 1
            continue

        posted_at = None
        if message.date:
            posted_at = message.date.replace(tzinfo=timezone.utc).isoformat()

        offer_id = save_telegram_offer(
            source_id=source_id,
            message_id=message.id,
            message_hash=message_hash(text, chat_key, message.id),
            raw_text=text,
            posted_at=posted_at,
            parsed=parsed.model_dump(),
        )
        if offer_id:
            imported += 1
        else:
            skipped += 1

        last_id = max(last_id, message.id)

    if last_id:
        update_source_sync_cursor(source_id, last_id)

    return {"imported": imported, "skipped": skipped, "title": title}


async def sync_all(limit: int = 100) -> None:
    chats = monitor_chats()
    if not chats:
        raise RuntimeError(
            "Nenhum chat em TELEGRAM_MONITOR_CHATS. "
            "Use scripts/list_groups.py para descobrir IDs."
        )

    init_db()
    client = create_client()
    await client.start()

    try:
        for chat_key in chats:
            stats = await sync_chat(client, chat_key, limit=limit)
            print(
                f"[{chat_key}] {stats['title']}: "
                f"{stats['imported']} novas, {stats['skipped']} ignoradas"
            )
    finally:
        await client.disconnect()


def main(limit: int = 100) -> None:
    asyncio.run(sync_all(limit=limit))


if __name__ == "__main__":
    main()
