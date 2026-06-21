---
name: agl-ruflo-orchestrator
description: |
  Ruflo/claude-flow AGL: hive-mind hierarchical, agent-os specs/tasks, bd/Linear, multi-frente paralelo. Usar para refactor >5 ficheiros, multi-repo, SPARC, swarm 6-8 agents, implementação agent-os/specs. Trigger ruflo, claude-flow, swarm, hive-mind, parallel workers, agent-os implement. Anti-drift maxAgents 8 raft consensus.
disable-model-invocation: false
---

# AGL Ruflo Orchestrator

Wiki: `llm-wiki/wiki/Ecossistema Harness Router AGL.md` · `llm-wiki/wiki/Ruflo Claude Flow.md`

## Bootstrap

```bash
npm i -g ruflo@latest @claude-flow/cli@latest
cd /mnt/overpower/apps/dev/agl/agl-hostman
npx ruflo@latest init --minimal
ruflo doctor
```

Pós-`npm i -g`: `python3 scripts/ruflo/apply-claude-flow-headless-dsp.py`

## Config swarm (anti-drift)

```bash
npx ruflo@latest swarm init \
  --topology hierarchical \
  --max-agents 8 \
  --strategy specialized
```

| Parâmetro | Valor        | Razão                |
| --------- | ------------ | -------------------- |
| topology  | hierarchical | Queen previne drift  |
| maxAgents | 6–8          | Coordenação apertada |
| strategy  | specialized  | Papéis distintos     |
| consensus | raft         | Estado autoritativo  |

## Integração Agent-OS

1. Ler `agent-os/specs/<spec>/tasks.md`
2. Decompor em workers: Researcher → Architect → Coder → Tester → Reviewer
3. Verificar: `.claude/agents/agent-os/implementation-verifier.md`
4. Fechar: `bd close` / Linear quando DoD cumprido

## SPARC (features novas)

Specification → Pseudocode → Architecture → Refinement → Completion

Standards: `agent-os/standards/` — injetar no prompt queen.

## Paralelismo (obrigatório)

- Spawn workers **numa única mensagem** (Task tool / ruflo parallel).
- MCP + Task juntos para trabalho complexo.
- Checkpoints frequentes; ciclos curtos com gates de verificação.

## Auth / modelos workers

| Worker       | Modelo típico AGL                    |
| ------------ | ------------------------------------ |
| Queen (plan) | Claude Max direct ou Sonnet          |
| Coder/Test   | LiteLLM `zai-coding-glm-4.7`         |
| Burst        | `agl-primary-vm110`, `glm-4.7-flash` |

Claude Max + swarm: validar `/status` — alguns fluxos assumem API.

## Memória

```bash
ruflo memory store --key "spec-name" --value "..." --namespace patterns
ruflo memory search --query "..." --namespace patterns
```

## Quando NÃO usar

- Bug 1 ficheiro → Cursor ou Claude Code solo
- Ops CT188/Hermes → Werner scripts
- Pesquisa wiki only → Curator

## Pipeline entrega

Seguir `mandatory-delivery-pipeline`: implement → test → code-review → (commit se pedido) → push/PR.

## Agent-OS dispatch (Fase 4)

```bash
bash scripts/agl/agent-os-ruflo-dispatch.sh --spec infrastructure/<spec> --write-orchestration --json
bash scripts/agl/agent-os-ruflo-dispatch.sh --spec infrastructure/<spec> --group <task-group> --apply
bash scripts/agl/agent-os-post-task-hook.sh --spec <spec> --group <task-group> [--bd-close bd-XXX]
bash scripts/agl/smoke-harness-agent-os.sh
```
