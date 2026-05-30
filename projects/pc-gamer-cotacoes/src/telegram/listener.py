"""Listener em tempo real para novas ofertas nos grupos monitorizados."""

from __future__ import annotations

import asyncio
from datetime import timezone

from telethon import events

from src.catalog.repository import save_telegram_offer, upsert_telegram_source
from src.config import monitor_chats
from src.db.database import init_db
from src.telegram.client import create_client
from src.telegram.parsers.offer_parser import format_price, message_hash, parse_offer


async def run_listener() -> None:
    chats = monitor_chats()
    if not chats:
        raise RuntimeError("Defina TELEGRAM_MONITOR_CHATS no .env")

    init_db()
    client = create_client()
    await client.start()

    source_ids: dict[str, int] = {}
    for chat_key in chats:
        entity = await client.get_entity(chat_key)
        title = getattr(entity, "title", None) or chat_key
        source_ids[chat_key] = upsert_telegram_source(chat_key, title)
        print(f"Monitorizando: {title} ({chat_key})")

    @client.on(events.NewMessage(chats=chats))
    async def handler(event: events.NewMessage.Event) -> None:
        text = (event.raw_text or "").strip()
        if len(text) < 12:
            return

        parsed = parse_offer(text)
        if parsed.price_cents is None and parsed.matched_category_slug is None:
            return

        chat = await event.get_chat()
        chat_key = getattr(chat, "username", None)
        if chat_key:
            chat_key = f"@{chat_key}"
        else:
            chat_key = str(event.chat_id)

        source_id = source_ids.get(chat_key) or upsert_telegram_source(
            chat_key, getattr(chat, "title", chat_key)
        )

        posted_at = None
        if event.message.date:
            posted_at = event.message.date.replace(
                tzinfo=timezone.utc).isoformat()

        offer_id = save_telegram_offer(
            source_id=source_id,
            message_id=event.message.id,
            message_hash=message_hash(text, chat_key, event.message.id),
            raw_text=text,
            posted_at=posted_at,
            parsed=parsed.model_dump(),
        )
        if not offer_id:
            return

        print(
            f"Nova oferta #{offer_id} | {parsed.matched_category_slug or '?'} | "
            f"{format_price(parsed.price_cents)} | {parsed.product_name or text[:60]}"
        )

    print("Listener ativo. Ctrl+C para sair.")
    await client.run_until_disconnected()


def main() -> None:
    asyncio.run(run_listener())


if __name__ == "__main__":
    main()
