# PowerShell Profile - Windows 11 Setup

Configuração completa do PowerShell para Windows 11 baseada no `.zshrc` do agldv03 (CT179), incluindo suporte a Claude Flow, múltiplos modelos de IA e otimizações de desenvolvimento.

## 📋 Índice

- [Características](#características)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Uso](#uso)
- [Comandos Disponíveis](#comandos-disponíveis)
- [Troubleshooting](#troubleshooting)

## ✨ Características

### Claude Flow
- ✅ 100+ variáveis de ambiente configuradas
- ✅ Aliases para comandos principais
- ✅ Funções hive-mind simplificadas
- ✅ Modos de operação (dev, prod, safe)
- ✅ SPARC methodology support

### Múltiplos Modelos de IA
- ✅ Anthropic Claude (via ANTHROPIC_API_KEY)
- ✅ OpenAI GPT (via OPENAI_API_KEY)
- ✅ Google Gemini (via GOOGLE_API_KEY)

### Otimizações
- ✅ Node.js otimizado (8GB heap)
- ✅ pnpm como gerenciador padrão
- ✅ Git shortcuts
- ✅ Prompt customizado com branch Git

### Funcionalidades
- ✅ Auto-commit e auto-push configuráveis
- ✅ Parallel execution (até 16 agentes)
- ✅ Memory management persistente
- ✅ Cache e logging estruturado
- ✅ Backup automático

## 📦 Pré-requisitos

### Obrigatórios
- **Windows 11** (ou Windows 10 com PowerShell 5.1+)
- **PowerShell 5.1+** (já incluído no Windows)
- **Node.js 18+** (recomendado: v24)
  - Download: https://nodejs.org/

### Recomendados
- **pnpm** - Gerenciador de pacotes rápido
  ```powershell
  npm install -g pnpm
  ```
- **Git** - Controle de versão
  - Download: https://git-scm.com/
- **Windows Terminal** - Terminal moderno
  - Microsoft Store: https://aka.ms/terminal

### API Keys (pelo menos uma)
- **Anthropic Claude**: https://console.anthropic.com/
- **OpenAI**: https://platform.openai.com/api-keys
- **Google Gemini**: https://makersuite.google.com/app/apikey

## 🚀 Instalação

### Método 1: Instalação Automática (Recomendado)

```powershell
# Clone o repositório (se ainda não tiver)
git clone https://github.com/your-org/agl-hostman.git
cd agl-hostman

# Execute o instalador
.\config\windows\install-profile.ps1

# Com API keys (opcional)
.\config\windows\install-profile.ps1 -AnthropicKey "sk-ant-..." -OpenAIKey "sk-..." -GeminiKey "..."

# Com backup do perfil existente
.\config\windows\install-profile.ps1 -Backup

# Forçar sobrescrita
.\config\windows\install-profile.ps1 -Force
```

### Método 2: Instalação Manual

```powershell
# 1. Localizar o perfil PowerShell
echo $PROFILE
# Saída: C:\Users\YourUser\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

# 2. Criar diretório se não existir
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force
}

# 3. Copiar o perfil
Copy-Item .\config\windows\Microsoft.PowerShell_profile.ps1 $PROFILE -Force

# 4. Recarregar o perfil
. $PROFILE
```

## ⚙️ Configuração

### 1. Configurar API Keys

Edite o arquivo de perfil:

```powershell
notepad $PROFILE
```

Substitua os placeholders pelas suas chaves reais:

```powershell
# Anthropic Claude
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."

# OpenAI
$env:OPENAI_API_KEY = "sk-..."

# Google Gemini
$env:GOOGLE_API_KEY = "AIza..."
```

### 2. Configurar ExecutionPolicy (se necessário)

```powershell
# Verificar política atual
Get-ExecutionPolicy

# Se for 'Restricted', alterar para 'RemoteSigned'
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. Verificar Instalação

```powershell
# Recarregar perfil
. $PROFILE

# Verificar configuração
cf-check

# Testar Claude Flow
claude-flow --version
```

## 📖 Uso

### Claude Flow - Modos de Operação

```powershell
# Modo desenvolvimento (debug ativado)
cf-dev

# Modo produção (logs mínimos)
cf-prod

# Modo seguro (sem auto-commit/push)
cf-safe

# Auto-commit apenas (sem push)
cf-auto
```

### Hive-Mind - Orquestração de Agentes

```powershell
# Executar tarefa com hive-mind
hive "install dependencies and run tests"

# Modo rápido (menos verbose)
hive-quick "fix all linting errors"

# Modo manual (controle total)
hive-manual "complex refactoring task"

# Modo sequencial (sem paralelização)
hive-seq "step by step migration"

# Utilitários
hive-help      # Ajuda do hive-mind
hive-status    # Status dos agentes
hive-agents    # Listar agentes disponíveis
```

### SPARC Methodology

```powershell
# Listar modos SPARC
sparc-modes

# Executar com SPARC
sparc-run "implement feature X"

# TDD com SPARC
sparc-tdd "create user authentication"
```

### Node.js Performance

```powershell
# Modo performance (8GB heap + GC tracing)
node-perf

# Modo trace (warnings + deprecations)
node-trace
```

### Git Shortcuts

```powershell
gs          # git status
ga .        # git add .
gc -m "msg" # git commit -m "msg"
gp          # git push
gl          # git log (pretty)
gd          # git diff
```

## 📚 Comandos Disponíveis

### Claude Flow

| Comando | Descrição |
|---------|-----------|
| `claude-flow` | Comando principal do Claude Flow |
| `cf` | Alias para claude-flow |
| `cf-dev` | Ativar modo desenvolvimento |
| `cf-prod` | Ativar modo produção |
| `cf-safe` | Ativar modo seguro |
| `cf-auto` | Ativar auto-commit |
| `cf-check` | Verificar configuração |
| `cf-init-dirs` | Criar diretórios do Claude Flow |
| `cf-clean` | Limpar cache |

### Hive-Mind

| Comando | Descrição |
|---------|-----------|
| `hive "task"` | Executar tarefa com hive-mind |
| `hive-quick "task"` | Modo rápido |
| `hive-manual "task"` | Modo manual |
| `hive-seq "task"` | Modo sequencial |
| `hive-help` | Ajuda do hive-mind |
| `hive-status` | Status dos agentes |
| `hive-agents` | Listar agentes |

### SPARC

| Comando | Descrição |
|---------|-----------|
| `sparc-modes` | Listar modos SPARC |
| `sparc-run` | Executar com SPARC |
| `sparc-tdd` | TDD com SPARC |

### Node.js

| Comando | Descrição |
|---------|-----------|
| `node-perf` | Modo performance |
| `node-trace` | Modo trace |
| `npm` | Alias para pnpm |

### Git

| Comando | Descrição |
|---------|-----------|
| `gs` | git status |
| `ga` | git add |
| `gc` | git commit |
| `gp` | git push |
| `gl` | git log (pretty) |
| `gd` | git diff |

## 🔧 Troubleshooting

### Erro: "Execution Policy"

```powershell
# Solução
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Erro: "Node.js not found"

```powershell
# Instalar Node.js
# Download: https://nodejs.org/
# Ou via Chocolatey:
choco install nodejs-lts
```

### Erro: "pnpm not found"

```powershell
# Instalar pnpm
npm install -g pnpm

# Ou via Chocolatey:
choco install pnpm
```

### Erro: "API Key not configured"

```powershell
# Editar perfil
notepad $PROFILE

# Substituir <YOUR_*_API_KEY> pelas chaves reais
# Recarregar perfil
. $PROFILE
```

### Perfil não carrega automaticamente

```powershell
# Verificar se o perfil existe
Test-Path $PROFILE

# Criar se não existir
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force
}

# Copiar configuração
Copy-Item .\config\windows\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

### Claude Flow não funciona

```powershell
# Verificar Node.js
node --version

# Verificar npx
npx --version

# Testar Claude Flow
npx -y claude-flow@v3alpha --version

# Verificar configuração
cf-check
```

### Cache corrompido

```powershell
# Limpar cache do Claude Flow
cf-clean

# Limpar cache do npm/pnpm
pnpm store prune
npm cache clean --force
```

## 📊 Variáveis de Ambiente

### Claude Flow - Core

| Variável | Valor Padrão | Descrição |
|----------|--------------|-----------|
| `CLAUDE_FLOW_MAX_AGENTS` | 16 | Número máximo de agentes |
| `CLAUDE_FLOW_MEMORY_SIZE` | 8192 | Tamanho da memória (MB) |
| `CLAUDE_FLOW_NEURAL_FEATURES` | true | Recursos neurais |
| `CLAUDE_FLOW_LOG_LEVEL` | info | Nível de log |

### Claude Flow - Features

| Variável | Valor Padrão | Descrição |
|----------|--------------|-----------|
| `CLAUDE_FLOW_HOOKS_ENABLED` | true | Hooks habilitados |
| `CLAUDE_FLOW_PARALLEL_EXECUTION` | true | Execução paralela |
| `CLAUDE_FLOW_CACHE_ENABLED` | true | Cache habilitado |
| `CLAUDE_FLOW_AUTO_COMMIT` | true | Auto-commit Git |
| `CLAUDE_FLOW_AUTO_PUSH` | true | Auto-push Git |

### Node.js

| Variável | Valor Padrão | Descrição |
|----------|--------------|-----------|
| `NODE_ENV` | production | Ambiente Node.js |
| `NODE_OPTIONS` | --max-old-space-size=8192 | Opções do Node.js |
| `NODE_PRESERVE_SYMLINKS` | 1 | Preservar symlinks |

### API Keys

| Variável | Descrição |
|----------|-----------|
| `ANTHROPIC_API_KEY` | Chave API Anthropic Claude |
| `OPENAI_API_KEY` | Chave API OpenAI |
| `GOOGLE_API_KEY` | Chave API Google Gemini |
| `GEMINI_API_KEY` | Alias para GOOGLE_API_KEY |

## 🔐 Segurança

### Boas Práticas

1. **Nunca commitar API keys** no Git
2. **Usar variáveis de ambiente** do sistema para produção
3. **Rotacionar chaves** regularmente (90 dias)
4. **Usar .env** para desenvolvimento local
5. **Backup do perfil** antes de modificar

### Configurar via Sistema

```powershell
# Configurar permanentemente (requer admin)
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-...', 'User')
[System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'sk-...', 'User')
[System.Environment]::SetEnvironmentVariable('GOOGLE_API_KEY', 'AIza...', 'User')
```

## 📝 Customização

### Adicionar Aliases Personalizados

Edite `$PROFILE` e adicione:

```powershell
# Seus aliases personalizados
function my-command { 
    Write-Host "Meu comando personalizado"
}
```

### Modificar Variáveis de Ambiente

```powershell
# Editar perfil
notepad $PROFILE

# Modificar valores
$env:CLAUDE_FLOW_MAX_AGENTS = "32"  # Aumentar para 32 agentes
$env:NODE_OPTIONS = "--max-old-space-size=16384"  # 16GB heap
```

### Desabilitar Recursos

```powershell
# Desabilitar auto-commit
$env:CLAUDE_FLOW_AUTO_COMMIT = "false"

# Desabilitar hooks
$env:CLAUDE_FLOW_HOOKS_ENABLED = "false"

# Desabilitar execução paralela
$env:CLAUDE_FLOW_PARALLEL_EXECUTION = "false"
```

## 🆘 Suporte

### Documentação Adicional

- [Claude Flow Documentation](../docs/CLAUDE-FLOW.md)
- [Hive-Mind Guide](../docs/HIVE-MIND.md)
- [SPARC Methodology](../docs/SPARC.md)

### Logs e Debug

```powershell
# Ativar modo debug
cf-dev

# Ver logs do Claude Flow
Get-Content "$HOME\.claude-flow\logs\*.log" -Tail 50

# Ver configuração completa
cf-check
```

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](../../LICENSE) para mais detalhes.

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, abra uma issue ou pull request no repositório.

---

**Criado por**: AGL Infrastructure Team  
**Baseado em**: agldv03 (CT179) .zshrc configuration  
**Última atualização**: 2025-01-24
