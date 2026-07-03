# Referência AGL — verification-loop

Comandos específicos do repositório **agl-hostman**. Substituir fases genéricas quando aplicável.

## Phase 4: Test Suite (AGL)

```bash
# Raiz — API Node
npm test 2>&1 | tail -50

# Laravel
cd src && php artisan test --parallel 2>&1 | tail -80

# Suite agregada (se existir)
./scripts/test/run_all_tests.sh 2>&1 | tail -50
./scripts/test/code_quality_check.sh 2>&1 | tail -30
```

Meta cobertura: 80% no módulo alterado (`common-testing.mdc`).

## Phase 5: Security (AGL)

Invocar skill `agl-sast-gate` em vez de greps genéricos apenas.

## Política de testes

Consultar `agl-testing-policy` se houver dúvida TDD vs velocity.

## DoD

`mandatory-delivery-pipeline.mdc` — review + testes antes de PR.
