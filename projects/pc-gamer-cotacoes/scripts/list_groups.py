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
        print(f"{'ID':>18}  {'Tipo':<11}  {'t.me/s/':<8}  Nome -> handle")
        print("-" * 80)
        count = 0
        monitor: list[str] = []
        async for dialog in client.iter_dialogs():
            entity = dialog.entity
            if not (dialog.is_group or dialog.is_channel):
                continue
            username = getattr(entity, "username", None)
            handle = f"@{username}" if username else str(dialog.id)
            # Reason: no MTProto canais e supergrupos são ambos Channel;
            # broadcast=canal puro (fallback t.me/s/), megagroup=supergrupo
            if getattr(entity, "broadcast", False):
                kind = "canal"
            elif getattr(entity, "megagroup", False):
                kind = "supergrupo"
            elif dialog.is_channel:
                kind = "canal?"
            else:
                kind = "grupo"
            fallback = "✓" if (getattr(entity, "broadcast",
                               False) and username) else "—"
            print(
                f"{dialog.id:>18}  {kind:<11}  {fallback:<8}  {dialog.name} -> {handle}")
            monitor.append(handle)
            count += 1
            if count >= limit:
                break
        print("\nCopie handles (@...) ou IDs para TELEGRAM_MONITOR_CHATS no .env:")
        print("TELEGRAM_MONITOR_CHATS=" + ",".join(monitor))
    finally:
        await client.disconnect()


def main() -> None:
    asyncio.run(list_dialogs())


if __name__ == "__main__":
    main()
