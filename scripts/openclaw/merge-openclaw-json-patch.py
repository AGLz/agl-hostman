#!/usr/bin/env python3
"""Funde um fragmento JSON (ex.: openclaw-patch.json) em ~/.openclaw/openclaw.json.

Merge profundo de dicts: chaves do patch sobrepõem ou fundem sub-objetos.
Útil para alinhar gateway/commands/channels/auth/agents.defaults sem apagar o resto
do ficheiro (tokens Telegram, etc.).

Ex.: python3 merge-openclaw-json-patch.py
     python3 merge-openclaw-json-patch.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def deep_merge(base: Any, patch: Any) -> Any:
    if isinstance(base, dict) and isinstance(patch, dict):
        out = dict(base)
        for key, val in patch.items():
            if key in out and isinstance(out[key], dict) and isinstance(val, dict):
                out[key] = deep_merge(out[key], val)
            else:
                out[key] = val
        return out
    return patch


def _load(p: Path) -> dict[str, Any]:
    return json.loads(p.read_text(encoding="utf-8"))


def _save(p: Path, data: dict[str, Any]) -> None:
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _backup(p: Path) -> Path:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    bak = p.with_suffix(p.suffix + f".bak.patch-{ts}")
    shutil.copy2(p, bak)
    return bak


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--target",
        type=Path,
        default=Path.home() / ".openclaw" / "openclaw.json",
        help="openclaw.json de destino",
    )
    ap.add_argument(
        "--patch",
        type=Path,
        default=None,
        help="Fragmento a fundir (predef.: repo config/openclaw/openclaw-patch.json)",
    )
    ap.add_argument("--dry-run", action="store_true", help="Mostra diff de chaves de topo apenas")
    args = ap.parse_args()

    repo = Path(__file__).resolve().parents[2]
    patch_path = args.patch or (repo / "config" / "openclaw" / "openclaw-patch.json")
    if not patch_path.is_file():
        raise SystemExit(f"Patch em falta: {patch_path}")

    target = args.target.expanduser()
    if not target.is_file():
        raise SystemExit(f"Destino em falta: {target}")

    base = _load(target)
    fragment = _load(patch_path)
    merged = deep_merge(base, fragment)

    if args.dry_run:
        b_keys, m_keys = set(base.keys()), set(merged.keys())
        print("Chaves novas:", sorted(m_keys - b_keys))
        print("Chaves removidas (não deve haver):", sorted(b_keys - m_keys))
        for k in sorted(b_keys & m_keys):
            if base[k] != merged[k]:
                print(f"~ alterado: {k}")
        return

    _backup(target)
    _save(target, merged)
    print(f"OK: fundido {patch_path.name} → {target}")


if __name__ == "__main__":
    main()
