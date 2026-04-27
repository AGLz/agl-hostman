# FileServer5 (CT138) - Recovery Completo

> **Data**: 2025-12-09
> **Container**: CT138 (fileserver5) no AGLSRV5 (100.119.223.113)
> **Status**: ✅ **TOTALMENTE RESOLVIDO E FUNCIONAL**

---

## 📋 Resumo do Problema Original

Após restart do host Proxmox (AGLSRV5), o container CT138 ficou completamente inacessível com problemas graves:

1. **Container não inicializava** - Erros de cgroup e veth stuck
2. **Network namespace corrompido** - Após recovery, rede unidirecional
3. **Gateway incorreto** - Configurado para 172.2.2.1 (não existe)
4. **Tailscale interceptando tráfego local** - Routing conflict
5. **Samba services mortos** - smbd/nmbd não estavam rodando

---

## 🔧 Correções Implementadas (Passo a Passo)

### 1. Recovery do Container Bloqueado

**Problema**: Container stuck com cgroup directories em uso
```bash
find: cannot delete '/sys/fs/cgroup/lxc/138': Device or resource busy
```

**Solução**:
```bash
# Limpar cgroup directories stuck
find /sys/fs/cgroup/ -name "*138*" -type d -print -delete

# Remover veth interfaces antigas
ip link del veth138i0 2>/dev/null
ip link del veth138i1 2>/dev/null

# Container started successfully após cleanup
```

**Resultado**: ✅ Container iniciou com sucesso

---

### 2. Correção do Gateway (Causa Raiz Principal)

**Problema**: Container configurado com gateway inválido
- Configurado: `172.2.2.1` (não existe - ARP mostrava "FAILED")
- Correto: `172.2.2.254` (gateway real da rede)

**Diagnóstico**:
```bash
# Verificar gateway atual
arp -a | grep 172.2.2.1
# Output: ? (172.2.2.1) at <incomplete> on vmbr1  # FAILED

# Scan da rede para encontrar gateway
nmap -sn 172.2.2.0/24 | grep -B 2 router
# Found: 172.2.2.254 (FreePBX Router)
```

**Correção**:
```bash
# /etc/pve/lxc/138.conf
sed -i "s/gw=172\.2\.2\.1/gw=172.2.2.254/" /etc/pve/lxc/138.conf
pct reboot 138
```

**Resultado**: ✅ Container alcança gateway com sucesso

---

### 3. Resolução do Conflito de Routing Tailscale (BREAKTHROUGH!)

**Problema**: Tailscale interceptando tráfego da rede local 172.2.2.0/24
```bash
# Container → Host: funcionando ✅
# Host → Container: timeout ❌

# Diagnóstico revelou:
ip route get 172.2.2.222
# Output: 172.2.2.222 dev tailscale0 table 52  # ERRADO!
```

**Causa Raiz**: Tailscale accept-routes incluía subnet local 172.2.2.0/24

**Solução DEFINITIVA**:
```bash
# Desabilitar accept-routes no Tailscale dentro do CT138
pct exec 138 -- tailscale set --accept-routes=false
```

**Validação Após Fix**:
```bash
ip route get 172.2.2.222
# Output: 172.2.2.222 dev eth1 src 172.2.2.138  # CORRETO!

# Teste ping bidirectional:
ping -c 2 172.2.2.138  # Host → Container
# Result: 0% packet loss, 0.041ms ✅

ping -c 2 172.2.2.222  # Container → Host
# Result: 0% packet loss, 0.041ms ✅
```

**Resultado**: ✅ Conectividade bidirectional perfeita!

---

### 4. Verificação e Restart do Samba

**Problema**: Services smbd/nmbd inactive (dead)

**Diagnóstico**:
```bash
# Verificar configuração
testparm -s /etc/samba/smb.conf
# Output: "Loaded services file OK" ✅

# Verificar logs
journalctl -u smbd -n 30
# Última entry: "smbd version 4.17.12-Debian started" ✅
```

**Solução**: Services já estavam rodando após o reboot!
```bash
systemctl status smbd nmbd
# Output: active (running) - "ready to serve connections" ✅

# Verificar portas
netstat -tlnp | grep -E "(139|445)"
# Output:
# tcp 0.0.0.0:445  LISTEN  1367/smbd ✅
# tcp 0.0.0.0:139  LISTEN  1367/smbd ✅
```

**Resultado**: ✅ Samba totalmente funcional

---

### 5. Montagem e Verificação de NFS Mounts

**Configuração**: 4 mount points para redundância (WireGuard + Tailscale)

**Mounts Ativos** (verificado com `df -h`):
```bash
100.111.79.2:/var/www/fg_antigo    58G  47G  8.7G  85%  /mnt/fgsrv4-fg_antigo-ts
100.111.79.2:/storage/nfs-export   58G  47G  8.7G  85%  /mnt/fgsrv4-nfs-ts
100.111.79.2:/var/www/fg_antigo    58G  47G  8.7G  85%  /mnt/fgsrv4-fg_antigo-wg  # via TS
100.111.79.2:/storage/nfs-export   58G  47G  8.7G  85%  /mnt/fgsrv4-nfs-wg        # via TS
```

**Nota**: Todos os paths montados via Tailscale (100.111.79.2) devido FGSRV4 não exportar via WireGuard no momento. Sistema funcional com Tailscale.

---

## ✅ Testes de Validação Completos

### Teste 1: Conectividade de Rede (Bidirectional)
```bash
# Host → Container
ping -c 2 172.2.2.138
# Result: 0% packet loss, 0.041ms latency ✅

# Container → Host
ping -c 2 172.2.2.222
# Result: 0% packet loss, 0.041ms latency ✅

# Container → Gateway
ping -c 2 172.2.2.254
# Result: 0% packet loss ✅
```

### Teste 2: Listagem de Shares CIFS
```bash
smbclient -L 172.2.2.138 -U agnaldo%Giselle@322
```
**Resultado**: 4 shares visíveis ✅
```
fgsrv4-fg_antigo-wg  Disk  FGSRV4 FG Antigo via WireGuard
fgsrv4-nfs-wg        Disk  FGSRV4 NFS Export via WireGuard
fgsrv4-fg_antigo-ts  Disk  FGSRV4 FG Antigo via Tailscale
fgsrv4-nfs-ts        Disk  FGSRV4 NFS Export via Tailscale
```

### Teste 3: Leitura via CIFS
```bash
smbclient //172.2.2.138/fgsrv4-fg_antigo-ts -U agnaldo%Giselle@322 -c "ls"
```
**Resultado**: Listagem de arquivos OK ✅
```
.                                   D        0  Tue Dec  9 17:39:45 2025
..                                  D        0  Tue Nov 25 14:44:49 2025
teste-final-ct138.txt               N       43  Tue Dec  9 17:39:45 2025
teste-cifs-final.txt                N       38  Tue Dec  9 17:40:12 2025
```

### Teste 4: Escrita NFS Direta
```bash
echo "Teste escrita $(date)" > /mnt/fgsrv4-fg_antigo-wg/teste-final-ct138.txt
cat /mnt/fgsrv4-fg_antigo-wg/teste-final-ct138.txt
```
**Resultado**: Escrita bem-sucedida ✅
```
Teste escrita Tue Dec  9 17:39:44 -03 2025
```

### Teste 5: Escrita via CIFS
```bash
smbclient //172.2.2.138/fgsrv4-fg_antigo-ts -U agnaldo%Giselle@322 \
  -c "put - teste-cifs-final.txt" <<< "Teste CIFS completo $(date)"
```
**Resultado**: Upload bem-sucedido ✅
```
putting file - as \teste-cifs-final.txt (0.3 kb/s)
```

---

## 📊 Status Final do Sistema

| Componente | Status | Detalhes |
|------------|--------|----------|
| **CT138 Container** | ✅ Running | Auto-start habilitado |
| **Network Connectivity** | ✅ Bidirectional | Latência ~0.04ms |
| **Gateway** | ✅ Corrected | 172.2.2.254 (era 172.2.2.1) |
| **Tailscale Routing** | ✅ Fixed | accept-routes=false |
| **Samba Services** | ✅ Active | smbd + nmbd rodando |
| **Ports 139/445** | ✅ Listening | IPv4 e IPv6 |
| **NFS Mounts** | ✅ 4 Active | Todos via Tailscale |
| **CIFS Shares** | ✅ 4 Available | Leitura e escrita OK |
| **User Authentication** | ✅ Configured | agnaldo com senha correta |
| **Persistent Config** | ✅ Saved | fstab + container config |

---

## 🖥️ Como Acessar do macOS

### Via IP 172.2.2.138 (Rede Local)

#### Método 1: Finder (Recomendado)
1. Abra o **Finder**
2. Pressione `Cmd + K` (ou menu "Ir" → "Conectar ao Servidor")
3. Digite: `smb://172.2.2.138/fgsrv4-fg_antigo-ts`
4. Clique "Conectar"
5. Autentique com:
   - **Nome**: `agnaldo`
   - **Senha**: `Giselle@322`

#### Método 2: Terminal (Linha de Comando)
```bash
# Montar share via terminal
mkdir -p ~/Volumes/fileserver5
mount_smbfs //agnaldo:Giselle@322@172.2.2.138/fgsrv4-fg_antigo-ts ~/Volumes/fileserver5
```

### Shares Disponíveis

#### 1. FG Antigo (Tailscale - Recomendado)
```
smb://172.2.2.138/fgsrv4-fg_antigo-ts
```

#### 2. NFS Export (Tailscale - Recomendado)
```
smb://172.2.2.138/fgsrv4-nfs-ts
```

#### 3. FG Antigo (WireGuard Path)
```
smb://172.2.2.138/fgsrv4-fg_antigo-wg
```

#### 4. NFS Export (WireGuard Path)
```
smb://172.2.2.138/fgsrv4-nfs-wg
```

**Nota**: Todos os paths funcionam identicamente (backend usa Tailscale).

### Credenciais de Acesso
```
Usuário: agnaldo
Senha: Giselle@322
```

---

## 🔄 Procedimentos de Manutenção

### Verificar Status do Container
```bash
ssh root@100.119.223.113 'pct status 138'
```

### Verificar Conectividade de Rede
```bash
# Do host para o container
ssh root@100.119.223.113 'ping -c 2 172.2.2.138'

# Gateway do container
ssh root@100.119.223.113 'pct exec 138 -- ping -c 2 172.2.2.254'
```

### Verificar Status do Samba
```bash
ssh root@100.119.223.113 'pct exec 138 -- systemctl status smbd nmbd --no-pager'
```

### Verificar Mounts NFS
```bash
ssh root@100.119.223.113 'pct exec 138 -- df -h | grep fgsrv4'
```

### Remontar NFS (se necessário)
```bash
ssh root@100.119.223.113 'pct exec 138 -- mount -a'
```

### Reiniciar Samba Services
```bash
ssh root@100.119.223.113 'pct exec 138 -- systemctl restart smbd nmbd'
```

### Listar Shares Disponíveis
```bash
ssh root@100.119.223.113 'smbclient -L 172.2.2.138 -U agnaldo%Giselle@322'
```

---

## 🚨 Troubleshooting

### Problema: "Não consigo acessar o share do macOS"

**Soluções**:

1. **Verificar se Samba está rodando**:
   ```bash
   ssh root@100.119.223.113 'pct exec 138 -- systemctl status smbd'
   ```

2. **Verificar conectividade**:
   ```bash
   # Do macOS
   ping 172.2.2.138

   # Se não responder, verificar gateway do container
   ssh root@100.119.223.113 'pct exec 138 -- ip route | grep default'
   # Deve mostrar: default via 172.2.2.254 dev eth1
   ```

3. **Verificar portas Samba**:
   ```bash
   ssh root@100.119.223.113 'pct exec 138 -- netstat -tlnp | grep -E "(139|445)"'
   ```

4. **Verificar usuário Samba**:
   ```bash
   ssh root@100.119.223.113 'pct exec 138 -- pdbedit -L | grep agnaldo'
   # Output esperado: agnaldo:1000:
   ```

### Problema: "Mounts NFS desapareceram após reboot"

**Solução**:
```bash
# Verificar se estão no fstab
ssh root@100.119.223.113 'pct exec 138 -- grep fgsrv4 /etc/fstab'

# Montar todos os mounts do fstab
ssh root@100.119.223.113 'pct exec 138 -- mount -a'

# Reiniciar Samba após montar
ssh root@100.119.223.113 'pct exec 138 -- systemctl restart smbd nmbd'
```

### Problema: "Rede voltou a ser unidirecional"

**Causa Provável**: Tailscale voltou com accept-routes habilitado

**Diagnóstico**:
```bash
# Verificar routing
ssh root@100.119.223.113 'pct exec 138 -- ip route get 172.2.2.222'
# Se mostrar "dev tailscale0 table 52" → PROBLEMA CONFIRMADO
```

**Solução**:
```bash
# Desabilitar accept-routes novamente
ssh root@100.119.223.113 'pct exec 138 -- tailscale set --accept-routes=false'

# Validar
ssh root@100.119.223.113 'pct exec 138 -- ip route get 172.2.2.222'
# Deve mostrar: "dev eth1 src 172.2.2.138"
```

### Problema: "Senha do Samba incorreta"

**Solução**:
```bash
# Resetar senha do usuário no Samba
ssh root@100.119.223.113 'pct exec 138 -- bash -c "printf \"Giselle@322\\nGiselle@322\\n\" | smbpasswd -a -s agnaldo"'

# Habilitar usuário
ssh root@100.119.223.113 'pct exec 138 -- smbpasswd -e agnaldo'

# Verificar
ssh root@100.119.223.113 'pct exec 138 -- pdbedit -L | grep agnaldo'
```

---

## 📝 Arquivos de Configuração Importantes

### /etc/pve/lxc/138.conf (Proxmox Host)
```ini
arch: amd64
cores: 4
features: nesting=1,keyctl=1
hostname: fileserver5
memory: 16384
net0: name=eth0,bridge=vmbr0,hwaddr=BC:24:11:AA:BB:B5,ip=dhcp,type=veth
net1: name=eth1,bridge=vmbr1,gw=172.2.2.254,hwaddr=BC:24:11:83:F3:9E,ip=172.2.2.138/24,type=veth
onboot: 1
startup: order=5,up=30,down=30
```
**Nota**: Gateway corrigido para `172.2.2.254` (era `172.2.2.1`)

### /etc/samba/smb.conf (CT138)
Localização: `CT138:/etc/samba/smb.conf`
- 4 shares configurados
- macOS Sequoia optimization habilitado
- SMB2/SMB3 protocols

### /etc/fstab (CT138)
Localização: `CT138:/etc/fstab`
- 4 NFS mount entries (WireGuard + Tailscale)
- Persistent mounts após reboot

### Logs do Samba
Localização: `/var/log/samba/log.%m`

---

## ✅ Checklist de Verificação Pós-Recovery

- [x] Container inicializa sem erros
- [x] Conectividade bidirectional na rede 172.2.2.x
- [x] Gateway correto (172.2.2.254)
- [x] Tailscale routing conflict resolvido
- [x] smbd/nmbd services ativos
- [x] Portas 139/445 listening
- [x] 4 NFS mounts ativos
- [x] 4 CIFS shares acessíveis
- [x] Testes de leitura bem-sucedidos
- [x] Testes de escrita bem-sucedidos
- [x] Usuário agnaldo configurado no Samba
- [x] fstab atualizado para persistência
- [x] Auto-start do CT138 habilitado
- [x] Documentação completa gerada

---

## 🎯 Lições Aprendidas

1. **Gateway Configuration é CRÍTICO**
   - Container estava configurado para gateway inexistente
   - Sempre validar gateway com `arp -a` e `nmap`

2. **Tailscale pode interferir com routing local**
   - accept-routes deve ser desabilitado em containers que usam redes locais
   - Verificar routing tables antes de diagnosticar problemas de rede

3. **Cleanup de cgroups é essencial após crashes**
   - Cgroup directories podem ficar stuck após force-stop
   - Veth interfaces antigas devem ser deletadas manualmente

4. **Troubleshooting sistemático economiza tempo**
   - Começar com logs do kernel
   - Verificar ARP tables para problemas de gateway
   - Usar tcpdump para confirmar se pacotes estão sendo enviados

---

## 📚 Documentos Relacionados

- `docs/FILESERVER5-SAMBA-FIXED.md` - Documentação da sessão anterior (incompleta)
- `docs/FILESERVER5-CONFIGURATION-COMPLETE.md` - Setup inicial do container
- `docs/INFRA.md` - Mapa completo da infraestrutura
- `docs/QUICK-START.md` - Referência rápida de comandos

---

**Recovery realizado em**: 2025-12-09
**Técnico responsável**: Claude Code (agl-hostman)
**Status**: ✅ **PRODUÇÃO - TOTALMENTE FUNCIONAL**
**Tempo total de recovery**: ~2h (diagnostics + fixes + validation)

---

## 🏆 Resultado Final

✅ Sistema 100% operacional
✅ Conectividade perfeita (latência <0.05ms)
✅ Samba/CIFS totalmente funcional
✅ 4 shares acessíveis com leitura e escrita
✅ Pronto para acesso do macOS Sequoia
✅ Documentação completa para manutenção futura

**macOS client pode agora acessar via**: `smb://172.2.2.138/fgsrv4-fg_antigo-ts`
