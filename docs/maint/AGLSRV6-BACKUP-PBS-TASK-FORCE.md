# Força-tarefa — Backups AGLSRV6 + PBS (política PBS-only)

**Última revisão:** 2026-07-18  
**Host:** man6 (`100.98.108.66`)  
**Script apply:** `scripts/proxmox/aglsrv6-pbs-policy-apply.sh --apply --remote`  
**Cold USB:** `scripts/proxmox/aglsrv6-usb-cold-export.sh --apply`  
**Health check:** `scripts/proxmox/aglsrv6-backup-health.sh --remote`

## Política hot/cold (2026-07-18)

| Tier | Estado |
|------|--------|
| Hot ZFS `keep-last=1` | ✅ prune-hot @ 08:00 (sem keep-daily); corrido manualmente 2026-07-18 |
| Cold USB exFAT | ✅ `cold/` via vzdump; cron 07:00 diário + Dom 07:30 (+620) |
| Sync PBS→USB | ❌ desactivado (exFAT); só com USB ext4 + `--force-usb-sync` |
| Cap USB | 70% (uso ~24% após limpeza dump) |

Ver [`AGLSRV6-BACKUP-RETENTION-POLICY.md`](AGLSRV6-BACKUP-RETENTION-POLICY.md).

## CT609 — root cause e fix (2026-07-18)

| Achado | Detalhe |
|--------|---------|
| Sintoma | PBS ~184 GB; ZFS `used` ~12 G; backup horas |
| Causa | `logicalused=171G` — logs PM2 altamente compressíveis; PBS lê tamanho **lógico** |
| Culprits | `Redis-commander-error.log` **128 GiB** aparente (5.4G disco); `pm2.log` **36 GiB** (2.4G) |
| Motivo spam | Redis-commander crash-loop: JSON inválido em `local-production.json` |

| Fix | Estado |
|-----|--------|
| Truncar logs PM2 | ✅ |
| `journalctl --vacuum-size=200M` | ✅ |
| `/etc/logrotate.d/pm2-node` (maxsize 100M) | ✅ |
| `pm2 stop Redis-commander` | ✅ (até corrigir config) |
| ZFS após fix | `used=1.34G` `logicalused=2.15G` |
| Tier2 | **609 reincluído** `601,602,609,614,617,621` |

## USB offline (verificado 2026-07-17 ~23:05 BRT)

| Item | Estado |
|------|--------|
| Disco físico | **Ausente** — sem `/dev/sdf3`/`sde3` desde 2026-07-04 (`USB disconnect`) |
| Mount stale CT613 | ✅ desmontado (`umount -l`) |
| fstab host | ✅ linha `/dev/sdf3` comentada (`OFFLINE 2026-07-17`) |
| Cron cold export | ✅ desactivado → `/etc/cron.d/aglsrv6-usb-cold-export.disabled` |
| Cold tier | bloqueado até reconectar USB + `aglsrv6-usb-remount.sh --apply` + uso ≤70% |

## Incidente 2026-07-17 — backup truncado VM605

| Item | Detalhe |
|------|---------|
| Sintoma | Snapshot PBS `vm/605` com **size=1** + ficheiros `.tmp_fidx` |
| Causa | Discos `scsi0`/`scsi1` com `volsize=930T` cada (~1.8 PiB); ZFS `used` ≈ 75 KB (quase vazio) |
| Efeito | vzdump 13→17 Jul a “ler” PiB de zeros; PBS task presa; `connection reset` |
| Acção | Abort task, limpar snap incompleto, reiniciar `proxmox-backup-proxy`, **excluir 605** do tier3 |
| Bloqueio | **Não** reactivar backup da 605 até validar OS / conteúdo dos discos |
| Fix 2026-07-17 | `volsize` 930T→**200G** em `vm-605-disk-0/1` (used≈75 KB — discos praticamente vazios) |

**Nota:** após o shrink, `qm list` mostra BOOTDISK 0.00 — a instalação Windows pode estar ausente; validar com WinPE/`qm start 605` antes de repor no tier3.

VM620: backup manual 2026-07-17 em curso/concluído — ver `pvesm list man6-pbs \| grep 620`.

## Política de retenção (canónica)

Ver documento dedicado: [`AGLSRV6-BACKUP-RETENTION-POLICY.md`](AGLSRV6-BACKUP-RETENTION-POLICY.md)

| Tier | Retenção alvo | Estado 2026-07-18 |
|------|---------------|-------------------|
| Hot ZFS `backups` | `keep-last=1` | ✅ activo |
| Cold USB exFAT | CT×7 / VM620×2 | ✅ `cold/` + cron (não PBS sync) |
| Watchdog | Hermes Werner `30 */2 * * *` | script pronto; deploy CT188 manual |

### Fluxo

```
PVE vzdump (man6) ──► PBS datastore backups (hot / ZFS)  keep-last=1
         │
         └──► (07:00) vzdump → /mnt/usb4tb-direct/cold   (histórico)
```

**Nota:** Com USB exFAT, «1× latest no rpool, resto no USB» = prune hot + cold-export (vzdump), **não** sync PBS.

### Jobs vzdump (todos → `man6-pbs`)

| Job | Schedule | VMIDs |
|-----|----------|-------|
| `backup-vm620-production` | 02:00 | 620 |
| `backup-pbs-tier1-sql-6h` | `*/6` | 610, 620 |
| `backup-pbs-tier2-infra-12h` | 2,14 | 601,602,609,614,617,621 |
| `backup-pbs-tier3-daily` | 04:00 | 604,605,608,611 |

Prune no job vzdump (PVE): `keep-last=1` — alinhado ao hot tier PBS (`keep-last=2` interim só se USB cold indisponível).

## Estado 2026-07-10 (pós-apply)

| Item | Estado |
|------|--------|
| Jobs tier1/2/3 + VM620 | ✅ `man6-pbs`, activos |
| Prune hot `prune-hot-backups` | ✅ criado |
| Prune cold `prune-cold-usb` | ✅ criado, **desactivado** |
| Sync `sync-hot-to-cold` | ✅ criado, **sem schedule** (USB I/O errors) |
| Remote loopback `local-push` | ✅ CT613 |
| USB `/dev/sdf3` | 🔴 I/O errors / desconexão USB — **bloqueador cold tier** |

## Bloqueador USB (P1)

`dmesg` no host: `critical target error dev sde`, `USB disconnect`, `Cannot enable. Maybe the USB cable is bad?`

**Acções antes de activar sync cold:**

1. Verificar cabo/porta USB3; confirmar `lsblk` mostra disco 4TB
2. PBS **não suporta exFAT** para datastore — migrar USB para **ext4** (janela + backup dos dados legados vzdump)
3. Repoint datastore `usb4tb-direct` para mount USB real no CT613 (não `/mnt/pbs-usb4tb-direct` ZFS vazio)
4. Activar sync: `bash aglsrv6-pbs-policy-apply.sh --apply --remote --force-usb-sync`

## VM620 — cobertura adicional

vzdump **não inclui** shares SMB nem consistência MSSQL sem guest agent:

- [ ] Reparar QEMU guest agent
- [ ] SQL Server native backup para destino off-VM
- [ ] Backup shares (robocopy/rclone)

Ver [`MSSQL-DR-RUNBOOK-AGLSRV6.md`](MSSQL-DR-RUNBOOK-AGLSRV6.md).

## Comandos úteis

```bash
# Aplicar / reaplicar política
bash scripts/proxmox/aglsrv6-pbs-policy-apply.sh --apply --remote

# Health
bash scripts/proxmox/aglsrv6-backup-health.sh --remote

# Backup manual VM620 (janela dedicada)
ssh root@100.98.108.66 'vzdump 620 --storage man6-pbs --mode snapshot --compress zstd'

# PBS prune/sync no CT613
ssh root@100.98.108.66 'pct exec 613 -- proxmox-backup-manager prune-job list'
ssh root@100.98.108.66 'pct exec 613 -- proxmox-backup-manager sync-job show sync-hot-to-cold'
```

## Histórico

- **2026-06:** Falhas `usb4tb-direct` (root 66 GB); tiers desactivados no pico
- **2026-07-09:** VM620 → `man6-pbs`
- **2026-07-10:** Política PBS-only aplicada; prune hot/cold + sync preparado; USB cold pendente hardware
