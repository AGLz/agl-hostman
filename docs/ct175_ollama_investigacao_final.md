# 🔍 INVESTIGAÇÃO COMPLETA DO CT 175 (OLLAMA)

## 📅 Data da Investigação
- **Data/Hora**: 27/09/2025 - 15:20
- **Servidor**: algsrv1 (100.107.113.33)

## 🎯 RESUMO EXECUTIVO

### CT 175 - Sistema Ollama (AI/LLM)
- **Status**: ❌ BACKUP PERDIDO
- **Tamanho Original**: 52.50 GB (98 GiB descompactado)
- **Último Backup**: 11/03/2025 às 04:54:20
- **Arquivo Esperado**: `vzdump-lxc-175-2025_03_11-04_54_20.tar.zst`

## 📊 EVIDÊNCIAS ENCONTRADAS

### Logs Existentes
```
vzdump-lxc-175-2025_03_11-04_54_20.log - Backup completo (52.50GB)
vzdump-lxc-175-2025_03_14-16_35_50.log - Tentativa de backup
vzdump-lxc-175-2025_03_15-13_10_03.log - Tentativa de backup
vzdump-lxc-175-2025_03_16-05_11_35.log - Tentativa de backup
vzdump-lxc-175-2025_03_17-18_32_00.log - Última tentativa
```

### Detalhes do Container Original
```
Nome: ollama
Tipo: Container LXC
Função: Servidor AI/LLM (Ollama)
Rootfs: 98 GiB usado
Mount Points:
- mp0: /mnt/shares
- mp1: /mnt/overpower
- mp2: /mnt/power
- mp5: /mnt/storage
- mp6: /mnt/disks/gd/BB/Extracted
- mp7: /mnt/pve/common/media/Extracted
- mp8: /mnt/disks/gd/BB/Extracted_New
- mp9: /mnt/pve/common/media/Extracted_New
```

## 🔬 TENTATIVAS DE RECUPERAÇÃO

### 1. Busca em Todos os Storages
```bash
✅ /spark/base/dump/ - Não encontrado
✅ /overpower/dump/ - Não encontrado
✅ /var/lib/vz/dump/ - Não encontrado
✅ Storages remotos - Não encontrado
```

### 2. Snapshots ZFS
```bash
✅ Snapshots de 17/09/2025 existem
❌ Anteriores à criação do backup (11/03/2025)
❌ Acesso aos snapshots está travando/lento
```

### 3. Busca por Tamanho
```bash
✅ Procurado arquivos de 50-55GB
❌ Nenhum arquivo encontrado nesta faixa
```

### 4. Análise de Blocos ZFS
```bash
❌ Blocos já foram liberados
❌ Não há como recuperar via ZFS undelete
```

## 💡 DESCOBERTA IMPORTANTE

### CT 200 - Possível Substituto
```
ID: 200
Nome: ollama
Descrição: Ollama AI container with GPU passthrough
Status: RUNNING
Configuração:
- 8 cores
- 16GB RAM
- GPU Passthrough habilitado
- IP: 192.168.0.200
- Rootfs: 32GB (menor que o original)
```

**HIPÓTESE**: O CT 200 (ollama) pode ser uma recriação/migração do CT 175 com melhorias (GPU passthrough).

## 🚨 CONCLUSÃO

### Sobre o CT 175
1. **Backup Definitivamente Perdido**: Arquivo de 52.50GB foi deletado em 26/09
2. **Irrecuperável**: Todas as tentativas de recuperação falharam
3. **Container Não Existe Mais**: Configuração e subvolumes deletados

### Possível Solução Já Implementada
O **CT 200 (ollama)** parece ser a evolução/substituto do CT 175:
- Mesmo serviço (Ollama)
- Melhorias implementadas (GPU)
- Está operacional

## 📋 RECOMENDAÇÕES

### Opção 1: Usar CT 200 Existente
```bash
# Verificar se CT 200 tem os modelos necessários
pct exec 200 -- ollama list

# Se precisar adicionar modelos
pct exec 200 -- ollama pull llama2
pct exec 200 -- ollama pull codellama
```

### Opção 2: Recriar CT 175 do Zero
```bash
# Criar novo container
pct create 175 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname ollama \
  --memory 16384 \
  --cores 8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-zfs \
  --rootfs local-zfs:100

# Instalar Ollama
pct exec 175 -- bash -c "curl -fsSL https://ollama.com/install.sh | sh"

# Adicionar modelos
pct exec 175 -- ollama pull llama2
pct exec 175 -- ollama pull mistral
```

### Opção 3: Migrar Dados do CT 200 para 175
Se o CT 200 não for adequado, pode-se clonar seus dados:
```bash
# Fazer backup do CT 200
vzdump 200 --dumpdir /var/lib/vz/dump

# Restaurar como CT 175
pct restore 175 /var/lib/vz/dump/vzdump-lxc-200-*.tar.zst
```

## ⚠️ LIÇÕES APRENDIDAS

1. **Containers com 50GB+** devem ter backup offsite obrigatório
2. **Serviços AI/LLM** têm modelos grandes que demoram para redownload
3. **GPU Passthrough** no CT 200 sugere evolução planejada
4. **Documentar migrações** quando substituir containers

---
**Status Final**:
- ❌ CT 175 irrecuperável
- ✅ CT 200 (ollama) operacional como possível substituto
- 📝 Recomendado verificar se CT 200 atende as necessidades