# auth2api spike (OAuth Plus/Pro → API)

> **Fonte de verdade:** llm-wiki — [[LLM Aggregators OAuth vs LiteLLM AGL]]  
> Upstream: [AmazingAng/auth2api](https://github.com/AmazingAng/auth2api) (pin SHA no `Dockerfile`)

## Aviso ToS

Claude Pro / ChatGPT Plus / Cursor via OAuth relay **não** é uso oficial da API. Spike **lab / 1 operador**. Não ligar Hermes multi-agente nem publicar `:8317` na LAN.

## Providers possíveis (upstream)

O auth2api **só** tem estes três providers OAuth — não há Google/Gemini, Groq, Z.AI, etc. (isso continua no LiteLLM com API keys).

| Provider | Flag login | Conta necessária | Modelos (roteamento) | Notas |
|----------|------------|------------------|----------------------|-------|
| **anthropic** | `--provider=anthropic` | Claude Pro / Max | `claude-*`, aliases `opus`/`sonnet`/`haiku` | OAuth Claude Code |
| **codex** | `--provider=codex` | ChatGPT **Plus** ou **Pro** | `gpt-5*`, `o\d*`, `codex-*` | Backend `chatgpt.com/.../codex`; Free autentica mas falha no 1º call |
| **cursor** | `--provider=cursor` | Conta Cursor | Prefixo `cursor-*` / `cr/*` (obrigatório se anthropic/codex também estiverem logados) | Experimental; OAuth OK; chat pode falhar com *version no longer supported* se o cloaking estiver atrás do gate Cursor — bump `cloaking.cursor.client-version` ou `--cursor-import-local` do desktop actualizado |

Multi-conta: podes repetir `--login` no mesmo provider (pool + failover).

**Não suportados** pelo auth2api: OpenAI API key clássica, Anthropic API key, Gemini, OpenRouter, Azure, Bedrock, Ollama, etc. — usar LiteLLM CT186.

## Arranque (neste repo)

O binário **recusa arrancar sem pelo menos uma conta OAuth**. Ordem:

```bash
bash scripts/auth2api/bootstrap.sh
bash scripts/auth2api/login.sh --provider=anthropic
bash scripts/auth2api/login.sh --provider=codex
bash scripts/auth2api/login.sh --provider=cursor --auto   # deep-link; ou --cursor-import-local
bash scripts/auth2api/up.sh
bash scripts/auth2api/smoke-test.sh
```

- Compose: `docker/auth2api/` — bind `127.0.0.1:8317`
- Tokens: `docker/auth2api/data/` (gitignored)
- API key: `docker/auth2api/.env` (`AUTH2API_API_KEY`)
- Cloaking: `cli-version` Claude Code + `codex.cli-version` (`@openai/codex`); patch AGL em `/codex/models` `client_version` (semver)

Login **manual** (anthropic/codex sem browser no host): abre o URL, autoriza, cola o redirect `localhost`.  
Login **Cursor**: abre `https://cursor.com/loginDeepControl?...` e clica “Yes, Log In” (poll automático; `--auto`).

Com anthropic+codex+cursor activos, pedidos Cursor devem usar ids `cursor-*` (ex. `cursor-default`).

## LiteLLM lab (agldv04 `/opt/litellm` — não CT186)

auth2api junta-se à rede docker `litellm_litellm-net` → LiteLLM usa `http://agl-auth2api:8317/v1`.

```bash
bash scripts/auth2api/enable-litellm-lab.sh   # inject Claude+Codex no model_list + .env
bash scripts/auth2api/smoke-litellm-lab.sh    # auth2api-claude-sonnet + auth2api-gpt-codex
bash scripts/auth2api/disable-litellm-lab.sh  # remove bloco do config
```

Modelos lab: `auth2api-claude-sonnet`, `auth2api-claude-opus`, `auth2api-gpt-codex`.  
Snippet: `config/litellm/auth2api-lab-snippet.yaml` (Cursor omitido).  
CT186 canónico: **não** sincronizar este bloco via `sync-config-all-hosts` sem decisão explícita.

Parar só o proxy OAuth: `bash scripts/auth2api/down.sh`
