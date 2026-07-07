# CT194 agl-makemoney01 — demos CRM/ERP makemoney01

| VMID | Hostname | IP LAN | Função |
|------|----------|--------|--------|
| **194** | agl-makemoney01 | 192.168.0.194 | nginx multi-app — **12 demos** niche CRM/ERP |

## Criar CT (root@aglsrv1 ou via deploy remoto)

```bash
# One-shot (de agldv03/agldv12 com SSH aglsrv1)
bash scripts/proxmox/deploy-ct194-makemoney01.sh

# Ou passo a passo:
bash scripts/proxmox/pct-create-makemoney01-ct194.sh
bash scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor 194
bash scripts/proxmox/bootstrap-ct194-makemoney01.sh
```

## URLs (DNS via túnel **archon** CT117 — não aglsrv1)

Script: `agl-hostman/scripts/cloudflare/provision-mm01-archon-tunnel.sh`

- `https://crm-imobiliaria.mm01.aglz.io` → CT194 :8101
- `https://erp-estacionamento.mm01.aglz.io` → :8108
- `https://erp-supermercado.mm01.aglz.io` → :8109
- … 12 demos + `https://mm01.aglz.io`

## Repos (NFS)

`/mnt/overpower/apps/dev/agl/crm-*` e `erp-*` — manifest `makemoney01/config/niche-projects.json`

Scaffold: `python3 makemoney01/scripts/scaffold_niche_projects.py`  
Pack AGL: `bash scripts/skills/propagate-agl-pack-makemoney-niches.sh`

Ver: [[makemoney01-CRM-ERP-Nichos]]
