---
name: agl-claude-code-agent
description: |
  Claude Code CLI na stack AGL: sessões Max OAuth (sem API key), fallback LiteLLM CT186, subagents, MCP, agent-os. Usar para debug profundo, arquitectura, specs agent-os, hooks, e trabalho terminal longo. Trigger Claude Code, claude CLI, Max plan, /status, ANTHROPIC_BASE_URL. Após routing via agl-harness-router quando AUTH=max-direct ou litellm.
---

# AGL Claude Code Agent

## Auth AGL (crítico)

**Max (subscrição, sem billing API):**

```bash
unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
claude   # confirmar com /status → OAuth, model opus/sonnet
```

**LiteLLM fallback (API/proxy):**

```bash
export ANTHROPIC_BASE_URL="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
export ANTHROPIC_AUTH_TOKEN="${LITELLM_MASTER_KEY}"   # virtual key — nunca commitar
```

Se `ANTHROPIC_API_KEY` estiver no ambiente, **precede OAuth** — remover para usar Max.

Referência: [Claude Code Authentication](https://code.claude.com/docs/en/authentication)

## fallbackModel (settings.json)

```json
{
  "model": "claude-sonnet-4-6",
  "fallbackModel": ["glm-4.7-flash", "agl-primary-vm110"]
}
```

Aliases via LiteLLM quando em modo proxy. `fallbackModel` cobre **529 overload**, não 429 quota.

## Skills e agentes

- **Agent-OS:** `agent-os/specs/`, comandos `.claude/commands/agent-os/`
- **Subagents:** `.claude/agents/`, `.claude/agents/agent-os/`
- **Six Repos:** `bash scripts/skills/sync-six-repos.sh`
- **Karpathy / ECC:** já sync — não duplicar regras nesta skill

## Casos de uso

| Tarefa             | Modelo        | Auth                               |
| ------------------ | ------------- | ---------------------------------- |
| Arquitectura / ADR | Opus / Sonnet | max-direct                         |
| Implementação spec | Sonnet        | max-direct → litellm se rate limit |
| Headless CI        | Sonnet        | litellm + virtual key              |
| Review pós-Ruflo   | Sonnet        | max-direct                         |

## Verificação

```bash
claude /status          # OAuth vs API key
bash scripts/skills/verify-six-repos.sh
```

## Quando NÃO usar

- Iteração UI rápida → `agl-cursor-agent`
- 3+ branches paralelos → `agl-verdent-agent` ou `agl-ruflo-orchestrator`
