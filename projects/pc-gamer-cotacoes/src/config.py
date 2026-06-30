"""Configuração via variáveis de ambiente."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")

DATABASE_PATH = Path(
    os.getenv("DATABASE_PATH", PROJECT_ROOT / "data" / "pc_gamer.sqlite3")
)
if not DATABASE_PATH.is_absolute():
    DATABASE_PATH = PROJECT_ROOT / DATABASE_PATH

SESSION_DIR = PROJECT_ROOT / "data" / "sessions"
SESSION_DIR.mkdir(parents=True, exist_ok=True)
SESSION_FILE = str(SESSION_DIR / "pc_gamer_userbot")

TELEGRAM_API_ID = os.getenv("TELEGRAM_API_ID", "")
TELEGRAM_API_HASH = os.getenv("TELEGRAM_API_HASH", "")
TELEGRAM_SESSION_STRING = os.getenv("TELEGRAM_SESSION_STRING", "")

DEFAULT_MARGIN_PERCENT = float(os.getenv("DEFAULT_MARGIN_PERCENT", "15"))

# Mercado Livre (opcional — API pública funciona sem token na maioria dos IPs residenciais)
MERCADOLIVRE_ACCESS_TOKEN = os.getenv("MERCADOLIVRE_ACCESS_TOKEN", "")
# Restringir a lojas oficiais (vendedores BR verificados). Default: todos os vendedores BR.
MERCADOLIVRE_ONLY_OFFICIAL = os.getenv(
    "MERCADOLIVRE_ONLY_OFFICIAL", "false"
).lower() in {"1", "true", "yes", "sim"}

# AliExpress Affiliate / IOP (https://portals.aliexpress.com/)
ALIEXPRESS_APP_KEY = os.getenv("ALIEXPRESS_APP_KEY", "")
ALIEXPRESS_APP_SECRET = os.getenv("ALIEXPRESS_APP_SECRET", "")
ALIEXPRESS_TRACKING_ID = os.getenv("ALIEXPRESS_TRACKING_ID", "")
# País de envio/destino para priorizar armazém Brasil ("BR" ou vazio para global)
ALIEXPRESS_SHIP_FROM = os.getenv("ALIEXPRESS_SHIP_FROM", "BR").strip().upper()


def market_fetch_providers() -> list[str]:
    raw = os.getenv("MARKET_FETCH_PROVIDERS",
                    "mercadolivre,pichau,aliexpress,4gamers")
    return [part.strip() for part in raw.split(",") if part.strip()]


def monitor_chats() -> list[str]:
    raw = os.getenv("TELEGRAM_MONITOR_CHATS", "")
    return [part.strip() for part in raw.split(",") if part.strip()]


def require_telegram_credentials() -> tuple[int, str]:
    if not TELEGRAM_API_ID or not TELEGRAM_API_HASH:
        raise RuntimeError(
            "Defina TELEGRAM_API_ID e TELEGRAM_API_HASH em .env "
            "(obter em https://my.telegram.org/apps)"
        )
    return int(TELEGRAM_API_ID), TELEGRAM_API_HASH
