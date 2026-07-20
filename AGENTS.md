# agl-hostman

> Orquestração multi-agente e gestão de infra AGL (hosts, stacks, gateway LLM)

## TL;DR

1. **Ler:** `.cursor/rules/primary-guide.mdc` + `llm-wiki/wiki/index.md`; `bd ready --json`
2. **Arrancar:** `npm install` → `npm run dev` / `src/README.md` (Laravel)
3. **Testar:** `npm test` + `php artisan test --filter=...` quando Laravel afetado
4. **Fechar:** testes → review → push; `git status` = up to date

## Stack

- **Node 18+** — API `src/api/` (Fastify)
- **Laravel 12** — app em `src/` (Inertia React, Pest); regra `laravel-boost.mdc` (scoped `src/**`)
- **LiteLLM** — `config/litellm/config.yaml` — `docs/CURSOR-LITELLM-INTEGRATION.md`
- **Docker** — `docker/`, compose na raiz

## Comandos

```bash
npm install && npm run dev   # API Node
npm test                     # testes raiz
```

Laravel: `src/README.md`, `composer install`, `php artisan test`.

## Regras Cursor (2 sempre ativas)

| Regra                                                     | Modo                  |
| --------------------------------------------------------- | --------------------- |
| `primary-guide`, `mandatory-delivery-pipeline`            | always                |
| `common-*`, `karpathy-skills`, `llm-wiki`, `self-improve` | intelligent           |
| `common-testing`, `laravel-boost`                         | globs                 |
| `prompt-improve`                                          | manual (`@` no Cmd+K) |

Instalar/propagar: `bash scripts/skills/install-cursor-agent-rules.sh`

## Pack QA + DevSecOps

```bash
bash scripts/skills/install-agl-pack-qa-devsecops.sh
bash scripts/skills/verify-agl-qa-devsecops-pack.sh
bash scripts/skills/eval-agl-qa-devsecops-skills.sh
bash scripts/skills/propagate-agl-pack-full-agldv.sh   # AGLDV*
```

## Plugins Claude Code + Codex

```bash
bash scripts/skills/install-agl-claude-codex-plugins.sh
bash scripts/skills/verify-agl-claude-codex-plugins.sh
```

Activa: `superpowers@marketplace`, github, context7, code-review, commit-commands, feature-dev, frontend-design, prompt-improver; sync ECC + open-design; prepara Codex CLI/config.

Skills: `agl-stack-testing`, `agl-devsecops`, `agl-testing-policy`, `agl-sast-gate`. Wiki: [[agl-hostman-qa-devsecops-pack]].

## Agentes

- Orquestração: `.cursor/rules/common-agents.mdc`
- Self-improve fim de sessão: `/reflect-yourself` ou `self-improve.mdc`
- Memória: `.cursor/rules/learned-memories.mdc`

## Segurança

Sem secrets no Git; validar inputs; paths anti-traversal.

## Wiki (runbooks — não duplicar aqui)

| Tema                       | Página                                    |
| -------------------------- | ----------------------------------------- |
| Contrato lean + propagação | [[agl-hostman — Contrato Agentes Cursor]] |
| Hermes CT188               | [[Hermes — Operações CT188]]              |
| AGLSRV1 / aglwk45          | [[AGLSRV1 — Troubleshooting aglwk45]]     |
| Ruflo workarounds          | [[Ruflo — Workarounds AGL]]               |

## Issue tracking (bd)

```bash
bd ready --json
bd create "Título" -t task -p 2 --json
```

Landing the plane: testes → `git pull --rebase` → push → `git status` limpo.

## Cursor Cloud specific instructions

Ambiente cloud já traz Node 20+ e (via snapshot) PHP 8.3 + Composer + extensão `php-redis`. O update script faz refresh de deps (`npm install` na raiz + `composer install`/`npm install` em `src/`). Migrações, build e arranque de serviços são manuais.

**Dois produtos independentes** partilham a árvore:

| Serviço | Onde | Dev run | Notas |
|---|---|---|---|
| API Fastify (Node) | raiz, `src/api/server.js` | `npm run dev` → `:3030` | Produto principal. Sem DB nem serviços externos para arrancar. |
| App Laravel 12 (Inertia/React) | `src/` | `php artisan serve` → `:8000` | SQLite/sync/file por defeito; Redis/MySQL/WorkOS opcionais. |

**Gotchas não óbvios (cloud):**

- **Serviços AGL externos não são acessíveis** a partir da VM cloud (LiteLLM CT186, Hermes CT188, Proxmox, OpenClaw estão em rede privada/Tailscale). Endpoints como `/api/ai/status` e o dashboard Laravel "Mission Control" mostram `offline`/erros — **é esperado**, não é bug; o degrade é graceful.
- **`npm run lint` está partido** (passa `--ext`, incompatível com o `eslint.config.js` flat). Correr direto: `npx eslint src/api/ src/services/ tests/api/` (passa limpo).
- **`npm test` falha ~50 testes num clone fresco**: são validadores de scripts infra em `tests/unit/` — muitos scripts estão commitados sem bit executável (git mode `100644`) e outros afirmam conteúdo de repos/config AGL externos. Os testes do produto passam: `node --test tests/api/*.test.js` (8/8).
- **`npm run migrate` está partido** (`src/package.json` tem `"type":"module"` mas `src/database/migrate.js` usa `require` CommonJS). A API Node não precisa de DB — ignorar.
- **CSP bloqueia o Vite dev server**: a app Laravel envia `script-src 'self'`, que bloqueia assets cross-origin do Vite (`:5173`). Correr `php artisan serve` + `npm run dev` juntos dá **página em branco**. Para UI funcional na cloud: `npm run build` e servir assets buildados (garantir que `src/public/hot` não existe). HMR exigiria ajustar a CSP.
- **Login local**: além do WorkOS (chaves vazias na cloud), existe auth email/password em `/auth/login`. Criar utilizador com `php artisan tinker` (`App\Models\User`, definir `is_active=true`).

**Setup manual da app Laravel** (uma vez, se `src/.env`/DB não existirem): `composer install` → `cp .env.example .env` → `php artisan key:generate` → `touch database/database.sqlite` → `php artisan migrate` → `npm install` → `npm run build`.
