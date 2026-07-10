# Força-tarefa — Backups AGLSRV6 + PBS (política PBS-only)

**Última revisão:** 2026-07-10  
**Host:** man6 (`100.98.108.66`)  
**Script apply:** `scripts/proxmox/aglsrv6-pbs-policy-apply.sh --apply --remote`  
**Health check:** `scripts/proxmox/aglsrv6-backup-health.sh --remote`

## Política de retenção (canónica)

Ver documento dedicado: [`AGLSRV6-BACKUP-RETENTION-POLICY.md`](AGLSRV6-BACKUP-RETENTION-POLICY.md)

| Tier | Retenção alvo | Estado 2026-07-10 |
|------|---------------|-------------------|
| Hot ZFS `backups` | `keep-last=1` | **keep-last=2** interim (sync USB off) |
| Cold USB | retenção longa | **Fase B** — exFAT → ext4 pendente |
| Watchdog | Hermes Werner `30 */2 * * *` | script pronto; deploy CT188 manual |

### Fluxo

```
PVE vzdump (man6) ──► PBS datastore backups (hot / ZFS)
                              │
                              │ sync-job push 06:30 (se USB OK)
                              ▼
                      PBS datastore usb4tb-direct (cold)
```

**Nota:** O modelo «1× latest no rpool, resto no USB» implementa-se via **prune agressivo no hot** + **sync push para cold**, não via vzdump directo para dois destinos.

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
