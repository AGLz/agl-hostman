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
