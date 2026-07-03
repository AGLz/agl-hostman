---
name: agl-qa-regression
description: QA Lead AGL — encontrar bugs, gerar testes de regressão, validar fixes com evidência. Usar após bug report, antes de release, ou quando pedirem regression suite para código gerado por agente.
origin: garrytan/qa (adaptado AGL)
---

# QA Regression (AGL)

## Workflow

1. **Reproduzir** — passos mínimos; log/stack trace
2. **Teste que falha** — Pest ou npm test (RED)
3. **Fix** — diff mínimo
4. **GREEN** — suite afetada + `ai-regression-testing` mindset
5. **Evidência** — screenshot Playwright se UI (`evidence-collector`)

## Tipos de teste por camada

| Camada | Ferramenta |
|--------|------------|
| Unit | Pest / node:test |
| Feature/API | Pest Feature, Supertest |
| E2E | Playwright (`e2e-testing`) |
| Visual | screenshot + compare manual |

## Código gerado por agente

- Assumir **pelo menos 1 bug** até prova em contrário
- Correr `verification-loop` ou `agl-stack-testing`
- Procurar callers do código alterado (fix na função partilhada)

## Release readiness

Combinar: `production-audit` + `agl-sast-gate` + testes verdes.

## Output

- Lista bugs encontrados (mín. verificação honesta)
- Testes adicionados (paths)
- Comandos de verificação executados
