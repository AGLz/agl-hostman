"""Testes de presets e referências BR."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.catalog.presets import BUILD_PRESETS, preset_total_cents  # noqa: E402
from src.catalog.reference_sites import BUILD_WIZARD_STEPS, REFERENCE_SITES  # noqa: E402


def test_presets_have_ten_slots() -> None:
    for preset in BUILD_PRESETS:
        assert len(preset["items"]) == 10
        assert preset_total_cents(preset) > 0


def test_wizard_covers_core_categories() -> None:
    slugs = {step["slug"] for step in BUILD_WIZARD_STEPS}
    assert "processador" in slugs
    assert "placa_video" in slugs
    assert "memoria_ddr5" in slugs


def test_reference_sites_include_meupc_and_kabum() -> None:
    slugs = {site["slug"] for site in REFERENCE_SITES}
    assert "meupc" in slugs
    assert "kabum" in slugs
    assert "terabyte" in slugs
