"""Presets de montagem inspirados em tiers do mercado BR (referência indicativa)."""

from __future__ import annotations

import json
from typing import Any

# Preços indicativos para comparação — atualizar via `add-market-price` ou importação
# Fonte de inspiração: faixas típicas MEUPC/Terabyte/KaBuM (2025-2026), não scrape ao vivo

BUILD_PRESETS: list[dict[str, Any]] = [
    {
        "slug": "amd-entry-7600-4060",
        "name": "AMD Entry — Ryzen 5 7600 + RTX 4060",
        "tier": "entry",
        "platform": "amd_am5",
        "reference_site": "terabyte",
        "description": "1080p alto; referência Terabyte AM5 entry / Pichau custo-benefício",
        "items": [
            {"category_slug": "processador",
                "label": "AMD Ryzen 5 7600", "reference_cents": 89900},
            {"category_slug": "motherboard",
                "label": "ASRock B650M Pro RS", "reference_cents": 79900},
            {"category_slug": "memoria_ddr5",
                "label": "16GB DDR5 5600 (2x8)", "reference_cents": 34900},
            {"category_slug": "placa_video",
                "label": "RTX 4060 8GB", "reference_cents": 219900},
            {"category_slug": "nvme", "label": "NVMe 1TB Gen4",
                "reference_cents": 39900},
            {"category_slug": "gabinete",
                "label": "Gabinete mid tower airflow", "reference_cents": 24900},
            {"category_slug": "fonte", "label": "Fonte 650W 80+ Bronze",
                "reference_cents": 34900},
            {"category_slug": "water_cooler",
                "label": "Cooler tower 120mm", "reference_cents": 12900},
            {"category_slug": "fan", "label": "Kit 3x120mm PWM",
                "reference_cents": 9900},
            {"category_slug": "suporte_vga",
                "label": "Bracket anti-sag", "reference_cents": 4900},
        ],
    },
    {
        "slug": "amd-mid-7800x3d-5070",
        "name": "AMD Mid — 7800X3D + RTX 5070",
        "tier": "mid",
        "platform": "amd_am5",
        "reference_site": "kabum",
        "description": "1440p ultra; perfil KaBuM Monte seu PC + MEUPC compare",
        "items": [
            {"category_slug": "processador",
                "label": "AMD Ryzen 7 7800X3D", "reference_cents": 189900},
            {"category_slug": "motherboard",
                "label": "MSI B650 Tomahawk WiFi", "reference_cents": 129900},
            {"category_slug": "memoria_ddr5",
                "label": "32GB DDR5 6000 CL30 (2x16)", "reference_cents": 89900},
            {"category_slug": "placa_video",
                "label": "RTX 5070 12GB", "reference_cents": 429900},
            {"category_slug": "nvme", "label": "Samsung 990 EVO Plus 1TB",
                "reference_cents": 54900},
            {"category_slug": "gabinete",
                "label": "Gabinete airflow vidro temperado", "reference_cents": 39900},
            {"category_slug": "fonte", "label": "Fonte 750W 80+ Gold modular",
                "reference_cents": 54900},
            {"category_slug": "water_cooler",
                "label": "AIO 240mm", "reference_cents": 39900},
            {"category_slug": "fan", "label": "3x120mm ARGB extra",
                "reference_cents": 14900},
            {"category_slug": "suporte_vga",
                "label": "Suporte VGA 3 fans RGB", "reference_cents": 8900},
        ],
    },
    {
        "slug": "amd-high-7900x-5080",
        "name": "AMD High — 7900X + RTX 5080",
        "tier": "high",
        "platform": "amd_am5",
        "reference_site": "studiopc",
        "description": "4K jogos + stream; inspiração StudioPC Supreme / Terabyte Full Custom",
        "items": [
            {"category_slug": "processador",
                "label": "AMD Ryzen 9 7900X", "reference_cents": 249900},
            {"category_slug": "motherboard",
                "label": "ASUS TUF X670E-PLUS WiFi", "reference_cents": 199900},
            {"category_slug": "memoria_ddr5",
                "label": "32GB DDR5 6400 (2x16)", "reference_cents": 109900},
            {"category_slug": "placa_video",
                "label": "RTX 5080 16GB", "reference_cents": 699900},
            {"category_slug": "nvme", "label": "Samsung 990 Pro 1TB",
                "reference_cents": 69900},
            {"category_slug": "gabinete", "label": "Gabinete premium airflow",
                "reference_cents": 59900},
            {"category_slug": "fonte", "label": "Fonte 850W 80+ Gold ATX 3.0",
                "reference_cents": 79900},
            {"category_slug": "water_cooler",
                "label": "AIO 360mm", "reference_cents": 59900},
            {"category_slug": "fan", "label": "Pack fans extra 140mm",
                "reference_cents": 19900},
            {"category_slug": "suporte_vga",
                "label": "Suporte VGA reforçado", "reference_cents": 12900},
        ],
    },
    {
        "slug": "amd-enthusiast-9950x-5090",
        "name": "AMD Enthusiast — 9950X3D + RTX 5090",
        "tier": "enthusiast",
        "platform": "amd_am5",
        "reference_site": "terabyte",
        "description": "Topo AM5; Terabyte Ryzen 9000 Full Custom",
        "items": [
            {"category_slug": "processador",
                "label": "AMD Ryzen 9 9950X3D", "reference_cents": 399900},
            {"category_slug": "motherboard",
                "label": "Gigabyte X870E AORUS Elite", "reference_cents": 249900},
            {"category_slug": "memoria_ddr5",
                "label": "64GB DDR5 6000 (2x32)", "reference_cents": 189900},
            {"category_slug": "placa_video",
                "label": "RTX 5090 32GB", "reference_cents": 1499900},
            {"category_slug": "nvme", "label": "Samsung 990 Pro 2TB",
                "reference_cents": 119900},
            {"category_slug": "gabinete",
                "label": "Gabinete full tower premium", "reference_cents": 89900},
            {"category_slug": "fonte", "label": "Fonte 1200W 80+ Platinum ATX 3.1",
                "reference_cents": 149900},
            {"category_slug": "water_cooler",
                "label": "AIO 360mm display", "reference_cents": 99900},
            {"category_slug": "fan", "label": "Fans premium pack",
                "reference_cents": 29900},
            {"category_slug": "suporte_vga",
                "label": "Suporte VGA + cable combs", "reference_cents": 15900},
        ],
    },
]


def preset_total_cents(preset: dict[str, Any]) -> int:
    return sum(int(item["reference_cents"]) for item in preset["items"])


def presets_as_json_rows() -> list[dict[str, Any]]:
    rows = []
    for preset in BUILD_PRESETS:
        rows.append(
            {
                "slug": preset["slug"],
                "name": preset["name"],
                "tier": preset["tier"],
                "platform": preset["platform"],
                "reference_site": preset["reference_site"],
                "description": preset["description"],
                "total_reference_cents": preset_total_cents(preset),
                "items_json": json.dumps(preset["items"], ensure_ascii=False),
            }
        )
    return rows
