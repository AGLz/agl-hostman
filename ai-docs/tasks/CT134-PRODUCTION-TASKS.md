# CT134 Produção — Backlog SCRUM

> Plano: [`../planning/CT134-IMPLEMENTATION-PLAN.md`](../planning/CT134-IMPLEMENTATION-PLAN.md)  
> Actualizado: 2026-06-12

Legenda: `[ ]` pendente · `[x]` feito · `[~]` em progresso

---

## Epic: CT134 agl-hostman produção (`ah.aglz.io`)

### Fase 0 — Pré-checks

| ID | Tarefa | Prioridade | Estado |
|----|--------|------------|--------|
| CT134-0.1 | Confirmar VMID 134 livre no AGLSRV1 | P0 | [x] |
| CT134-0.2 | Validar IP 192.168.0.134 livre | P0 | [x] |
| CT134-0.3 | Testar conectividade CT149 (Postgres) e CT137 (Redis) | P0 | [x] |
| CT134-0.4 | Commit/merge artefactos pipeline no repo | P0 | [x] |

### Fase 1 — CT134 LXC + Docker

| ID | Tarefa | Prioridade | Estado |
|----|--------|------------|--------|
| CT134-1.1 | `pct-create-agl-hostman-prod.sh` | P0 | [x] |
| CT134-1.2 | SSH + password/chave deploy | P0 | [~] |
| CT134-1.3 | `bootstrap-ct134-agl-hostman-prod.sh` | P0 | [x] |
| CT134-1.4 | Configurar `.env` prod (DB, Redis, APP_URL) | P0 | [x] |
| CT134-1.5 | Tailscale no CT134 (opcional) | P2 | [x] |

### Fase 2 — Harbor + DB

| ID | Tarefa | Prioridade | Estado |
|----|--------|------------|--------|
| CT134-2.1 | Projecto Harbor `agl-hostman-prod` | P0 | [x] |
| CT134-2.2 | Robot account → GitHub Secrets | P0 | [x] |
| CT134-2.3 | DB `agl_hostman_prod` CT149 | P0 | [x] |
| CT134-2.6 | Certificado Harbor `harbor.aglz.io` + trust Docker CT134 | P0 | [x] |
| CT134-2.4 | Push imagem smoke manual | P1 | [x] |
| CT134-2.5 | Política retention Harbor | P2 | [ ] |

### Fase 3 — Dokploy

| ID | Tarefa | Prioridade | Estado |
|----|--------|------------|--------|
| CT134-3.1 | Registar CT134 como Server | P0 | [x] |
| CT134-3.2 | App `agl-hostman-prod` + scripts API | P0 | [x] |
| CT134-3.3 | Deploy manual primeira imagem | P0 | [x] |
| CT134-3.4 | Webhook + `DOKPLOY_API_KEY` GitHub | P0 | [x] |
| CT134-3.5 | Preview PR (opcional) | P2 | [ ] |

### Fase 4 — GitHub CI/CD

| ID | Tarefa | Prioridade | Estado |
|----|--------|------------|--------|
| CT134-4.1 | Secrets GitHub completos | P0 | [x] |
| CT134-4.2 | Environment `production-ct134` | P1 | [x] |
| CT134-4.3 | Branch protection `main` | P1 | [ ] |
| CT134-4.4 | PR teste → tag `pr-*` Harbor | P0 | [ ] |
| CT134-4.5 | Merge teste → deploy automático | P0 | [~] |

### Fase 5 — Cloudflare

| ID | Tarefa | Prioridade | Estado |
|----|--------|------------|--------|
| CT134-5.1 | Documentar origin dev actual `ah.aglz.io` | P0 | [x] |
| CT134-5.2 | Criar `ah-dev.aglz.io` → dev | P0 | [x] |
| CT134-5.3 | Repoint `ah.aglz.io` → CT134 | P0 | [x] |
| CT134-5.4 | `CT134_HEALTH_URL` público | P0 | [x] |
| CT134-5.5 | Ingress `dok.aglz.io` → CT180 | P1 | [x] |

Runbook: [`docs/runbooks/CT134-CLOUDFLARE-CUTOVER.md`](../../docs/runbooks/CT134-CLOUDFLARE-CUTOVER.md)

### Fase 6 — Go-live

| ID | Tarefa | Prioridade | Estado |
|----|--------|------------|--------|
| CT134-6.1 | E2E `npm run test:e2e:ah` | P0 | [ ] |
| CT134-6.2 | Horizon + scheduler OK | P0 | [ ] |
| CT134-6.3 | Comunicação equipa cutover | P1 | [ ] |
| CT134-6.4 | Monitorização 48 h | P1 | [ ] |
| CT134-6.5 | Entrada llm-wiki (domínios + CT134) | P2 | [ ] |

---

## Backlog pós go-live

| ID | Tarefa | Prioridade |
|----|--------|------------|
| CT134-B.1 | `ah-qa.aglz.io` + pipeline QA | P2 |
| CT134-B.2 | `ah-uat.aglz.io` + pipeline UAT | P2 |
| CT134-B.3 | PR preview `pr-N.ah.aglz.io` | P2 |
| CT134-B.4 | Deduplicar push imagem em `ci.yml` | P2 |
| CT134-B.5 | Mission Control CT134 | P2 |

---

## Descobertas / blockers

_Registar aqui durante a implementação._

| Data | Nota |
|------|------|
| 2026-06-12 | Plano criado; cutover depende de origin dev documentado em §3 runbook Cloudflare |
| 2026-06-12 | **F1 CT134 criado AGLSRV1:** VMID 134 `agl-hostman` · IP `192.168.0.134/24` · Docker 29.5.3 · compose+env em `/opt/agl-hostman-prod` · AppArmor unconfined · `docker compose up` aguarda imagem Harbor (F2) · Harbor :443/:5000 recusado de CT134→182 (validar CT182) · Tailscale instalado, falta `tailscale up` |
