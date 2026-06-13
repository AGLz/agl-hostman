# CT134 agl-hostman — Produção AGLSRV1

> **Plano de implementação:** [`ai-docs/planning/CT134-IMPLEMENTATION-PLAN.md`](../ai-docs/planning/CT134-IMPLEMENTATION-PLAN.md)  
> **Cutover DNS:** [`docs/runbooks/CT134-CLOUDFLARE-CUTOVER.md`](../runbooks/CT134-CLOUDFLARE-CUTOVER.md)  
> **Backlog SCRUM:** [`ai-docs/tasks/CT134-PRODUCTION-TASKS.md`](../tasks/CT134-PRODUCTION-TASKS.md)  
> **Plano detalhado:** [`ai-docs/planning/CT134-PRODUCTION-PIPELINE.md`](../ai-docs/planning/CT134-PRODUCTION-PIPELINE.md)  
> **Dokploy:** CT180 · **Harbor:** CT182 · **Runtime:** CT134 · **Branch:** `main`

## Resumo

| Item | Valor |
|------|--------|
| VMID | **134** (confirmar livre no AGLSRV1) |
| Hostname | `agl-hostman` |
| IP LAN (sugerido) | `192.168.0.134` |
| Runtime | CT134 AGLSRV1 |
| URL pública | **`https://ah.aglz.io`** (ex-dev; outros ambientes: `ah-dev`, `ah-qa`, `ah-uat`) |
| Stack | Laravel 12 (`src/Dockerfile`) + Horizon + scheduler |
| Registry | `harbor.aglz.io/agl-hostman-prod/hostman` |
| Orquestração | Dokploy (CT180) → deploy no CT134 |
| Dev | CT179 agldv03 (NFS) — **não** partilhar código com prod |

## Provisionamento (AGLSRV1)

```bash
ssh root@100.107.113.33   # AGLSRV1 Tailscale

cd /path/to/agl-hostman/scripts/proxmox
cp pct-create-agl-hostman-prod.env.example pct-create-agl-hostman-prod.env
# editar IP/recursos se necessário
set -a && source pct-create-agl-hostman-prod.env && set +a
bash pct-create-agl-hostman-prod.sh

pct exec 134 -- bash -s < bootstrap-ct134-agl-hostman-prod.sh
# ou copiar repo e: COMPOSE_SOURCE=... HARBOR_USER=... HARBOR_PASSWORD=... bootstrap...
```

## Pipeline GitHub

Workflow: [`.github/workflows/deploy-ct134-production.yml`](../.github/workflows/deploy-ct134-production.yml)

| Evento | Acção |
|--------|--------|
| PR → `main` | Testes + imagem `pr-{n}-{sha}` no Harbor |
| Push `main` (merge) | Imagem `prod-{sha}` + `prod-latest` → webhook Dokploy → health CT134 |

**Secrets GitHub (repo):**

| Secret | Uso |
|--------|-----|
| `HARBOR_USERNAME` / `HARBOR_PASSWORD` | Push imagem |
| `DOKPLOY_PROD_WEBHOOK_URL` | Deploy produção (app Dokploy CT134) |
| `DOKPLOY_PREVIEW_WEBHOOK_URL` | Opcional — preview por PR |
| `CT134_HEALTH_URL` | ex. `https://ah.aglz.io/health/` |

## Dokploy + Harbor (manual inicial)

Ver [`scripts/dokploy/setup-ct134-production.md`](../scripts/dokploy/setup-ct134-production.md).

## Rollback

Ver [`ROLLBACK-USAGE.md`](ROLLBACK-USAGE.md) — redeploy tag anterior no Harbor/Dokploy.

## Documentação completa

| Documento | Uso |
|-----------|-----|
| [`ai-docs/planning/CT134-IMPLEMENTATION-PLAN.md`](../ai-docs/planning/CT134-IMPLEMENTATION-PLAN.md) | Plano faseado (F0–F6) |
| [`docs/runbooks/CT134-CLOUDFLARE-CUTOVER.md`](runbooks/CT134-CLOUDFLARE-CUTOVER.md) | Cutover `ah.aglz.io` / `ah-dev` |
| [`ai-docs/tasks/CT134-PRODUCTION-TASKS.md`](../ai-docs/tasks/CT134-PRODUCTION-TASKS.md) | Checklist SCRUM |
