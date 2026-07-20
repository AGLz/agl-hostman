# auth2api (OAuth Plus/Pro → API) — CT186 canónico

> **Fonte de verdade:** llm-wiki — [[LLM Aggregators OAuth vs LiteLLM AGL]]

## Deploy canónico (CT186)

Hermes/LiteLLM **não** dependem do lab agldv04.

```bash
bash scripts/auth2api/deploy-ct186.sh
bash scripts/proxmox/apply-hermes-auth2api-fleet-ct188.sh
```

| Path CT186 | Função |
|------------|--------|
| `/opt/agl-auth2api` | Proxy OAuth |
| `/opt/agl-litellm` | LiteLLM → `http://agl-auth2api:8317/v1` |

## Aliases

`auth2api-claude-fable-5` (só Jarvis) · `auth2api-claude-sonnet` · `auth2api-claude-opus` · `auth2api-claude-haiku` · `auth2api-gpt-5.5` · `auth2api-gpt-codex` · `auth2api-gpt-5.4` · `auth2api-gpt-5.6` (→ gpt-5.5)

## Matriz Hermes

| Agente | Primary | Aux |
|--------|---------|-----|
| Jarvis | `auth2api-claude-fable-5` | `glm-4.7-flash` |
| Elon | `auth2api-gpt-5.5` | glm |
| Werner | `auth2api-claude-opus` | glm |
| Satya/Curator/Orion/Verifier/Composio | `auth2api-claude-sonnet` | glm |
| Argus | `auth2api-claude-haiku` | glm |

Monitor: `bash scripts/monitoring/auth2api-quota-monitor.sh` (stats via CT186).

## Cursor (experimental) — spike 2026-07-20

### Sintoma

- OAuth + `/v1/models` OK (~192 `cursor-*`, incl. GPT-5.6 / Fable).
- Chat falha: `ERROR_GPT_4_VISION_PREVIEW_RATE_LIMIT` + *Your version of Cursor is no longer supported* (código enganador = version-gate).

### Matriz testada (CT186, token deep-link)

| Variante | Resultado |
|----------|-----------|
| baseline `3.12.17` + `api2.cursor.sh` | FAIL version-gate |
| `cli-2026.01.09-231024f` + ide/cli | FAIL version-gate |
| `ghost-mode=false` | FAIL version-gate |
| `agentn.api5.cursor.sh` | FAIL 404 (path `StreamUnifiedChatWithTools` inexistente nesse host) |

Config restaurada ao ORIG após o spike. Hermes **não** usa Cursor.

### Próximo passo obrigatório

Neste host **não há** `~/.config/Cursor/.../state.vscdb` (só Cursor remote). Fingerprint real exige desktop:

```bash
# Numa máquina com Cursor 3.12.x instalado e logado:
bash scripts/auth2api/login.sh --provider=cursor --cursor-import-local
# ou: --cursor-storage=/path/to/state.vscdb
bash scripts/auth2api/deploy-ct186.sh --skip-build
bash scripts/auth2api/spike-cursor-chat.sh
```

### Script

`scripts/auth2api/spike-cursor-chat.sh` — matriz cloaking/hosts; `--keep-working` para não restaurar.

### Alternativas se import-local falhar

- Sidecar Cursor-only (auth2api exclusive mode) — lab isolado.
- Proxies alheios ([Cursor-To-OpenAI](https://github.com/timxx/Cursor-To-OpenAI), [cursor_api_demo](https://github.com/eisbaw/cursor_api_demo)) — protocolo `agentn.api5`; maior manutenção.
- Manter GPT-5.6 via alias Codex (`auth2api-gpt-5.6` → gpt-5.5) até chat Cursor estável.

