"""Scraper do feed público t.me/s/<canal> (fallback sem Telethon)."""

from __future__ import annotations

import html
import re
from dataclasses import dataclass
from datetime import datetime, timezone

from src.market.http import get_client

# Reason: blocos de mensagem no HTML público do Telegram Web
_MESSAGE_BLOCK = re.compile(
    r'data-post="(?P<post>[^"]+)"[^>]*>.*?'
    r'class="tgme_widget_message_text[^"]*"[^>]*>(?P<body>.*?)</div>',
    re.S,
)


@dataclass(frozen=True)
class TmePost:
    chat_key: str
    message_id: int
    text: str
    post_url: str


def username_from_chat_key(chat_key: str) -> str | None:
    """Extrai username de @canal ou URL t.me."""
    key = chat_key.strip()
    if key.startswith("@"):
        return key[1:]
    match = re.search(r"(?:t\.me/|telegram\.me/)([A-Za-z0-9_]{4,32})", key)
    return match.group(1) if match else None


def _html_to_text(raw: str) -> str:
    text = re.sub(r"<br\s*/?>", "\n", raw, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    return html.unescape(text).strip()


def parse_feed_html(chat_key: str, html_page: str, limit: int = 20) -> list[TmePost]:
    """Extrai mensagens de uma página t.me/s/ já obtida."""
    username = username_from_chat_key(chat_key) or chat_key.lstrip("@")
    posts: list[TmePost] = []
    for match in _MESSAGE_BLOCK.finditer(html_page):
        post_path = match.group("post")
        if "/" not in post_path:
            continue
        _, msg_id_raw = post_path.rsplit("/", 1)
        try:
            message_id = int(msg_id_raw)
        except ValueError:
            continue
        text = _html_to_text(match.group("body"))
        if len(text) < 12:
            continue
        posts.append(
            TmePost(
                chat_key=f"@{username}",
                message_id=message_id,
                text=text,
                post_url=f"https://t.me/{post_path}",
            )
        )
        if len(posts) >= limit:
            break
    return posts


def fetch_channel_posts(chat_key: str, limit: int = 20) -> list[TmePost]:
    """Obtém as últimas mensagens visíveis no feed público t.me/s/."""
    username = username_from_chat_key(chat_key)
    if not username:
        raise ValueError(f"Chat key inválido para t.me/s/: {chat_key!r}")

    url = f"https://t.me/s/{username}"
    with get_client(timeout=30) as client:
        response = client.get(url, follow_redirects=True)
        response.raise_for_status()
        html_page = response.text

    if "tgme_widget_message" not in html_page:
        raise RuntimeError(f"Feed vazio ou bloqueado para {chat_key} ({url})")

    return parse_feed_html(chat_key, html_page, limit=limit)


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()
