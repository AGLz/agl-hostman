"""Cliente Telethon partilhado."""

from __future__ import annotations

from telethon import TelegramClient
from telethon.sessions import StringSession

from src.config import (
    SESSION_FILE,
    TELEGRAM_SESSION_STRING,
    require_telegram_credentials,
)


def create_client() -> TelegramClient:
    api_id, api_hash = require_telegram_credentials()
    if TELEGRAM_SESSION_STRING:
        session: StringSession | str = StringSession(TELEGRAM_SESSION_STRING)
    else:
        session = SESSION_FILE
    return TelegramClient(session, api_id, api_hash)
