# 🔍 ANÁLISE PROFUNDA DOS SISTEMAS PERDIDOS

## 📅 Data da Análise
- **Data/Hora**: 27/09/2025 - 14:55
- **Servidor**: algsrv1 (100.107.113.33)

## 📊 RESUMO EXECUTIVO

### Sistemas Identificados
| ID | Tipo | Nome/Função | Status | Prioridade |
|----|------|-------------|--------|------------|
| 129 | VM | Template-Cloud-init | Template sem discos | BAIXA |
| 175 | CT | ollama | Container AI/LLM | BAIXA |
| 130 | CT | agldc1 (Domain Controller) | **CRÍTICO - Sem backup** | **ALTA** |
| 140 | CT | nzbget (Usenet) | **CRÍTICO - Sem backup** | **ALTA** |
| 127 | ? | Desconhecido | Sem vestígios | N/A |
| 166 | ? | Desconhecido | Sem vestígios | N/A |
| 177 | ? | Desconhecido | Sem vestígios | N/A |

## 🔴 SISTEMAS CRÍTICOS SEM BACKUP (CT 130 e 140)

### CT 130 - agldc1 (Domain Controller)
- **Função**: Active Directory / Domain Controller
- **Último Backup**: 17/03/2025 (deletado)
- **Tamanho Estimado**: Desconhecido
- **Impacto da Perda**: ALTO - Autenticação centralizada
- **Status**: ❌ IRRECUPERÁVEL pelos métodos tradicionais

### CT 140 - nzbget
- **Função**: Cliente Usenet/Download Manager
- **Último Backup**: 17/03/2025 (deletado)
- **Tamanho Estimado**: Desconhecido
- **Impacto da Perda**: MÉDIO - Sistema de downloads
- **Status**: ❌ IRRECUPERÁVEL pelos métodos tradicionais

## 📝 SISTEMAS COM INFORMAÇÕES DESCOBERTAS

### VM 129 - Template-Cloud-init
```
Nome: Template-Cloud-init
Tipo: Template VM (sem discos ativos)
Último Log: 28/08/2024
Status: Template apenas - não continha dados
Recuperação: Não necessária (era só template)
```

### CT 175 - ollama
```
Nome: ollama
Tipo: Container LXC
Função: Servidor AI/LLM (Ollama)
Último Backup: 17/03/2025
Múltiplos Mount Points: /mnt/shares, /mnt/overpower, etc
Status: Logs existem mas backup deletado
Recuperação: Não prioritária
```

## 🔬 TENTATIVAS DE RECUPERAÇÃO REALIZADAS

### 1. Snapshot ZFS Clonado
```bash
✅ Snapshot criado: spark/base@before-recovery-attempt-20250927-225213
✅ Clone criado: spark/base-recovery (do snapshot de 17/09)
❌ Resultado: Snapshot não contém os backups (já haviam sido deletados)
```

### 2. Análise de Blocos ZFS
- Snapshots existem mas são anteriores aos backups
- Não há como recuperar arquivos que nunca existiram nos snapshots

## 💡 OPÇÕES DE RECRIAÇÃO PARA CT 130 e 140

### Opção 1: Recriar CT 130 (agldc1) - Domain Controller
```bash
# Criar novo container
pct create 130 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname agldc1 \
  --memory 4096 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-zfs \
  --password

# Instalar Samba AD DC
apt update && apt install samba krb5-config winbind smbclient
samba-tool domain provision --use-rfc2307 --interactive
```

### Opção 2: Recriar CT 140 (nzbget)
```bash
# Usar script tteck
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/nzbget.sh)"

# Ou criar manualmente
pct create 140 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname nzbget \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-zfs
```

## 🚨 AÇÕES RECOMENDADAS IMEDIATAS

### Para CT 130 (agldc1) - CRÍTICO
1. **Verificar** se há outro DC na rede que tenha replicação
2. **Se sim**: Promover outro DC e recriar este como secundário
3. **Se não**: Recriar do zero e reimportar usuários

### Para CT 140 (nzbget)
1. **Recriar** usando script tteck (mais simples)
2. **Reconfigurar** servidores Usenet
3. **Restaurar** configurações se tiver backup externo

## 🔍 SISTEMAS SEM VESTÍGIOS (127, 166, 177)

Análise completa realizada:
- ❌ Sem arquivos .notes ou .log
- ❌ Sem configurações em /etc/pve/
- ❌ Sem registros no journal
- ❌ Sem evidências em qualquer storage

**Conclusão**: Estes IDs provavelmente nunca existiram ou foram deletados há muito tempo.

## 📋 PRÓXIMOS PASSOS

### Prioridade 1: CT 130 (agldc1)
```bash
# Verificar se há backup do AD em outro lugar
smbclient -L //outro-servidor -U administrator

# Se não houver, recriar do zero
```

### Prioridade 2: CT 140 (nzbget)
```bash
# Recriar usando automação
wget -qO - https://github.com/tteck/Proxmox/raw/main/ct/nzbget.sh | bash
```

### Prioridade 3: Documentação
- Documentar configurações dos novos containers
- Implementar backup policy adequada
- Configurar snapshots automáticos mais frequentes

## ⚠️ LIÇÕES CRÍTICAS

1. **CT 130 (Domain Controller)** nunca deveria estar sem backup offsite
2. **Deletar backups** sem verificação prévia é catastrófico
3. **Snapshots ZFS** não substituem backups completos
4. **Documentação** de cada sistema é essencial

---
**Status Final**:
- ✅ Análise profunda completa
- ❌ CT 130 e 140 irrecuperáveis
- 🔄 Prontos para recriação manual
- 📝 IDs 127, 166, 177 sem vestígios (provavelmente nunca existiram)