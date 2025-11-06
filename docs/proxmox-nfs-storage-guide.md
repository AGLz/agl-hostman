# 📦 Guia de Configuração NFS Storage no Proxmox AGLSRV1

**Data:** 2025-10-15
**Storages:** FGSRV5 (14.0 MB/s) e FGSRV6 (12.6 MB/s)
**Protocolo:** NFS v4.2 via Tailscale

---

## 🎯 Objetivo

Adicionar os storages remotos FGSRV5 e FGSRV6 ao datacenter Proxmox AGLSRV1 para uso em:
- Backups de containers e VMs
- Templates de containers (vztmpl)
- ISOs de instalação
- Snippets de configuração
- Armazenamento de containers (rootdir)

---

## 📊 Storages Disponíveis

| Storage ID | Servidor | Performance Write | Capacidade | Latência | Melhor Para |
|-----------|----------|-------------------|------------|----------|-------------|
| **fgsrv5-nfs** | 100.71.107.26 | 14.0 MB/s ⭐ | 14GB | 24ms | Backups rápidos, templates |
| **fgsrv6-nfs** | 100.83.51.9 | 12.6 MB/s | 132GB | 23ms | Backups grandes, arquivos |

---

## 🚀 Método 1: Configuração Automática (Recomendado)

### 1. Execute o Script de Configuração

No host Proxmox AGLSRV1:

```bash
# Tornar executável
chmod +x /root/host-admin/scripts/add-nfs-to-proxmox.sh

# Executar
/root/host-admin/scripts/add-nfs-to-proxmox.sh
```

O script irá:
- ✅ Verificar conectividade NFS
- ✅ Adicionar ambos os storages ao Proxmox
- ✅ Configurar opções otimizadas de mount
- ✅ Verificar funcionamento
- ✅ Criar mount points

**Tempo estimado:** ~30 segundos

---

## 🔧 Método 2: Configuração Manual via CLI

### 1. Instalar Ferramentas NFS (se necessário)

```bash
apt-get update
apt-get install -y nfs-common
```

### 2. Verificar Conectividade

**FGSRV5:**
```bash
showmount -e 100.71.107.26
# Deve mostrar: /storage/nfs-export *

ping -c 3 100.71.107.26
# Deve responder com latência ~24ms
```

**FGSRV6:**
```bash
showmount -e 100.83.51.9
# Deve mostrar: /storage/nfs-export *

ping -c 3 100.83.51.9
# Deve responder com latência ~23ms
```

### 3. Adicionar Storage FGSRV5 (High-Speed)

```bash
pvesm add nfs fgsrv5-nfs \
    --server 100.71.107.26 \
    --export / \
    --content vztmpl,iso,backup,snippets,rootdir \
    --options vers=4.2,rsize=1048576,wsize=1048576,hard,intr,noatime,nodiratime,nconnect=4 \
    --nodes $(hostname) \
    --disable 0
```

**Explicação dos parâmetros:**
- `fgsrv5-nfs`: ID do storage no Proxmox
- `--server 100.71.107.26`: IP do servidor NFS (via Tailscale)
- `--export /`: Caminho NFSv4 (pseudo-root com fsid=0)
- `--content`: Tipos de conteúdo permitidos
- `--options`: Otimizações de performance NFS v4.2
- `--nodes`: Nó Proxmox que pode acessar (use hostname atual)
- `--disable 0`: Storage ativo (1 = desativado)

### 4. Adicionar Storage FGSRV6 (Large-Capacity)

```bash
pvesm add nfs fgsrv6-nfs \
    --server 100.83.51.9 \
    --export / \
    --content vztmpl,iso,backup,snippets,rootdir \
    --options vers=4.2,rsize=1048576,wsize=1048576,hard,intr,noatime,nodiratime,nconnect=4 \
    --nodes $(hostname) \
    --disable 0
```

### 5. Verificar Storages

```bash
# Listar todos os storages
pvesm status

# Verificar storage específico
pvesm status -storage fgsrv5-nfs
pvesm status -storage fgsrv6-nfs

# Listar conteúdo (deve estar vazio inicialmente)
pvesm list fgsrv5-nfs
pvesm list fgsrv6-nfs
```

**Saída esperada:**
```
Name           Type     Status           Total            Used       Available        %
fgsrv5-nfs     nfs      active       14.00 GiB        0.00 GiB       14.00 GiB    0.00%
fgsrv6-nfs     nfs      active      132.00 GiB        0.00 GiB      132.00 GiB    0.00%
```

---

## 🖥️ Método 3: Configuração via Proxmox Web UI

### 1. Acessar Datacenter Storage

1. Login no Proxmox Web UI: `https://AGLSRV1_IP:8006`
2. Navegue: **Datacenter** → **Storage** → **Add** → **NFS**

### 2. Configurar FGSRV5 (High-Speed)

**Preencha os campos:**

- **ID:** `fgsrv5-nfs`
- **Server:** `100.71.107.26`
- **Export:** `/`
- **Content:** ✅ Selecionar todos:
  - Container templates
  - ISO images
  - VZDump backup file
  - Snippets
  - Container
- **Nodes:** Selecione o nó atual (AGLSRV1)
- **Enable:** ✅ Marcado
- **Max Backups:** (deixar padrão ou definir limite)

**Opções Avançadas (Advanced):**

Na aba "Advanced", adicione em **NFS Version:**
```
4.2
```

Em **Mount Options:**
```
rsize=1048576,wsize=1048576,hard,intr,noatime,nodiratime,nconnect=4
```

Clique em **Add**.

### 3. Configurar FGSRV6 (Large-Capacity)

Repita o processo acima com:

- **ID:** `fgsrv6-nfs`
- **Server:** `100.83.51.9`
- **Export:** `/`
- Demais configurações iguais ao FGSRV5

### 4. Verificar no Web UI

Após adicionar, você verá os storages em:
- **Datacenter** → **Storage**

Com indicadores:
- 🟢 Verde = Active
- Espaço disponível visível
- Tipo: NFS

---

## ⚙️ Detalhes Técnicos das Configurações

### NFS Mount Options Explicadas

```bash
vers=4.2              # NFSv4.2 - melhor performance e segurança
rsize=1048576         # Read buffer 1MB - otimizado para arquivos grandes
wsize=1048576         # Write buffer 1MB - otimizado para backups
hard                  # Nunca desistir de operações falhadas (importante!)
intr                  # Permitir interrupções de I/O
noatime               # Não atualizar access time (melhora performance)
nodiratime            # Não atualizar directory access time
nconnect=4            # 4 conexões paralelas TCP (melhor throughput)
```

### Content Types (Tipos de Conteúdo)

| Tipo | Descrição | Recomendação |
|------|-----------|--------------|
| **vztmpl** | Container templates (CT) | Ambos storages |
| **iso** | ISOs de instalação | Ambos storages |
| **backup** | Backups VZDump | FGSRV6 (132GB) |
| **snippets** | Scripts e configs | Ambos storages |
| **rootdir** | Armazenamento de containers | FGSRV5 (velocidade) |

### Por que usar "/" como export?

Os servidores FGSRV5 e FGSRV6 usam `fsid=0` em `/etc/exports`, que cria um **pseudo-filesystem root** NFSv4.

**Comportamento:**
- Export real no servidor: `/storage/nfs-export`
- Mount no cliente: `SERVER:/` (não `SERVER:/storage/nfs-export`)
- NFSv4 mapeia automaticamente para o diretório correto

---

## 🔍 Verificação e Testes

### 1. Verificar Status dos Storages

```bash
# Status geral
pvesm status

# Status específico
pvesm status -storage fgsrv5-nfs
pvesm status -storage fgsrv6-nfs

# Listar conteúdo
pvesm list fgsrv5-nfs
pvesm list fgsrv6-nfs
```

### 2. Teste de Escrita (FGSRV5)

```bash
# Criar arquivo de teste
dd if=/dev/zero of=/mnt/pve/fgsrv5-nfs/test-write.bin bs=1M count=100 conv=fdatasync

# Verificar
ls -lh /mnt/pve/fgsrv5-nfs/test-write.bin

# Limpar
rm /mnt/pve/fgsrv5-nfs/test-write.bin
```

**Performance esperada:** ~14 MB/s

### 3. Teste de Escrita (FGSRV6)

```bash
# Criar arquivo de teste
dd if=/dev/zero of=/mnt/pve/fgsrv6-nfs/test-write.bin bs=1M count=100 conv=fdatasync

# Verificar
ls -lh /mnt/pve/fgsrv6-nfs/test-write.bin

# Limpar
rm /mnt/pve/fgsrv6-nfs/test-write.bin
```

**Performance esperada:** ~12.6 MB/s

### 4. Teste de Upload de ISO

Via Web UI:
1. Navegue para: **fgsrv5-nfs** → **ISO Images** → **Upload**
2. Selecione um arquivo ISO pequeno de teste
3. Monitore velocidade de upload

Ou via CLI:
```bash
# Download ISO de teste (Alpine Linux - pequeno)
wget https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-virt-3.18.0-x86_64.iso

# Upload para storage
pvesm upload fgsrv5-nfs alpine-virt-3.18.0-x86_64.iso -content iso

# Verificar
pvesm list fgsrv5-nfs -content iso
```

---

## 📋 Casos de Uso Recomendados

### FGSRV5 (14.0 MB/s - High-Speed)

**Melhor para:**
- ✅ Container templates (download/upload rápido)
- ✅ ISOs de instalação
- ✅ Backups de containers pequenos (<5GB)
- ✅ Snippets de configuração
- ✅ Migrações rápidas de containers

**Configuração de Backup:**
```bash
# No Proxmox, criar job de backup para FGSRV5
# Datacenter → Backup → Add
# - Storage: fgsrv5-nfs
# - Schedule: Diário às 2:00 AM
# - Retention: Manter 3 backups
# - Mode: Snapshot
# - Compress: ZSTD (rápido)
```

### FGSRV6 (12.6 MB/s - Large-Capacity)

**Melhor para:**
- ✅ Backups grandes de VMs (>10GB)
- ✅ Arquivos de backup de longo prazo
- ✅ Armazenamento de múltiplas ISOs
- ✅ Backups incrementais PBS
- ✅ Arquivamento

**Configuração de Backup:**
```bash
# No Proxmox, criar job de backup para FGSRV6
# Datacenter → Backup → Add
# - Storage: fgsrv6-nfs
# - Schedule: Semanal aos domingos 3:00 AM
# - Retention: Manter 4 backups semanais
# - Mode: Snapshot
# - Compress: ZSTD level 3 (economia de espaço)
```

---

## 🔧 Troubleshooting

### Problema: Storage não aparece como "active"

**Diagnóstico:**
```bash
# Verificar status
pvesm status -storage fgsrv5-nfs

# Verificar logs
journalctl -u pve-cluster -f

# Testar mount manual
mount -t nfs -o vers=4.2 100.71.107.26:/ /mnt/test
```

**Soluções:**
1. Verificar conectividade Tailscale
2. Verificar firewall no servidor NFS
3. Verificar que NFS server está rodando
4. Re-ativar storage: `pvesm set fgsrv5-nfs --disable 0`

### Problema: "Permission denied" ao fazer upload

**Causa:** Export configurado com `root_squash`

**Verificação:**
```bash
ssh root@100.71.107.26 "exportfs -v | grep nfs-export"
# Deve mostrar: no_root_squash
```

**Solução:** Já configurado corretamente com `no_root_squash`

### Problema: Performance lenta (<5 MB/s)

**Diagnóstico:**
```bash
# Testar largura de banda
iperf3 -c 100.71.107.26

# Verificar MTU
ip link show tailscale0

# Verificar latência
ping -c 10 100.71.107.26
```

**Otimizações:**
```bash
# Aumentar MTU (se suportado)
ip link set dev tailscale0 mtu 1420

# Verificar BBR ativo
sysctl net.ipv4.tcp_congestion_control
# Deve retornar: bbr
```

### Problema: Mount falha com "No such file or directory"

**Causa:** Usando caminho completo ao invés do pseudo-root NFSv4

**Solução:** Sempre usar `/` como export com `fsid=0`:
```bash
# ❌ ERRADO
--export /storage/nfs-export

# ✅ CORRETO
--export /
```

### Problema: Storage aparece mas não consegue criar diretórios

**Diagnóstico:**
```bash
# Verificar permissões
ssh root@100.71.107.26 "ls -la /storage/nfs-export"

# Testar criação manual
ssh root@100.71.107.26 "touch /storage/nfs-export/test.txt"
```

**Solução:** Garantir permissões corretas:
```bash
ssh root@100.71.107.26 "chmod 755 /storage/nfs-export"
```

---

## 📊 Monitoramento

### Comandos Úteis

**Uso de espaço:**
```bash
pvesm status | grep -E 'fgsrv5|fgsrv6'
```

**Lista de backups:**
```bash
pvesm list fgsrv5-nfs -content backup
pvesm list fgsrv6-nfs -content backup
```

**Performance I/O:**
```bash
# Monitorar NFS stats (no cliente)
nfsstat -c

# Atualizar a cada 5 segundos
watch -n 5 "nfsstat -c | head -20"
```

**Logs de mount:**
```bash
# Ver logs de mount NFS
dmesg | grep -i nfs | tail -20

# Logs do Proxmox storage
tail -f /var/log/pve/tasks/active
```

---

## 🚀 Configurações Avançadas

### 1. Habilitar Compression para Backups

Edite `/etc/pve/storage.cfg` e adicione:

```ini
nfs: fgsrv6-nfs
    server 100.83.51.9
    export /
    content backup,vztmpl,iso
    options vers=4.2,rsize=1048576,wsize=1048576,hard,intr,noatime,nodiratime,nconnect=4
    prune-backups keep-last=4
    compression zstd
```

### 2. Configurar Retenção Automática de Backups

```bash
# Manter últimos 3 backups no FGSRV5
pvesm set fgsrv5-nfs --prune-backups keep-last=3

# Manter 4 backups semanais no FGSRV6
pvesm set fgsrv6-nfs --prune-backups keep-weekly=4
```

### 3. Adicionar Storage a Cluster (Multi-Node)

Se você tiver múltiplos nós Proxmox:

```bash
# Remover restrição de nó específico
pvesm set fgsrv5-nfs --nodes ""

# Agora todos os nós podem acessar
```

**Requisito:** Todos os nós devem ter acesso via Tailscale aos servidores NFS.

---

## 📚 Referências

**Documentação Relacionada:**
- [FGSRV5 Final Results](/root/host-admin/docs/test-reports/fgsrv5-final-results.md)
- [FGSRV6 Final Results](/root/host-admin/docs/test-reports/fgsrv6-final-results.md)
- [Complete Deployment Summary](/root/host-admin/docs/test-reports/complete-deployment-summary.md)
- [Storage Architecture](/root/host-admin/docs/storage-architecture.md)

**Scripts:**
- [add-nfs-to-proxmox.sh](/root/host-admin/scripts/add-nfs-to-proxmox.sh)
- [deploy-nfs-to-remote.sh](/root/host-admin/scripts/deploy-nfs-to-remote.sh)

**Proxmox Documentation:**
- [Proxmox VE Storage](https://pve.proxmox.com/wiki/Storage)
- [Proxmox NFS Storage](https://pve.proxmox.com/wiki/Storage:_NFS)

---

## ✅ Checklist de Implantação

### Pré-requisitos
- [ ] Acesso SSH ao host Proxmox AGLSRV1
- [ ] Tailscale ativo e funcionando
- [ ] FGSRV5 e FGSRV6 com NFS v4.2 deployado
- [ ] Pacote `nfs-common` instalado no Proxmox

### Configuração
- [ ] Executar script `add-nfs-to-proxmox.sh` OU
- [ ] Adicionar manualmente via CLI OU
- [ ] Adicionar via Web UI
- [ ] Verificar storages aparecem como "active"
- [ ] Testar escrita em ambos os storages

### Validação
- [ ] Upload de ISO de teste bem-sucedido
- [ ] Criar backup de teste de um container
- [ ] Verificar performance esperada (10-14 MB/s)
- [ ] Confirmar espaço disponível correto

### Produção
- [ ] Configurar jobs de backup automático
- [ ] Definir retenção de backups
- [ ] Configurar alertas de capacidade
- [ ] Documentar uso para equipe

---

**Status:** ✅ **PRONTO PARA IMPLANTAÇÃO**
**Última Atualização:** 2025-10-15
**Versão:** 1.0

---

*Guia criado pelo Hive Mind Collective Intelligence System*
