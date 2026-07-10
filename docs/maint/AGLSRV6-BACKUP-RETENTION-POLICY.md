# Política de retenção — AGLSRV6 (man6)

**Última revisão:** 2026-07-10  
**Host:** man6 (`100.98.108.66`) · PBS CT613 (`192.168.0.231`)  
**Apply:** `scripts/proxmox/aglsrv6-pbs-policy-apply.sh --apply --remote`  
**Watchdog:** Hermes Werner `aglsrv6-backup-watchdog` (CT188)

## Objectivo

| Tier | Mídia | Retenção | Função |
|------|-------|----------|--------|
| **Hot** | ZFS `rpool/backups` (datastore `backups`) | **1 snapshot** por guest (`keep-last=1`) | Restore rápido |
| **Cold** | USB 4TB (datastore `usb4tb-direct` em ext4) | `keep-daily=7`, `keep-weekly=4`, `keep-monthly=3`, `keep-yearly=1` | Histórico / offsite físico |

**Fluxo diário:**

```
06:00–06:00  vzdump → man6-pbs (datastore backups)
06:30        sync push backups → usb4tb-direct  (após USB ext4 — ver Fase B)
08:00        prune hot (keep-last=1)
weekly       prune cold (retenção longa)
```

Todos os backups passam pelo **PBS** (`man6-pbs`). Nunca vzdump directo para `dir` no host.

---

## Inventário UP (2026-07-10)

| VMID | Tipo | Nome | Tier | Schedule |
|------|------|------|------|----------|
| 620 | VM | WinServer2016-VirtIO (MSSQL legado) | **P0 SQL** | `*/6` + dedicado 02:00 |
| 610 | CT | mssql6 | **P0 SQL** | `*/6` |
| 601 | CT | cloudflared6 | P1 Infra | 02:00, 14:00 |
| 602 | CT | meshcentral6 | P1 Infra | 02:00, 14:00 |
| 609 | CT | redis6 | P1 Infra | 02:00, 14:00 |
| 614 | CT | cloudflared6b | P1 Infra | 02:00, 14:00 |
| 617 | CT | pihole6 | P1 Infra | 02:00, 14:00 |
| 621 | CT | wireguard-aglsrv6 | P1 Infra | 02:00, 14:00 |
| 605 | VM | aglhq26 | P2 Apps | 04:00 |
| 604 | CT | luzdivina | P2 Apps | 04:00 |
| 608 | CT | agldv06 | P2 Apps | 04:00 |
| 611 | CT | aluzdivina | P2 Apps | 04:00 |

### Excluídos do backup automático

| VMID | Motivo |
|------|--------|
| **613** | PBS — auto-backup causa recursão / pressão no próprio datastore |
| 107, 616, 622 | Parados (backup manual antes de start se necessário) |
| 603 | opnsense parado |

### Jobs vzdump (canónicos)

| Job ID | VMIDs | Storage |
|--------|-------|---------|
| `backup-vm620-production` | 620 | `man6-pbs` |
| `backup-pbs-tier1-sql-6h` | 610,620 | `man6-pbs` |
| `backup-pbs-tier2-infra-12h` | 601,602,609,614,617,621 | `man6-pbs` |
| `backup-pbs-tier3-daily` | 604,605,608,611 | `man6-pbs` |

Prune no job PVE (ingest): `keep-last=1` — alinhado ao hot tier PBS.

---

## PBS — prune e sync

| Job PBS | Datastore | Schedule | Política |
|---------|-----------|----------|----------|
| `prune-hot-backups` | `backups` | `08:00` diário | `keep-last=1` |
| `sync-hot-to-cold` | `backups` → `usb4tb-direct` | `06:30` push | activar após Fase B |
| `prune-cold-usb` | `usb4tb-direct` | semanal | retenção longa |

---

## Fase B — USB cold (pendente)

**Bloqueadores actuais:**

1. USB montado em **exFAT** (`/dev/sdf3`) — PBS exige ext4/xfs/zfs para chunk store
2. Datastore PBS `usb4tb-direct` aponta para ZFS vazio (`/mnt/pbs-usb4tb-direct`), não o USB físico
3. USB ~**95% cheio** — libertar espaço antes da migração

**Janela de migração (checklist):**

- [ ] Backup completo VM620+610 validado (feito 2026-07-10)
- [ ] Copiar dados legados vzdump exFAT para arquivo ou apagar após sync PBS
- [ ] Reformatar partição USB para **ext4** (ou dataset dedicado)
- [ ] `proxmox-backup-manager datastore update usb4tb-direct --path /mnt/usb4tb-direct`
- [ ] `bash aglsrv6-pbs-policy-apply.sh --apply --remote --force-usb-sync`
- [ ] Confirmar prune hot `keep-last=1` não apaga dados só existentes no cold

---

## Monitorização — Hermes Werner

| Item | Valor |
|------|-------|
| Script | `scripts/monitoring/aglsrv6-backup-watchdog.sh` |
| Cron | `30 */2 * * *` (a cada 2h, :30) |
| Agente | Werner @ CT188 |
| Deploy | `scripts/proxmox/deploy-hermes-werner-aglsrv6-backup-watchdog-ct188.sh` |

### Detecções

| Check | Limiar | Acção sugerida |
|-------|--------|----------------|
| `vzdump` activo | > 4 h (CT) / > 8 h (VM >100G) | Alerta Telegram; investigar |
| `vzdump.lock` sem processo | imediato | Alerta; remover lock se confirmado stale |
| Lock Proxmox `backup` em guest | > 6 h | Alerta; `pct unlock` / `qm unlock` se task morta |
| PBS task `running` | > limiar por tipo | Alerta |
| Job vzdump falhou 24 h | última task `job errors` | Alerta |
| Sync cold desactivado | USB não migrado | WARN no digest (não spam) |
| Espaço `backups` | > 80% | Alerta |

Em OK: `[SILENT]` (sem Telegram).

---

## Referências

- [`AGLSRV6-BACKUP-PBS-TASK-FORCE.md`](AGLSRV6-BACKUP-PBS-TASK-FORCE.md)
- [`MSSQL-DR-RUNBOOK-AGLSRV6.md`](MSSQL-DR-RUNBOOK-AGLSRV6.md)
- `scripts/proxmox/aglsrv6-pbs-policy-apply.sh`
- `scripts/proxmox/aglsrv6-backup-health.sh`
