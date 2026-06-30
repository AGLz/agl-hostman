#!/usr/bin/env python3
"""Classifica chats Telegram públicos (canal broadcast vs grupo) por HTTP.

Não requer credenciais Telethon nem que a conta seja membro: usa as páginas
públicas `t.me`. Responde a duas perguntas para cada chat:

1. É **canal** (broadcast) ou **grupo/supergrupo**?
2. O fallback `https://t.me/s/<nome>` está disponível? (só canais broadcast públicos)

Para chats **privados** (links de convite `t.me/+...` ou `joinchat/...`) não há
página pública: entrar com a conta userbot e usar `scripts/list_groups.py`.

Uso:
    python scripts/classify_chats.py @canal1 https://t.me/canal2 nome3
"""

from __future__ import annotations

import re
import sys

import httpx

UA = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
}

INVITE_MARKERS = ("/+", "/joinchat/")


def parse_username(token: str) -> str | None:
    """Extrai o @username público de um token (@nome, t.me/nome, link, nome).

    Devolve None para links de convite privados ou tokens inválidos.
    """
    token = token.strip()
    if not token or token.startswith("+") or any(m in token for m in INVITE_MARKERS):
        return None
    match = re.search(
        r"(?:https?://)?(?:t\.me/|telegram\.me/|@)?([A-Za-z0-9_]{4,32})/?$", token
    )
    return match.group(1) if match else None


def classify(username: str) -> dict:
    base = f"https://t.me/{username}"
    feed = f"https://t.me/s/{username}"
    result = {
        "username": username,
        "type": "desconhecido",
        "public": False,
        "tme_s_fallback": False,
        "monitor_value": f"@{username}",
        "note": "",
    }
    with httpx.Client(headers=UA, timeout=15, follow_redirects=True) as client:
        try:
            response = client.get(base)
        except Exception as exc:  # noqa: BLE001
            result["note"] = f"erro de rede: {exc!r}"
            return result

        html = response.text
        if response.status_code != 200 or "tgme_page" not in html:
            result["note"] = "privado/inexistente — entrar com a conta e usar list_groups.py"
            return result

        result["public"] = True
        extra = re.search(r'tgme_page_extra">([^<]+)<', html)
        label = extra.group(1).lower() if extra else ""
        # Reason: a página pública rotula canais com "subscribers" e grupos com "members"
        if "subscriber" in label or "inscrito" in label:
            result["type"] = "canal"
        elif "member" in label or "membro" in label:
            result["type"] = "grupo"
        elif "bot" in label:
            result["type"] = "bot"

        try:
            feed_response = client.get(feed)
            if feed_response.status_code == 200 and "tgme_widget_message" in feed_response.text:
                result["tme_s_fallback"] = True
                if result["type"] in ("desconhecido", "canal"):
                    result["type"] = "canal"
        except Exception:  # noqa: BLE001
            pass

    if result["type"] == "grupo":
        result["note"] = "sem fallback t.me/s/ — depende do userbot Telethon"
    elif result["type"] == "canal" and not result["tme_s_fallback"]:
        result["note"] = "canal sem feed público — usar userbot Telethon"
    return result


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 1

    rows: list[dict] = []
    for token in argv:
        username = parse_username(token)
        if username is None:
            rows.append(
                {
                    "username": token,
                    "type": "privado",
                    "public": False,
                    "tme_s_fallback": False,
                    "monitor_value": "ID numérico (list_groups.py)",
                    "note": "link de convite — entrar com a conta userbot primeiro",
                }
            )
            continue
        rows.append(classify(username))

    print(f"{'Chat':<28}{'Tipo':<12}{'t.me/s/':<9}Nota")
    print("-" * 90)
    monitor: list[str] = []
    for row in rows:
        fallback = "✓" if row["tme_s_fallback"] else "—"
        name = row["username"] if row["username"].startswith(
            "@") else f"@{row['username']}"
        if row["type"] in ("privado",):
            name = row["username"]
        print(f"{name:<28}{row['type']:<12}{fallback:<9}{row['note']}")
        if row["public"] and row["type"] in ("canal", "grupo"):
            monitor.append(f"@{row['username']}")

    if monitor:
        print("\nTELEGRAM_MONITOR_CHATS=" + ",".join(monitor))
        print("(adicionar IDs numéricos dos privados via scripts/list_groups.py)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
