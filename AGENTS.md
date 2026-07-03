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
