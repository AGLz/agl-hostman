# CT134 agl-hostman — Produção AGLSRV1

> **Fonte de verdade (runbook):** wiki [[CT134 — Pipeline Produção agl-hostman]] em `llm-wiki`  
> (`/mnt/overpower/apps/dev/agl/llm-wiki/wiki/CT134 — Pipeline Produção agl-hostman.md`)  
> **Cutover DNS:** [`docs/runbooks/CT134-CLOUDFLARE-CUTOVER.md`](runbooks/CT134-CLOUDFLARE-CUTOVER.md)

## Resumo rápido

| Item | Valor |
|------|--------|
| VMID | **134** · `192.168.0.134` · URL `https://ah.aglz.io` |
| Disco | **128G** · `scripts/proxmox/resize-ct134-disk.sh` |
| Registry | [[Harbor]] CT182 · `harbor.aglz.io/agl-hostman-prod/hostman` |
| Runner | agldv04 · labels `self-hosted,agl-network` |
| Workflow | `.github/workflows/deploy-ct134-production.yml` |
| Deploy manual | `scripts/dokploy/build-push-ct134-harbor.sh` + `trigger-ct134-deploy.sh` |
| Secrets | `scripts/github/setup-ct134-github-secrets.sh` |
| Harbor health | `scripts/proxmox/harbor-health-ct182.sh` |

Não duplicar o runbook completo aqui — actualizar a página wiki.
