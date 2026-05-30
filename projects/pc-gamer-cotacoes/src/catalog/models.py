"""Modelos de domínio para cotações PC gamer."""

from __future__ import annotations

from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field


class BuildStatus(StrEnum):
    DRAFT = "draft"
    QUOTED = "quoted"
    APPROVED = "approved"
    ORDERED = "ordered"
    ASSEMBLY = "assembly"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class ComponentCategory(StrEnum):
    GABINETE = "gabinete"
    MOTHERBOARD = "motherboard"
    MEMORIA_DDR5 = "memoria_ddr5"
    NVME = "nvme"
    PLACA_VIDEO = "placa_video"
    PROCESSADOR = "processador"
    WATER_COOLER = "water_cooler"
    FAN = "fan"
    FONTE = "fonte"
    SUPORTE_VGA = "suporte_vga"


MOTHERBOARD_BRANDS = ("asus", "gigabyte", "msi", "asrock")

BUILD_TEMPLATE_AMD_GAMER: list[dict[str, Any]] = [
    {"category_slug": "gabinete", "label": "Gabinete"},
    {"category_slug": "motherboard",
        "label": "Placa-mãe (Asus/Gigabyte/MSI/ASRock)"},
    {"category_slug": "processador", "label": "Processador AMD"},
    {"category_slug": "memoria_ddr5", "label": "Memória DDR5"},
    {"category_slug": "nvme", "label": "SSD NVMe 1TB (ex.: Samsung)"},
    {"category_slug": "placa_video", "label": "Placa de vídeo"},
    {"category_slug": "water_cooler", "label": "Water cooler"},
    {"category_slug": "fan", "label": "Fans adicionais"},
    {"category_slug": "fonte", "label": "Fonte"},
    {"category_slug": "suporte_vga",
        "label": "Suporte/conector VGA (ex.: 3 fans)"},
]


class ParsedOffer(BaseModel):
    product_name: str | None = None
    price_cents: int | None = None
    currency: str = "BRL"
    url: str | None = None
    matched_category_slug: str | None = None
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    keywords: list[str] = Field(default_factory=list)


class BuildSummary(BaseModel):
    id: int
    code: str
    title: str
    status: str
    customer_name: str | None
    cost_cents: int
    quote_cents: int
    margin_percent: float
    item_count: int
