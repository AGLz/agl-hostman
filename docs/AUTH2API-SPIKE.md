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

## LiteLLM lab (agldv04) + CT186 (Hermes)

```bash
# Lab local agldv04
bash scripts/auth2api/enable-litellm-lab.sh
bash scripts/auth2api/smoke-litellm-lab.sh

# Canónico CT186 (Hermes) — auth2api em LAN/Tailscale
bash scripts/auth2api/enable-litellm-ct186.sh

# Só Jarvis / Elon / Werner → auth2api-* (resto do fleet intacto)
bash scripts/proxmox/apply-hermes-auth2api-jew-ct188.sh
# Reverter JEW: bash scripts/proxmox/apply-hermes-auth2api-jew-ct188.sh --revert-free
```

| Agente | Primary | Fallback / aux |
|--------|---------|----------------|
| Jarvis | `auth2api-claude-sonnet` | `zai-glm-flash` / `glm-4.7-flash` |
| Elon | `auth2api-gpt-codex` | idem |
| Werner | `auth2api-claude-sonnet` | idem |

Modelos: `auth2api-claude-sonnet`, `auth2api-claude-opus`, `auth2api-gpt-codex`.  
Snippet: `config/litellm/auth2api-lab-snippet.yaml` (Cursor omitido).

### Monitor de tokens (dia / semana / mês)

```bash
bash scripts/monitoring/auth2api-quota-monitor.sh --daily
bash scripts/monitoring/auth2api-quota-monitor.sh --alert   # [SILENT] se OK
# Timer: config/systemd/agl-auth2api-quota.{service,timer}
sudo cp config/systemd/agl-auth2api-quota.* /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now agl-auth2api-quota.timer
```

Soft limits (env): `AUTH2API_DAILY_TOKEN_WARN=500000`, `WEEKLY=2000000`, `MONTHLY=8000000`.  
Estado: `/var/log/hostman/auth2api-quota-state.json` (Argus digest lê se presente).

Parar só o proxy OAuth: `bash scripts/auth2api/down.sh`
