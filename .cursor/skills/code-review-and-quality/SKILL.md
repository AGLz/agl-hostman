---
name: code-review-and-quality
description: Review de código AGL — cinco eixos (correctness, security, maintainability, performance, tests), severidades Nit/Optional/Blocker, ~100 linhas por PR. Usar antes de merge, em review-bugbot follow-up, ou quando pedirem code review estruturado.
origin: addyosmani/agent-skills (adaptado AGL)
---

# Code Review & Quality (AGL)

## Cinco eixos

1. **Correctness** — faz o que o ticket pede? edge cases?
2. **Security** — input validation, auth, secrets (`review-security` se sensível)
3. **Maintainability** — legível, diff mínimo (`ponytail.mdc`)
4. **Performance** — N+1, queries, bundle size
5. **Tests** — `agl-testing-policy`; regressão coberta?

## Severidades

| Label | Significado |
|-------|-------------|
| **Blocker** | Merge proibido até fix |
| **Important** | Deve corrigir neste PR ou issue imediata |
| **Optional** | Melhoria desejável |
| **Nit** | Estilo/preferência |

## Tamanho de PR

- Ideal: **&lt;100 linhas** lógica por review round
- &gt;300 linhas: pedir split ou review por módulo

## Checklist rápido

- [ ] Testes passam (`agl-stack-testing`)
- [ ] Sem secrets no diff
- [ ] Docs/wiki se decisão durável
- [ ] `mandatory-delivery-pipeline` cumprido

## Invocação automática

- `/review-bugbot` — bugs gerais
- `review-security` — superfície sensível
- Subagent `code-reviewer` — após implementação

## Output esperado

Tabela markdown: Severity | Location | Finding | Sugestão
