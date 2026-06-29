# CLAUDE.md — Contexto do workspace (agl-hostman)

## TL;DR

1. **Ler:** `primary-guide.mdc`, `llm-wiki/wiki/index.md`, `bd ready --json`
2. **Implementar:** diff mínimo; convenções em ficheiros irmãos e `laravel-boost.mdc` (scoped `src/**`)
3. **Fechar:** `mandatory-delivery-pipeline` (testes → review → push/PR)
4. **Conflito de regras:** stack/repo prevalece sobre hábitos gerais (Karpathy)

## Identidade

**agl-hostman:** infra AGL, API Node (`src/api/`), Laravel 12 (`src/`), LiteLLM, Docker, docs operacionais.  
Harnesses: Cursor + Claude Code + Ruflo (opcional).

## Factos essenciais

| Área          | Local                                     |
| ------------- | ----------------------------------------- |
| API Node      | `src/api/server.js` — `npm run dev`       |
| Laravel       | `src/` — `php artisan test`               |
| LiteLLM       | `config/litellm/config.yaml`              |
| OpenClaw prod | CT187; LiteLLM CT186                      |
| llm-wiki      | `/mnt/overpower/apps/dev/agl/llm-wiki`    |
| Clone agldv03 | `/mnt/overpower/apps/dev/agl/agl-hostman` |
| bd / beads    | `.beads/` — fluxo em `AGENTS.md`          |

## Protocolo de sessão

**Início:** `bd ready --json` → objetivos → consultar wiki se infra/features.  
**Durante:** decisões duráveis → bd ou llm-wiki; padrões → skills/rules (`self-improve`).  
**Fim:** testes → push se política exigir → `/reflect-yourself` se houve correções.

## Karpathy Skills

Texto completo: `.cursor/rules/karpathy-skills.mdc` (intelligent). Em conflito: **laravel-boost**, **primary-guide** prevalecem.

## Wiki (detalhe operacional)

Não duplicar runbooks aqui — ver `llm-wiki/wiki/`:

- [[agl-hostman — Contrato Agentes Cursor]]
- [[Hermes — Operações CT188]]
- [[AGLSRV1 — Troubleshooting aglwk45]]
- [[Ruflo — Workarounds AGL]]

## Isolamento paralelo

`git worktree add .worktrees/agent-N -b agent-N/nome-tarefa` — evitar `--dangerously-skip-permissions` fora de containers.
