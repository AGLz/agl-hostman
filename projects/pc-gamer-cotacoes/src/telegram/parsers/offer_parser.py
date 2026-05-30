"""Parser heurístico de ofertas em mensagens Telegram (PT-BR)."""

from __future__ import annotations

import hashlib
import re
from re import Match
from urllib.parse import urlparse

from src.catalog.models import ParsedOffer

URL_PATTERN = re.compile(r"https?://[^\s<>\"']+", re.IGNORECASE)

# R$ 1.299,90 | R$1299 | 1299,90 | por 999
PRICE_PATTERNS = [
    re.compile(
        r"(?:r\$|rs\.?)\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\d+(?:,\d{2})?)",
        re.IGNORECASE,
    ),
    re.compile(
        r"por\s+(\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\d+(?:,\d{2})?)", re.IGNORECASE),
]

CATEGORY_KEYWORDS: dict[str, tuple[str, ...]] = {
    "placa_video": (
        "rtx",
        "gtx",
        "rx ",
        "radeon",
        "placa de video",
        "placa de vídeo",
        "gpu",
        "geforce",
    ),
    "motherboard": (
        "placa mae",
        "placa-mãe",
        "placa mãe",
        "motherboard",
        "b650",
        "b850",
        "x670",
        "x870",
        "am5",
    ),
    "memoria_ddr5": ("ddr5", "memoria", "memória", "ram", "fury", "vengeance"),
    "nvme": ("nvme", "m.2", "ssd", "samsung 990", "samsung 980", "sn850"),
    "processador": ("ryzen", "processador", "cpu", "7950x", "7800x3d", "7600"),
    "fonte": ("fonte", "psu", "power supply", "80 plus", "gold", "platinum"),
    "gabinete": ("gabinete", "case", "mid tower", "full tower"),
    "water_cooler": ("water cooler", "aio", "liquid cooler", "arctic liquid"),
    "fan": ("fan", "ventoinha", "cooler master", "pwm", "120mm", "140mm"),
    "suporte_vga": ("suporte vga", "gpu bracket", "anti sag", "rise", "holder"),
}

BRAND_HINTS = ("asus", "gigabyte", "msi", "asrock",
               "samsung", "corsair", "kingston")


def message_hash(text: str, chat_key: str, message_id: int) -> str:
    payload = f"{chat_key}:{message_id}:{text.strip()}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _parse_price_cents(raw: str) -> int | None:
    cleaned = raw.strip().replace(".", "").replace(",", ".")
    try:
        value = float(cleaned)
    except ValueError:
        return None
    return int(round(value * 100))


def extract_price(text: str) -> int | None:
    for pattern in PRICE_PATTERNS:
        match = pattern.search(text)
        if match:
            cents = _parse_price_cents(match.group(1))
            if cents and cents >= 1000:
                return cents
    return None


def extract_url(text: str) -> str | None:
    match = URL_PATTERN.search(text)
    if not match:
        return None
    url = match.group(0).rstrip(").,]")
    parsed = urlparse(url)
    if parsed.scheme in {"http", "https"}:
        return url
    return None


def detect_category(text: str) -> tuple[str | None, float, list[str]]:
    lowered = text.lower()
    best_slug: str | None = None
    best_score = 0.0
    hits: list[str] = []

    for slug, keywords in CATEGORY_KEYWORDS.items():
        score = 0.0
        local_hits: list[str] = []
        for keyword in keywords:
            if keyword in lowered:
                score += 1.0
                local_hits.append(keyword)
        if score > best_score:
            best_score = score
            best_slug = slug
            hits = local_hits

    confidence = min(best_score / 3.0, 1.0) if best_slug else 0.0
    return best_slug, confidence, hits


def extract_product_name(text: str) -> str | None:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return None

    candidates: list[str] = []
    for line in lines[:4]:
        if URL_PATTERN.search(line):
            continue
        if re.search(r"^r\$", line, re.IGNORECASE):
            continue
        if len(line) >= 8:
            candidates.append(line)

    if candidates:
        return candidates[0][:240]

    return lines[0][:240]


def parse_offer(text: str) -> ParsedOffer:
    category, confidence, keywords = detect_category(text)
    price_cents = extract_price(text)
    url = extract_url(text)
    product_name = extract_product_name(text)

    if product_name and any(brand in product_name.lower() for brand in BRAND_HINTS):
        confidence = min(confidence + 0.15, 1.0)

    return ParsedOffer(
        product_name=product_name,
        price_cents=price_cents,
        currency="BRL",
        url=url,
        matched_category_slug=category,
        confidence=confidence,
        keywords=keywords,
    )


def format_price(cents: int | None) -> str:
    if cents is None:
        return "—"
    value = cents / 100
    return f"R$ {value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
