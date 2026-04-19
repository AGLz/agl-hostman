# FileServer5 (CT138) - Guia de Acesso macOS Sequoia

> **Data**: 2025-12-09
> **Container**: CT138 (fileserver5) no AGLSRV5
> **macOS Version**: Sequoia (15.x)
> **Status**: ✅ Configuração Completa - Aguardando Teste do Usuário

---

## 📋 Informações da Configuração

### Endereços IP do FileServer5 (CT138)

| Interface | Rede | IP | Gateway | Uso |
|-----------|------|-----|---------|-----|
| **eth0** | 192.168.15.x | `192.168.15.100` | 192.168.15.1 | Rede principal |
| **eth1** | 172.2.2.x | `172.2.2.138` | 172.2.2.1 | Rede secundária |
| **Tailscale** | 100.x.x.x | `100.66.136.84` | - | VPN (backup) |

### Credenciais de Acesso

```
Usuário: agnaldo
Senha: Giselle@322
```

### Shares Disponíveis

1. **fgsrv4-fg_antigo-wg** - FG Antigo via WireGuard (58GB, 85% usado)
2. **fgsrv4-nfs-wg** - NFS Export via WireGuard (58GB, 85% usado)
3. **fgsrv4-fg_antigo-ts** - FG Antigo via Tailscale (backup)
4. **fgsrv4-nfs-ts** - NFS Export via Tailscale (backup)

---

## 🍎 Conectar do macOS Sequoia

### Método 1: Via Finder (Recomendado)

#### Opção A: Rede 172.2.2.x (Se o Mac está nesta rede)

1. Abra o **Finder**
2. Pressione `⌘K` (Command + K) ou vá em **Ir → Conectar ao Servidor**
3. Digite uma das seguintes URLs:

```
smb://172.2.2.138/fgsrv4-fg_antigo-wg
```

Ou para o share NFS:
```
smb://172.2.2.138/fgsrv4-nfs-wg
```

#### Opção B: Rede 192.168.15.x (Alternativa)

```
smb://192.168.15.100/fgsrv4-fg_antigo-wg
```

#### Opção C: Via Tailscale (Backup Global)

```
smb://100.66.136.84/fgsrv4-fg_antigo-wg
```

4. Clique em **Conectar**
5. Selecione **Usuário Registrado**
6. Entre com:
   - **Nome**: `agnaldo`
   - **Senha**: `Giselle@322`
7. ✅ O share será montado em `/Volumes/fgsrv4-fg_antigo-wg`

### Método 2: Via Terminal

```bash
# Listar shares disponíveis
smbutil view //agnaldo@172.2.2.138

# Conectar via linha de comando
open smb://agnaldo:Giselle%40322@172.2.2.138/fgsrv4-fg_antigo-wg

# Ou montar manualmente
mkdir -p ~/mnt/fgsrv4
mount_smbfs //agnaldo:Giselle%40322@172.2.2.138/fgsrv4-fg_antigo-wg ~/mnt/fgsrv4
```

**Nota**: `%40` = `@` (URL encoded)

---

## 🔍 Diagnóstico Passo a Passo

### Passo 1: Verificar Conectividade de Rede

```bash
# Testar se o CT138 está acessível
ping -c 3 172.2.2.138

# Resultado esperado:
# 64 bytes from 172.2.2.138: icmp_seq=0 ttl=64 time=0.5 ms
```

**Se falhar**:
- ✗ Verifique se o Mac está realmente na rede 172.2.2.x
- ✗ Execute `ifconfig | grep inet` para ver seus IPs
- ✗ Tente o IP alternativo: `ping 192.168.15.100`

### Passo 2: Verificar Porta SMB (445)

```bash
# Testar se a porta SMB está aberta
nc -zv 172.2.2.138 445

# Resultado esperado:
# Connection to 172.2.2.138 port 445 [tcp/microsoft-ds] succeeded!
```

**Se falhar**:
- ✗ Porta 445 pode estar bloqueada por firewall
- ✗ Tente a porta 139: `nc -zv 172.2.2.138 139`
- ✗ Verifique firewall do macOS: **Preferências do Sistema → Segurança e Privacidade → Firewall**

### Passo 3: Listar Shares Disponíveis

```bash
# Ver shares do servidor
smbutil view //172.2.2.138

# Resultado esperado:
# Share name       Type     Comments
# ----------------------------------------
# fgsrv4-fg_antigo-wg  Disk     FGSRV4 FG Antigo via WireGuard
# fgsrv4-nfs-wg        Disk     FGSRV4 NFS Export via WireGuard
# fgsrv4-fg_antigo-ts  Disk     FGSRV4 FG Antigo via Tailscale
# fgsrv4-nfs-ts        Disk     FGSRV4 NFS Export via Tailscale
```

**Se falhar**:
- ✗ Erro de autenticação → Verifique usuário/senha
- ✗ "Connection refused" → Samba não está rodando
- ✗ Timeout → Problema de rede ou firewall

### Passo 4: Testar Montagem

```bash
# Criar diretório de montagem
mkdir -p ~/mnt/test-fgsrv4

# Tentar montar
mount_smbfs //agnaldo:Giselle%40322@172.2.2.138/fgsrv4-fg_antigo-wg ~/mnt/test-fgsrv4

# Verificar se montou
df -h | grep fgsrv4

# Listar conteúdo
ls -la ~/mnt/test-fgsrv4

# Teste de escrita
echo "teste $(date)" > ~/mnt/test-fgsrv4/teste-macos-$(date +%Y%m%d-%H%M%S).txt

# Desmontar
umount ~/mnt/test-fgsrv4
```

---

## 🚨 Problemas Comuns e Soluções

### Problema 1: "You do not have permission to access this server"

**Causa**: Credenciais incorretas ou não configuradas no Keychain

**Solução**:
```bash
# Remover credenciais antigas do Keychain
security delete-generic-password -s "smb://172.2.2.138"

# Tentar novamente com credenciais explícitas
open smb://agnaldo:Giselle%40322@172.2.2.138/fgsrv4-fg_antigo-wg
```

Ou manualmente:
1. Abra **Acesso às Chaves** (Keychain Access)
2. Busque por "172.2.2.138" ou "fileserver5"
3. Delete entradas antigas
4. Tente conectar novamente

### Problema 2: "The version of the server you are trying to connect to is not supported"

**Causa**: Versão SMB incompatível (macOS Sequoia requer SMB2+)

**Solução**: Já configurado no servidor! O smb.conf tem:
```ini
server min protocol = SMB2
server max protocol = SMB3
```

Se ainda ocorrer, force SMB3 no Mac:
```bash
# Editar configuração SMB do macOS
sudo nano /etc/nsmb.conf

# Adicionar:
[default]
protocol_vers_map=6
```

Depois reinicie:
```bash
sudo killall nsmbd
```

### Problema 3: "Connection failed" ou timeout

**Causas Possíveis**:
1. Mac não está na rede 172.2.2.x
2. Firewall bloqueando
3. Roteamento incorreto

**Diagnóstico**:
```bash
# 1. Verificar sua rede
ifconfig | grep "inet " | grep -v 127.0.0.1

# 2. Verificar rota para 172.2.2.138
netstat -rn | grep 172.2.2

# 3. Testar IPs alternativos
ping 192.168.15.100  # Rede principal
ping 100.66.136.84   # Tailscale (sempre funciona)
```

**Solução**: Use o IP que responder ao ping:
- Se `172.2.2.138` funciona → Use este (melhor performance local)
- Se apenas `192.168.15.100` funciona → Use este
- Se apenas `100.66.136.84` funciona → Use Tailscale (mais lento mas funciona globalmente)

### Problema 4: Conecta mas não consegue escrever

**Causa**: Permissões de arquivo no servidor

**Diagnóstico no CT138**:
```bash
ssh root@172.2.2.138

# Verificar permissões dos mount points
ls -la /mnt/fgsrv4-fg_antigo-wg
ls -la /mnt/fgsrv4-nfs-wg

# Verificar se NFS está montado
df -h | grep fgsrv4

# Testar escrita local
echo "teste" > /mnt/fgsrv4-fg_antigo-wg/teste-$(date +%s).txt
```

**Solução**:
```bash
# Se NFS não estiver montado
mount -a

# Reiniciar Samba
systemctl restart smbd nmbd
```

### Problema 5: "Operation not supported" ao copiar arquivos

**Causa**: Extended attributes ou resource forks do macOS

**Solução**: Já configurado no servidor! O smb.conf tem:
```ini
vfs objects = fruit streams_xattr catia
fruit:metadata = stream
fruit:zero_file_id = yes
```

Se persistir, desabilite resource forks no Mac:
```bash
# Copiar sem metadata extra
cp -X arquivo.txt /Volumes/fgsrv4-fg_antigo-wg/

# Ou use rsync sem atributos estendidos
rsync -av --no-perms --no-owner --no-group arquivo.txt /Volumes/fgsrv4-fg_antigo-wg/
```

### Problema 6: Ícones ".DS_Store" ou "._*" aparecem

**Causa**: Arquivos de metadata do macOS

**Solução**: Já configurado no servidor para limpar automaticamente:
```ini
fruit:veto_appledouble = no
fruit:delete_empty_adfiles = yes
```

Para prevenir criação:
```bash
# Desabilitar .DS_Store em volumes de rede (permanente)
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE

# Aplicar imediatamente
killall Finder
```

---

## 📊 Verificação de Performance

### Teste de Velocidade de Escrita

```bash
# Criar arquivo de 100MB
dd if=/dev/zero of=~/mnt/test-fgsrv4/testfile bs=1m count=100

# Resultado esperado:
# ~30-50 MB/s em rede local 172.2.2.x
# ~20-40 MB/s em rede 192.168.15.x
# ~5-15 MB/s via Tailscale (depende da internet)
```

### Teste de Latência

```bash
# Medir tempo de resposta SMB
time smbutil view //agnaldo@172.2.2.138

# Resultado esperado:
# real    0m0.1s - 0m0.5s (rede local)
# real    0m0.5s - 2m0.0s (Tailscale)
```

---

## 🔧 Comandos de Manutenção (macOS)

### Ver Conexões SMB Ativas

```bash
# Lista de shares montados
mount | grep smbfs

# Ou
smbutil statshares -a
```

### Desconectar Share

```bash
# Via Finder
# Clique com botão direito no volume montado → Ejetar

# Via Terminal
umount /Volumes/fgsrv4-fg_antigo-wg
```

### Limpar Cache SMB

```bash
# Reiniciar serviço SMB do macOS
sudo killall nsmbd

# Limpar cache de DNS/Bonjour
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Ver Logs de Conexão SMB

```bash
# Abrir Console.app
open -a Console

# Filtrar por "SMB" ou "smbclient"
# Ou via terminal:
log show --predicate 'eventMessage contains "SMB"' --last 1h
```

---

## 🎯 Checklist de Validação

Execute este checklist para validar a conexão:

- [ ] **1. Rede Acessível**
  ```bash
  ping -c 3 172.2.2.138
  ```

- [ ] **2. Porta SMB Aberta**
  ```bash
  nc -zv 172.2.2.138 445
  ```

- [ ] **3. Shares Visíveis**
  ```bash
  smbutil view //172.2.2.138
  ```

- [ ] **4. Autenticação Funciona**
  ```bash
  smbutil view //agnaldo@172.2.2.138
  # Deve pedir senha e mostrar shares
  ```

- [ ] **5. Montagem Bem-Sucedida**
  ```bash
  open smb://agnaldo:Giselle%40322@172.2.2.138/fgsrv4-fg_antigo-wg
  # Deve abrir Finder com conteúdo
  ```

- [ ] **6. Leitura de Arquivos**
  ```bash
  ls /Volumes/fgsrv4-fg_antigo-wg
  ```

- [ ] **7. Escrita de Arquivos**
  ```bash
  echo "teste $(date)" > /Volumes/fgsrv4-fg_antigo-wg/teste-macos.txt
  cat /Volumes/fgsrv4-fg_antigo-wg/teste-macos.txt
  ```

- [ ] **8. Performance Aceitável**
  ```bash
  time dd if=/dev/zero of=/Volumes/fgsrv4-fg_antigo-wg/testfile bs=1m count=10
  # Deve completar em < 5 segundos (rede local)
  ```

---

## 🆘 Suporte e Logs

### Logs do Servidor (CT138)

Se algo não funcionar, peça para verificar os logs no servidor:

```bash
# SSH no CT138
ssh root@172.2.2.138

# Ver logs do Samba (substitua pelo seu IP)
tail -50 /var/log/samba/172.2.2.xxx.log

# Ver status do Samba
systemctl status smbd nmbd

# Ver mounts NFS
df -h | grep fgsrv4
mount | grep fgsrv4
```

### Informações para Reportar Problemas

Se encontrar problemas, colete estas informações:

```bash
# 1. Seu IP no Mac
ifconfig | grep "inet " | grep -v 127.0.0.1

# 2. Teste de conectividade
ping -c 3 172.2.2.138

# 3. Teste de porta
nc -zv 172.2.2.138 445

# 4. Tentativa de listagem
smbutil view //172.2.2.138 2>&1

# 5. Versão do macOS
sw_vers

# 6. Logs recentes
log show --predicate 'eventMessage contains "SMB"' --last 10m
```

---

## 📝 Configuração Atual do Servidor

Para referência, a configuração do Samba no CT138 inclui:

### Protocolos SMB
- **Mínimo**: SMB2 (compatível com macOS Sequoia)
- **Máximo**: SMB3 (performance otimizada)
- **SMB1**: Desabilitado (segurança)

### Módulos VFS para macOS
- ✅ `vfs_fruit` - Suporte completo para macOS
- ✅ `streams_xattr` - Extended attributes
- ✅ `catia` - Mapeamento de caracteres especiais

### Otimizações Específicas
```ini
fruit:metadata = stream
fruit:model = MacSamba
fruit:zero_file_id = yes
fruit:nfs_aces = no
fruit:posix_rename = yes
unix charset = UTF-8
```

### Redes Permitidas
- 127.0.0.1 (localhost)
- 192.168.0.0/16 (todas as redes 192.168.x.x)
- **172.2.2.0/24** ✅ (sua rede)
- 192.168.15.0/24 (rede principal)
- 10.6.0.0/24 (WireGuard)
- 100.0.0.0/8 (Tailscale)

---

## ✅ Status da Configuração

| Componente | Status | Detalhes |
|------------|--------|----------|
| **Samba Instalado** | ✅ OK | Versão completa com 31 pacotes |
| **Serviços Ativos** | ✅ Running | smbd + nmbd ativos |
| **Porta 445 Aberta** | ✅ OK | Listening em todas as interfaces |
| **Porta 139 Aberta** | ✅ OK | Listening em todas as interfaces |
| **MacOS Support** | ✅ Configured | vfs_fruit com todas as opções |
| **NFS Mounts** | ✅ Active | 4 mounts funcionais |
| **Usuário Samba** | ✅ Configured | agnaldo com senha |
| **Rede 172.2.2.x** | ✅ Accessible | IP 172.2.2.138 ativo |

---

## 🚀 Próximos Passos

1. **Teste do Mac**: Conecte do seu macOS Sequoia usando `smb://172.2.2.138/fgsrv4-fg_antigo-wg`

2. **Se funcionar**:
   - ✅ Marque o share como favorito no Finder
   - ✅ Configure para reconectar automaticamente no login (Preferências → Usuários → Itens de Login)

3. **Se não funcionar**:
   - Execute o **Checklist de Validação** acima
   - Colete as **Informações para Reportar Problemas**
   - Reporte o erro específico para ajuste da configuração

---

**Documento criado em**: 2025-12-09
**Última atualização**: 2025-12-09
**Testado em**: Aguardando teste do usuário
**Status**: ✅ **CONFIGURAÇÃO COMPLETA - PRONTO PARA TESTES**
