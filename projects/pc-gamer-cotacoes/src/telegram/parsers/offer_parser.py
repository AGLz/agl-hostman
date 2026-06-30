"""Parser heurístico de ofertas em mensagens Telegram (PT-BR)."""

from __future__ import annotations

import hashlib
import re
from re import Match
from urllib.parse import urlparse

from src.catalog.models import OfferRequirements, ParsedOffer

URL_PATTERN = re.compile(r"https?://[^\s<>\"']+", re.IGNORECASE)

# Reason: captura bloco numérico após R$ — parse inteligente em _parse_price_cents
PRICE_LINE = re.compile(
    r"(?:r\$|rs\.?)\s*([\d][\d.\s,]*)",
    re.IGNORECASE,
)

COUPON_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"`([A-Z0-9][A-Z0-9_-]{3,23})`", re.IGNORECASE),
    re.compile(r"cupom[:\s]+`?([A-Z0-9][A-Z0-9_-]{3,23})`?", re.IGNORECASE),
    re.compile(
        r"c[oó]digo[:\s]+`?([A-Z0-9][A-Z0-9_-]{3,23})`?", re.IGNORECASE),
)

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

RETAILER_DOMAINS: dict[str, tuple[str, ...]] = {
    "aliexpress": ("aliexpress.com", "a.aliexpress.com", "s.click.aliexpress.com"),
    "shopee": ("shopee.com.br", "s.shopee.com.br"),
    "mercadolivre": ("mercadolivre.com.br", "meli.la", "mercadolibre.com"),
    "kabum": ("kabum.com.br", "tidd.ly"),
    "terabyte": ("terabyteshop.com.br", "terabyte.com.br", "aoferta.net"),
    "amazon": ("amazon.com.br", "amzn.to", "amzn.com"),
    "magalu": ("magazineluiza.com.br", "magalu.com"),
    "pichau": ("pichau.com.br",),
}


def message_hash(text: str, chat_key: str, message_id: int) -> str:
    payload = f"{chat_key}:{message_id}:{text.strip()}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _parse_price_cents(raw: str) -> int | None:
    token = raw.strip().split()[0].replace(" ", "")
    if not token:
        return None

    if "," in token:
        cleaned = token.replace(".", "").replace(",", ".")
    elif token.count(".") >= 1 and len(token.split(".")[-1]) == 3:
        cleaned = token.replace(".", "")
    else:
        cleaned = token.replace(".", "") if token.count(
            ".") == 1 and len(token.split(".")[-1]) <= 2 else token

    try:
        value = float(cleaned)
    except ValueError:
        return None
    if value <= 0:
        return None
    return int(round(value * 100))


def extract_price(text: str) -> int | None:
    candidates: list[int] = []
    for match in PRICE_LINE.finditer(text):
        cents = _parse_price_cents(match.group(1))
        if cents and cents >= 1000:
            candidates.append(cents)
    if not candidates:
        return None
    # Reason: posts misturam cupom "R$ 10 OFF" com preço real — usar o maior plausível
    plausible = [c for c in candidates if c <= 50_000_000]
    return max(plausible) if plausible else max(candidates)


def extract_url(text: str) -> str | None:
    match = URL_PATTERN.search(text)
    if not match:
        return None
    url = match.group(0).rstrip(").,]")
    parsed = urlparse(url)
    if parsed.scheme in {"http", "https"}:
        return url
    return None


def extract_all_urls(text: str) -> list[str]:
    urls: list[str] = []
    for match in URL_PATTERN.finditer(text):
        url = match.group(0).rstrip(").,]")
        if urlparse(url).scheme in {"http", "https"}:
            urls.append(url)
    return urls


def detect_retailer(text: str, url: str | None) -> str | None:
    haystack = f"{text}\n{url or ''}".lower()
    for slug, domains in RETAILER_DOMAINS.items():
        if any(domain in haystack for domain in domains):
            return slug
    return None


def extract_coupon_codes(text: str) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()
    for pattern in COUPON_PATTERNS:
        for match in pattern.finditer(text):
            code = match.group(1).upper()
            if code in seen:
                continue
            seen.add(code)
            found.append(code)
    return found


def extract_requirements(text: str, url: str | None) -> OfferRequirements:
    lowered = text.lower()
    conditions: list[str] = []
    requires_coins = any(
        kw in lowered
        for kw in ("moedas", "super moedas", "super moeda", "coins", "moeda no app")
    )
    requires_app = any(
        kw in lowered
        for kw in ("somente no app", "só no app", "only app", "no app com moedas", "no app,")
    )
    requires_pix = any(
        kw in lowered
        for kw in ("pix", "pagamento pix", "só pix", "somente pix", "pague com pix")
    )
    is_flash = any(
        kw in lowered
        for kw in (
            "esgota",
            "correria",
            "limitado",
            "relâmpago",
            "relampago",
            "flash",
            "age rápido",
            "age rapido",
            "muito rapido",
            "muito rápido",
            "nao espera",
            "não espera",
        )
    )

    if requires_coins:
        conditions.append("moedas")
    if requires_app:
        conditions.append("app_only")
    if requires_pix:
        conditions.append("pix")
    if is_flash:
        conditions.append("flash")

    retailer = detect_retailer(text, url)
    if retailer == "aliexpress" and not requires_coins and "aliexpress" in lowered:
        if "app" in lowered:
            requires_app = True
            if "app_only" not in conditions:
                conditions.append("app_only")

    return OfferRequirements(
        requires_coins=requires_coins,
        requires_app=requires_app,
        requires_pix=requires_pix,
        coupon_codes=extract_coupon_codes(text),
        retailer=retailer,
        is_flash=is_flash,
        conditions=conditions,
    )


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


def pick_product_url(text: str) -> str | None:
    """Prefere URL de produto sobre links de cupom/lista."""
    urls = extract_all_urls(text)
    if not urls:
        return None
    product_hints = (
        "produto",
        "product",
        "item",
        "aliexpress.com/_",
        "shopee.com.br",
        "mercadolivre.com.br",
        "kabum.com.br",
        "terabyte",
        "amazon.com.br",
    )
    for url in urls:
        lower = url.lower()
        if any(h in lower for h in product_hints):
            return url
    return urls[-1]


def parse_offer(text: str) -> ParsedOffer:
    category, confidence, keywords = detect_category(text)
    price_cents = extract_price(text)
    url = pick_product_url(text)
    product_name = extract_product_name(text)
    requirements = extract_requirements(text, url)

    if product_name and any(brand in product_name.lower() for brand in BRAND_HINTS):
        confidence = min(confidence + 0.15, 1.0)
    if requirements.coupon_codes or requirements.requires_coins:
        confidence = min(confidence + 0.05, 1.0)

    return ParsedOffer(
        product_name=product_name,
        price_cents=price_cents,
        currency="BRL",
        url=url,
        matched_category_slug=category,
        confidence=confidence,
        keywords=keywords,
        requirements=requirements,
    )


def format_price(cents: int | None) -> str:
    if cents is None:
        return "—"
    value = cents / 100
    return f"R$ {value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
