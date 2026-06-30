"""Validação periódica de ofertas Telegram (disponibilidade + preço no link)."""

from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urlparse

from src.market.http import get_client

UNAVAILABLE_STRONG: tuple[str, ...] = (
    "currently unavailable",
    "produto esgotado",
    "sem estoque",
    "out of stock",
    "sold out",
    "this item is unavailable",
    "item is no longer available",
    "não disponível para compra",
    "nao disponivel para compra",
    "produto indisponível no momento",
    "produto indisponivel no momento",
)

UNAVAILABLE_GENERIC: tuple[str, ...] = (
    "esgotado",
    "sem estoque",
    "out of stock",
    "sold out",
    "no longer available",
    "item not found",
    "page not found",
    "não encontrado",
    "nao encontrado",
)

MARKETPLACE_HOSTS: tuple[str, ...] = (
    "amazon.",
    "shopee.",
    "aliexpress.",
    "mercadolivre.",
    "mercadolibre.",
)

PRICE_SCAN = re.compile(
    r"(?:r\$|rs\.?)\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})|\d{4,}(?:,\d{2})?|\d{1,3}(?:,\d{2}))",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ValidationResult:
    status: str
    validated_price_cents: int | None
    notes: str
    final_url: str | None = None
    http_status: int | None = None


def _parse_price_cents(raw: str) -> int | None:
    token = raw.strip()
    if "," in token:
        cleaned = token.replace(".", "").replace(",", ".")
    elif token.count(".") >= 1 and len(token.split(".")[-1]) == 3:
        cleaned = token.replace(".", "")
    else:
        cleaned = token
    try:
        value = float(cleaned)
    except ValueError:
        return None
    if value <= 0:
        return None
    return int(round(value * 100))


def extract_prices_from_html(html: str) -> list[int]:
    prices: list[int] = []
    for match in PRICE_SCAN.finditer(html):
        cents = _parse_price_cents(match.group(1))
        if cents and cents >= 1000:
            prices.append(cents)
    return prices


def price_within_tolerance(
    expected_cents: int | None,
    found_cents: int | None,
    tolerance_percent: float,
) -> bool | None:
    if expected_cents is None or found_cents is None:
        return None
    if expected_cents <= 0:
        return None
    delta = abs(found_cents - expected_cents) / expected_cents * 100
    return delta <= tolerance_percent


def validate_offer_url(
    url: str,
    *,
    expected_price_cents: int | None,
    tolerance_percent: float = 5.0,
    requirements_note: str = "",
) -> ValidationResult:
    """GET no link da oferta; verifica indisponível e compara preço (best-effort)."""
    if not url:
        return ValidationResult(
            status="needs_manual",
            validated_price_cents=None,
            notes="sem URL para validar",
        )

    try:
        with get_client(timeout=25) as client:
            response = client.get(url, follow_redirects=True)
    except Exception as exc:  # noqa: BLE001
        return ValidationResult(
            status="needs_manual",
            validated_price_cents=None,
            notes=f"erro HTTP: {exc!r}",
            final_url=url,
        )

    final_url = str(response.url)
    html_lower = response.text[:500_000].lower()
    http_status = response.status_code
    host = urlparse(final_url).netloc.lower()
    is_marketplace = any(part in host for part in MARKETPLACE_HOSTS)

    if http_status >= 400:
        return ValidationResult(
            status="needs_manual",
            validated_price_cents=None,
            notes=f"HTTP {http_status}",
            final_url=final_url,
            http_status=http_status,
        )

    markers = UNAVAILABLE_STRONG if is_marketplace else UNAVAILABLE_STRONG + UNAVAILABLE_GENERIC
    for marker in markers:
        if marker in html_lower:
            return ValidationResult(
                status="unavailable",
                validated_price_cents=None,
                notes=f"indisponível: {marker}",
                final_url=final_url,
                http_status=http_status,
            )

    found_prices = extract_prices_from_html(response.text)
    validated_price = min(found_prices) if found_prices else None

    notes_parts: list[str] = []
    if requirements_note:
        notes_parts.append(requirements_note)

    if is_marketplace:
        notes_parts.append("validação parcial (página pode exigir JS/login)")

    if expected_price_cents and validated_price:
        within = price_within_tolerance(
            expected_price_cents, validated_price, tolerance_percent
        )
        if within is True:
            status = "active"
            notes_parts.append("preço confirmado no link")
        elif within is False:
            status = "price_changed"
            notes_parts.append(
                f"preço no link difere (esperado {expected_price_cents}, visto {validated_price})"
            )
        else:
            status = "active"
            notes_parts.append("preço no link não comparável")
    elif validated_price:
        status = "active"
        notes_parts.append(f"preço visto: {validated_price}")
    else:
        status = "needs_manual"
        notes_parts.append(
            "não foi possível confirmar preço/estoque automaticamente")

    return ValidationResult(
        status=status,
        validated_price_cents=validated_price,
        notes="; ".join(notes_parts),
        final_url=final_url,
        http_status=http_status,
    )
