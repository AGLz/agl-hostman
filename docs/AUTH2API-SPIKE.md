# auth2api (OAuth Plus/Pro → API) — CT186 canónico

> **Fonte de verdade:** llm-wiki — [[LLM Aggregators OAuth vs LiteLLM AGL]]  
> Upstream: [AmazingAng/auth2api](https://github.com/AmazingAng/auth2api) (pin SHA no `Dockerfile`)

## Aviso ToS

Claude Pro / ChatGPT Plus / Cursor via OAuth relay **não** é uso oficial da API. Uso **1 operador / Agency**. Não publicar `:8317` em `0.0.0.0`.

## Deploy canónico (CT186)

Hermes e LiteLLM **não** devem depender do lab agldv04.

```bash
# Tokens OAuth (uma vez; neste host ou no CT186)
bash scripts/auth2api/bootstrap.sh
bash scripts/auth2api/login.sh --provider=anthropic
bash scripts/auth2api/login.sh --provider=codex

# Deploy proxy + inject LiteLLM no CT186
bash scripts/auth2api/deploy-ct186.sh

# Fleet Hermes (todos Plus/Pro; auxiliares glm; só Jarvis = Fable 5)
bash scripts/proxmox/apply-hermes-auth2api-fleet-ct188.sh
```

| Path CT186 | Função |
|------------|--------|
| `/opt/agl-auth2api` | Proxy OAuth (`docker-compose.ct186.yml`) |
| `/opt/agl-litellm` | LiteLLM → `http://agl-auth2api:8317/v1` |

Lab agldv04 (`docker/auth2api/docker-compose.yml` + `enable-litellm-lab.sh`) fica só para desenvolvimento.

## Modelos LiteLLM (aliases)

| Alias | Upstream auth2api | Notas |
|-------|-------------------|-------|
| `auth2api-claude-fable-5` | `claude-fable-5` | **Só Jarvis** por defeito |
| `auth2api-claude-sonnet` | `claude-sonnet-5` | Fleet default |
| `auth2api-claude-opus` | `claude-opus-4-8` | Werner |
| `auth2api-claude-haiku` | `claude-haiku-4-5` | Argus |
| `auth2api-gpt-5.5` / `auth2api-gpt-codex` | `gpt-5.5` | Elon |
| `auth2api-gpt-5.4` | `gpt-5.4` | Opção |
| `auth2api-gpt-5.6` | → `gpt-5.5` | Plus não lista 5.6 ainda |

Cursor omitido (chat 502 version gate). Trocar primary: `JARVIS_MODEL=auth2api-claude-opus bash scripts/proxmox/apply-hermes-auth2api-fleet-ct188.sh`.

## Matriz Hermes (primary)

| Agente | Primary | Aux |
|--------|---------|-----|
| Jarvis | `auth2api-claude-fable-5` | `glm-4.7-flash` |
| Elon | `auth2api-gpt-5.5` | idem |
| Werner | `auth2api-claude-opus` | idem |
| Satya / Curator / Orion / Verifier / Composio | `auth2api-claude-sonnet` | idem |
| Argus | `auth2api-claude-haiku` | idem |

Fallback OAuth fail: `zai-glm-flash`. Reverter: `--revert-free`.

## Monitor tokens (dia / semana / mês)

```bash
bash scripts/monitoring/auth2api-quota-monitor.sh --daily
# lê stats do CT186 via scp; timer: agl-auth2api-quota.timer
```

Soft limits: `AUTH2API_DAILY_TOKEN_WARN=500000`, `WEEKLY=2000000`, `MONTHLY=8000000`.
