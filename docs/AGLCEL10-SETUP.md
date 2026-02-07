# 🔧 AGLCEL10 - Configuração de Acesso SSH

## 📱 Informações do Dispositivo

**Nome**: aglcel10
**Tipo**: Android Device
**IP Tailscale**: 100.80.84.69
**Status**: ✅ Online (7ms latency)
**SSH**: ❌ Não configurado

---

## 🚀 Configuração Rápida

### Método 1: Script Automatizado (Recomendado)

```bash
./scripts/setup-aglcel10-ssh.sh
```

O script irá:
1. Verificar conectividade Tailscale
2. Detectar portas SSH disponíveis
3. Configurar acesso em `~/.ssh/config`
4. Oferecer copiar o `.zshrc` automaticamente

---

## 📋 Configuração Manual

### Passo 1: Instalar Servidor SSH no Android

#### Opção A: Termux (Recomendado)

```bash
# No app Termux do Android:
pkg update && pkg upgrade
pkg install openssh

# Iniciar servidor SSH
sshd

# Definir senha
passwd

# Verificar usuário
whoami  # Anotar (ex: u0_a363)
```

#### Opção B: UserLAnd

1. Instalar app UserLAnd
2. Escolher distribuição (Ubuntu/Arch)
3. Ativar serviço SSH na interface

### Passo 2: Identificar Usuário e Porta

```bash
# No Android (Termux):
echo $USER          # Usuário SSH
whoami             # Alternativa

# Porta padrão Termux: 8022
```

### Passo 3: Testar Conexão do Host Local

```bash
# Do agl-hostman para aglcel10:
ssh -p 8022 <usuario-android>@100.80.84.69

# Exemplo:
ssh -p 8022 u0_a363@100.80.84.69
```

### Passo 4: Configurar ~/.ssh/config

```bash
# Adicionar ao ~/.ssh/config:
cat >> ~/.ssh/config <<'EOF'

# AGLCEL10 - Android Device via Tailscale
Host aglcel10
    HostName 100.80.84.69
    User u0_a363
    Port 8022
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
```

### Passo 5: Copiar .zshrc

```bash
# Usar alias configurado:
scp /root/.zshrc aglcel10:~/.zshrc

# Aplicar configurações:
ssh aglcel10 'source ~/.zshrc'
```

---

## 🔐 Configuração de Chaves SSH (Opcional)

### No Host Local (agl-hostman)

```bash
# Gerar chave se não existir
ssh-keygen -t ed25519 -f ~/.ssh/aglcel10 -N ""

# Copiar chave pública para Android
ssh-copy-id -i ~/.ssh/aglcel10.pub -p 8022 u0_a363@100.80.84.69
```

### No Android (Termux)

```bash
# Criar diretório .ssh
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Adicionar chave pública manualmente se necessário
echo "CONTEÚDO_DA_CHAVE_PÚBLICA" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## 📦 Copiando Arquivos para aglcel10

### Método 1: scp (simples)

```bash
# Copiar .zshrc
scp /root/.zshrc aglcel10:~/.zshrc

# Copiar múltiplos arquivos
scp /root/.zshrc /root/.vimrc aglcel10:~/

# Copiar diretório
scp -r /root/.config aglcel10:~/
```

### Método 2: rsync (sincronização)

```bash
# Sincronizar dotfiles
rsync -avz --progress /root/.zshrc aglcel10:~/

# Sincronizar diretório completo
rsync -avz --progress /root/.config/ aglcel10:~/.config/
```

### Método 3: tar + ssh (preservar permissões)

```bash
# Empacotar e enviar
tar czf - /root/.zshrc | ssh aglcel10 'tar xzf - -C ~/'
```

---

## 🐛 Troubleshooting

### Problema: "Connection refused"

**Causa**: Servidor SSH não está rodando no Android

**Solução**:
```bash
# No Android (Termux):
sshd                     # Iniciar servidor
ps aux | grep sshd       # Verificar se está rodando
netstat -tuln | grep 8022  # Verificar porta
```

### Problema: "Permission denied"

**Causa**: Senha incorreta ou autenticação falhando

**Solução**:
```bash
# No Android (Termux):
passwd                   # Redefinir senha

# Testar com verbose:
ssh -vvv aglcel10
```

### Problema: "Host key verification failed"

**Solução**:
```bash
# Adicionar ao ~/.ssh/config:
StrictHostKeyChecking no
UserKnownHostsFile /dev/null
```

### Problema: Termux não inicia sshd

**Solução**:
```bash
# No Android (Termux):
pkg install termux-exec
termux-setup-storage
pkill sshd
sshd
```

---

## ✅ Verificação de Configuração

### Teste Completo

```bash
# 1. Verificar conectividade Tailscale
tailscale ping 100.80.84.69

# 2. Verificar porta SSH
nmap -p 8022 100.80.84.69

# 3. Testar conexão SSH
timeout 5 ssh aglcel10 'echo "SSH OK"'

# 4. Verificar .zshrc copiado
ssh aglcel10 'ls -la ~/.zshrc'

# 5. Testar shell configurado
ssh aglcel10 'zsh --version'
```

---

## 📚 Referências

- **Termux Wiki**: https://wiki.termux.com/wiki/Main_Page
- **Termux SSH**: https://wiki.termux.com/wiki/SSH
- **UserLAnd**: https://github.com/CypherpunkBraintrust/UserLAnd
- **Tailscale**: https://tailscale.com/

---

## 🎯 Checklist de Configuração

- [ ] Termux instalado no Android
- [ ] Pacote openssh instalado
- [ ] Servidor sshd rodando
- [ ] Senha configurada com `passwd`
- [ ] Usuário identificado (`whoami`)
- [ ] Conexão SSH testada do host local
- [ ] ~/.ssh/config configurado
- [ ] Chaves SSH configuradas (opcional)
- [ ] .zshrc copiado para aglcel10
- [ ] Configurações testadas (`source ~/.zshrc`)

---

**Última atualização**: 2025-01-14
**Status**: 🟡 Aguardando configuração SSH no Android
