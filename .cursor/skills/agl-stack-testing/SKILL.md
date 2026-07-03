---
name: agl-stack-testing
description: Testes no stack AGL — Fastify API Node, Laravel 12 Pest, Inertia React, Playwright E2E. Usar quando correr testes, criar testes Pest/PHPUnit, Supertest, E2E Inertia, ou validar CI agl-hostman.
origin: agl-hostman
---

# Testes — Stack AGL (agl-hostman)

## Comandos canónicos

```bash
# API Node (raiz)
npm test
npm test -- --grep "nome"   # se tap/node:test suportar

# Laravel (src/)
cd src && composer install --no-interaction
cd src && php artisan test
cd src && php artisan test --parallel
cd src && php artisan test --filter=FeatureName
cd src && php artisan test tests/Feature/ExampleTest.php

# Suite agregada (quando existir)
./scripts/test/run_all_tests.sh
./scripts/test/code_quality_check.sh
```

## Onde colocar testes

| Stack | Path | Framework |
|-------|------|-----------|
| API Node | `tests/` (raiz) | node:test / tap (ver package.json) |
| Laravel | `src/tests/Feature/`, `src/tests/Unit/` | Pest |
| E2E | `tests/e2e/` (criar se necessário) | Playwright |

## Pest / Laravel

- `RefreshDatabase` em features que tocam DB
- Factories em `src/database/factories/`
- Inertia: `assertInertia` em Feature tests
- Seguir `laravel-boost.mdc` e `php-testing.mdc`

## API Node (Fastify)

- Testes de integração contra `src/api/server.js`
- Mock de LiteLLM/externos nos boundaries
- Validar inputs nos endpoints públicos

## E2E (Inertia + React)

1. Activar skill `e2e-testing` para padrões POM
2. `data-testid` em componentes shadcn quando possível
3. Auth: fixture de login antes dos fluxos
4. CI: artefactos (screenshot, trace) em falha

## Fluxo recomendado

1. `agl-testing-policy` — escolher modo (strict-tdd vs regression-min)
2. Escrever/correr teste
3. `verification-before-completion` — evidência na sessão
4. PR: `verification-loop` + `review-bugbot`

## Anti-padrões

- Não mockar sem entender dependência (`testing-anti-patterns`)
- Não `sleep` em E2E — usar `condition-based-waiting` / `expect.poll`
- Não saltar Pest quando só Node foi alterado (e vice-versa) — verificar ambos se shared contract
