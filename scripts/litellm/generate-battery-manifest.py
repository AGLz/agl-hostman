#!/usr/bin/env python3
"""Regenera scripts/litellm/litellm-battery-manifest.json a partir de config.yaml."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from litellm_config_models import (  # noqa: E402
    DEFAULT_CONFIG,
    build_battery_manifest,
    load_env_file,
)

DEFAULT_OUT = SCRIPT_DIR / "litellm-battery-manifest.json"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Gera litellm-battery-manifest.json")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument(
        "--require-keys",
        action="store_true",
        help="Incluir só modelos cujas env keys existem (LITELLM_ENV_FILE ou ambiente)",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=Path(os.environ.get(
            "LITELLM_ENV_FILE", "/opt/agl-litellm/.env")),
    )
    args = parser.parse_args()

    if args.require_keys and args.env_file.is_file():
        load_env_file(args.env_file)

    manifest = build_battery_manifest(
        args.config, require_keys=args.require_keys)
    payload = {"models": manifest["models"]}
    args.out.write_text(json.dumps(payload, indent=2,
                        ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"Manifest: {args.out} ({len(payload['models'])} modelos)")
    print(f"Providers: {', '.join(manifest['providers'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
