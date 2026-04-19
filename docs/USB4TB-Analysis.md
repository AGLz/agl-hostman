# USB4TB - Análise de Conexão e Performance

## Situação Atual

### Topologia Atual
```
USB4TB (exFAT)
    ↓ USB passthrough (usb2: mapping=usb4tb)
VM105 (aglhq26) - Windows
    ↓ SMB Share (\\192.168.0.203\usb4tb)
Host Proxmox man6
    ↓ CIFS mount (/mnt/pve/usb4tb)
Backup jobs
```

**Device ID**: 048d:1234 (Integrated Technology Express Chipsbank CBM2199)
**Connection**: USB3 passthrough para VM105
**Filesystem**: exFAT (4TB)
**Current mount**: CIFS via network (192.168.0.203 = VM105)
**Performance**: ~100-125 MB/s (limitado por CIFS sobre rede)

## Problema Identificado

### Caminho Atual (LENTO)
1. Proxmox backup job inicia
2. Lê dados da VM/CT
3. **Envia via REDE** para VM105 (SMB/CIFS)
4. VM105 escreve no USB
5. Roundtrip: Proxmox → Rede → VM105 → USB

**Gargalos:**
- Latência de rede SMB
- Overhead de protocolo CIFS
- CPU da VM105 para processar SMB
- Dupla camada: rede + USB

### Caminho Direto (RÁPIDO)
1. Proxmox backup job inicia
2. Lê dados da VM/CT
3. **Escreve DIRETO** no USB montado localmente
4. Path direto: Proxmox → USB (sem intermediários)

**Vantagens:**
- Sem latência de rede
- Sem overhead CIFS/SMB
- Velocidade nativa USB3 (~400-500 MB/s teórico)
- Menos CPU overhead

## Análise: exFAT vs Outras Opções

### exFAT (Atual)

**PRÓS:**
- ✅ Compatível Windows/Linux/Mac
- ✅ Sem limite de tamanho de arquivo (>4GB)
- ✅ Simples, sem permissões complexas
- ✅ Portável entre sistemas

**CONTRAS:**
- ❌ Não tem journaling (risco de corrupção em crash)
- ❌ Performance média em Linux (driver FUSE)
- ❌ Sem checksums de integridade
- ❌ Não otimizado para I/O sequencial grande

### ext4 (Recomendado para Backup)

**PRÓS:**
- ✅ Journaling (resistente a crashes)
- ✅ Performance excelente em Linux
- ✅ Suporte nativo no kernel
- ✅ Otimizado para arquivos grandes
- ✅ Checksums e integridade

**CONTRAS:**
- ❌ Não compatível nativamente com Windows
- ❌ Precisa reformatar (perda de dados atuais)

### XFS (Alternativa)

**PRÓS:**
- ✅ Excelente para arquivos muito grandes
- ✅ Performance superior em I/O paralelo
- ✅ Journaling robusto

**CONTRAS:**
- ❌ Não compatível com Windows
- ❌ Precisa reformatar

### ZFS (Máximo)

**PRÓS:**
- ✅ Checksums, compressão, deduplicação
- ✅ Máxima integridade de dados
- ✅ Snapshots instantâneos

**CONTRAS:**
- ❌ Overhead de CPU/RAM
- ❌ Complexo para USB externo
- ❌ Não compatível Windows

## Causa do Travamento Anterior

**"USB estava travando com compressão"**

### Análise Provável:

1. **CIFS + ZSTD:8 + exFAT = Perfect Storm**
   - ZSTD:8 é CPU-intensive
   - CIFS adiciona latência de rede
   - exFAT via FUSE adiciona overhead
   - Múltiplas camadas saturando

2. **exFAT Performance em Linux**
   - Driver FUSE (userspace) = mais lento
   - Sem I/O scheduling eficiente
   - Fragmentação com arquivos grandes
   - Latência em fsync/sync operations

3. **USB Direto no Host Travando**
   - exFAT FUSE driver pode travar com I/O pesado
   - Kernel pode marcar device como "busy"
   - Timeout de I/O em operações longas

## Soluções Possíveis

### Opção 1: USB Direto + exFAT + SEM Compressão (RECOMENDADO IMEDIATO)

**Setup:**
```bash
# Remover USB passthrough da VM105
qm set 105 --delete usb2

# Montar USB direto no host
mkdir -p /mnt/usb4tb
mount -t exfat /dev/sdX1 /mnt/usb4tb -o uid=0,gid=0,umask=0

# Configurar storage no Proxmox
pvesm add dir usb4tb-direct \
  --path /mnt/usb4tb \
  --content backup \
  --prune-backups keep-all=1 \
  --shared 0
```

**Performance Esperada:**
- Sem compressão = I/O direto
- exFAT direct mount = ~200-300 MB/s
- VM200 (500GB): 30-45 minutos (antes: 2-3 horas)

**PRÓS:**
- ✅ Implementação imediata
- ✅ Mantém dados existentes
- ✅ Compatibilidade Windows preservada
- ✅ 3-4x mais rápido que CIFS

**CONTRAS:**
- ⚠️ exFAT ainda pode travar com I/O pesado
- ⚠️ Performance não ideal
- ⚠️ Sem journaling (risco em crash)

**Mitigações:**
- Backups sem compressão (menos I/O)
- Max-workers limitado (menos paralelo)
- Sync periódico durante backup

### Opção 2: Reformatar para ext4 (MELHOR PERFORMANCE)

**Setup:**
```bash
# ATENÇÃO: APAGA TODOS OS DADOS!
# Backup dos backups primeiro!

umount /mnt/usb4tb
mkfs.ext4 -L BACKUP4TB /dev/sdX1 -E lazy_itable_init=0,lazy_journal_init=0
tune2fs -o journal_data_writeback /dev/sdX1

mount -t ext4 /dev/sdX1 /mnt/usb4tb -o noatime,nodiratime
```

**Performance Esperada:**
- ext4 nativo = ~400-500 MB/s (USB3 full speed)
- VM200 (500GB): 15-20 minutos
- **10x mais rápido que CIFS atual**

**PRÓS:**
- ✅ Performance máxima
- ✅ Journaling (segurança)
- ✅ Suporte nativo kernel
- ✅ Sem overhead FUSE

**CONTRAS:**
- ❌ Precisa backup e reformatação
- ❌ Incompatível com Windows direto
- ❌ Downtime durante migração

### Opção 3: Dual Storage Strategy

**Setup:**
```
rpool-backup (ZFS local) - Backup primário rápido (local SSD/NVMe)
    ↓ sync periódico
USB4TB (exFAT) - Backup offsite (pode manter via CIFS ou direto)
```

**Estratégia:**
1. Backups primários para rpool-backup (local, rápido)
2. Sync diário para USB4TB (offsite)
3. USB pode ficar na VM105 (não crítico para velocidade)

**PRÓS:**
- ✅ Backups super rápidos (local ZFS)
- ✅ Offsite mantido no USB
- ✅ Não precisa reformatar USB
- ✅ Melhor redundância

**CONTRAS:**
- ❌ Usa espaço do rpool
- ❌ Mais complexo

### Opção 4: USB Direto + Tuning exFAT

**Setup:**
```bash
# Mount com opções otimizadas
mount -t exfat /dev/sdX1 /mnt/usb4tb -o \
  uid=0,gid=0,umask=0,\
  noatime,\
  big_writes,\
  max_read=131072,\
  max_write=131072

# Tuning do kernel para I/O USB
echo 8192 > /sys/block/sdX/queue/nr_requests
echo 4096 > /sys/block/sdX/queue/read_ahead_kb
echo deadline > /sys/block/sdX/queue/scheduler
```

**PRÓS:**
- ✅ Mantém exFAT
- ✅ Performance melhorada
- ✅ Mais estável que mount padrão

**CONTRAS:**
- ⚠️ Ainda limitado por exFAT
- ⚠️ Pode não resolver travamentos completamente

## Recomendação

### Plano de 2 Fases

#### FASE 1 - IMEDIATO (Hoje)
**USB Direto + exFAT + Sem Compressão + Tuning**

1. Remover USB passthrough da VM105
2. Montar USB direto no host com tuning
3. Configurar novo storage no Proxmox
4. Implementar novos jobs **sem compressão**
5. Testar performance

**Ganho esperado:** 3-4x mais rápido
**Risco:** Baixo (reversível)
**Tempo:** 30 minutos

#### FASE 2 - FUTURO (Próximas semanas)
**Migrar para ext4 (se Fase 1 não for suficiente)**

1. Aguardar próximo ciclo de retenção completo
2. Durante manutenção programada:
   - Fazer último backup no USB exFAT
   - Reformatar para ext4
   - Restaurar estrutura de backups
3. Aproveitar performance máxima

**Ganho esperado:** 10x mais rápido que CIFS atual
**Risco:** Médio (precisa backup dos backups)
**Tempo:** 4-6 horas (com restore)

## Comparação de Performance

### Cenário: Backup VM200 (500GB)

| Método | Throughput | Tempo | Notas |
|--------|-----------|-------|-------|
| **CIFS + ZSTD:8** (atual) | 50-80 MB/s | 2-3h | Múltiplos gargalos |
| **CIFS + Sem Compress** | 100-125 MB/s | 70-90min | Remove CPU overhead |
| **USB Direto + exFAT + No Compress** | 200-300 MB/s | 30-45min | Remove rede |
| **USB Direto + exFAT + Tuning** | 250-350 MB/s | 25-35min | Otimizado |
| **USB Direto + ext4** | 400-500 MB/s | 15-20min | Performance máxima |
| **Local ZFS (rpool)** | 800-1200 MB/s | 7-10min | Baseline mais rápido |

## Implementação Fase 1

### Passo 1: Preparação

```bash
# Na VM105 (Windows) - desmontar compartilhamento
# Via RDP/Console da VM105:
# 1. Parar compartilhamento SMB do USB4TB
# 2. Eject USB safely
```

### Passo 2: No Proxmox Host

```bash
# Remover USB passthrough da VM105
qm set 105 --delete usb2

# Aguardar device aparecer no host
sleep 5
lsblk

# Identificar device (provavelmente sdc ou sdd)
USBDEV=$(lsblk -o NAME,SIZE,TYPE | grep "3.7T.*disk" | awk '{print $1}')
echo "USB Device: /dev/$USBDEV"

# Criar mountpoint
mkdir -p /mnt/usb4tb-direct

# Montar com tuning
mount -t exfat /dev/${USBDEV}1 /mnt/usb4tb-direct -o \
  uid=0,gid=0,umask=0,noatime,big_writes

# Tuning I/O
echo 8192 > /sys/block/$USBDEV/queue/nr_requests
echo 4096 > /sys/block/$USBDEV/queue/read_ahead_kb

# Verificar mount
df -hT /mnt/usb4tb-direct
ls -lah /mnt/usb4tb-direct/dump
```

### Passo 3: Configurar Storage Proxmox

```bash
# Remover ou desabilitar storage CIFS antigo
pvesm set usb4tb --disable 1

# Adicionar novo storage direto
pvesm add dir usb4tb-direct \
  --path /mnt/usb4tb-direct \
  --content backup \
  --prune-backups keep-all=1 \
  --shared 0 \
  --maxfiles 0

# Verificar
pvesm status | grep usb4tb
```

### Passo 4: Adicionar ao fstab

```bash
# Obter UUID do device
USBUID=$(blkid /dev/${USBDEV}1 | grep -oP 'UUID="\K[^"]+')

# Adicionar ao fstab
cat >> /etc/fstab <<EOF
# USB4TB Direct Mount
UUID=$USBUID /mnt/usb4tb-direct exfat uid=0,gid=0,umask=0,noatime,big_writes 0 0
EOF

cat /etc/fstab
```

### Passo 5: Criar Script de Tuning

```bash
cat > /usr/local/bin/usb4tb-tune.sh <<'EOF'
#!/bin/bash
# USB4TB Performance Tuning Script

USBDEV=$(lsblk -o NAME,SIZE,TYPE | grep "3.7T.*disk" | awk '{print $1}')

if [ -z "$USBDEV" ]; then
  echo "USB4TB not found"
  exit 1
fi

echo "Tuning /dev/$USBDEV..."
echo 8192 > /sys/block/$USBDEV/queue/nr_requests
echo 4096 > /sys/block/$USBDEV/queue/read_ahead_kb
echo deadline > /sys/block/$USBDEV/queue/scheduler

echo "Done. Status:"
cat /sys/block/$USBDEV/queue/nr_requests
cat /sys/block/$USBDEV/queue/read_ahead_kb
cat /sys/block/$USBDEV/queue/scheduler
EOF

chmod +x /usr/local/bin/usb4tb-tune.sh

# Adicionar ao cron para aplicar após reboot
cat > /etc/cron.d/usb4tb-tune <<'EOF'
@reboot root sleep 30 && /usr/local/bin/usb4tb-tune.sh
EOF
```

### Passo 6: Teste de Performance

```bash
# Teste de escrita
dd if=/dev/zero of=/mnt/usb4tb-direct/test.dat bs=1M count=10000 conv=fdatasync
# Anote o throughput (MB/s)

# Limpar
rm /mnt/usb4tb-direct/test.dat
```

## Monitoramento

### Durante Backup

```bash
# Terminal 1: iostat
watch -n 2 'iostat -x 1 1 | grep -E "Device|sd[a-z]"'

# Terminal 2: backup log
tail -f /var/log/pve/tasks/*/UPID*

# Terminal 3: throughput
while true; do
  du -sh /mnt/usb4tb-direct/dump/vzdump-*.tmp 2>/dev/null
  sleep 5
done
```

### Indicadores de Sucesso

✅ **Throughput > 200 MB/s**
✅ **Sem errors no dmesg**
✅ **VM200 backup < 45 minutos**
✅ **Sem travamentos de I/O**

### Sinais de Problema

❌ **Throughput < 100 MB/s** → exFAT ainda limitando
❌ **I/O errors no dmesg** → Considerar ext4
❌ **Device busy/timeout** → Problema de driver
❌ **Backup > 60 minutos** → Não melhorou suficiente

## Rollback Plan

Se houver problemas:

```bash
# Desmontar USB do host
umount /mnt/usb4tb-direct

# Remover storage
pvesm remove usb4tb-direct

# Re-habilitar CIFS
pvesm set usb4tb --disable 0

# Retornar USB para VM105
qm set 105 --usb2 mapping=usb4tb,usb3=1

# Re-habilitar jobs antigos
pvesh set /cluster/backup/backup-197c33fb-3f3e -enabled 1
# ... etc
```

## Decisão

**Implementar Fase 1 agora?**
- Se sim: Continuar com comandos de implementação
- Se não: Manter CIFS mas remover compressão nos jobs

**Após Fase 1, avaliar:**
- Se performance OK (>200 MB/s) → Ficar com exFAT
- Se ainda lento (<150 MB/s) → Planejar Fase 2 (ext4)
