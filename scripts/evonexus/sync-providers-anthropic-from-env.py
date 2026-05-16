#!/usr/bin/env python3
"""Sincroniza env_vars do provider anthropic em providers.json a partir de /workspace/config/.env (CT EvoNexus).

O Claude Code no terminal EvoNexus fala sempre com a API **Anthropic** (`ANTHROPIC_BASE_URL` → LiteLLM
`/v1/messages`). Modelos cujo upstream é **OpenAI** (`openai/gpt-*`, etc.) são traduzidos pelo LiteLLM;
com o CLI isto provoca com frequência **turnos sem texto** ("Crunched…" / stream vazio) após ferramentas
ou em mensagens curtas — não é um bug do `claude-bridge` isoladamente. Para GPT vê issue LiteLLM /
Claude Code (ex.: tradução Anthropic↔OpenAI em stream). O default EvoNexus usa alias **DashScope**
compatível com esse caminho; para GPT defina `ANTHROPIC_MODEL` conscientemente ou use fluxo Chat
OpenAI nativo (não o terminal Anthropic-only).
"""
import json
from pathlib import Path

ENV_PATH = Path("/workspace/config/.env")
PROV_PATH = Path("/workspace/config/providers.json")

# Alias LiteLLM AGL — omissão em .env: estável no terminal (API Anthropic + Read/tools; ver docstring).
DEFAULT_ANTHROPIC_MODEL = "qwen3.5-plus"


def normalize_anthropic_base_url(url: str) -> str:
    """ANTHROPIC_BASE_URL deve ser a raiz do gateway (ex. http://host:4000), sem sufixo /v1."""
    u = (url or "").strip().rstrip("/")
    if u.endswith("/v1"):
        return u[:-3].rstrip("/")
    return u


def load_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        out[key] = val
    return out


def main() -> None:
    env = load_dotenv(ENV_PATH)
    patch: dict[str, str] = {}
    for k in (
        "ANTHROPIC_BASE_URL",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_AUTH_TOKEN",
        "DISABLE_LOGIN_COMMAND",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL",
        "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY",
        "API_TIMEOUT_MS",
        "IS_SANDBOX",
    ):
        if env.get(k):
            patch[k] = env[k]
    if not patch.get("ANTHROPIC_BASE_URL") and env.get("LITELLM_GATEWAY_URL"):
        u = env["LITELLM_GATEWAY_URL"].rstrip("/")
        patch["ANTHROPIC_BASE_URL"] = u.replace("/v1", "") if "/v1" in u else u

    if patch.get("ANTHROPIC_BASE_URL"):
        patch["ANTHROPIC_BASE_URL"] = normalize_anthropic_base_url(patch["ANTHROPIC_BASE_URL"])

    base_url = (patch.get("ANTHROPIC_BASE_URL") or "").strip()
    official_anthropic = bool(base_url and "api.anthropic.com" in base_url)

    if env.get("LITELLM_MASTER_KEY"):
        if not patch.get("ANTHROPIC_AUTH_TOKEN"):
            patch["ANTHROPIC_AUTH_TOKEN"] = env["LITELLM_MASTER_KEY"]
        if not patch.get("ANTHROPIC_API_KEY") and official_anthropic:
            patch["ANTHROPIC_API_KEY"] = env["LITELLM_MASTER_KEY"]

    model = (
        patch.get("ANTHROPIC_MODEL")
        or env.get("EVONEXUS_ANTHROPIC_MODEL")
        or DEFAULT_ANTHROPIC_MODEL
    )
    patch["ANTHROPIC_MODEL"] = model
    if not patch.get("ANTHROPIC_DEFAULT_HAIKU_MODEL"):
        patch["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = env.get("ANTHROPIC_DEFAULT_HAIKU_MODEL") or model
    if not patch.get("ANTHROPIC_DEFAULT_SONNET_MODEL"):
        patch["ANTHROPIC_DEFAULT_SONNET_MODEL"] = env.get("ANTHROPIC_DEFAULT_SONNET_MODEL") or model
    if not patch.get("CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"):
        patch["CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"] = env.get(
            "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY", "1"
        )
    if not patch.get("IS_SANDBOX"):
        patch["IS_SANDBOX"] = env.get("IS_SANDBOX", "1")

    # Claude Code: pedidos longos via LiteLLM (default 10 min); subir em gateways lentos.
    if not patch.get("API_TIMEOUT_MS") and base_url and "api.anthropic.com" not in base_url:
        patch["API_TIMEOUT_MS"] = env.get("API_TIMEOUT_MS", "900000")

    cfg = json.loads(PROV_PATH.read_text())
    anth = cfg.setdefault("providers", {}).setdefault("anthropic", {})
    ev = anth.setdefault("env_vars", {})
    for k, v in patch.items():
        if v:
            ev[k] = v
    # Claude Code 2.1+: gateway não oficial + Bearer e API key iguais → aviso "Auth conflict".
    merged_base = (ev.get("ANTHROPIC_BASE_URL") or "").strip()
    merged_base = normalize_anthropic_base_url(merged_base)
    if merged_base:
        ev["ANTHROPIC_BASE_URL"] = merged_base
    if merged_base and "api.anthropic.com" not in merged_base:
        if ev.get("ANTHROPIC_AUTH_TOKEN") and ev.get("ANTHROPIC_API_KEY"):
            del ev["ANTHROPIC_API_KEY"]
    PROV_PATH.write_text(json.dumps(cfg, indent=2) + "\n")
    print("anthropic env_vars keys:", sorted(ev.keys()))


if __name__ == "__main__":
    main()
