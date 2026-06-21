---
name: agl-verdent-agent
description: |
  Verdent IDE AGL (wk45/Windows): parallel agents, git worktrees, subagents @Multi-Model Planner @Reviewer, skills SKILL.md open standard. Usar para multi-feature paralelo, comparar abordagens, Performance config, aglwk45 VM104. Trigger Verdent, worktree, parallel agents, wk45, Windows dev workstation.
---

# AGL Verdent Agent

## Diferencial vs Cursor

Verdent optimiza **paralelismo explícito** com **git worktrees** — cada agent/feature isolado, merge selective.

| Capacidade       | Verdent                           | Cursor AGL               |
| ---------------- | --------------------------------- | ------------------------ |
| Parallel agents  | Nativo, worktrees                 | Agent único por chat     |
| Multi-model plan | @Multi-Model Planner (2–3 models) | Manual / LiteLLM aliases |
| Skills           | `~/.verdent/skills/` SKILL.md     | `~/.cursor/skills/`      |

Docs: [Verdent Agents](https://www.verdent.ai/docs/verdent/core-features/agents)

## Setup AGL (wk45)

```powershell
# Skills sync (desde agldv03 ou wk45 com repo montado)
bash scripts/skills/propagate-six-repos-wk45-qemu.sh
# ou local:
bash scripts/skills/sync-six-repos.sh --repo harness-router --harness verdent
```

LiteLLM (se configurado OpenAI-compat): apontar para `http://100.125.249.8:4000` — mesma política que Cursor.

## Subagents built-in

| Subagent             | Uso AGL                                                  |
| -------------------- | -------------------------------------------------------- |
| @Multi-Model Planner | Decisões arquitectura (complementa Ruflo, não substitui) |
| @Reviewer            | Review pós-implementação                                 |
| @Verifier            | Lint/types rápido                                        |
| @Fast Context        | Index codebase                                           |

## Casos de uso

| Cenário                                     | Abordagem                     |
| ------------------------------------------- | ----------------------------- |
| Auth + Payments + Notifications em paralelo | 3 worktrees, 3 agents         |
| Comparar 2 designs API                      | 2 workspaces, rebase vencedor |
| Dev Windows sem SSH Linux                   | Verdent + LiteLLM TS          |

## Skills partilhadas

Instalar subset Six Repos em `~/.verdent/skills/`:

- `agl-harness-router`, `agl-verdent-agent`, `obsidian-cli`, `andrej-karpathy-skills`

## Quando NÃO usar

- Infra Proxmox/CT → `agl-infra` + Claude Code
- Swarm 6+ workers coordenados → `agl-ruflo-orchestrator`
- Hermes/Telegram bots → CT188
