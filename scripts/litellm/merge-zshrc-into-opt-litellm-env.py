#!/usr/bin/env python3
"""
Preenche chaves vazias em /opt/litellm/.env a partir de exports em ~/.zshrc (agldv03).

Reason: chaves reais costumam estar apenas no zshrc; LiteLLM lê /opt/litellm/.env no container.
Não sobrescreve valores já definidos no .env. Ignora linhas zshrc com ${ (expansão).
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

ZSHRC = Path("/root/.zshrc")
ENV_PATH = Path("/opt/litellm/.env")

# Variável no LiteLLM → candidatos no zshrc (primeiro não vazio ganha)
ALIASES: dict[str, list[str]] = {
    "OPENAI_API_KEY": ["OPENAI_API_KEY", "OPENAI_AUTH"],
    "GEMINI_API_KEY": ["GEMINI_API_KEY", "GEMINI_AUTH"],
    "ANTHROPIC_API_KEY": ["ANTHROPIC_API_KEY"],
    "DEEPSEEK_API_KEY": ["DEEPSEEK_API_KEY", "DEEPSEEK_AUTH"],
    "MOONSHOT_API_KEY": ["MOONSHOT_API_KEY", "KIMI_AUTH"],
    "ZAI_API_KEY": ["ZAI_API_KEY", "GLM_AUTH"],
    "DASHSCOPE_API_KEY": ["DASHSCOPE_API_KEY"],
    "OPENROUTER_API_KEY": ["OPENROUTER_API_KEY", "OPENROUTER_AUTH"],
    "REDIS_PASSWORD": ["REDIS_PASSWORD"],
}

EXPORT_RE = re.compile(r"^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$")


def strip_quotes(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v


def parse_zshrc_exports(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    text = path.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        line = line.strip()
        m = EXPORT_RE.match(line)
        if not m:
            continue
        key, raw = m.group(1), m.group(2).strip()
        if "${" in raw:
            continue
        val = strip_quotes(raw)
        if val:
            out[key] = val
    return out


def parse_env_values(content: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in content.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if "=" not in s:
            continue
        k, _, rest = s.partition("=")
        k = k.strip()
        v = strip_quotes(rest.strip())
        out[k] = v
    return out


def env_value_empty(v: str | None) -> bool:
    if v is None:
        return True
    return len(v.strip()) == 0


def format_line(key: str, value: str) -> str:
    if re.search(r"[\s'#\"$`]", value):
        esc = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'{key}="{esc}"'
    return f"{key}={value}"


def upsert_env_line(content: str, key: str, value: str) -> str:
    pat = re.compile(rf"(?m)^\s*{re.escape(key)}\s*=\s*.*$")
    line = format_line(key, value)
    if pat.search(content):
        return pat.sub(line, content, count=1)
    if content and not content.endswith("\n"):
        content += "\n"
    elif not content:
        content = ""
    return content + line + "\n"


def main() -> int:
    if not ENV_PATH.is_file():
        print("ERRO: /opt/litellm/.env inexistente", file=sys.stderr)
        return 1

    zsh = parse_zshrc_exports(ZSHRC)
    original = ENV_PATH.read_text(encoding="utf-8", errors="replace")
    current = parse_env_values(original)

    to_apply: list[tuple[str, str]] = []
    for litellm_key, candidates in ALIASES.items():
        if not env_value_empty(current.get(litellm_key)):
            continue
        pick = ""
        for c in candidates:
            v = zsh.get(c, "")
            if v and "${" not in v:
                pick = v
                break
        if pick:
            to_apply.append((litellm_key, pick))

    if not to_apply:
        print("Nada a atualizar: .env já tem valores ou zshrc não tem exports correspondentes.")
        return 0

    bak = ENV_PATH.with_suffix(".env.bak.zshrc-merge")
    shutil.copy2(ENV_PATH, bak)

    new_content = original
    names = []
    for key, value in to_apply:
        new_content = upsert_env_line(new_content, key, value)
        current[key] = value
        names.append(key)

    ENV_PATH.write_text(new_content, encoding="utf-8")
    ENV_PATH.chmod(0o600)
    print(f"OK: backup {bak}")
    print("OK: preenchido no LiteLLM .env:", ", ".join(names))
    print(
        "    Aplicar ao contentor: cd /opt/litellm && docker compose up -d --force-recreate litellm-proxy"
    )
    print("    (docker restart NÃO recarrega env_file; só recreate.)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
