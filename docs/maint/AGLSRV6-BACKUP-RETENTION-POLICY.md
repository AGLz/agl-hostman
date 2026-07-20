# Política de retenção — AGLSRV6 (man6)

**Última revisão:** 2026-07-18  
**Host:** man6 (`100.98.108.66`) · PBS CT613 (`192.168.0.231`)  
**Apply:** `scripts/proxmox/aglsrv6-pbs-policy-apply.sh --apply --remote`  
**Cold:** `scripts/proxmox/aglsrv6-usb-cold-export.sh --apply`  
**Watchdog:** Hermes Werner `aglsrv6-backup-watchdog` (CT188)

## Objectivo

| Tier | Mídia | Retenção | Função |
|------|-------|----------|--------|
| **Hot** | ZFS `rpool/backups` (PBS datastore `backups`) | **1 snapshot** por guest (`keep-last=1`) | Restore rápido |
| **Cold** | USB 4TB **exFAT** → `/mnt/usb4tb-direct/cold` | CT: 7 cópias · VM620: 2 (semanal) | Histórico / offsite físico |

**Nota exFAT:** PBS **não** usa o USB como datastore (exige ext4/xfs/zfs). O cold tier é **vzdump** para `cold/`, não sync PBS.

### Fluxo diário

```
02:00–06:00  vzdump → man6-pbs (hot ZFS), prune job keep-last=1
07:00        cold-export CTs → /mnt/usb4tb-direct/cold (cap USB 70%)
07:30 Dom    cold-export + VM620 (--include-weekly)
08:00        prune PBS hot keep-last=1 (remove extras no ZFS)
```

---

## Inventário UP (política)

| VMID | Tipo | Nome | Tier | Schedule PBS |
|------|------|------|------|--------------|
| 620 | VM | WinServer2016-VirtIO (MSSQL) | **P0 SQL** | `0,6,12,18` + 02:00 |
| 610 | CT | mssql6 | **P0 SQL** | `0,6,12,18` |
| 601,602,609,614,617,621 | CT | infra | P1 | `3,15` |
| 604,608,611 | CT | apps | P2 | 05:00 |

### Excluídos do backup automático

| VMID | Motivo |
|------|--------|
| **613** | PBS — recursão |
| **605** | discos/volsize — fora do tier3 até validação |
| 107,616,622,603 | parados / manual |

### Jobs vzdump (canónicos → `man6-pbs`)

| Job ID | VMIDs | prune |
|--------|-------|-------|
| `backup-vm620-production` | 620 | keep-last=1 |
| `backup-pbs-tier1-sql-6h` | 610,620 | keep-last=1 |
| `backup-pbs-tier2-infra-12h` | 601,602,609,614,617,621 | keep-last=1 |
| `backup-pbs-tier3-daily` | 604,608,611 | keep-last=1 |

---

## PBS prune + cold

| Job | Estado | Política |
|-----|--------|----------|
| `prune-hot-backups` | activo 08:00 | `keep-last=1` (sem keep-daily) |
| `sync-hot-to-cold` | **sem schedule** | só se USB passar a ext4 + `--force-usb-sync` |
| `prune-cold-usb` | **disabled** | datastore PBS `usb4tb-direct` não é o USB físico |
| cron `aglsrv6-usb-cold-export` | activo | cold real em `cold/` |

Se USB offline: apply sobe hot para `keep-last=2` e desactiva o cron cold.

---

## Cap USB

- Abortar novos cold se uso ≥ **70%**
- Prune cold até ~**65%**
- Disco USB2 — aceitar throughput baixo; VM620 só Domingo

---

## Monitorização

| Item | Valor |
|------|-------|
| Script | `scripts/monitoring/aglsrv6-backup-watchdog.sh` |
| Health | `scripts/proxmox/aglsrv6-backup-health.sh --remote` |

---

## Referências

- [`AGLSRV6-BACKUP-PBS-TASK-FORCE.md`](AGLSRV6-BACKUP-PBS-TASK-FORCE.md)
- `scripts/proxmox/aglsrv6-pbs-policy-apply.sh`
- `scripts/proxmox/aglsrv6-usb-cold-export.sh`
)
