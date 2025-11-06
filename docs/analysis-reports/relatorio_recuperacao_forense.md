# 🔬 RELATÓRIO DE ANÁLISE FORENSE E OPÇÕES DE RECUPERAÇÃO

## 📅 Data da Análise
- **Data/Hora**: 27/09/2025 - 14:30
- **Servidor**: algsrv1 (100.107.113.33)
- **Evento Original**: Otimização de storage em 26/09/2025

## 🔍 SISTEMAS IDENTIFICADOS ATRAVÉS DOS ARQUIVOS .notes

### Containers LXC Perdidos
| ID | Nome | Função | Última Backup Date |
|----|------|--------|-------------------|
| 109 | omv | OpenMediaVault - NAS | 17/03/2025 |
| 110 | scrypted | Home Security Video | 17/03/2025 |
| 118 | shinobi | CCTV/NVR System | 17/03/2025 |
| 119 | motioneye | Motion Detection | 17/03/2025 |
| 130 | agldc1 | Domain Controller | 17/03/2025 |
| 140 | nzbget | Usenet Downloader | 17/03/2025 |
| 143 | casaos | Home Cloud OS | 28/06/2024 |
| 158 | nextcloud | Cloud Storage | 17/03/2025 |
| 164 | aglwk50 | Workstation | 09/01/2025 |

### VMs Perdidas
| ID | Nome | Função | Detalhes |
|----|------|--------|----------|
| 108 | truenas | TrueNAS Storage | 32GB OS + 1.5TB + 3TB disks |
| 134 | aglwk47 | Workstation | 480GB disk |
| 127 | ? | Desconhecido | Sem registros |
| 129 | ? | Desconhecido | Sem registros |
| 166 | ? | Desconhecido | Sem registros |
| 175 | ? | Container? | Logs até 17/03/2025 |
| 177 | ? | Desconhecido | Sem registros |

## 💾 ANÁLISE DE SNAPSHOTS ZFS

### Snapshots Disponíveis
```
Pool: spark
Snapshots mais recentes: 17/09/2025
Status: Anteriores à deleção (26/09/2025)
Problema: Acesso aos snapshots está muito lento/travando
```

### Tentativa de Acesso
- ✅ Snapshots existem de antes da deleção
- ❌ Acesso via .zfs/snapshot está travando
- ⚠️ Possível corrupção ou problema de performance

## 🛠️ OPÇÕES DE RECUPERAÇÃO

### 1. Recuperação via ZFS Snapshots (RECOMENDADO)
```bash
# Clonar snapshot para novo dataset
zfs clone spark@autosnap_2025-09-17_14:30:04_frequently spark/recovered

# Ou montar snapshot em local alternativo
mount -t zfs spark@autosnap_2025-09-17_14:30:04_frequently /mnt/recovery
```

**Vantagens**:
- Recuperação completa se os arquivos existiam em 17/09
- Mantém integridade dos dados

**Desvantagens**:
- Snapshots parecem estar com problemas de acesso

### 2. Ferramentas Forenses (testdisk/photorec)
```bash
# PhotoRec para recuperar arquivos deletados
photorec /d /recovery /spark

# TestDisk para análise de partições
testdisk /spark
```

**Vantagens**:
- Pode recuperar arquivos mesmo após deleção
- Já instalado no servidor

**Desvantagens**:
- Não funciona bem com ZFS
- Pode recuperar arquivos fragmentados

### 3. ZFS Undelete (Análise de Blocos)
```bash
# Verificar blocos não liberados
zdb -bcsvL spark

# Procurar por arquivos específicos
zdb -ddddd spark | grep -E "vzdump.*(108|109|110)"
```

**Vantagens**:
- Específico para ZFS
- Pode encontrar dados não liberados

**Desvantagens**:
- Complexo e demorado
- Sem garantia de sucesso

### 4. Recriação Manual dos Containers
Como identificamos o que cada sistema era, podemos recriar:

| Container | Script Base | Configuração |
|-----------|-------------|--------------|
| omv | tteck/Proxmox | OpenMediaVault |
| scrypted | tteck/Proxmox | Scrypted NVR |
| shinobi | Manual | Shinobi CCTV |
| motioneye | Manual | MotionEye |
| nextcloud | tteck/Proxmox | NextCloud |
| casaos | Manual | CasaOS |

## ⚠️ PROBLEMAS CRÍTICOS

### VM 108 - TrueNAS
- **Criticidade**: MUITO ALTA
- **Discos**: 1.5TB + 3TB de dados
- **Problema**: Backup nunca completou (timeout)
- **Ação**: Verificar se discos físicos ainda têm dados

```bash
# Verificar discos físicos
ls -la /dev/disk/by-id/ata-ST1500DL003-9VT16L_6YD00WNY
ls -la /dev/disk/by-id/ata-ST3000DM003-1F216N_W3014A0A
```

## 📋 RECOMENDAÇÕES IMEDIATAS

### Prioridade 1: Tentar Recuperação via Snapshot
```bash
# Fazer rollback do spark/base para 17/09
zfs rollback -r spark/base@autosnap_2025-09-17_14:30:04_frequently
```

### Prioridade 2: Verificar Discos Físicos da VM 108
Os discos físicos podem ainda conter o pool ZFS do TrueNAS

### Prioridade 3: Recriar Containers Menos Críticos
- Usar scripts tteck para containers padrão
- Documentar configurações para futuro

## 🔴 AÇÃO URGENTE NECESSÁRIA

1. **DECISÃO SOBRE ROLLBACK**:
   - Fazer rollback perderia trabalhos de 17/09 até hoje
   - Mas recuperaria os 16 sistemas perdidos

2. **BACKUP ANTES DE QUALQUER AÇÃO**:
   ```bash
   # Backup atual antes de tentativas
   zfs snapshot spark/base@before-recovery-attempt
   ```

3. **VERIFICAR COM USUÁRIOS**:
   - Quais sistemas são mais críticos?
   - Existe backup externo de algum?
   - VM 108 (TrueNAS) tinha backup em outro lugar?

## 💡 LIÇÕES APRENDIDAS

1. **Política de Retenção**: Nunca deletar backups sem verificação
2. **Snapshot Regular**: Configurar snapshots mais frequentes
3. **Backup Offsite**: Crítico para sistemas importantes
4. **Documentação**: Manter registro do que cada VM/CT faz

---
**Status**: AGUARDANDO DECISÃO SOBRE MÉTODO DE RECUPERAÇÃO
**Próximo Passo**: Decidir entre rollback ZFS ou recriação manual