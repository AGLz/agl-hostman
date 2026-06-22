---
name: agl-harness-router
description: |
  Router AGL multi-harness. Usar no INÍCIO de tarefas ambíguas ou multi-step para escolher Claude Code (Max OAuth), Cursor (Pro/LiteLLM), Verdent (parallel worktrees), ou Ruflo (swarm multi-frente). Trigger quando o utilizador menciona harness, quota, subscrição, parallel agents, swarm, wk45, ou não souber qual IDE/CLI usar. Consultar wiki [[Ecossistema Harness Router AGL]]. Não implementar código — só decidir harness, auth mode e skill filha.
disable-model-invocation: false
---

# AGL Harness Router

Fonte canónica: `llm-wiki/wiki/Ecossistema Harness Router AGL.md` · `agl-hostman/docs/HARNESS-ROUTER.md`

## Quando usar

- Tarefa nova sem harness óbvio.
- Quota esgotada — re-router para tier inferior.
- Multi-frente (vários repos/issues em paralelo).
- Pedido explícito: "usa Cursor", "swarm", "Max", "Verdent".

## Matriz de decisão

| Cenário                                      | Harness       | Auth mode             | Skill seguinte           |
| -------------------------------------------- | ------------- | --------------------- | ------------------------ |
| Bug/UI 1–3 ficheiros                         | Cursor        | `litellm` ou Pro Auto | `agl-cursor-agent`       |
| Debug / arquitectura / MCP                   | Claude Code   | `max-direct`          | `agl-claude-code-agent`  |
| 2+ features paralelas (branches)             | Verdent       | `litellm`             | `agl-verdent-agent`      |
| Refactor / feature >5 ficheiros / multi-repo | Ruflo         | `mixed`               | `agl-ruflo-orchestrator` |
| Cron / infra / CT188                         | Hermes Werner | `free-tier`           | (fora deste router)      |
| KB / llm-wiki                                | Curator       | `free-tier`           | `obsidian-cli`           |
| OpenAI/Z.AI 429                              | Qualquer      | `litellm-free`        | re-triage                |

## Auth modes (AGL)

| Mode           | Env                                                          | Consome          |
| -------------- | ------------------------------------------------------------ | ---------------- |
| `max-direct`   | `unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL`                 | Claude Max OAuth |
| `litellm`      | `ANTHROPIC_BASE_URL=http://100.125.249.8:4000` + virtual key | API via CT186    |
| `litellm-free` | LiteLLM aliases T2 (`glm-4.7-flash`, `groq-*`)               | Free/burst       |
| `cursor-pro`   | Cursor IDE sem override URL                                  | Pool Pro Cursor  |

Perfis exemplo: `agl-hostman/config/harness/*.env.example`

Dispatch executável (Fase 2):

```bash
bash scripts/agl/harness-dispatch.sh --harness claude-code --auth max-direct --task "..."
bash scripts/agl/harness-dispatch.sh --dry-run --harness ruflo --auth litellm --task "spec X"
```

## Output obrigatório

Responder com bloco estruturado:

```
HARNESS: claude-code | cursor | verdent | ruflo
AUTH: max-direct | litellm | litellm-free | cursor-pro
SKILL: agl-*-agent
RATIONALE: (1–2 frases)
NEXT: comando ou acção concreta
```

Depois invocar a skill filha ou pedir confirmação se auth mode misturar subscrição com API.

## Anti-patterns

- Não usar Max via LiteLLM com API key estática.
- Não spawn Ruflo >8 agents.
- Não Cursor premium manual com pool Pro esgotado — Auto ou LiteLLM.
