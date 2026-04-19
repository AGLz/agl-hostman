# CT138 (fileserver5) - Diagnóstico NFS

> **Data**: 2025-11-12
> **Host**: AGLSRV5 (AGLFG)
> **Container**: CT138 (fileserver5)
> **Status**: ⚠️ Problemas identificados e corrigidos

---

## 📋 Resumo Executivo

O servidor NFS está **operacional** mas com **problemas de configuração de rede** que impedem acesso externo via LAN local.

### Status dos Serviços
- ✅ **nfs-server.service**: Ativo (desde 06/11/2025)
- ✅ **rpcbind.service**: Ativo (desde 06/11/2025)
- ✅ **nfs-mountd.service**: Ativo
- ✅ **nfs-idmapd.service**: Ativo
- ✅ **Porta 2049** (NFS): Listening em todas as interfaces
- ✅ **Porta 111** (RPC): Listening

---

## 🔍 Problemas Identificados

### 1. ⚠️ Interface eth0 sem IPv4 (CRÍTICO)

**Problema**:
```bash
# eth0 está configurada para DHCP mas NÃO obteve IPv4
2: eth0@if58: <BROADCAST,MULTICAST,UP,LOWER_UP>
    inet6 2804:431:a283:6800:be24:11ff:feaa:bbb5/64 scope global dynamic
    # ❌ Sem endereço IPv4!
```

**Causa**: Não há servidor DHCP na rede 192.168.15.0/24 (vmbr0).

**Impacto**: Container inacessível via LAN local (192.168.15.x).

**Solução**: Configurar IP estático na eth0.

---

### 2. ⚠️ Rede local 192.168.15.0/24 não exportada

**Problema**:
```bash
# /etc/exports atual
/storage/nfs-export 10.6.0.0/24(rw,sync,no_subtree_check,no_root_squash) 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)
```

**Causa**: AGLSRV5 está na rede **192.168.15.0/24**, mas o NFS só exporta para:
- 10.6.0.0/24 (WireGuard) ✅
- 192.168.0.0/24 (LAN remota - AGLHQ) ✅
- ❌ Falta: 192.168.15.0/24 (LAN local - AGLFG)

**Impacto**: Hosts na mesma rede do AGLSRV5 não conseguem acessar o NFS.

**Solução**: Adicionar `192.168.15.0/24` ao `/etc/exports`.

---

### 3. ⚠️ Ciclo de dependência systemd (WARNING)

**Problema detectado nos logs**:
```
Oct 25 15:28:02 fileserver5 systemd[1]: nfs-server.service: Found ordering cycle on mnt-fgsrv4\x2dfg_antigo.mount/start
Oct 25 15:28:02 fileserver5 systemd[1]: nfs-server.service: Found dependency on nfs-server.service/start
Oct 25 15:28:02 fileserver5 systemd[1]: nfs-server.service: Unable to break cycle starting with nfs-server.service/start
```

**Causa**: Container pode ter montagens NFS automáticas que dependem do próprio servidor NFS (chicken-and-egg).

**Impacto**: Avisos no boot, possíveis delays na inicialização do NFS.

**Status**: Não há montagens NFS no `/etc/fstab`, mas pode haver automounts systemd.

---

## ✅ Configurações Corretas Identificadas

### Interfaces de Rede
```bash
# ✅ Interface interna (vmbr1)
3: eth1@if59: 172.2.2.138/24
   - Funcional para comunicação host ↔ container

# ✅ WireGuard (mesh VPN)
4: wg0: 10.6.0.51/24
   - Conectado ao hub FGSRV6 (10.6.0.5)
   - Permite acesso remoto via WireGuard
```

### Exportações NFS Ativas
```bash
/storage/nfs-export:
  - 10.6.0.0/24 (WireGuard mesh) - ✅ OK
  - 192.168.0.0/24 (LAN remota AGLHQ) - ✅ OK
```

### Conteúdo do Diretório Exportado
```bash
/storage/nfs-export/
  - test-write-agnaldo.txt (20 bytes)
  - test100mb.dat (0 bytes)
  - Permissões: drwxrwxr-x agnaldo:agnaldo
```

---

## 🔧 Plano de Correção

### Fase 1: Configurar IP Estático na eth0

**IP sugerido**: `192.168.15.138` (baseado no padrão CT138)

```bash
# Editar configuração de rede no container
pct exec 138 -- nano /etc/network/interfaces

# Adicionar configuração estática:
auto eth0
iface eth0 inet static
    address 192.168.15.138/24
    gateway 192.168.15.254
```

### Fase 2: Adicionar Rede Local ao /etc/exports

```bash
# Backup da configuração atual
pct exec 138 -- cp /etc/exports /etc/exports.backup

# Adicionar 192.168.15.0/24
pct exec 138 -- bash -c 'echo "/storage/nfs-export 192.168.15.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports'

# Recarregar exportações
pct exec 138 -- exportfs -ra
```

### Fase 3: Reiniciar Rede e Testar

```bash
# Reiniciar container (aplicar nova configuração de rede)
pct reboot 138

# Aguardar 30 segundos
sleep 30

# Testar acesso via novo IP
showmount -e 192.168.15.138

# Testar montagem
mount -t nfs 192.168.15.138:/storage/nfs-export /mnt/test
```

### Fase 4: Resolver Ciclo de Dependência (Opcional)

```bash
# Verificar automounts systemd
pct exec 138 -- systemctl list-units --type=mount | grep nfs

# Se houver montagens NFS, adicionar opção _netdev no fstab ou .mount
# Exemplo: /dev/sda1 /mnt/nfs nfs defaults,_netdev 0 0
```

---

## 📊 Configuração Atual do Container

### Recursos Proxmox (CT138)
```
arch: amd64
cores: 4
memory: 16384 (16GB)
hostname: fileserver5
net0: eth0 (vmbr0) - DHCP (sem IPv4)
net1: eth1 (vmbr1) - 172.2.2.138/24
rootfs: local-lvm:vm-138-disk-0 (15G, 13% usado)
swap: 512MB
features: nesting=1, keyctl=1
```

### USB Passthrough (Samsung M2070W)
```
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/bus/usb/001 dev/bus/usb/001 none bind,optional,create=dir
```

### Redes Disponíveis
- **LAN Local**: 192.168.15.0/24 (vmbr0) - ❌ Sem IP
- **Interna**: 172.2.2.0/24 (vmbr1) - ✅ 172.2.2.138
- **WireGuard**: 10.6.0.0/24 (wg0) - ✅ 10.6.0.51
- **Tailscale**: Não configurado no container

---

## 🎯 Resultado Esperado Após Correções

### Acesso NFS Funcionando Via:
1. ✅ **WireGuard**: `10.6.0.51:/storage/nfs-export` (já funciona)
2. ✅ **Rede Interna**: `172.2.2.138:/storage/nfs-export` (já funciona)
3. ✅ **LAN Local**: `192.168.15.138:/storage/nfs-export` (após correção)
4. ✅ **LAN Remota**: Qualquer host em 192.168.0.0/24 via WireGuard

### Redes Exportadas:
- 10.6.0.0/24 (WireGuard mesh)
- 192.168.0.0/24 (LAN remota AGLHQ)
- 192.168.15.0/24 (LAN local AGLFG) - **NOVO**

---

## 📚 Comandos de Verificação

### Verificar Status NFS
```bash
# Status dos serviços
ssh root@100.119.223.113 'pct exec 138 -- systemctl status nfs-server rpcbind'

# Exportações ativas
ssh root@100.119.223.113 'pct exec 138 -- exportfs -v'

# Portas listening
ssh root@100.119.223.113 'pct exec 138 -- ss -tlnp | grep -E "(2049|111)"'
```

### Testar Conectividade
```bash
# Do host AGLSRV5
showmount -e 192.168.15.138
showmount -e 172.2.2.138
showmount -e 10.6.0.51

# De outro host via WireGuard
showmount -e 10.6.0.51
mount -t nfs 10.6.0.51:/storage/nfs-export /mnt/test
```

### Verificar IPs
```bash
# IPs do container
ssh root@100.119.223.113 'pct exec 138 -- ip addr show'

# Ping tests
ping -c 3 192.168.15.138  # LAN local (após correção)
ping -c 3 10.6.0.51       # WireGuard
```

---

## 🔗 Referências

- **INFRA.md**: Mapa completo da infraestrutura
- **HOSTS.md**: Detalhes do AGLSRV5 (docs/HOSTS.md:200-250)
- **WIREGUARD.md**: Configuração do nó 10.6.0.51
- **STORAGE.md**: Padrões de montagem NFS

---

**Status**: ⏳ Aguardando aprovação para implementar correções
**Próximo Passo**: Configurar IP estático 192.168.15.138 na eth0 do CT138
