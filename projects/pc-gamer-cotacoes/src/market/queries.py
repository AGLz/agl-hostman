"""Queries de busca por categoria (PT-BR) para automação de cotações."""

from __future__ import annotations

DEFAULT_CATEGORY_QUERIES: dict[str, list[str]] = {
    "processador": ["AMD Ryzen 7 7800X3D", "AMD Ryzen 5 7600", "Ryzen 9 7900X"],
    "motherboard": ["placa mãe B650 AM5", "ASUS TUF B650", "MSI B650M"],
    "memoria_ddr5": ["memória DDR5 32GB 6000", "DDR5 16GB 5600 Kingston Fury"],
    "placa_video": ["RTX 4060 8GB", "RTX 5070 12GB", "RX 7800 XT"],
    "nvme": ["SSD NVMe 1TB Samsung 990", "NVMe 1TB Gen4"],
    "gabinete": ["gabinete gamer mid tower airflow"],
    "fonte": ["fonte 750W 80 plus gold modular"],
    "water_cooler": ["water cooler 240mm AIO", "cooler CPU AM5"],
    "fan": ["fan 120mm PWM ARGB pack 3"],
    "suporte_vga": ["suporte placa de video anti sag bracket"],
}


def queries_for_category(category_slug: str, custom: str | None = None) -> list[str]:
    if custom:
        return [custom.strip()]
    return DEFAULT_CATEGORY_QUERIES.get(category_slug, [category_slug.replace("_", " ")])
