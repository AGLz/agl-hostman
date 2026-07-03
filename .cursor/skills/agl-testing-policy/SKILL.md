---
name: agl-testing-policy
description: Política de testes AGL — resolve conflitos TDD vs ponytail vs velocity mode. Usar ao implementar features, hotfixes, refactors ou quando skills de testing discordarem (test-driven-development, testing-test-writing, common-testing, ponytail).
origin: agl-hostman
---

# Política de Testes AGL

## Precedência (maior → menor)

1. **Pedido explícito do utilizador** — ex.: "sem testes", "só E2E"
2. **`mandatory-delivery-pipeline`** — testes antes de declarar feito
3. **Esta skill** — escolhe modo por contexto
4. Skills específicas (`tdd-workflow`, `testing-test-writing`, `ponytail`)

## Modos

| Modo | Quando | O que fazer |
|------|--------|-------------|
| **strict-tdd** | Feature P0/P1, API pública, auth, pagamentos | RED→GREEN→REFACTOR; meta 80% no módulo tocado |
| **regression-min** | Hotfix, bug pontual | 1 teste que reproduz o bug + suite afetada |
| **velocity** | Spike, protótipo descartável, docs-only | Testes só em paths críticos; marcar `ponytail: spike` |
| **agent-meta** | Criar/validar skills | `testing-skills-with-subagents` |

## Stack agl-hostman

```bash
npm test                          # API Node (raiz)
cd src && php artisan test        # Laravel Pest
cd src && php artisan test --filter=NomeTeste
./scripts/test/run_all_tests.sh   # se existir
./scripts/test/code_quality_check.sh
```

## Regras

- **Nunca** declarar "feito" sem `verification-before-completion` (comando executado).
- **Conflito** `testing-test-writing` vs `tdd-workflow`: usar **velocity** só se utilizador ou task disser explicitamente; caso contrário **strict-tdd**.
- **E2E**: Playwright para Inertia; não substituir testes unitários em lógica de negócio.
- **AI regression**: após edits de agente, correr `ai-regression-testing` ou subset da suite.

## Verificação

Antes de PR: invocar `verification-loop` ou `agl-stack-testing`.
