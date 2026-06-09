# Plano de migração — Backups spark → PBS local (somente spark)

**Host:** AGLSRV1 (`100.107.113.33` / `192.168.0.245`)  
**Data:** 2026-06-06  
**PBS:** CT240 `aglsrv1-pbs` (`192.168.0.240`)  
**Estado actual:** PBS em **`spark/pbs`** (Fase 0 concluída 2026-06-06); jobs vzdump activos ainda em **`spark` (dir)**

---

## Objetivos

1. PBS passa a usar **apenas o pool `spark`** — sem `overpower`.
2. Preservar as **políticas de retenção** vigentes antes do PBS.
3. Migrar em **levas**, começando pelos CTs menores.
4. Em cada guest: garantir **≥1 backup saudável no PBS** antes de remover histórico em `spark`.
5. Libertar espaço **progressivamente** (não há margem para migrar tudo de uma vez).

---

## Situação de referência (2026-06-06)

| Recurso | Valor |
|---------|-------|
| `spark` livre | ~315 GB |
| `spark` uso | ~6,83 TB (95%) |
| `overpower` uso | ~97% (PBS actual — a abandonar) |
| Backups em `spark` (dir) | ~130 ficheiros `.tar.zst` / `.vma.zst` |
| Snapshots PBS | 0 (datastores vazios) |
| Job activo | `small-vms-backup` → `spark` @ 03:15 |
| Job desactivado | `large-vms-backup` → `spark` @ 03:30 |

---

## Políticas a preservar

Estas regras **não mudam** com a migração; apenas o destino passa de `spark` (dir) para `pbs-spark`.

### Tier Small — disco &lt; 10 GB

**VMIDs:** `101, 102, 111, 112, 117, 176`

| Parâmetro | Valor |
|-----------|-------|
| Horário | 03:15 diário |
| Modo | `snapshot` |
| Compressão | `zstd` |
| Retenção job | `keep-last=7`, `keep-weekly=4`, `keep-monthly=6`, `keep-yearly=1` |

### Tier Large — disco ≥ 10 GB

**VMIDs:** lista em `large-vms-backup` (job actualmente **desactivado**)

| Parâmetro | Valor |
|-----------|-------|
| Horário | 03:30 diário (quando reactivado) |
| Modo | `snapshot` |
| Compressão | `zstd` |
| Retenção job | `keep-last=1`, `keep-monthly=1` |

> **Nota:** O storage `dir: spark` tem prune global `keep-last=3, keep-weekly=2, keep-monthly=3, keep-yearly=1`. Durante a migração, o prune em `spark` é **manual por VMID**; após cutover total, remover backups `dir` ou desactivar conteúdo `backup` em `spark`.

### PBS (pós-cutover por tier)

Replicar no `pvesm` / job o mesmo `prune-backups` do tier correspondente:

```ini
# small
prune-backups keep-last=7,keep-weekly=4,keep-monthly=6,keep-yearly=1

# large
prune-backups keep-last=1,keep-monthly=1
```

---

## Fase 0 — Repatriar PBS para spark (pré-requisito)

**Objectivo:** um único datastore PBS em `spark`; remover dependência de `overpower`.

### 0.1 Criar dataset dedicado no ZFS

```bash
# No AGLSRV1
zfs create -o mountpoint=/spark/pbs spark/pbs
zfs set compression=lz4 spark/pbs
zfs set recordsize=128K spark/pbs   # adequado a chunks PBS
```

Reservar espaço inicial: começar com **quota 80G** na Leva 1; aumentar por leva conforme `zfs list spark/pbs`.

```bash
zfs set quota=80G spark/pbs   # ajustar após cada leva
```

### 0.2 Reconfigurar CT240

```bash
pct stop 240

# Remover mp1..mp12 (overpower/pbs-*)
# Manter apenas:
pct set 240 -delete mp1   # repetir até só restar mp0
pct set 240 -mp0 /spark/pbs,mp=/mnt/datastore/spark

pct start 240
```

### 0.3 Datastore único no PBS

```bash
pct exec 240 -- bash -c '
  for ds in ct111-shares ct111-sistema fgsrv5-wg fgsrv6-wg local local-zfs \
            man6-bb man6-usb4tb overpower overpower-zfs spark spark-zfs backups; do
    proxmox-backup-manager datastore remove "$ds" 2>/dev/null || true
  done
  proxmox-backup-manager datastore create spark /mnt/datastore/spark \
    --comment "AGLSRV1 backups — único destino no pool spark"
'
```

### 0.4 Storage Proxmox (pvesm)

```bash
# Remover entradas pbs-* excepto pbs-spark (ou recriar limpo)
pvesm remove pbs-overpower 2>/dev/null || true
# ... demais pbs-* legados

pvesm set pbs-spark --datastore spark \
  --prune-backups 'keep-last=7,keep-weekly=4,keep-monthly=6,keep-yearly=1'
```

### 0.5 Critério de aceitação Fase 0

- [x] `pct exec 240 -- proxmox-backup-manager datastore list` → só `spark` *(2026-06-06)*
- [x] `pvesm status | grep pbs-spark` → `active` *(quota 80G em spark/pbs)*
- [x] Nenhum mount do CT240 em `/overpower/pbs-*`
- [x] Teste: `vzdump 117 --storage pbs-spark` + `verify spark` OK *(~580 MiB no datastore)*

---

## Workflow por guest (regra de ouro)

Para **cada** VM/CT, nesta ordem — nunca inverter 3 e 4:

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌────────────────────┐
│ 1. vzdump   │───▶│ 2. verify    │───▶│ 3. Marcar   │───▶│ 4. Prune spark     │
│  pbs-spark  │    │  PBS snapshot│    │  migrado    │    │ (manter 1 até OK)  │
└─────────────┘    └──────────────┘    └─────────────┘    └────────────────────┘
```

### Comandos (template)

```bash
VMID=117
STORAGE_PBS=pbs-spark
STORAGE_LEGACY=spark

# 1 — Backup no PBS
vzdump "${VMID}" --storage "${STORAGE_PBS}" --mode snapshot --compress zstd

# 2 — Verificar integridade
pct exec 240 -- proxmox-backup-manager verify "${VMID}" --store spark

# 3 — Confirmar snapshot listado
pct exec 240 -- proxmox-backup-manager snapshot list spark | grep "ct/${VMID}/"

# 4 — Prune em spark: manter APENAS o backup mais recente (segurança)
# Listar volumes do VMID
pvesm list "${STORAGE_LEGACY}" --content backup | grep "vzdump-.*-${VMID}-"

# Apagar manualmente todos excepto o mais recente (exemplo CT)
LATEST=$(pvesm list spark --content backup | grep "vzdump-lxc-${VMID}-" | tail -1 | awk '{print $1}')
pvesm list spark --content backup | grep "vzdump-lxc-${VMID}-" | awk '{print $1}' | grep -v "${LATEST}" | \
  while read -r vol; do
    echo "Remover: $vol"
    # pvesm free "$vol"   # descomentar após revisão humana
  done
```

### Quando remover o último backup em `spark`

Só após **≥2 snapshots PBS** para o mesmo guest (ou 1 snapshot + 1 ciclo de job PBS confirmado), executar:

```bash
pvesm free "${LATEST}"   # último vzdump legado
```

---

## Leva 1 — CTs pequenos (&lt; 10 GB)

Ordem sugerida (menor footprint de backup primeiro → liberta mais cedo):

| Ordem | VMID | Nome | Disco | Backups em spark | Tamanho total spark | Último backup |
|-------|------|------|-------|------------------|---------------------|---------------|
| 1 | 117 | — | 2 GB | 12 | ~9,1 GB | 2026-06-05 |
| 2 | 176 | — | 2 GB | 12 | ~8,8 GB | 2026-06-05 |
| 3 | 111 | — | 4 GB | 12 | ~14,9 GB | 2026-06-05 |
| 4 | 112 | — | 4 GB | 12 | ~13,8 GB | 2026-06-05 |
| 5 | 102 | pihole | 8 GB | 12 | ~34,6 GB | 2026-06-05 |
| 6 | 101 | — | 0,5 GB | 0 | 0 | — (backup inicial) |

**Espaço:** ~7 GB novos no PBS (últimos backups) + manter 1 cópia legada cada até verificação.  
**Libertação estimada após prune (manter 1 em spark, depois remover):** ~80 GB.

**Estado (2026-06-06):** Leva 1 concluída — 117, 176, 111, 112, 102, 101 migrados; 1 legado `spark` cada; job `small-vms-backup` → `pbs-spark`.

### Leva 1 — Cutover do job

Após migrar os 6 guests:

```bash
pvesh set /cluster/backup/small-vms-backup \
  --storage pbs-spark \
  --prune-backups 'keep-last=7,keep-weekly=4,keep-monthly=6,keep-yearly=1'
```

Desactivar escrita de backup em `spark` dir quando todos os 6 tiverem ≥1 snapshot PBS verificado.

---

## Leva 2 — CTs 10–20 GB

| VMIDs | Disco aprox. | Notas |
|-------|--------------|-------|
| 151–156 | 10,5 GB | QEMU parados |
| 157 | 20 GB | LXC |
| 182 | 16 GB | Sem backup em spark hoje — backup inicial PBS |

**Pré-requisito:** Leva 1 concluída + `spark` livre ≥ 200 GB (aumentar `quota` em `spark/pbs`).

**Estado (2026-06-06):** Leva 2 concluída — 151–157, 182 migrados; quota `spark/pbs` = **120G**; job `large-vms-backup` activo → `pbs-spark` (retenção large: keep-last=1, keep-monthly=1).

Reactivar job parcial ou migrar manualmente com o workflow por guest; aplicar retenção **large** (`keep-last=1, keep-monthly=1`).

---

## Leva 3 — CTs 32 GB

VMIDs: `120, 122, 123, 124, 126, 132, 137, 139, 157, 159, 161, 162, 163, 165, 170, 171, 172, 178, 201`, etc.

- Migrar **2–3 CTs por noite** (janela 22:00–06:00).
- Monitorizar `zfs list spark/pbs` e `spark` avail após cada prune.
- VMs QEMU 32 GB: idem workflow; backups `.vma.zst` maiores.

---

## Leva 4 — CTs 40–64 GB e críticos

Inclui `103, 113, 121, 141, 144, 180, 182–192`, LiteLLM/OpenClaw (`186–187`), etc.

- Priorizar **críticos** (`183` archon, `184` supabase, `180` dokploy) com janela dedicada.
- Retenção large até haver margem; depois subir para política small se o disco &lt; 10 GB (não aplicável a estes).

---

## Leva 5 — CTs ≥ 100 GB

`131, 133, 149, 167–169, 173, 179, 181, 185, 180, 183, 145`, …

- **Uma VM/CT por noite** no máximo.
- Confirmar `avail` ≥ 1,5× tamanho do último vzdump antes de iniciar.
- Benefício PBS: deduplicação incremental reduz crescimento após o primeiro full.

---

## Gestão de espaço durante a migração

| Acção | Quando |
|-------|--------|
| `zfs set quota=NG spark/pbs` | Antes de cada leva (+20–50G) |
| Prune spark legado | Imediatamente após verify PBS (manter 1) |
| `proxmox-backup-manager garbage-collection spark` | Após cada leva |
| Remover último vzdump spark | Após 2º backup PBS ou 7 dias estável |
| Aumentar quota PBS | Se `avail` spark &lt; 100 GB |

**Alarmes:**

- `spark` avail &lt; 80 GB → pausar migração
- verify PBS falha → **não** prune spark
- job vzdump erro → manter cópia legada

---

## Jobs finais (estado alvo)

| Job ID | Storage | VMIDs | Retenção |
|--------|---------|-------|----------|
| `small-vms-backup` | `pbs-spark` | 101,102,111,112,117,176 | 7/4/6/1 |
| `large-vms-backup` | `pbs-spark` | (lista large) | 1/0/1/0 |
| Job antigo `9c5aa827…` | — | — | **permanece desactivado** |

`dir: spark` — remover `backup` do `content` quando não restarem vzdump legados:

```bash
pvesm set spark --content vztmpl,iso,import,images,snippets,rootdir
```

---

## Rollback

Se o PBS falhar para um guest:

1. Restaurar a partir do vzdump mantido em `spark`:  
   `pct restore <vmid> spark:backup/vzdump-lxc-<vmid>-<ts>.tar.zst`
2. Não remover backups spark até rollback testado.
3. CT240 pode voltar temporariamente a overpower **só em emergência** — não é o estado alvo.

---

## Script de apoio (repo)

Plano operacionalizado em:

```bash
# Dry-run Leva 1
bash scripts/proxmox/pbs-migrate-spark-wave.sh --wave 1 --dry-run

# Executar guest a guest
bash scripts/proxmox/pbs-migrate-spark-wave.sh --wave 1 --vmid 117 --apply
```

Ver `scripts/proxmox/pbs-migrate-spark-wave.sh`.

---

## Checklist de conclusão global

- [ ] Fase 0: PBS só em `spark/pbs`
- [ ] Leva 1–N: todos os guests com snapshot PBS verificado
- [ ] Jobs cluster apontam para `pbs-spark` com prune correcto por tier
- [ ] Zero backups em `spark` dir (ou só temporários em migração)
- [ ] `aglsrv6-pbs` removido ou documentado como legado inactivo
- [ ] Documentar em `docs/BACKUP_RETENTION_POLICY.md` o cutover PBS

---

## Referências

- `docs/BACKUP_RETENTION_POLICY.md` — políticas spark 2025-10
- `scripts/proxmox/pbs-link-host-storages.sh` — ligação storages (variante spark-only)
- `scripts/proxmox/aglsrv-vmid-map.env` — `AGLSRV1_PBS_VMID=240`
- `scripts/proxmox/pct-provision-pbs-from-ct113.sh` — provisionamento inicial CT240
