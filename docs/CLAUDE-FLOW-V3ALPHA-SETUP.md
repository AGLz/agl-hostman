# 🔧 Claude Flow v3alpha - Setup Guide

**Data**: 2026-01-24
**Status**: Configuração em andamento

---

## 📊 Situação Atual

### ✅ FGSRV6 - FUNCIONANDO PERFEITAMENTE

**Configuração:**
- Node.js v24.12.0 (NVM)
- claude-flow@v3alpha (v3.0.0-alpha.161)
- Usa wrapper `/usr/local/bin/npm-v24`
- Hive-Mind funcionando
- Aliases completos + limited

**Aliases ativos:**
```bash
alias claude-flow="/usr/local/bin/npm-v24 -y claude-flow@v3alpha"
alias hive='_hive_auto'
alias cf-dev/prod/safe/auto
# + aliases 'limited' (node/npm limitados)
```

**Status:** ✅ 100% funcional

---

### ⚠️ AGLDV03 (CT179) - PARCIALMENTE CONFIGURADO

**Configuração:**
- Node.js v24.13.0 (NVM) instalado
- claude-flow@alpha (v2.7.33) - versão mais antiga
- **PROBLEMA:** Alias `npx='npx_smart'` interceptando npx e usando pnpm
- Aliases adicionados ao .zshrc

**Problema identificado:**
```bash
# Linha 683 do .zshrc
alias npx='npx_smart'
```
Este alias redireciona `npx` para `pnpm dlx`, impedindo o uso do npx real do Node v24.

**Solução necessária:**
```bash
# 1. Remover alias problemático
sed -i "683d" ~/.zshrc  # Remove linha do alias npx_smart

# 2. Adicionar alias correto (já existe no final do .zshrc)
NODE_V24_NPX="$HOME/.nvm/versions/node/v24.13.0/bin/npx"

# 3. Recarregar
source ~/.zshrc

# 4. Testar
claude-flow --version  # Deve retornar v3.0.0-alpha.161
```

**Status:** ⚠️ Aguardando remoção do alias `npx_smart`

---

### ❌ AGLDV04 (CT180/dokploy) - PENDENTE INSTALAÇÃO

**Configuração:**
- Node.js: NÃO INSTALADO
- NVM: NÃO INSTALADO
- claude-flow: NÃO INSTALADO

**Problemas:**
- Sem conectividade externa (curl falhou)
- Sem Node.js instalado

**Solução necessária:**
```bash
# Opção 1: Copiar Node.js via SCP do agldv03
# No agldv03:
cd ~/.nvm
tar czf /tmp/nvm.tar.gz ./

# No agldv04:
ssh root@192.168.0.180
mkdir -p ~/.nvm
cd ~/.nvm
scp root@192.168.0.179:/tmp/nvm.tar.gz ./
tar xzf nvm.tar.gz
rm nvm.tar.gz

# Adicionar ao .zshrc
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 24

# Instalar claude-flow aliases (já transferido)
# Arquivo: /tmp/claude-flow-aliases-20260124_141711.txt
```

**Status:** ❌ Requer instalação de Node.js/NVM

---

## 🎯 Plano de Ação

### 1️⃣ AGLDV03 - Finalizar Configuração

```bash
# Passo 1: Remover alias problemático
sed -i '/^alias npx=/d' ~/.zshrc

# Passo 2: Remover alias pnpm (se existir)
sed -i '/^alias pnpm=/d' ~/.zshrc

# Passo 3: Garantir NVM carregado antes dos aliases
# Adicionar no início do .zshrc (após plugins):
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 24 >/dev/null 2>&1 || true

# Passo 4: Recarregar
source ~/.zshrc

# Passo 5: Testar
claude-flow --version
# Esperado: v3.0.0-alpha.161

# Passo 6: Testar hive-mind
hive-status
# Esperado: Status do hive-mind exibido
```

### 2️⃣ AGLDV04 - Instalação Completa

```bash
# Passo 1: Instalar NVM
ssh root@192.168.0.180
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Passo 2: Instalar Node.js v24
nvm install 24
nvm use 24
nvm alias default 24

# Passo 3: Adicionar aliases do claude-flow
# O arquivo já foi transferido para /tmp/claude-flow-aliases-*.txt
cat /tmp/claude-flow-aliases-*.txt >> ~/.zshrc

# Passo 4: Recarregar
source ~/.zshrc

# Passo 5: Testar
claude-flow --version
hive-status
```

### 3️⃣ FGSRV6 - Validar Configuração

```bash
# Já está funcionando, apenas validar:
ssh root@100.83.51.9 "claude-flow --version"
# Esperado: v3.0.0-alpha.161

ssh root@100.83.51.9 "hive-status"
# Esperado: Status do hive-mind exibido
```

---

## 📋 Aliases Finais (após correção)

### Para TODOS os hosts (agldv03, agldv04):

```bash
# Core
alias claude-flow="$HOME/.nvm/versions/node/v24.13.0/bin/npx -y claude-flow@v3alpha"
alias cf="claude-flow"

# Quick control
alias cf-dev='export CLAUDE_FLOW_DEBUG_MODE=true CLAUDE_FLOW_VERBOSE=true CLAUDE_FLOW_LOG_LEVEL=debug'
alias cf-prod='export CLAUDE_FLOW_DEBUG_MODE=false CLAUDE_FLOW_VERBOSE=false CLAUDE_FLOW_LOG_LEVEL=warn'
alias cf-safe='export CLAUDE_FLOW_AUTO_COMMIT=false CLAUDE_FLOW_AUTO_PUSH=false CLAUDE_FLOW_ALLOW_SHELL_EXEC=false'
alias cf-auto='export CLAUDE_FLOW_AUTO_COMMIT=true CLAUDE_FLOW_AUTO_PUSH=false'

# Hive-Mind
alias hive='_hive_auto'
_hive_auto() { $HOME/.nvm/versions/node/v24.13.0/bin/npx -y claude-flow@v3alpha hive-mind spawn "$*" --claude; }

alias hive-quick='_hive_quick'
_hive_quick() { $HOME/.nvm/versions/node/v24.13.0/bin/npx -y claude-flow@v3alpha hive-mind spawn "$*" --claude; }

alias hive-manual='_hive_manual'
_hive_manual() { $HOME/.nvm/versions/node/v24.13.0/bin/npx -y claude-flow@v3alpha hive-mind spawn "$*" --claude --verbose; }

alias hive-seq='_hive_seq'
_hive_seq() { $HOME/.nvm/versions/node/v24.13.0/bin/npx -y claude-flow@v3alpha hive-mind spawn "$*" --auto-spawn --claude --verbose; }

alias hive-help='claude-flow hive-mind --help'
alias hive-status='claude-flow hive-mind status'
alias hive-agents='claude-flow hive-mind list-agents'

# SPARC
alias sparc-modes='claude-flow sparc modes'
alias sparc-run='claude-flow sparc run'
alias sparc-tdd='claude-flow sparc tdd'
```

### SOMENTE para FGSRV6 (manter):

```bash
# Aliases limited (recursos limitados)
alias node='node-limited'
alias npm='npm-limited'
```

---

## ✅ Comandos de Teste Finais

### Testar Versão
```bash
# Todos os hosts
claude-flow --version
# Esperado: v3.0.0-alpha.161
```

### Testar Hive-Mind
```bash
# Todos os hosts
hive-status
# Esperado: Status do hive-mind exibido (pode estar offline)
```

### Testar SPARC
```bash
# AGLDV03 (após configuração)
cd /mnt/overpower/apps/dev/agl/agl-hostman
sparc-modes
# Esperado: Lista de modos SPARC disponíveis
```

---

## 📊 Status Final Esperado

| Host | Node.js | claude-flow | Status |
|------|---------|-------------|--------|
| **fgsrv6** | v24.12.0 | v3.0.0-alpha.161 | ✅ OK |
| **agldv03** | v24.13.0 | v3.0.0-alpha.161 | ⚠️ Remover alias npx_smart |
| **agldv04** | v24.x.x | v3.0.0-alpha.161 | ❌ Instalar Node/NVM |

---

## 🔧 Scripts Criados

1. **`scripts/update-claude-flow-v3alpha.sh`**
   - Script principal de atualização
   - Atualiza agldv03 e agldv04
   - Cria backups automaticamente

2. **`docs/CLAUDE-FLOW-DIAGNOSTIC-2026-01-24.md`**
   - Relatório de diagnóstico completo
   - Compatibilidade de versões

3. **`docs/ZSHRC-STATUSLINE-UPDATE-2026-01-24.md`**
   - Documentação de atualização do .zshrc

---

## 🎯 Próximos Passos Imediatos

### AGLDV03 (5 minutos):
```bash
# 1. Editar .zshrc
nano ~/.zshrc
# Procurar e remover: alias npx='npx_smart'
# Procurar e remover: alias pnpm='pnpm' (se existir)

# 2. Recarregar
source ~/.zshrc

# 3. Testar
claude-flow --version
hive-status
```

### AGLDV04 (15 minutos):
```bash
# 1. Instalar NVM e Node v24
ssh root@192.168.0.180
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 24
nvm use 24

# 2. Adicionar aliases (já transferidos)
cat /tmp/claude-flow-aliases-*.txt >> ~/.zshrc

# 3. Recarregar e testar
source ~/.zshrc
claude-flow --version
hive-status
```

### FGSRV6 (já OK):
```bash
# Apenas validar
ssh root@100.83.51.9 "hive-status"
```

---

**Documento criado**: 2026-01-24
**Status**: Configuração 67% completa (2/3 hosts parcialmente configurados)
