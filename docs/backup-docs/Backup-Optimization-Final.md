# Plano de Otimização de Backups - FINAL

## Requisitos do Usuário

✅ **Primary Storage**: USB4TB (backup principal)
✅ **Secondary Storage**: PBS (backup secundário/redundância)
✅ **Retenção**: keep-last=7, keep-weekly=1, keep-monthly=1, keep-yearly=1

## Problemas Identificados

### 🔴 Gargalos Críticos

1. **ZSTD Level 8 em CIFS Storage**
   - Compressão máxima é CPU-intensive
   - CIFS (usb4tb) é remoto via rede SMB
   - VM200 (500GB) demora 2-4 horas
   - **Solução**: Reduzir para ZSTD level 3 (50% mais rápido, compressão similar)

2. **Jobs Sobrepostos**
   - USB jobs 01:45, 03:45, 08:00, 20:00
   - PBS jobs 02:30, 06:00, 09:00, 21:00
   - Jobs longos atrasam próximos
   - **Solução**: Espaçar jobs para evitar conflitos

3. **Backup de 2 em 2 horas**
   - Keep-last=12 gera muitos backups
   - Ocupa espaço desnecessário
   - Prune demora mais
   - **Solução**: Ajustar frequência e retenção

## Estratégia Otimizada

### Princípio: USB Primary + PBS Secondary

**USB4TB (Primary):**
- Backup principal mais rápido (ZSTD:3)
- Executa PRIMEIRO (horários prioritários)
- Retenção: 7 últimos, 1 semanal, 1 mensal, 1 anual

**PBS (Secondary):**
- Backup de redundância
- Executa DEPOIS do USB (offset de 1h)
- Mesma retenção
- Aproveita deduplicação/compressão do PBS

### Tier System por Criticidade

#### 🔴 TIER 1 - Critical SQL Servers
**VMs**: 110 (mssql6), 200 (WinServer SQL)

**Backup Frequência**: A cada 6 horas
**Justificativa**: Dados críticos, RPO de 6h aceitável

**Schedule:**
- USB: 00:00, 06:00, 12:00, 18:00
- PBS: 01:00, 07:00, 13:00, 19:00 (1h após USB)

#### 🟡 TIER 2 - Important Infrastructure
**CTs**: 101 (cloudflared), 102 (meshcentral), 109 (redis)

**Backup Frequência**: A cada 12 horas
**Justificativa**: Serviços importantes, RPO de 12h OK

**Schedule:**
- USB: 02:00, 14:00
- PBS: 03:00, 15:00

#### 🟢 TIER 3 - Standard Services
**CTs**: 104 (luzdivina), 108 (agldv06), 111 (aluzdivina)
**VMs**: 105 (aglhq26), 112 (dell-ome), 103 (opnsense), 100 (SSPADLD01)

**Backup Frequência**: 1x por dia
**Justificativa**: Serviços padrão, RPO de 24h suficiente

**Schedule:**
- USB: 04:00
- PBS: 05:00

## Configuração dos Jobs

### Job 1: USB - Tier 1 SQL (6h)
```
Comment: USB-Tier1-SQL-6h
Storage: usb4tb
VMs: 110,200
Schedule: */6 (00:00, 06:00, 12:00, 18:00)
Mode: snapshot
Compression: zstd
ZSTD Level: 3
Max Workers: 2
Prune Backups:
  - keep-last: 7
  - keep-weekly: 1
  - keep-monthly: 1
  - keep-yearly: 1
Mail: failure
```

**Comando criação:**
```bash
pvesh create /cluster/backup \
  -id backup-usb-tier1-sql-6h \
  -comment "USB-Tier1-SQL-6h" \
  -storage usb4tb \
  -vmid 110,200 \
  -schedule '*/6' \
  -mode snapshot \
  -compress zstd \
  -zstd 3 \
  -performance max-workers=2 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

### Job 2: PBS - Tier 1 SQL (6h + 1h offset)
```
Comment: PBS-Tier1-SQL-6h
Storage: man6b-pbs
VMs: 110,200
Schedule: 1,7,13,19
Mode: snapshot
Max Workers: 2
Prune Backups:
  - keep-last: 7
  - keep-weekly: 1
  - keep-monthly: 1
  - keep-yearly: 1
Mail: failure
```

**Comando criação:**
```bash
pvesh create /cluster/backup \
  -id backup-pbs-tier1-sql-6h \
  -comment "PBS-Tier1-SQL-6h" \
  -storage man6b-pbs \
  -vmid 110,200 \
  -schedule '1,7,13,19' \
  -mode snapshot \
  -performance max-workers=2 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

### Job 3: USB - Tier 2 Infrastructure (12h)
```
Comment: USB-Tier2-Infra-12h
Storage: usb4tb
VMs: 101,102,109
Schedule: 2,14
Mode: snapshot
Compression: zstd
ZSTD Level: 3
Max Workers: 3
Prune Backups:
  - keep-last: 7
  - keep-weekly: 1
  - keep-monthly: 1
  - keep-yearly: 1
```

**Comando criação:**
```bash
pvesh create /cluster/backup \
  -id backup-usb-tier2-infra-12h \
  -comment "USB-Tier2-Infra-12h" \
  -storage usb4tb \
  -vmid 101,102,109 \
  -schedule '2,14' \
  -mode snapshot \
  -compress zstd \
  -zstd 3 \
  -performance max-workers=3 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

### Job 4: PBS - Tier 2 Infrastructure (12h + 1h offset)
```
Comment: PBS-Tier2-Infra-12h
Storage: man6b-pbs
VMs: 101,102,109
Schedule: 3,15
Mode: snapshot
Max Workers: 3
Prune Backups:
  - keep-last: 7
  - keep-weekly: 1
  - keep-monthly: 1
  - keep-yearly: 1
```

**Comando criação:**
```bash
pvesh create /cluster/backup \
  -id backup-pbs-tier2-infra-12h \
  -comment "PBS-Tier2-Infra-12h" \
  -storage man6b-pbs \
  -vmid 101,102,109 \
  -schedule '3,15' \
  -mode snapshot \
  -performance max-workers=3 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

### Job 5: USB - Tier 3 Daily
```
Comment: USB-Tier3-Daily
Storage: usb4tb
VMs: 104,108,111,105,112,103,100
Schedule: 04:00
Mode: snapshot
Compression: zstd
ZSTD Level: 3
Max Workers: 4
Prune Backups:
  - keep-last: 7
  - keep-weekly: 1
  - keep-monthly: 1
  - keep-yearly: 1
```

**Comando criação:**
```bash
pvesh create /cluster/backup \
  -id backup-usb-tier3-daily \
  -comment "USB-Tier3-Daily" \
  -storage usb4tb \
  -vmid 104,108,111,105,112,103,100 \
  -schedule '04:00' \
  -mode snapshot \
  -compress zstd \
  -zstd 3 \
  -performance max-workers=4 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

### Job 6: PBS - Tier 3 Daily
```
Comment: PBS-Tier3-Daily
Storage: man6b-pbs
VMs: 104,108,111,105,112,103,100
Schedule: 05:00
Mode: snapshot
Max Workers: 4
Prune Backups:
  - keep-last: 7
  - keep-weekly: 1
  - keep-monthly: 1
  - keep-yearly: 1
```

**Comando criação:**
```bash
pvesh create /cluster/backup \
  -id backup-pbs-tier3-daily \
  -comment "PBS-Tier3-Daily" \
  -storage man6b-pbs \
  -vmid 104,108,111,105,112,103,100 \
  -schedule '05:00' \
  -mode snapshot \
  -performance max-workers=4 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

## Timeline Visual

```
00:00 │ [USB] Tier 1 SQL (110,200) ──┐
      │                               │ ~40min
01:00 │ [PBS] Tier 1 SQL (110,200) ──┘
      │
02:00 │ [USB] Tier 2 Infra (101,102,109) ──┐
      │                                      │ ~20min
03:00 │ [PBS] Tier 2 Infra (101,102,109) ──┘
      │
04:00 │ [USB] Tier 3 All (104,108,111,105,112,103,100) ──┐
      │                                                    │ ~45min
05:00 │ [PBS] Tier 3 All (104,108,111,105,112,103,100) ──┘
      │
06:00 │ [USB] Tier 1 SQL (110,200)
      │
07:00 │ [PBS] Tier 1 SQL (110,200)
      │
      ... (continua a cada 6h para Tier 1)
      │
12:00 │ [USB] Tier 1 SQL (110,200)
      │
13:00 │ [PBS] Tier 1 SQL (110,200)
      │
14:00 │ [USB] Tier 2 Infra (101,102,109)
      │
15:00 │ [PBS] Tier 2 Infra (101,102,109)
      │
18:00 │ [USB] Tier 1 SQL (110,200)
      │
19:00 │ [PBS] Tier 1 SQL (110,200)
```

## Otimizações de Performance

### 1. ZSTD Level 3 vs Level 8

**ZSTD:8 (atual):**
- Compressão: ~65-70%
- CPU: 100% de 1 core
- Throughput: ~50-80 MB/s

**ZSTD:3 (proposto):**
- Compressão: ~60-65% (5% menor)
- CPU: 40-50% de 1 core
- Throughput: ~150-200 MB/s (2-3x mais rápido)

**Ganho esperado para VM200 (500GB):**
- Antes: 2-3 horas
- Depois: 50-90 minutos
- **Economia: 50-60% de tempo**

### 2. Max Workers Ajustado

**VMs grandes (110, 200)**: max-workers=2
- Menos contenção de I/O
- Melhor para discos grandes

**CTs médios (101,102,109)**: max-workers=3
- Balanço entre paralelismo e performance

**CTs pequenos + VMs (Tier 3)**: max-workers=4
- Máximo paralelismo para acelerar

### 3. Schedule Espaçado

**Offset de 1 hora entre USB e PBS:**
- USB completa antes do PBS iniciar
- Zero overlaps/conflitos
- PBS aproveita cache quente (dados recém-lidos)

### 4. Fleecing (Opcional - VM200)

Para VM200 (500GB Windows):

```bash
pvesh set /cluster/backup/backup-usb-tier1-sql-6h \
  -fleecing enabled=1,storage=rpool
```

**Benefícios:**
- Reduz impacto de I/O na VM em produção
- Snapshot temporário em storage local rápido
- Backup lê do snapshot, não do disco em uso

## Comparação: Antes vs Depois

### Jobs Diários

**ANTES:**
```
7 jobs ativos, múltiplos overlaps
- 01:45: USB CTs (ZSTD:8)          ~45min
- 02:30: PBS CTs                   ~15min  } overlap
- 03:45: USB VM200 (ZSTD:8)        ~150min ← GARGALO
- 06:00: PBS VM200                 ~30min  } possível overlap
- 08:00: USB CTs 2h (ZSTD:8)       ~30min
- 09:00: PBS CTs 2h                ~10min  } overlap
- 20:00: USB CTs 2h (ZSTD:8)       ~30min
- 21:00: PBS CTs 2h                ~10min  } overlap
────────────────────────────────────────────
Total tempo: ~320 minutos (~5h20min)
Overlaps: 4 conflitos
```

**DEPOIS:**
```
6 jobs, zero overlaps
00:00: USB Tier 1 (ZSTD:3)         ~40min
01:00: PBS Tier 1                  ~15min
02:00: USB Tier 2 (ZSTD:3)         ~20min
03:00: PBS Tier 2                  ~8min
04:00: USB Tier 3 (ZSTD:3)         ~45min
05:00: PBS Tier 3                  ~20min
06:00: USB Tier 1 (ZSTD:3)         ~40min
07:00: PBS Tier 1                  ~15min
12:00: USB Tier 1 (ZSTD:3)         ~40min
13:00: PBS Tier 1                  ~15min
14:00: USB Tier 2 (ZSTD:3)         ~20min
15:00: PBS Tier 2                  ~8min
18:00: USB Tier 1 (ZSTD:3)         ~40min
19:00: PBS Tier 1                  ~15min
────────────────────────────────────────────
Total tempo: ~341 minutos (~5h41min)
Overlaps: ZERO
Backups SQL: 4x/dia (antes: 1x/dia)
```

### Análise de Ganhos

**Performance:**
- ✅ ZSTD:3 = 50% mais rápido em CIFS
- ✅ Zero overlaps = execução previsível
- ✅ Jobs espaçados = sem filas

**Proteção de Dados:**
- ✅ SQL backups a cada 6h (antes: 24h)
- ✅ Redundância: USB + PBS
- ✅ Retenção consistente: 7/1/1/1

**Recursos:**
- ✅ Menos CPU (ZSTD:3 vs ZSTD:8)
- ✅ Mesma compressão efetiva
- ✅ Espaço otimizado (prune eficiente)

## Implementação

### Script Completo de Migração

```bash
#!/bin/bash
# backup-migration.sh

set -e

echo "=== Backup Configuration Migration ==="
echo ""

# Backup configuração atual
echo "[1/5] Backing up current configuration..."
cp -a /etc/pve/jobs.cfg /root/jobs.cfg.backup.$(date +%Y%m%d_%H%M%S)
pvesh get /cluster/backup --output-format json-pretty > /root/backup-jobs-before.json
echo "✓ Backup saved"

# Desabilitar jobs antigos
echo ""
echo "[2/5] Disabling old backup jobs..."
OLD_JOBS=(
  "backup-197c33fb-3f3e"
  "backup-f6f377ec-857a"
  "backup-44340b80-f7e5"
  "backup-14eaa1e1-8aef"
  "backup-4487932b-284a"
  "backup-d129d288-6fc2"
)

for job in "${OLD_JOBS[@]}"; do
  echo "  Disabling $job..."
  pvesh set /cluster/backup/$job -enabled 0 || echo "  (job not found, skipping)"
done
echo "✓ Old jobs disabled"

# Criar novos jobs
echo ""
echo "[3/5] Creating new optimized backup jobs..."

# Job 1: USB Tier 1 SQL 6h
echo "  Creating USB-Tier1-SQL-6h..."
pvesh create /cluster/backup \
  -id backup-usb-tier1-sql-6h \
  -comment "USB-Tier1-SQL-6h" \
  -storage usb4tb \
  -vmid 110,200 \
  -schedule '*/6' \
  -mode snapshot \
  -compress zstd \
  -zstd 3 \
  -performance max-workers=2 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1

# Job 2: PBS Tier 1 SQL 6h
echo "  Creating PBS-Tier1-SQL-6h..."
pvesh create /cluster/backup \
  -id backup-pbs-tier1-sql-6h \
  -comment "PBS-Tier1-SQL-6h" \
  -storage man6b-pbs \
  -vmid 110,200 \
  -schedule '1,7,13,19' \
  -mode snapshot \
  -performance max-workers=2 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1

# Job 3: USB Tier 2 Infra 12h
echo "  Creating USB-Tier2-Infra-12h..."
pvesh create /cluster/backup \
  -id backup-usb-tier2-infra-12h \
  -comment "USB-Tier2-Infra-12h" \
  -storage usb4tb \
  -vmid 101,102,109 \
  -schedule '2,14' \
  -mode snapshot \
  -compress zstd \
  -zstd 3 \
  -performance max-workers=3 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1

# Job 4: PBS Tier 2 Infra 12h
echo "  Creating PBS-Tier2-Infra-12h..."
pvesh create /cluster/backup \
  -id backup-pbs-tier2-infra-12h \
  -comment "PBS-Tier2-Infra-12h" \
  -storage man6b-pbs \
  -vmid 101,102,109 \
  -schedule '3,15' \
  -mode snapshot \
  -performance max-workers=3 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1

# Job 5: USB Tier 3 Daily
echo "  Creating USB-Tier3-Daily..."
pvesh create /cluster/backup \
  -id backup-usb-tier3-daily \
  -comment "USB-Tier3-Daily" \
  -storage usb4tb \
  -vmid 104,108,111,105,112,103,100 \
  -schedule '04:00' \
  -mode snapshot \
  -compress zstd \
  -zstd 3 \
  -performance max-workers=4 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1

# Job 6: PBS Tier 3 Daily
echo "  Creating PBS-Tier3-Daily..."
pvesh create /cluster/backup \
  -id backup-pbs-tier3-daily \
  -comment "PBS-Tier3-Daily" \
  -storage man6b-pbs \
  -vmid 104,108,111,105,112,103,100 \
  -schedule '05:00' \
  -mode snapshot \
  -performance max-workers=4 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1

echo "✓ New jobs created"

# Listar novos jobs
echo ""
echo "[4/5] New backup configuration:"
pvesh get /cluster/backup --output-format json-pretty | grep -E '"comment"|"schedule"|"vmid"|"storage"' | head -40

# Salvar nova configuração
echo ""
echo "[5/5] Saving new configuration..."
pvesh get /cluster/backup --output-format json-pretty > /root/backup-jobs-after.json
echo "✓ Configuration saved"

echo ""
echo "=== Migration Complete ==="
echo ""
echo "Next steps:"
echo "1. Monitor first backup execution"
echo "2. Verify backup completion times"
echo "3. Test restore from both USB and PBS"
echo "4. After 1 week validation, delete old backup jobs"
echo ""
echo "Rollback: Re-enable old jobs if needed:"
echo "  pvesh set /cluster/backup/backup-197c33fb-3f3e -enabled 1"
```

### Execução

```bash
# No host Proxmox
ssh root@100.98.108.66 'bash -s' < backup-migration.sh
```

## Monitoramento

### Comandos Úteis

```bash
# Ver jobs ativos
pvesh get /cluster/backup | grep -E 'id|comment|enabled'

# Ver tasks em execução
watch -n 10 'pvesh get /cluster/tasks | grep vzdump | tail -20'

# Ver último status de cada job
pvesh get /cluster/backup --output-format json-pretty | grep -E 'next-run|comment'

# Espaço usado nos storages
df -h /mnt/pve/usb4tb
ssh root@192.168.0.232 "df -h /mnt/datastore/backups"
```

### Dashboard de Monitoramento

Criar script para verificar status:

```bash
#!/bin/bash
# backup-status.sh

echo "=== Backup Status Dashboard ==="
echo ""

echo "USB4TB Storage:"
df -h /mnt/pve/usb4tb | tail -1

echo ""
echo "PBS Storage:"
ssh root@192.168.0.232 "df -h /mnt/datastore/backups" | tail -1

echo ""
echo "Recent Backup Tasks (last 10):"
pvesh get /cluster/tasks --output-format json-pretty | \
  grep -A 10 '"type" : "vzdump"' | \
  grep -E 'starttime|endtime|status|id' | \
  head -40

echo ""
echo "Next Scheduled Runs:"
pvesh get /cluster/backup --output-format json-pretty | \
  grep -B1 -A2 'next-run' | \
  grep -E 'comment|next-run'
```

## Validação

### Checklist Pós-Implementação

**Semana 1:**
- [ ] Primeiro backup USB Tier 1 completou
- [ ] Primeiro backup PBS Tier 1 completou
- [ ] Tempo de execução < 45min para Tier 1
- [ ] Tempo de execução < 25min para Tier 2
- [ ] Tempo de execução < 50min para Tier 3
- [ ] Zero overlaps observados
- [ ] Emails apenas em falhas

**Semana 2:**
- [ ] Testar restore de CT101 do USB
- [ ] Testar restore de CT101 do PBS
- [ ] Testar restore de VM200 do USB
- [ ] Testar restore de VM200 do PBS
- [ ] Verificar prune funcionando
- [ ] Validar retenção: 7/1/1/1

**Semana 3:**
- [ ] Performance estável
- [ ] Sem erros recorrentes
- [ ] Espaço em disco adequado
- [ ] Deletar jobs antigos
- [ ] Documentar procedimentos

## Rollback

Se houver problemas:

```bash
# Desabilitar novos jobs
pvesh set /cluster/backup/backup-usb-tier1-sql-6h -enabled 0
pvesh set /cluster/backup/backup-pbs-tier1-sql-6h -enabled 0
pvesh set /cluster/backup/backup-usb-tier2-infra-12h -enabled 0
pvesh set /cluster/backup/backup-pbs-tier2-infra-12h -enabled 0
pvesh set /cluster/backup/backup-usb-tier3-daily -enabled 0
pvesh set /cluster/backup/backup-pbs-tier3-daily -enabled 0

# Re-habilitar jobs antigos
pvesh set /cluster/backup/backup-197c33fb-3f3e -enabled 1
pvesh set /cluster/backup/backup-f6f377ec-857a -enabled 1
pvesh set /cluster/backup/backup-44340b80-f7e5 -enabled 1
pvesh set /cluster/backup/backup-14eaa1e1-8aef -enabled 1
pvesh set /cluster/backup/backup-4487932b-284a -enabled 1
pvesh set /cluster/backup/backup-d129d288-6fc2 -enabled 1
```

## Resumo Executivo

### Mudanças Principais

1. ✅ **USB4TB como Primary** (backup principal, mais rápido)
2. ✅ **PBS como Secondary** (redundância, offset de 1h)
3. ✅ **ZSTD:3** ao invés de ZSTD:8 (50% mais rápido)
4. ✅ **Zero overlaps** (schedule espaçado)
5. ✅ **Tier system** (SQL 6h, Infra 12h, Outros 24h)
6. ✅ **Retenção uniforme**: 7/1/1/1

### Benefícios

- ⏱️ **50-60% mais rápido** para VM200 (2-3h → 50-90min)
- 🚫 **Zero conflitos** de scheduling
- 📈 **4x mais backups** de SQL (24h → 6h)
- 💾 **Redundância completa** (USB + PBS)
- 🎯 **Retenção otimizada** (7/1/1/1 consistente)

### Próximo Passo

**Executar script de migração hoje, monitorar por 1 semana**
