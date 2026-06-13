#!/usr/bin/env python3
"""Testes patch LiteLLM VM110 Plan C."""
from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "litellm"))

from patch_config_vm110_plan_c import patch_config  # noqa: E402


class PatchVm110PlanCTest(unittest.TestCase):
    def test_patches_agl_primary_to_ollama(self) -> None:
        src = REPO / "config" / "litellm" / "config.yaml"
        self.assertTrue(src.is_file(), f"falta {src}")
        os.environ["VM110_OLLAMA_BASE"] = "http://100.116.57.111:11434"
        out = patch_config(src.read_text(encoding="utf-8"))
        self.assertIn("http://100.116.57.111:11434", out)
        self.assertIn("model: ollama/gemma4-qat", out)
        self.assertIn("model_name: agl-primary", out)
        self.assertNotIn("model: groq/llama-3.1-8b-instant",
                         out.split("model_name: agl-primary")[0][-400:])


if __name__ == "__main__":
    unittest.main()
