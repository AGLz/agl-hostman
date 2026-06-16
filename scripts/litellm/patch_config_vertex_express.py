#!/usr/bin/env python3
"""Migra aliases Gemini para Vertex Express via gemini/ + api_base publishers/google."""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = REPO / "config" / "litellm" / "config.yaml"

EXPRESS_API_BASE = "https://aiplatform.googleapis.com/v1/publishers/google"

VERTEX_HEADER = (
    "# Gemini via Vertex Express (aglznet): GEMINI_API_KEY = API key AQ.* ligada a vertex-express@aglznet.\n"
    "# LiteLLM: prefixo gemini/ + api_base publishers/google (NÃO vertex_ai/ — exige ADC).\n"
    "# VERTEXAI_PROJECT / VERTEXAI_LOCATION em config/litellm/.env (billing; não passar ao proxy).\n"
    f"# Endpoint: {EXPRESS_API_BASE} — NÃO usar generativelanguage (AI Studio).\n"
)

LITELLM_PARAMS_VERTEX = f"""      api_key: os.environ/GEMINI_API_KEY
      api_base: {EXPRESS_API_BASE}"""


def _normalize_model_line(line: str) -> str:
    return re.sub(r"^(\s+model:\s+)vertex_ai/", r"\1gemini/", line)


def _patch_gemini_block(block: str) -> tuple[str, bool]:
    model_match = re.search(
        r"^\s+model:\s+(?:vertex_ai|gemini)/gemini-[^\n]+",
        block,
        re.MULTILINE,
    )
    if not model_match:
        return block, False

    model_line = _normalize_model_line(model_match.group(0))

    patched = re.sub(
        r"(\s+- litellm_params:\n)"
        r"(?:\s+api_key:.*\n)?"
        r"(?:\s+api_base:.*\n)?"
        r"(?:\s+vertex_location:.*\n)?"
        r"(?:\s+vertex_project:.*\n)?"
        r"\s+model: (?:vertex_ai|gemini)/gemini-[^\n]+\n",
        r"\1" + LITELLM_PARAMS_VERTEX + "\n" + model_line + "\n",
        block,
        count=1,
    )
    if patched != block:
        return patched, True

    # fallback linha-a-linha
    lines = block.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith("model:") and re.search(
            r"model:\s+(?:vertex_ai|gemini)/gemini-",
            line,
        ):
            out.append(_normalize_model_line(line))
            i += 1
            continue
        if line.strip() == "- litellm_params:":
            out.append(line)
            i += 1
            skip_keys = ("api_key:", "api_base:", "vertex_location:", "vertex_project:")
            while i < len(lines) and lines[i].startswith("      ") and not lines[i].strip().startswith("model:"):
                if not any(lines[i].strip().startswith(k) for k in skip_keys):
                    out.append(lines[i])
                i += 1
            if i < len(lines) and "model:" in lines[i]:
                if not any("api_base:" in l for l in out):
                    out.extend(LITELLM_PARAMS_VERTEX.splitlines())
                out.append(_normalize_model_line(lines[i]) if "gemini" in lines[i] else lines[i])
                i += 1
            continue
        out.append(line)
        i += 1
    return "\n".join(out) + ("\n" if block.endswith("\n") else ""), True


def patch_config(text: str) -> tuple[str, list[str]]:
    chunks = re.split(r"(?=\n  - litellm_params:)", text)
    if len(chunks) <= 1:
        return text, []

    head, *rest = chunks
    changed_names: list[str] = []
    new_rest: list[str] = []
    for chunk in rest:
        name_m = re.search(r"^\s+model_name:\s+(.+)$", chunk, re.MULTILINE)
        new_chunk, changed = _patch_gemini_block(chunk)
        if changed and name_m:
            changed_names.append(name_m.group(1).strip().strip('"'))
        new_rest.append(new_chunk)

    out = head + "".join(new_rest)
    out = _patch_header(out)
    return out, changed_names


def _patch_header(text: str) -> str:
    lines = text.splitlines()
    while lines and (
        lines[0].startswith("# Gemini (Google API)")
        or (lines[0].startswith("# GEMINI_API_KEY:") and "AI Studio" in lines[0])
        or lines[0].startswith("# Gemini via Vertex Express")
        or lines[0].startswith("# LiteLLM:")
        or lines[0].startswith("# VERTEXAI_PROJECT")
        or lines[0].startswith("# Endpoint")
    ):
        lines.pop(0)
    return VERTEX_HEADER + "\n".join(lines) + ("\n" if text.endswith("\n") else "")


def main() -> int:
    parser = argparse.ArgumentParser(description="Patch config.yaml para Vertex Express")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    config_path: Path = args.config
    src = config_path.read_text(encoding="utf-8")
    out, names = patch_config(src)
    if not names:
        print("Nenhum bloco Gemini (gemini/ ou vertex_ai/) encontrado para migrar.", file=sys.stderr)
        return 1
    print(f"Migrados {len(names)} aliases: {', '.join(names)}")
    if args.dry_run:
        print(out[:2000])
        return 0
    backup = config_path.with_suffix(config_path.suffix + ".bak.pre-vertex-express-v2")
    shutil.copy2(config_path, backup)
    config_path.write_text(out, encoding="utf-8")
    print(f"Backup: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
