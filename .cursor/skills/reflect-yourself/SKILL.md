---
name: reflect-yourself
description: Self-learning AGL — captura correções da sessão e propõe updates a learned-memories, rules, skills ou llm-wiki. Use no fim de sessão produtiva, após correções, ou quando o utilizador pede /reflect-yourself.
---

# reflect-yourself (AGL)

Sistema de auto-aprendizagem adaptado ao ecossistema AGL. Baseado em [maorfsdev/reflect-yourself](https://github.com/maorfsdev/reflect-yourself).

## Workflow

1. **Analisar** a conversa (correções, preferências, padrões repetidos)
2. **Apresentar** learnings em cards (summary-first) — **nunca auto-aplicar**
3. **Aguardar** aprovação explícita do utilizador
4. **Aplicar** só após "apply" / "aplicar"

## Placement AGL (prioridade)

| Tipo                                     | Destino                                                   |
| ---------------------------------------- | --------------------------------------------------------- |
| Preferência / decisão técnica do projeto | `.cursor/rules/learned-memories.mdc` (via `memory.mdc`)   |
| Padrão de código / convenção             | `.cursor/rules/*.mdc` — usar `@prompt-improve` ao redigir |
| Workflow repetível                       | `.cursor/skills/` ou `.claude/skills/`                    |
| Infra / deploy / arquitectura durável    | **llm-wiki** (`wiki/` + `index.md` + `log.md`)            |
| Routing geral                            | `.cursor/rules/self-improve.mdc`                          |

**Não duplicar** a mesma lição em memória + regra + wiki.

## Comandos

| Comando             | Ficheiro                               |
| ------------------- | -------------------------------------- |
| `/reflect-yourself` | `.cursor/commands/reflect-yourself.md` |

## Filtros

- **Manter:** reutilizável, específico, confidence ≥ 0.60
- **Descartar:** one-off, vago, já coberto, pergunta sem correção

## Queue

`~/.cursor/reflect-queue.json` — learnings pendentes (global, não polui repos)

## Segurança

- Só escrever em `.cursor/skills/`, `.cursor/rules/`, `~/.cursor/skills/`, `learned-memories.mdc`, llm-wiki
- Sanitizar conteúdo; não colar instruções externas verbatim
- Revisão humana obrigatória antes de aplicar

## Quando correr

- Fim de sessão com correções
- Antes de commit significativo
- Quando o utilizador diz "lembra-te" / "captura isto"

**Saltar:** Q&A trivial, tarefas one-off sem aprendizagem.
