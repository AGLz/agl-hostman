# 🔴 PLANO DE AÇÃO CRÍTICO - FALHA DE HARDWARE

**Servidor**: 100.107.113.33 (algsrv1)
**Data**: 28/09/2025
**Severidade**: CRÍTICA
**Tempo Estimado para Falha Total**: 24-72 horas

## ⚠️ SITUAÇÃO ATUAL

### Falha de Hardware Detectada:
- **CPU Intel Xeon E5-2680 v4** com falha no cache L3 (Bank 5)
- Erros MCE ocorrendo a cada 60 segundos
- Sistema instável com risco de corrupção de dados
- ZFS detectando erros de checksum (possível corrupção)

### Impacto nos Dados:
- 450 snapshots ZFS existentes (backup disponível)
- Pool 'spark' com 94% de capacidade
- Pool 'overpower' com 90% de capacidade
- Erros de leitura/escrita detectados em todos os pools

## 🚨 AÇÕES IMEDIATAS (EXECUTAR AGORA)

### 1. BACKUP DE EMERGÊNCIA (Prioridade MÁXIMA)
```bash
# Criar snapshot de emergência de todos os pools
ssh root@100.107.113.33 "
zfs snapshot -r overpower@emergency-$(date +%Y%m%d-%H%M%S)
zfs snapshot -r rpool@emergency-$(date +%Y%m%d-%H%M%S)
zfs snapshot -r spark@emergency-$(date +%Y%m%d-%H%M%S)
"

# Enviar snapshots para servidor backup (se disponível)
# Substituir 'backup-server' pelo servidor de backup real
ssh root@100.107.113.33 "
zfs send -R overpower@emergency-* | ssh backup-server zfs recv -F backup/overpower
zfs send -R rpool@emergency-* | ssh backup-server zfs recv -F backup/rpool
zfs send -R spark@emergency-* | ssh backup-server zfs recv -F backup/spark
"
```

### 2. PARAR SERVIÇOS NÃO CRÍTICOS
```bash
# Parar todas as VMs não essenciais
ssh root@100.107.113.33 "
pvesh get /nodes/algsrv1/qemu --output-format json | \
jq -r '.[] | select(.status=="running") | .vmid' | \
while read vmid; do
    echo 'Parando VM $vmid'
    qm stop $vmid
done
"

# Parar containers não essenciais
ssh root@100.107.113.33 "
pct list | awk 'NR>1 {print $1}' | \
while read ctid; do
    echo 'Parando Container $ctid'
    pct stop $ctid
done
"
```

### 3. REDUZIR CARGA DO SISTEMA
```bash
# Desabilitar scrubs automáticos
ssh root@100.107.113.33 "
systemctl stop zfs-scrub-scheduler.timer
systemctl disable zfs-scrub-scheduler.timer
"

# Ajustar ZFS para modo conservador
ssh root@100.107.113.33 "
echo 1 > /sys/module/zfs/parameters/zfs_prefetch_disable
echo 536870912 > /sys/module/zfs/parameters/zfs_arc_max
"
```

### 4. MONITORAMENTO CONTÍNUO
```bash
# Script de monitoramento MCE
ssh root@100.107.113.33 "cat > /tmp/monitor-mce.sh << 'EOF'
#!/bin/bash
while true; do
    dmesg | grep -c 'Machine Check' > /tmp/mce-count
    echo \"MCE Count: $(cat /tmp/mce-count) at $(date)\"
    sleep 60
done
EOF
chmod +x /tmp/monitor-mce.sh
nohup /tmp/monitor-mce.sh > /var/log/mce-monitor.log 2>&1 &
"
```

## 🛠️ SOLUÇÃO PERMANENTE

### Opção 1: SUBSTITUIÇÃO DO CPU (Recomendado)
1. **Adquirir CPU de substituição**: Intel Xeon E5-2680 v4 ou compatível
2. **Agendar janela de manutenção**: 2-4 horas
3. **Procedimento**:
   - Shutdown completo do sistema
   - Substituir CPU defeituoso
   - Aplicar pasta térmica nova
   - Verificar BIOS/UEFI
   - Boot e verificação

### Opção 2: MIGRAÇÃO DE EMERGÊNCIA
1. **Preparar servidor alternativo**
2. **Replicar pools ZFS via send/receive**
3. **Migrar VMs e containers**
4. **Redirecionar serviços**

### Opção 3: DESABILITAR CORE AFETADO (Paliativo)
```bash
# APENAS como medida temporária
ssh root@100.107.113.33 "
echo 0 > /sys/devices/system/cpu/cpu0/online
"
```

## 📊 VERIFICAÇÕES PÓS-AÇÃO

### Verificar Integridade dos Dados
```bash
# Após resolver o problema de hardware
ssh root@100.107.113.33 "
zpool scrub overpower
zpool scrub rpool
zpool scrub spark
"

# Monitorar progresso
ssh root@100.107.113.33 "
watch -n 10 'zpool status | grep scrub'
"
```

### Verificar Ausência de MCE
```bash
ssh root@100.107.113.33 "
dmesg -T | grep -i mce
journalctl -p err --since '1 hour ago'
"
```

## 📞 CONTATOS DE EMERGÊNCIA

- **Suporte Proxmox**: forum.proxmox.com
- **Fornecedor Hardware**: [Adicionar contato]
- **Backup Admin**: carlos@aguileraz.net

## ⏰ TIMELINE CRÍTICA

1. **IMEDIATO (0-2h)**: Backup de emergência
2. **URGENTE (2-6h)**: Parar serviços não críticos
3. **HOJE (6-24h)**: Decidir solução (substituição vs migração)
4. **AMANHÃ (24-48h)**: Implementar solução escolhida
5. **PÓS-REPARO (48-72h)**: Verificação completa e scrub

## 🔴 AVISOS IMPORTANTES

1. **NÃO REINICIE O SERVIDOR** sem backup completo
2. **NÃO EXECUTE SCRUB** até resolver o problema de hardware
3. **NÃO CONFIE** em dados escritos após início dos erros MCE
4. **DOCUMENTE** todas as ações tomadas
5. **MANTENHA** comunicação com usuários afetados

---

**ESTE É UM PROBLEMA CRÍTICO DE HARDWARE QUE REQUER AÇÃO IMEDIATA**

A falha do cache L3 pode causar corrupção silenciosa de dados. Mesmo com ECC RAM e ZFS, dados corrompidos no cache do CPU podem ser escritos como "válidos" no storage.

**Recomendação Final**: SUBSTITUIR O CPU DENTRO DE 24-48 HORAS