#!/usr/bin/env python3
"""Lista diálogos Telegram para configurar TELEGRAM_MONITOR_CHATS."""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.telegram.client import create_client  # noqa: E402


async def list_dialogs(limit: int = 80) -> None:
    client = create_client()
    await client.start()
    try:
        print(f"{'ID':>18}  {'Tipo':<10}  Nome")
        print("-" * 72)
        count = 0
        async for dialog in client.iter_dialogs():
            entity = dialog.entity
            if not (dialog.is_group or dialog.is_channel):
                continue
            username = getattr(entity, "username", None)
            handle = f"@{username}" if username else str(dialog.id)
            kind = "canal" if dialog.is_channel else "grupo"
            print(f"{dialog.id:>18}  {kind:<10}  {dialog.name}  -> {handle}")
            count += 1
            if count >= limit:
                break
        print("\nCopie handles (@...) ou IDs para TELEGRAM_MONITOR_CHATS no .env")
    finally:
        await client.disconnect()


def main() -> None:
    asyncio.run(list_dialogs())


if __name__ == "__main__":
    main()
