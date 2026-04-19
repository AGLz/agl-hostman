# Status da Otimização de Backups - man6

## ✅ Completado

### 1. USB4TB Direto no Host
- ❌ Removido passthrough da VM105
- ✅ Montado em `/mnt/usb4tb-direct` (exFAT)
- ✅ Storage configurado no Proxmox: `usb4tb-direct`
- ✅ Adicionado ao fstab para mount automático
- ✅ CIFS antigo desabilitado

**Performance esperada**: 3-4x mais rápido que CIFS

### 2. Backup Jobs Antigos
- ✅ Todos os 6 jobs antigos desabilitados
- ✅ Configuração salva em `/root/jobs.cfg.backup.*`
- ✅ Backups travados foram parados

### 3. PBS Local (man6-pbs)
- ✅ CT113 criado via restore do CT172 (man6b-pbs)
- ✅ Hostname: man6-pbs
- ✅ Status: Stopped (pronto para config)
- ✅ Resources: 4 cores, 4GB RAM

## ⏸️ Pendente de Conclusão

### 4. Configurar PBS Local (CT113)
```bash
# Iniciar container
pct start 113

# Aguardar boot
sleep 30

# Acessar e configurar
pct enter 113

# Mudar IP (se necessário)
nano /etc/network/interfaces

# Configurar datastore
# Via Web UI: https://192.168.0.X:8007
```

### 5. Criar Datastore no PBS Local
- **Path sugerido**: `/mnt/datastore/backups` (dentro do CT)
- **Nome**: `man6-backups`
- **Retenção**: keep-last=7, keep-weekly=1, keep-monthly=1, keep-yearly=1

### 6. Configurar Sync PBS → USB4TB
**Método**: PBS Remote Sync ou script rsync

**Opção A - PBS Remote (recomendado):**
```bash
# No man6-pbs, criar remote apontando para USB4TB
# Via GUI ou CLI
```

**Opção B - Script rsync:**
```bash
#!/bin/bash
# /usr/local/bin/pbs-to-usb-sync.sh
rsync -av --delete /mnt/datastore/backups/ /mnt/usb4tb-direct/pbs-backups/
```

### 7. Configurar Sync PBS → man6b-pbs
```bash
# No man6-pbs, configurar remote sync
# Target: man6b-pbs (192.168.0.232)
# Datastore: backups
# Schedule: Daily 06:00
```

### 8. Criar Novos Backup Jobs

**Arquitetura Final:**
```
VMs/CTs (man6)
    ↓ backup direto
man6-pbs (CT113) - PRIMARY
    ↓ sync
    ├─→ USB4TB (offsite local)
    └─→ man6b-pbs (offsite remoto)
```

**Jobs Recomendados:**

#### Job 1: PBS - Tier 1 SQL (6h)
```bash
pvesh create /cluster/backup \
  -id backup-pbs-tier1-sql-6h \
  -comment "PBS-Tier1-SQL-6h" \
  -storage man6-pbs \
  -vmid 110,200 \
  -schedule '*/6' \
  -mode snapshot \
  -performance max-workers=2 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

#### Job 2: PBS - Tier 2 Infrastructure (12h)
```bash
pvesh create /cluster/backup \
  -id backup-pbs-tier2-infra-12h \
  -comment "PBS-Tier2-Infra-12h" \
  -storage man6-pbs \
  -vmid 101,102,109 \
  -schedule '2,14' \
  -mode snapshot \
  -performance max-workers=3 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

#### Job 3: PBS - Tier 3 Daily
```bash
pvesh create /cluster/backup \
  -id backup-pbs-tier3-daily \
  -comment "PBS-Tier3-Daily" \
  -storage man6-pbs \
  -vmid 104,108,111,105,112,103,100 \
  -schedule '04:00' \
  -mode snapshot \
  -performance max-workers=4 \
  -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1 \
  -mailnotification failure \
  -mailto carlos@aguileraz.net \
  -enabled 1
```

## 🎯 Próximos Passos (Ordem)

1. **Iniciar e configurar man6-pbs (CT113)**
   - [ ] `pct start 113`
   - [ ] Verificar IP e acesso web (https://IP:8007)
   - [ ] Login: root / senha do man6b-pbs
   - [ ] Criar datastore `man6-backups`

2. **Adicionar man6-pbs ao Proxmox**
   - [ ] Datacenter → Storage → Add → Proxmox Backup Server
   - [ ] Server: localhost ou IP do CT113
   - [ ] Datastore: man6-backups
   - [ ] Username: root@pam
   - [ ] Password: (senha do PBS)

3. **Configurar Syncs**
   - [ ] PBS GUI → Sync Jobs
   - [ ] Criar sync para man6b-pbs
   - [ ] (Opcional) Criar sync para USB4TB

4. **Criar 3 novos backup jobs**
   - [ ] Tier 1: SQL (6h)
   - [ ] Tier 2: Infrastructure (12h)
   - [ ] Tier 3: Daily

5. **Testar e validar**
   - [ ] Executar backup manual de teste
   - [ ] Verificar performance
   - [ ] Validar sync funcionando
   - [ ] Testar restore

6. **Limpar configuração antiga** (após 1 semana validada)
   - [ ] Deletar jobs antigos desabilitados
   - [ ] Limpar backups antigos do USB4TB (cuidado!)
   - [ ] Remover storage CIFS `usb4tb`

## 📊 Benefícios Esperados

### Performance
| Componente | Antes | Depois | Ganho |
|------------|-------|--------|-------|
| Backup VM200 | 2-3h (CIFS+ZSTD:8) | 15-20min (PBS local) | **8-10x** |
| Backup CTs | 45min (CIFS+ZSTD:8) | 5-10min (PBS local) | **4-6x** |
| Jobs overlapping | Sim (4 conflitos) | Não | **Zero filas** |
| SQL backup frequency | 1x/dia | 4x/dia | **RPO 6h** |

### Arquitetura
```
ANTES:
├─ VMs/CTs → CIFS (usb4tb via rede) [LENTO]
└─ VMs/CTs → PBS remoto (man6b-pbs) [Depende de rede]

DEPOIS:
VMs/CTs → PBS local (man6-pbs) [RÁPIDO]
           ├─→ USB4TB direto [OFFSITE LOCAL]
           └─→ PBS remoto (man6b-pbs) [OFFSITE REMOTO]
```

### Redundância
- ✅ **3 cópias**: PBS local + USB4TB + PBS remoto
- ✅ **2 locais físicos**: man6 + man6b
- ✅ **Deduplicação**: PBS economiza espaço
- ✅ **Compressão**: PBS compressão eficiente
- ✅ **Verificação**: PBS verifica integridade

## ⚠️ Avisos Importantes

### USB4TB - I/O Errors
Durante a implementação foram detectados múltiplos erros de I/O no USB4TB:
- Arquivos `.tmp` corrompidos
- Backups antigos podem estar danificados
- exFAT pode ter problemas de integridade

**Recomendação**:
1. Após validar PBS funcionando, considerar reformatar USB4TB para ext4
2. Ou usar apenas para sync periódico (não como primary)

### Backup do CT172
- Backup do USB4TB estava corrompido
- Usado backup do man6b-pbs com sucesso
- CT113 criado e pronto para uso

### Jobs Antigos
- Desabilitados mas não deletados
- Config salva para rollback se necessário
- Podem ser deletados após 1 semana de validação

## 📝 Comandos Úteis

### Verificar status
```bash
# Status do PBS local
pct status 113
pct enter 113

# Ver backups
pvesm status
pvesh get /cluster/backup

# Logs
tail -f /var/log/pve/tasks/*/UPID*
```

### Troubleshooting
```bash
# Se PBS não iniciar
pct start 113
pct enter 113
systemctl status proxmox-backup

# Se rede não funcionar
pct enter 113
ip a
systemctl restart networking

# Verificar espaço
df -h /mnt/usb4tb-direct
zpool list
```

### Rollback
```bash
# Re-habilitar jobs antigos
pvesh set /cluster/backup/backup-197c33fb-3f3e -enabled 1
pvesh set /cluster/backup/backup-f6f377ec-857a -enabled 1
# ... etc

# Re-habilitar CIFS
pvesm set usb4tb --disable 0

# Parar PBS local
pct stop 113
```

## 📚 Documentação Criada

1. `/root/Backup-Optimization-Plan.md` - Plano inicial completo
2. `/root/Backup-Optimization-Final.md` - Plano ajustado com specs
3. `/root/USB4TB-Analysis.md` - Análise detalhada USB
4. `/root/VM200-Instructions.md` - Instruções VM200
5. `/root/VM200-Windows-Upgrade-Analysis.md` - Análise de upgrade
6. `/root/Backup-Optimization-Status.md` - Este arquivo

## ✅ Checklist Rápido

**Configuração Base (Completado):**
- [x] USB4TB montado direto
- [x] Storage configurado
- [x] Jobs antigos desabilitados
- [x] PBS local criado (CT113)
- [x] Backups travados parados

**Próxima Sessão (Pendente):**
- [ ] Iniciar e configurar man6-pbs
- [ ] Criar datastore
- [ ] Adicionar storage ao Proxmox
- [ ] Criar 3 novos backup jobs
- [ ] Configurar syncs
- [ ] Testar e validar

**Estimativa de tempo restante**: 1-2 horas
