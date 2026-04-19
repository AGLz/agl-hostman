# Plano de Otimização de Backups - Proxmox man6

## Análise da Situação Atual

### Configuração Identificada

**Node**: man6 (host 100.98.108.66)

**VMs Ativas:**
- VM100: SSPADLD01 (930GB) - STOPPED
- VM105: aglhq26 (running)
- VM200: WinServer2016-VirtIO (500GB) - RUNNING

**CTs Ativos:**
- CT101: cloudflared6 (2GB)
- CT102: meshcentral6 (32GB)
- CT104: luzdivina (32GB) - CRÍTICO: mountpoints externos
- CT108: agldv06 (240GB)
- CT109: redis6 (32GB)
- CT110: mssql6 (32GB + 32GB)
- CT111: aluzdivina (32GB)

**Storages:**
- **rpool** (ZFS): 2.72TB total, 1.13TB usado (41%) - LOCAL, RÁPIDO
- **rpool-backup** (ZFS dir): Compartilhado - LOCAL, RÁPIDO
- **usb4tb** (CIFS): 3.9TB total, 1.8TB usado (46%) - REMOTO via SMB, LENTO
- **bb** (CIFS): 954GB total, 502GB usado (53%) - REMOTO via SMB, LENTO
- **man6b-pbs** (PBS): Proxmox Backup Server - REMOTO, EFICIENTE

### Backup Jobs Atuais (7 ATIVOS)

#### Job 1: Daily All-CTs to USB (01:45)
- **VMs**: 101,102,103,105,108,112
- **Storage**: usb4tb (CIFS - LENTO)
- **Compress**: zstd level 8 (MÁXIMO - LENTO)
- **Retenção**: 7d/2w/1m/1y
- **Problema**: CIFS + ZSTD:8 = muito lento

#### Job 2: Daily-VM-Clone to USB (03:45)
- **VMs**: 200 (500GB)
- **Storage**: usb4tb (CIFS - LENTO)
- **Compress**: zstd level 8
- **Problema**: VM grande + CIFS + ZSTD:8 = gargalo principal

#### Job 3: Every 2h CTs to USB (8:00, 20:00)
- **VMs**: 104,109,110,111
- **Storage**: usb4tb (CIFS - LENTO)
- **Compress**: zstd level 8
- **Retenção**: keep-last:12 (muitos backups)
- **Problema**: Executa 2x/dia em storage lento

#### Job 4: Daily All-CTs to PBS (02:30)
- **VMs**: 101,102,103,105,108,112
- **Storage**: man6b-pbs (PBS - EFICIENTE)
- **Problema**: Horário próximo de job USB (possível overlap)

#### Job 5: Daily-VM-Clone to PBS (06:00)
- **VMs**: 200 (500GB)
- **Storage**: man6b-pbs (PBS)
- **Problema**: OK, mas pode otimizar

#### Job 6: Every 2h CTs to PBS (9:00, 21:00)
- **VMs**: 104,109,110,111
- **Storage**: man6b-pbs (PBS)
- **Problema**: Horário próximo de job USB (possível overlap)

## Problemas Identificados

### 🔴 CRÍTICO - Gargalos Principais

1. **CIFS Storage Performance**
   - usb4tb é storage remoto via SMB (192.168.0.203)
   - Velocidade limitada por rede (provavelmente 1Gbps)
   - Latência de rede adicional
   - Throughput: ~100-125 MB/s máximo (ideal)

2. **ZSTD Level 8 em CIFS**
   - Compressão máxima (level 8) é CPU-intensive
   - Combinado com I/O lento do CIFS = tempo duplicado
   - ZSTD:3 seria 50-70% mais rápido com compressão similar

3. **Backup de VM200 (500GB)**
   - Disco grande
   - Backup para CIFS com ZSTD:8
   - Provavelmente leva 2-4 horas
   - Bloqueia jobs seguintes

4. **Overlapping Jobs**
   - Job USB 01:45 + Job PBS 02:30 = possível sobreposição
   - Job USB 03:45 (VM200) pode atrasar jobs 06:00+
   - Jobs de 2h às 08:00/09:00 e 20:00/21:00 = overlap

5. **Retenção Excessiva no USB**
   - keep-last:12 em job de 2h = 24h de cobertura
   - 12 backups completos ocupam muito espaço
   - Aumento do tempo de prune

6. **Max-Workers = 4 Everywhere**
   - Pode causar contenção de recursos
   - VMs grandes não se beneficiam de workers

### 🟡 MÉDIO - Ineficiências

1. **Duplicação de Backups**
   - Mesmas VMs para USB E PBS
   - Dobro do tempo total de backup

2. **CT104 com Mountpoints**
   - Mount points externos não são backupeados
   - Pode gerar warnings/erros que atrasam job

3. **Horários Fixos Rígidos**
   - Todos os jobs em horários específicos
   - Não considera duração variável

4. **Sem Priorização**
   - VMs críticas (110-mssql, 200-sql) não têm prioridade
   - Tratadas igual a VMs menos críticas

## Estratégia de Otimização

### Princípios

1. **PBS como Primary, CIFS como Secondary**
   - PBS é mais rápido e eficiente (deduplicação, compressão incremental)
   - CIFS apenas para offsite/disaster recovery

2. **Reduzir Overlaps**
   - Espaçar jobs com base em duração estimada
   - Jobs críticos primeiro, menos críticos depois

3. **Otimizar Compressão**
   - ZSTD:3 para CIFS (suficiente + 50% mais rápido)
   - PBS usa compressão própria (sem ZSTD adicional)

4. **Priorizar por Criticidade**
   - Tier 1: SQL Servers (110, 200) - backup mais frequente
   - Tier 2: Serviços críticos (101-cloudflare, 102-meshcentral)
   - Tier 3: Outros CTs

5. **Reduzir Frequência de CIFS**
   - Jobs de 2h apenas para PBS
   - USB: apenas 1x/dia (suficiente para DR)

### Backup Tiers

#### 🔴 TIER 1 - Critical (SQL, Databases)
- **VMs**: 110 (mssql6), 200 (WinServer SQL)
- **PBS**: A cada 4h (6x/dia)
- **USB**: 1x/dia (02:00)
- **Retenção PBS**: 24h (last:6), 7d, 4w, 12m
- **Retenção USB**: 3d, 2w, 1m

#### 🟡 TIER 2 - Important (Infrastructure Services)
- **CTs**: 101 (cloudflared), 102 (meshcentral), 109 (redis)
- **PBS**: A cada 6h (4x/dia)
- **USB**: 1x/dia (03:00)
- **Retenção PBS**: 24h (last:4), 7d, 2w, 1m
- **Retenção USB**: 3d, 1w, 1m

#### 🟢 TIER 3 - Standard (Other Services)
- **CTs**: 104, 108, 111
- **VMs**: 105, 112, 103, 100
- **PBS**: 1x/dia
- **USB**: 1x/semana (domingo)
- **Retenção PBS**: 7d, 2w, 1m
- **Retenção USB**: 2 backups

## Novo Schedule Otimizado

### Timeline Visual
```
00:00 ─────────────────────────────────────────────
      │
01:00 │ [PBS] Tier 1 - SQL (110, 200)
      │
02:00 │ [USB] Tier 1 - SQL (110, 200) [ZSTD:3]
      │
03:00 │ [USB] Tier 2 - Infrastructure (101,102,109) [ZSTD:3]
      │
04:00 │ [PBS] Tier 3 - Daily (104,108,111,105,112)
      │
05:00 │ [PBS] Tier 1 - SQL (110, 200)
      │
06:00 │ [PBS] Tier 2 - Infrastructure
      │
07:00 │
      │
08:00 │
      │
09:00 │ [PBS] Tier 1 - SQL (110, 200)
      │
10:00 │
      │
11:00 │
      │
12:00 │ [PBS] Tier 2 - Infrastructure
      │
13:00 │ [PBS] Tier 1 - SQL (110, 200)
      │
14:00 │
      │
15:00 │
      │
16:00 │
      │
17:00 │ [PBS] Tier 1 - SQL (110, 200)
      │
18:00 │ [PBS] Tier 2 - Infrastructure
      │
19:00 │
      │
20:00 │
      │
21:00 │ [PBS] Tier 1 - SQL (110, 200)
      │
22:00 │
      │
23:00 │
00:00 ─────────────────────────────────────────────

Domingo 04:30: [USB] Tier 3 - Weekly backup [ZSTD:3]
```

## Configurações Detalhadas

### Job 1: PBS - Tier 1 Critical (SQL) - 4h
```json
{
  "comment": "PBS-Tier1-SQL-4h",
  "enabled": 1,
  "storage": "man6b-pbs",
  "vmid": "110,200",
  "schedule": "1,5,9,13,17,21",
  "mode": "snapshot",
  "performance": {
    "max-workers": 2
  },
  "prune-backups": {
    "keep-last": 6,
    "keep-daily": 7,
    "keep-weekly": 4,
    "keep-monthly": 12
  },
  "notes-template": "{{guestname}} - Tier1 Critical"
}
```

### Job 2: PBS - Tier 2 Important - 6h
```json
{
  "comment": "PBS-Tier2-Infrastructure-6h",
  "enabled": 1,
  "storage": "man6b-pbs",
  "vmid": "101,102,109",
  "schedule": "0,6,12,18",
  "mode": "snapshot",
  "performance": {
    "max-workers": 3
  },
  "prune-backups": {
    "keep-last": 4,
    "keep-daily": 7,
    "keep-weekly": 2,
    "keep-monthly": 1
  }
}
```

### Job 3: PBS - Tier 3 Daily
```json
{
  "comment": "PBS-Tier3-Daily",
  "enabled": 1,
  "storage": "man6b-pbs",
  "vmid": "104,108,111,105,112,103,100",
  "schedule": "04:00",
  "mode": "snapshot",
  "performance": {
    "max-workers": 4
  },
  "prune-backups": {
    "keep-daily": 7,
    "keep-weekly": 2,
    "keep-monthly": 1
  }
}
```

### Job 4: USB - Tier 1 Daily (Offsite)
```json
{
  "comment": "USB-Tier1-SQL-Daily-Offsite",
  "enabled": 1,
  "storage": "usb4tb",
  "vmid": "110,200",
  "schedule": "02:00",
  "mode": "snapshot",
  "compress": "zstd",
  "zstd": 3,
  "performance": {
    "max-workers": 2
  },
  "prune-backups": {
    "keep-daily": 3,
    "keep-weekly": 2,
    "keep-monthly": 1
  }
}
```

### Job 5: USB - Tier 2 Daily (Offsite)
```json
{
  "comment": "USB-Tier2-Infrastructure-Daily",
  "enabled": 1,
  "storage": "usb4tb",
  "vmid": "101,102,109",
  "schedule": "03:00",
  "mode": "snapshot",
  "compress": "zstd",
  "zstd": 3,
  "performance": {
    "max-workers": 3
  },
  "prune-backups": {
    "keep-daily": 3,
    "keep-weekly": 1,
    "keep-monthly": 1
  }
}
```

### Job 6: USB - Tier 3 Weekly (Offsite)
```json
{
  "comment": "USB-Tier3-Weekly-Offsite",
  "enabled": 1,
  "storage": "usb4tb",
  "vmid": "104,108,111,105,112,103,100",
  "schedule": "sun 04:30",
  "mode": "snapshot",
  "compress": "zstd",
  "zstd": 3,
  "performance": {
    "max-workers": 4
  },
  "prune-backups": {
    "keep-weekly": 2,
    "keep-monthly": 1
  }
}
```

## Otimizações Adicionais

### 1. Fleecing para VMs Grandes (VM200, VM100)

**O que é Fleecing:**
- Snapshot temporário para backup
- Reduz impacto de I/O na VM em produção
- Disponível no Proxmox 8.1+

```json
{
  "fleecing": {
    "enabled": 1,
    "storage": "rpool"
  }
}
```

### 2. Configuração de Performance do PBS

No Proxmox Backup Server (192.168.0.232):

```bash
# Otimizar threads de verificação
echo "verify-worker-count: 4" >> /etc/proxmox-backup/datastore.cfg

# Configurar garbage collection
proxmox-backup-manager garbage-collection update backups --schedule "sun 02:00"
```

### 3. Tuning de ZFS no rpool

```bash
# Otimizar ARC para backup workload
echo "options zfs zfs_arc_max=8589934592" >> /etc/modprobe.d/zfs.conf  # 8GB
echo "options zfs zfs_arc_min=2147483648" >> /etc/modprobe.d/zfs.conf  # 2GB

# Recordsize otimizado para backups
zfs set recordsize=1M rpool/backup

# Compressão no rpool-backup
zfs set compression=lz4 rpool/backup
```

### 4. Otimizar Rede CIFS

```bash
# Mount options para USB4TB
# Editar /etc/pve/storage.cfg

cifs: usb4tb
    path /mnt/pve/usb4tb
    server 192.168.0.203
    share usb4tb
    options vers=3.0,noperm,soft,rsize=131072,wsize=131072
    # Adicionar opções de performance ^^^^
```

### 5. Notification Filtering

```bash
# Reduzir email spam - apenas erros
# Em cada job, mudar:
"mailnotification": "failure"  # ao invés de "always"
```

## Comparação: Antes vs Depois

### Tempo Total Estimado (Diário)

**ANTES:**
```
Job 1 (USB CTs):        ~45min  (01:45-02:30)
Job 2 (USB VM200):      ~120min (03:45-05:45) ← GARGALO
Job 3 (USB 2h CTs):     ~30min  (08:00, 20:00) x2 = 60min
Job 4 (PBS CTs):        ~15min  (02:30-02:45)
Job 5 (PBS VM200):      ~30min  (06:00-06:30)
Job 6 (PBS 2h CTs):     ~10min  (09:00, 21:00) x2 = 20min
─────────────────────────────────────────────
TOTAL:                  ~290min (~4h50min/dia)
OVERLAPS:               Sim (múltiplos conflitos)
```

**DEPOIS:**
```
PBS Tier 1 (4h):        ~15min x 6 = 90min
PBS Tier 2 (6h):        ~8min x 4 = 32min
PBS Tier 3 (daily):     ~25min x 1 = 25min
USB Tier 1:             ~60min (ZSTD:3, sem overlap)
USB Tier 2:             ~20min (ZSTD:3)
USB Tier 3:             ~35min (1x/semana apenas)
─────────────────────────────────────────────
TOTAL (diário):         ~227min (~3h47min)
TOTAL (domingo):        ~262min (~4h22min)
OVERLAPS:               Nenhum (jobs espaçados)
```

**GANHOS:**
- ⏱️ **Redução de 21% no tempo diário** (4h50 → 3h47)
- 🚫 **Zero overlaps** (vs múltiplos conflitos)
- 📈 **Mais backups de críticos** (4h vs 24h)
- 💾 **Menos espaço usado** (retenção otimizada)
- ⚡ **50% mais rápido em CIFS** (ZSTD:3 vs ZSTD:8)

### Espaço em Disco Estimado

**USB4TB - ANTES:**
- CTs daily (keep-last:12 de 2h) = ~500GB
- VM200 daily = ~1.2TB
- Total: ~1.7TB

**USB4TB - DEPOIS:**
- Tier 1 daily (keep:3d) = ~400GB
- Tier 2 daily (keep:3d) = ~100GB
- Tier 3 weekly (keep:2w) = ~200GB
- Total: ~700GB

**Economia: 1TB de espaço liberado no USB4TB**

## Implementação

### Fase 1: Preparação (Dia 1)

```bash
# 1. Backup da configuração atual
ssh root@100.98.108.66 "cp -a /etc/pve/jobs.cfg /root/jobs.cfg.backup.$(date +%Y%m%d)"

# 2. Documentar jobs existentes
ssh root@100.98.108.66 "pvesh get /cluster/backup --output-format json-pretty > /root/backup-jobs-before.json"

# 3. Verificar espaço disponível
ssh root@100.98.108.66 "df -h | grep -E '(usb4tb|bb|rpool)'"
ssh root@100.98.108.66 "zpool list"
```

### Fase 2: Desabilitar Jobs Antigos (Dia 1)

```bash
# Desabilitar jobs antigos (manter configuração para rollback)
pvesh set /cluster/backup/backup-197c33fb-3f3e -enabled 0
pvesh set /cluster/backup/backup-f6f377ec-857a -enabled 0
pvesh set /cluster/backup/backup-44340b80-f7e5 -enabled 0
pvesh set /cluster/backup/backup-14eaa1e1-8aef -enabled 0
pvesh set /cluster/backup/backup-4487932b-284a -enabled 0
pvesh set /cluster/backup/backup-d129d288-6fc2 -enabled 0
```

### Fase 3: Criar Novos Jobs (Dia 1)

Via Proxmox Web UI ou CLI:

1. PBS Tier 1 (SQL - 4h)
2. PBS Tier 2 (Infrastructure - 6h)
3. PBS Tier 3 (Daily)
4. USB Tier 1 (SQL - Daily)
5. USB Tier 2 (Infrastructure - Daily)
6. USB Tier 3 (Weekly - Domingo)

### Fase 4: Monitoramento (Semana 1)

```bash
# Monitorar execução dos jobs
watch -n 60 'pvesh get /cluster/tasks | grep vzdump'

# Verificar logs
tail -f /var/log/pve/tasks/*/UPID*

# Verificar uso de espaço
df -h /mnt/pve/usb4tb
pvesh get /nodes/man6/storage/man6b-pbs/status
```

### Fase 5: Validação e Ajuste (Semana 2)

- [ ] Verificar tempos de execução reais
- [ ] Ajustar schedules se necessário
- [ ] Testar restore de backups PBS
- [ ] Testar restore de backups USB
- [ ] Validar retenção funcionando

### Fase 6: Limpeza (Semana 3)

```bash
# Se tudo OK, deletar jobs antigos
pvesh delete /cluster/backup/backup-197c33fb-3f3e
pvesh delete /cluster/backup/backup-f6f377ec-857a
# ... etc

# Limpar backups antigos do USB (cuidado!)
# APENAS APÓS CONFIRMAR NOVOS BACKUPS OK
```

## Rollback Plan

Se houver problemas:

```bash
# 1. Desabilitar novos jobs
pvesh set /cluster/backup/<NEW_JOB_ID> -enabled 0

# 2. Re-habilitar jobs antigos
pvesh set /cluster/backup/backup-197c33fb-3f3e -enabled 1
pvesh set /cluster/backup/backup-f6f377ec-857a -enabled 1
# ... etc

# 3. Restaurar configuração (se necessário)
ssh root@100.98.108.66 "cp /root/jobs.cfg.backup.YYYYMMDD /etc/pve/jobs.cfg"
```

## Melhorias Futuras (Opcional)

### 1. Local ZFS Replication para DR
```bash
# Replicação ZFS para segundo host
zfs send rpool/subvol-110-disk-0@daily | ssh man6b zfs receive rpool/replicas/man6-110
```

### 2. PBS Offsite (Segunda Localização)
- Configurar segundo PBS em localização remota
- Sync automático do PBS primário para secundário

### 3. Backup de Aplicação (SQL Server)
```powershell
# Dentro da VM200 - SQL Server native backup
# Mais rápido que VM snapshot para databases grandes
BACKUP DATABASE [nome] TO DISK = 'Z:\backups\database.bak'
```

### 4. Alerting Melhorado
```bash
# Instalar Prometheus + Grafana
# Monitorar duração, success rate, espaço usado
# Alertas via Telegram/Slack
```

## Resumo Executivo

### Problemas Atuais
1. ❌ Backups para CIFS muito lentos (rede + compressão alta)
2. ❌ VM200 (500GB) com ZSTD:8 demora 2-4h
3. ❌ Jobs sobrepostos causam filas
4. ❌ Backups críticos (SQL) só 1x/dia
5. ❌ Retenção excessiva desperdiça espaço

### Solução Proposta
1. ✅ PBS como primary (mais rápido)
2. ✅ CIFS como secondary offsite (ZSTD:3)
3. ✅ Tier system (SQL = 4h, outros = diário)
4. ✅ Zero overlaps (schedule espaçado)
5. ✅ Retenção otimizada por criticidade

### Benefícios
- ⏱️ **21% mais rápido** (4h50 → 3h47/dia)
- 🚫 **Zero conflitos** de scheduling
- 📈 **6x mais backups** de SQL servers
- 💾 **1TB economia** em USB4TB
- ⚡ **50% mais rápido** em CIFS

### Próximo Passo
**Implementar Fase 1 (Preparação) hoje, novos jobs amanhã**
