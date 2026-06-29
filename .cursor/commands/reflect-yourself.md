---
description: Self-learning AGL — captura correções da sessão e propõe updates a learned-memories, rules, skills ou llm-wiki. Use no fim de sessão produtiva, após correções, ou quando o utilizador pede /reflect-yourself.
---

# /reflect-yourself — Session Self-Learning (AGL)

Captura correções e padrões da sessão; propõe destino segundo routing AGL (`self-improve.mdc`).

## Instruções para o agente

### Fase 1 — Análise

Procurar na conversa:

- Correções: "não", "usa X", "lembra-te", "da próxima vez", "está errado"
- Preferências: "sempre", "nunca"
- Padrões repetidos (candidatos a skill)

### Fase 2 — Extração

Por learning: `type`, `content`, `confidence` (0.60–0.95), `destination`, `why`.

### Fase 3 — Placement AGL

1. Decisão/preferência projeto → `learned-memories.mdc`
2. Convenção código → nova/atualizar `.cursor/rules/*.mdc` (aplicar `prompt-improve` ao texto)
3. Workflow → skill `.cursor/skills/` ou `.claude/skills/`
4. Infra/runbook → llm-wiki (`wiki/` + actualizar `index.md` e `log.md`)

### Fase 4 — Revisão humana

Apresentar summary + cards numerados. **Parar e pedir aprovação.**

Opções: aplicar tudo / selecionados / saltar tudo.

### Fase 5 — Aplicar (só após aprovação)

- Deduplicar contra `learned-memories.mdc` e rules existentes
- Diff mínimo; um lar por concern

### Fase 6 — Relatório

Listar aplicado / ignorado / recomendações.

## Complementos

- Export wiki: `/llm-wiki-ingest` (raw + síntese)
- Melhorar texto de regra: Cmd+K + `@prompt-improve`

## Referência upstream

Fluxo completo: [reflect-yourself commands](https://github.com/maorfsdev/reflect-yourself/blob/main/commands/reflect-yourself.md)
