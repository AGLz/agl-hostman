"""Validação em lote de ofertas Telegram pendentes/recentes."""

from __future__ import annotations

from dataclasses import dataclass

from src.catalog.repository import list_offers_for_validation, update_offer_validation
from src.config import (
    OFFER_PRICE_TOLERANCE_PERCENT,
    OFFER_REVALIDATE_MINUTES,
    OFFER_VALIDATION_BATCH,
    OFFER_VALIDATION_MAX_AGE_HOURS,
)
from src.telegram.offer_validator import validate_offer_url


@dataclass
class ValidationBatchResult:
    checked: int
    active: int
    price_changed: int
    unavailable: int
    needs_manual: int


def _requirements_note(parsed: dict) -> str:
    req = parsed.get("requirements") or {}
    parts: list[str] = []
    if req.get("requires_coins"):
        parts.append("requer moedas")
    if req.get("requires_app"):
        parts.append("app-only")
    if req.get("requires_pix"):
        parts.append("PIX")
    codes = req.get("coupon_codes") or []
    if codes:
        parts.append(f"cupom:{','.join(codes[:3])}")
    if req.get("is_flash"):
        parts.append("promo relâmpago")
    return "; ".join(parts)


def validate_pending_offers(
    *,
    max_age_hours: int | None = None,
    revalidate_minutes: int | None = None,
    batch_size: int | None = None,
    tolerance_percent: float | None = None,
) -> ValidationBatchResult:
    offers = list_offers_for_validation(
        max_age_hours=max_age_hours or OFFER_VALIDATION_MAX_AGE_HOURS,
        revalidate_minutes=revalidate_minutes or OFFER_REVALIDATE_MINUTES,
        limit=batch_size or OFFER_VALIDATION_BATCH,
    )

    result = ValidationBatchResult(
        checked=0,
        active=0,
        price_changed=0,
        unavailable=0,
        needs_manual=0,
    )

    tol = tolerance_percent if tolerance_percent is not None else OFFER_PRICE_TOLERANCE_PERCENT

    for offer in offers:
        parsed = offer.get("parsed") or {}
        validation = validate_offer_url(
            offer.get("url") or "",
            expected_price_cents=offer.get("price_cents"),
            tolerance_percent=tol,
            requirements_note=_requirements_note(parsed),
        )
        update_offer_validation(
            offer_id=int(offer["id"]),
            status=validation.status,
            validated_price_cents=validation.validated_price_cents,
            notes=validation.notes,
        )
        result.checked += 1
        if validation.status == "active":
            result.active += 1
        elif validation.status == "price_changed":
            result.price_changed += 1
        elif validation.status == "unavailable":
            result.unavailable += 1
        else:
            result.needs_manual += 1

    return result
