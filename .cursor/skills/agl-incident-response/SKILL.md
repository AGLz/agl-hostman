---
name: agl-incident-response
description: Resposta a incidentes AGL — LiteLLM CT186, OpenClaw CT187, Hermes CT188, aglwk45, escalação SEV, post-mortem. Usar em outage, breach, degradação produção ou alertas críticos infra AGL.
origin: agl-hostman
---

# Incident Response AGL

## Primeiros 15 minutos

1. **Classificar SEV** (P0–P3) — ver `agl-devsecops`
2. **Conter** — rollback, disable feature flag, rotacionar secret se leak
3. **Comunicar** — canal interno; status se user-facing
4. **Preservar evidência** — logs, timestamps, diff deploy

## Runbooks (llm-wiki)

Consultar MCP `llm-wiki-fs` ou vault:

- [[Hermes — Operações CT188]]
- [[AGLSRV1 — Troubleshooting aglwk45]]
- [[agl-hostman — Contrato Agentes Cursor]]

Não inventar procedimentos se runbook existir.

## Comandos úteis

```bash
# Smoke Hermes (de agl-hostman)
bash scripts/skills/smoke-hermes-six-repos.sh

# Audit pack nos hosts
bash scripts/skills/audit-agl-pack-all-hosts.sh --host agldv04

# LiteLLM — ver config
cat config/litellm/config.yaml  # sem expor keys
```

## Roles (ICS simplificado)

| Role | Responsabilidade |
|------|------------------|
| Commander | Coordena, decide rollback |
| Communicator | Updates stakeholders |
| Fixer | Debug + patch |
| Scribe | Timeline para post-mortem |

Em sessão agente única: documentar timeline em comentário/commit.

## Post-mortem (template)

```markdown
## Incidente YYYY-MM-DD — [título]

- **SEV:** P?
- **Duração:** 
- **Impacto:** 
- **Causa raiz:** 
- **Correcção:** 
- **Acções preventivas:** 
- **Links:** PR, logs, wiki
```

Ingerir no llm-wiki via `llm-wiki-ingest` — decisões duráveis.

## Skills relacionadas

- `incident-response-commander` (agency) — profundidade ICS
- `systematic-debugging` — root cause
- `agl-devsecops` — checklist pré/post
