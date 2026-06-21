---
name: agl-cursor-agent
description: |
  Cursor IDE/Agent AGL: Ask/Plan com LiteLLM CT186 (/cursor), pool Pro (Auto/Composer), rules vs skills, MCP llm-wiki. Usar para UI, iteracao rapida, edits visuais, Ask/Plan mode. Trigger Cursor, composer, cursor-composer, Override OpenAI Base URL, Agent chat. Evitar Agent mode com custom key até issue LiteLLM #19800 resolvida.
paths: .cursor/**, **/*.tsx, **/*.jsx, resources/js/**
---

# AGL Cursor Agent

## Config LiteLLM (Ask/Plan)

1. **Settings → Models → Override OpenAI Base URL:** `http://100.125.249.8:4000/cursor`
2. Virtual key LiteLLM (equipa) — ver `docs/CURSOR-LITELLM-INTEGRATION.md`
3. Modelos custom: `cursor-composer`, `cursor-composer-2-fast`, `cursor-claude-sonnet`, `cursor-glm-5`

**Backend composer:** `gpt-5.4-mini` via proxy (não Composer proprietário Cursor).

## Quota Pro vs API

| Modo                            | Consome                                              |
| ------------------------------- | ---------------------------------------------------- |
| **Auto**                        | Routing Cursor; pool Pro diferente de premium manual |
| Premium manual (GPT-5.5, Opus…) | ~$20/mo pool Pro                                     |
| Custom URL → LiteLLM            | **API keys** AGL, não pool Pro                       |

Toast _"Switched to Composer"_ = pool premium esgotado — usar Auto ou LiteLLM.

## Rules vs Skills (Cursor 2.4+)

|        | Rules `.cursor/rules/`  | Skills `.cursor/skills/` |
| ------ | ----------------------- | ------------------------ |
| Quando | Always-on / globs       | On-demand                |
| Uso    | Convenções Laravel, git | Workflows (`agl-*`, ECC) |

Invocar manualmente: `/agl-harness-router` ou `/agl-cursor-agent` se auto-match falhar.

## MCP AGL

- `llm-wiki-fs` — segundo cérebro
- LiteLLM MCP — opcional

## Casos de uso

| Tarefa                  | Recomendação                   |
| ----------------------- | ------------------------------ |
| Fix componente React    | Ask/Plan + `cursor-composer`   |
| Explorar codebase       | Ask + Auto ou Sonnet via proxy |
| Agent multi-file pesado | Preferir Ruflo ou Claude Code  |
| Docs wiki               | `/llm-wiki-ingest` + Curator   |

## Limitações

- **Agent mode + custom API key:** limitado ([litellm#19800](https://github.com/BerriAI/litellm/issues/19800))
- Preferir **Ask/Plan** com proxy AGL para controlo de custo

## Sync skills

```bash
bash scripts/skills/sync-six-repos.sh --repo harness-router --harness cursor
```
