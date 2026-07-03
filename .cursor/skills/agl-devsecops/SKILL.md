---
name: agl-devsecops
description: DevSecOps AGL — CTs Proxmox, LiteLLM CT186, OpenClaw CT187, Hermes CT188, Dokploy, secrets, SAST, incident response. Usar antes de deploy, hardening, audit segurança ou resposta a incidentes infra AGL.
origin: agl-hostman
---

# DevSecOps AGL

## Mapa infra (referência)

| CT/Serviço | Função | Smoke |
|------------|--------|-------|
| CT186 | LiteLLM gateway | `curl -sS http://<host>:4000/health` |
| CT187 | OpenClaw prod | health endpoint do stack |
| CT188 | Hermes | `scripts/skills/smoke-hermes-six-repos.sh` |
| CT179 | Laravel app (se aplicável) | `php artisan about` |

Runbooks detalhados: **llm-wiki** (`wiki/index.md`) — não duplicar aqui.

## Checklist pré-deploy

1. **Secrets** — nenhum em diff; `.env` fora do Git
2. **Deps** — `npm audit --audit-level=high`; `cd src && composer audit`
3. **SAST** — skill `agl-sast-gate` ou workflow `security-scan.yml`
4. **Testes** — `agl-stack-testing`
5. **Review** — `review-security` + `review-bugbot` em features sensíveis

## Shift-left local

```bash
# Secrets rápidos (não substitui TruffleHog CI)
bash scripts/skills/scan-skill-security.sh .cursor/skills/<nome>  # skills novas

# GHA workflows
# Ver skill github-actions-validator se disponível
```

## Incident response (resumo)

| SEV | Exemplo | Acção imediata |
|-----|---------|----------------|
| P0 | LiteLLM down, leak secrets | Rotacionar keys; skill `agl-incident-response` |
| P1 | API 5xx sustentado | Rollback deploy; logs CT |
| P2 | Degradação performance | SLO review; `observability-engineer` |
| P3 | Vuln não explorada | Ticket + patch window |

Post-mortem blameless → `llm-wiki-ingest` (não README longo).

## Agent harness security

- Auditar skills externas com `scan-skill-security.sh` antes de propagate
- `skill-scout` antes de adoptar repo desconhecido
- Não `--no-verify` em commits com alterações security

## Skills relacionadas

- `defense-in-depth` — validação multi-camada em código
- `security-review` — checklist auth/secrets/API
- `agl-sast-gate` — comandos SAST locais
- `agl-incident-response` — runbook operacional
