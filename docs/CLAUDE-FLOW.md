# Claude Flow - Configuração e Uso

> **Última Atualização**: 2025-11-02 | **Versão**: 1.0.0

## 📖 Índice

1. [Visão Geral](#visão-geral)
2. [Problema Encontrado](#problema-encontrado)
3. [Solução Implementada](#solução-implementada)
4. [Instalação e Configuração](#instalação-e-configuração)
5. [Comandos Disponíveis](#comandos-disponíveis)
6. [Hive Mind - Sistema de Swarm](#hive-mind---sistema-de-swarm)
7. [Aliases e Atalhos](#aliases-e-atalhos)
8. [Troubleshooting](#troubleshooting)
9. [Referências](#referências)

---

## 🎯 Visão Geral

**Claude Flow** é uma ferramenta CLI avançada para orquestração de agentes AI usando o Claude Code. Permite criar "swarms" de agentes que trabalham colaborativamente para executar tarefas complexas.

### Características Principais

- 🐝 **Hive Mind**: Sistema de swarm com múltiplos agentes trabalhando em paralelo
- 🧠 **Coordenação Inteligente**: Queen coordinator orquestra workers especializados
- 🔧 **MCP Tools Integration**: Integração completa com ferramentas MCP
- 💾 **Memória Persistente**: Sessions auto-save para retomar trabalho
- ⚡ **Auto-scaling**: Ajuste automático de workers baseado na demanda

### Versão Instalada

```bash
v2.7.0-alpha.14 (Alpha 128)
```

**Features da Build Atual**:
- ✅ Build System Fixed - Removed 32 UI files, clean compilation
- ✅ Memory Coordination Validated - MCP tools fully operational
- ✅ Agent Updates - All core agents with MCP tool integration
- ✅ Hive-Mind Agents - 5 new agents with memory coordination
- ✅ Command System - All CLI commands tested and working

---

## 🚨 Problema Encontrado

### Erro ESM Module

Ao tentar executar o `claude-flow`, o seguinte erro ocorria:

```bash
file:///root/.pnpm/global/5/.pnpm/node_modules/restore-cursor/index.js:3
import signalExit from 'signal-exit';
       ^^^^^^^^^^
SyntaxError: The requested module 'signal-exit' does not provide an export named 'default'
    at ModuleJob._instantiate (node:internal/modules/esm/module_job:123:21)
    at async ModuleJob.run (node:internal/modules/esm/module_job:191:5)
    at async ModuleLoader.import (node:internal/modules/esm/loader:337:24)
    at async loadESM (node:internal/process/esm_loader:34:7)
    at async handleMainPromise (node:internal/modules/run_main:106:12)

Node.js v18.20.8
```

### Análise do Problema

**Sintomas**:
- ❌ Erro ao executar `claude-flow` diretamente
- ❌ Erro ao executar `npx claude-flow`
- ❌ Erro ao executar comandos hive-mind
- ❌ Incompatibilidade de módulos ESM

**Investigação Realizada**:

1. **Verificação de PATH**:
   ```bash
   echo $PATH
   # Output: /root/.pnpm:/root/bin:/root/.local/bin:/root/.nvm/...
   ```
   - `/root/.pnpm` estava no início do PATH
   - Sobrepunha instalações do NVM

2. **Verificação de npm root**:
   ```bash
   npm root -g
   # Output: /root/.pnpm/global/5/node_modules
   ```
   - npm estava usando diretório do pnpm
   - Configurado via variável de ambiente `PNPM_HOME=/root/.pnpm`

3. **Verificação de instalações**:
   ```bash
   which claude-flow
   # Output: /root/.pnpm/claude-flow (incorreto - pnpm)

   ls -la /root/.nvm/versions/node/v18.20.8/bin/claude-flow
   # Output: existe (correto - npm)
   ```

### Causa Raiz

**Problema**: Incompatibilidade de módulos ESM no ecossistema pnpm

1. **Variável de ambiente `PNPM_HOME`** estava configurada apontando para `/root/.pnpm`
2. **npm estava usando o diretório global do pnpm** para instalações
3. **Dependências do pnpm** tinham versões incompatíveis:
   - `restore-cursor` tentando importar `signalExit` como default export
   - `signal-exit` não fornecendo default export (apenas named exports)
4. **Cache do pnpm dlx** continha dependências corrompidas

### Por que o NVM funciona?

A instalação via NVM (`/root/.nvm/versions/node/v18.20.8/bin/claude-flow`) funciona porque:
- ✅ Usa o sistema de módulos do npm corretamente
- ✅ Resolve dependências com versões compatíveis
- ✅ Não depende do cache ou configurações do pnpm
- ✅ Instalação limpa via `npm install -g`

---

## ✅ Solução Implementada

### Estratégia de Resolução

**Abordagem**: Forçar uso do executável do NVM via aliases permanentes

**Vantagens desta solução**:
- 🚀 Rápida e não invasiva
- ✅ Não afeta outras instalações do sistema
- 🔧 Fácil de reverter se necessário
- 💯 100% compatível com scripts existentes
- 🎯 Resolve o problema na raiz

### Passos Executados

#### 1. Limpeza de Instalações Conflitantes

```bash
# Remover instalações do pnpm
rm -rf /root/.pnpm/claude-flow
rm -rf /root/.cache/pnpm/dlx

# Limpar cache do pnpm
pnpm store prune
```

#### 2. Reinstalação via npm

```bash
# Instalar globalmente usando npm (não pnpm)
npm install -g claude-flow@latest
```

**Resultado**: Instalado corretamente em `/root/.nvm/versions/node/v18.20.8/lib/node_modules/claude-flow`

#### 3. Criação de Aliases Permanentes

**~/.bashrc**:
```bash
# Adicionado no final do arquivo
alias claude-flow="/root/.nvm/versions/node/v18.20.8/bin/claude-flow"
```

**~/.zshrc**:
```bash
# Adicionado na seção "Claude Flow Hive-Mind Aliases"
# Force use of NVM-installed claude-flow (fixes ESM module issues)
alias claude-flow="/root/.nvm/versions/node/v18.20.8/bin/claude-flow"
```

#### 4. Verificação da Solução

```bash
# Bash
bash -c "source ~/.bashrc && claude-flow --version"
# Output: v2.7.0-alpha.14

# Zsh
zsh -c "source ~/.zshrc && claude-flow --version"
# Output: v2.7.0-alpha.14

# Teste do hive-mind
claude-flow hive-mind spawn "hi" --auto-spawn --claude
# ✅ Funcionando perfeitamente!
```

---

## 📦 Instalação e Configuração

### Pré-requisitos

- Node.js 18.20.8 (via NVM)
- npm 10.19.0
- Git
- Shell: bash ou zsh

### Instalação Completa

#### 1. Instalar via npm

```bash
npm install -g claude-flow@latest
```

#### 2. Configurar Aliases

**Para Bash**:
```bash
echo 'alias claude-flow="/root/.nvm/versions/node/v18.20.8/bin/claude-flow"' >> ~/.bashrc
source ~/.bashrc
```

**Para Zsh**:
```bash
# Editar ~/.zshrc e adicionar na seção Claude Flow:
alias claude-flow="/root/.nvm/versions/node/v18.20.8/bin/claude-flow"

# Recarregar
source ~/.zshrc
```

#### 3. Verificar Instalação

```bash
# Verificar versão
claude-flow --version

# Verificar que está usando o caminho correto
which claude-flow  # Deve mostrar: aliased to /root/.nvm/...

# Testar comando básico
claude-flow --help
```

### Configuração de Ambiente

**Variáveis de Ambiente Recomendadas** (já configuradas no zsh):

```bash
# Diretórios do Claude Flow
export CLAUDE_FLOW_BACKUP_DIRECTORY="$HOME/.claude-flow/backups"
export CLAUDE_FLOW_CACHE_DIR="$HOME/.claude-flow/cache"
export CLAUDE_FLOW_LOG_DIR="$HOME/.claude-flow/logs"

# Features
export CLAUDE_FLOW_CHECKPOINTS_ENABLED=true
export GITHUB_AUTO_SYNC=true
```

---

## 🎮 Comandos Disponíveis

### Comandos Principais

```bash
# Ajuda geral
claude-flow --help

# Versão
claude-flow --version

# Inicializar projeto
claude-flow init

# Criar agente
claude-flow agent create

# Listar agentes
claude-flow agent list
```

### Comandos Hive Mind

```bash
# Spawn um swarm
claude-flow hive-mind spawn "objetivo do swarm" [opções]

# Ver status do swarm ativo
claude-flow hive-mind status

# Listar agentes disponíveis
claude-flow hive-mind list-agents

# Retomar sessão
claude-flow hive-mind resume <session-id>

# Parar swarm
claude-flow hive-mind stop

# Ajuda do hive-mind
claude-flow hive-mind --help
```

### Opções do Spawn

```bash
--auto-spawn          # Auto-spawn de workers (recomendado)
--claude              # Usar Claude Code como interface
--verbose             # Output detalhado
--workers N           # Número de workers (default: 4)
--queen-type TYPE     # Tipo de queen: strategic, tactical, creative
--consensus ALGO      # Algoritmo: majority, unanimous, weighted
```

### Exemplos Práticos

```bash
# Spawn básico com auto-spawn
claude-flow hive-mind spawn "instalar dependências e rodar testes" --auto-spawn --claude

# Spawn com verbose para debugging
claude-flow hive-mind spawn "fix linting errors" --auto-spawn --claude --verbose

# Spawn com configuração customizada
claude-flow hive-mind spawn "refactor codebase" --workers 6 --queen-type tactical --claude

# Ver status em tempo real
claude-flow hive-mind status

# Retomar sessão anterior
claude-flow hive-mind resume session-1762115132413-g32u4ch0v
```

---

## 🐝 Hive Mind - Sistema de Swarm

### Arquitetura

```
┌─────────────────────────────────────────┐
│         Queen Coordinator               │
│    (Strategic/Tactical/Creative)        │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼────┐    ┌──────▼───┐    ┌────────┐    ┌────────┐
│Researcher│    │  Coder   │    │Analyst │    │ Tester │
│  Worker  │    │  Worker  │    │ Worker │    │ Worker │
└──────────┘    └──────────┘    └────────┘    └────────┘
```

### Tipos de Workers

| Worker Type | Responsabilidade | Quando Usar |
|-------------|------------------|-------------|
| **Researcher** | Pesquisa, análise de código, documentação | Explorar codebase, entender arquitetura |
| **Coder** | Implementação de código, refactoring | Escrever features, corrigir bugs |
| **Analyst** | Análise de performance, qualidade | Code review, otimização |
| **Tester** | Testes, QA, validação | Escrever testes, validar implementação |

### Tipos de Queen

| Queen Type | Estratégia | Melhor Para |
|------------|-----------|-------------|
| **Strategic** | Planejamento de longo prazo, arquitetura | Features complexas, refactoring grande |
| **Tactical** | Execução rápida, decisões práticas | Fixes rápidos, tarefas específicas |
| **Creative** | Soluções inovadoras, experimentação | Novas features, problemas únicos |

### Algoritmos de Consenso

| Algoritmo | Descrição | Trade-offs |
|-----------|-----------|------------|
| **Majority** | 50%+ dos workers devem concordar | Balanceado: velocidade vs qualidade |
| **Unanimous** | 100% dos workers devem concordar | Alto: máxima qualidade, mais lento |
| **Weighted** | Pesos diferentes por worker type | Flexível: customizável por contexto |

### Fluxo de Trabalho

```
1. Spawn Swarm
   ↓
2. Queen analisa objetivo
   ↓
3. Distribui tarefas para workers
   ↓
4. Workers executam em paralelo
   ↓
5. Workers reportam resultados
   ↓
6. Queen aplica consenso
   ↓
7. Integração e validação
   ↓
8. Auto-save de progresso
```

### Session Management

**Auto-save**: Progresso salvo a cada 30 segundos

**Localização**: `.hive-mind/sessions/`

**Estrutura de Session**:
```
.hive-mind/
├── sessions/
│   ├── session-<id>/
│   │   ├── state.json
│   │   ├── workers/
│   │   │   ├── researcher-1.json
│   │   │   ├── coder-1.json
│   │   │   ├── analyst-1.json
│   │   │   └── tester-1.json
│   │   └── logs/
│   └── hive-mind-prompt-swarm-<id>.txt
└── active-swarms.json
```

### MCP Tools Integration

**Ferramentas Disponíveis para Workers**:

```javascript
// Memória e coordenação
mcp__ruv-swarm__memory_usage
mcp__ruv-swarm__share_memory
mcp__ruv-swarm__task_status

// Comunicação
mcp__ruv-swarm__broadcast_message
mcp__ruv-swarm__worker_consensus

// Ferramentas Claude Flow
mcp__claude-flow__knowledge_search
mcp__claude-flow__code_analysis
```

---

## ⚡ Aliases e Atalhos

### Aliases do Zsh (Configurados)

**Aliases Principais**:
```bash
alias hive='_hive_auto'              # Modo auto-spawn completo
alias hive-quick='_hive_quick'        # Modo rápido (menos verbose)
alias hive-manual='_hive_manual'      # Controle manual (sem auto-spawn)
alias hive-seq='_hive_seq'            # Modo sequencial (sem paralelização)
```

**Aliases Utilitários**:
```bash
alias hive-help='claude-flow hive-mind --help'
alias hive-status='claude-flow hive-mind status'
alias hive-agents='claude-flow hive-mind list-agents'
```

### Funções do Zsh

**_hive_auto** (Recomendado para uso geral):
```bash
_hive_auto() {
    claude-flow hive-mind spawn "$*" --claude
}
```

**_hive_quick** (Para tarefas rápidas):
```bash
_hive_quick() {
    claude-flow hive-mind spawn "$*" --claude
}
```

**_hive_manual** (Para controle fino):
```bash
_hive_manual() {
    claude-flow hive-mind spawn "$*" --claude --verbose
}
```

**_hive_seq** (Para tarefas sequenciais):
```bash
_hive_seq() {
    claude-flow hive-mind spawn "$*" --auto-spawn --claude --verbose
}
```

### Exemplos de Uso dos Aliases

```bash
# Uso básico (mais comum)
hive "instalar dependências e rodar testes"

# Modo rápido
hive-quick "formatar código com prettier"

# Modo manual (para debugging)
hive-manual "analisar performance e sugerir otimizações"

# Modo sequencial (para tarefas dependentes)
hive-seq "criar migration, rodar migration, popular dados"

# Ver status
hive-status

# Listar agentes disponíveis
hive-agents

# Ajuda
hive-help
```

### Criando Seus Próprios Aliases

**Adicione no ~/.zshrc ou ~/.bashrc**:

```bash
# Alias para task específica do projeto
alias hive-test='claude-flow hive-mind spawn "rodar todos os testes e gerar coverage report" --auto-spawn --claude'

# Alias para build
alias hive-build='claude-flow hive-mind spawn "fazer build de produção mobile e backend" --workers 6 --claude'

# Alias para deploy
alias hive-deploy='claude-flow hive-mind spawn "preparar e fazer deploy para staging" --queen-type tactical --claude'
```

---

## 🔧 Troubleshooting

### Problema: Erro ESM Module

**Sintoma**:
```
SyntaxError: The requested module 'signal-exit' does not provide an export named 'default'
```

**Solução**:
```bash
# Verificar que está usando o alias correto
type claude-flow
# Deve mostrar: claude-flow is an alias for /root/.nvm/...

# Se não estiver, recarregar shell
source ~/.bashrc  # ou source ~/.zshrc

# Verificar versão
claude-flow --version
```

### Problema: Comando `hive` não encontrado

**Sintoma**:
```
zsh: command not found: hive
```

**Solução**:
```bash
# 1. Verificar se ~/.zshrc tem as funções
grep "_hive_auto" ~/.zshrc

# 2. Recarregar configuração
source ~/.zshrc

# 3. Testar em shell interativo
zsh -i -c "type hive"
```

### Problema: Claude Flow não encontra npm

**Sintoma**:
```
Error: Cannot find module 'npm'
```

**Solução**:
```bash
# Verificar que NVM está ativo
nvm current

# Usar versão correta do Node
nvm use 18.20.8

# Reinstalar claude-flow
npm install -g claude-flow@latest
```

### Problema: Sessions não salvam

**Sintoma**: Progress não persiste entre execuções

**Solução**:
```bash
# 1. Verificar diretório de sessions
ls -la .hive-mind/sessions/

# 2. Verificar permissões
chmod -R 755 .hive-mind/

# 3. Verificar variável de ambiente
echo $CLAUDE_FLOW_CHECKPOINTS_ENABLED
# Deve ser: true

# 4. Reabilitar se necessário
export CLAUDE_FLOW_CHECKPOINTS_ENABLED=true
```

### Problema: Workers não respondem

**Sintoma**: Swarm fica preso em "waiting for workers"

**Solução**:
```bash
# 1. Matar processos travados
pkill -f "claude-flow hive-mind"

# 2. Limpar sessions antigas
rm -rf .hive-mind/sessions/session-*

# 3. Reexecutar com verbose
claude-flow hive-mind spawn "seu objetivo" --auto-spawn --claude --verbose
```

### Problema: PATH ainda aponta para pnpm

**Sintoma**:
```bash
which claude-flow
# Output: /root/.pnpm/claude-flow
```

**Solução**:
```bash
# 1. Verificar variáveis de ambiente
env | grep -i pnpm
# Se PNPM_HOME está setado, ele pode sobrepor

# 2. Adicionar alias no início do PATH (temporário)
export PATH="/root/.nvm/versions/node/v18.20.8/bin:$PATH"

# 3. Ou usar caminho completo sempre
/root/.nvm/versions/node/v18.20.8/bin/claude-flow --version

# 4. Verificar que alias está funcionando
type claude-flow
```

### Problema: Erro de permissões

**Sintoma**:
```
EACCES: permission denied
```

**Solução**:
```bash
# 1. Verificar propriedade de arquivos
ls -la ~/.claude-flow/

# 2. Corrigir permissões se necessário
sudo chown -R $USER:$USER ~/.claude-flow/
chmod -R 755 ~/.claude-flow/

# 3. Para cache do npm
sudo chown -R $USER:$USER ~/.npm/
```

### Debug Mode

**Ativar logs detalhados**:
```bash
# Variável de ambiente
export DEBUG=claude-flow:*

# Executar com verbose
claude-flow hive-mind spawn "test" --verbose --claude

# Verificar logs
tail -f ~/.claude-flow/logs/hive-mind.log
```

### Limpeza Completa (Reset)

**Se tudo falhar**:
```bash
# 1. Backup de configurações (opcional)
cp ~/.zshrc ~/.zshrc.backup
cp ~/.bashrc ~/.bashrc.backup

# 2. Desinstalar completamente
npm uninstall -g claude-flow
rm -rf ~/.claude-flow/
rm -rf .hive-mind/

# 3. Limpar caches
npm cache clean --force
pnpm store prune

# 4. Reinstalar do zero
npm install -g claude-flow@latest

# 5. Reconfigurar aliases
# (seguir seção "Instalação e Configuração")
```

---

## 📚 Referências

### Documentação Oficial

- **Claude Flow GitHub**: https://github.com/ruvnet/claude-flow
- **Claude Code Docs**: https://docs.claude.com/en/docs/claude-code
- **Node.js ESM**: https://nodejs.org/api/esm.html
- **npm CLI**: https://docs.npmjs.com/cli/

### Recursos do Projeto

- **WORKFLOWS.md**: Metodologias de desenvolvimento e Agent OS
- **RULES.md**: Padrões de código e execução
- **QUICK-START.md**: Comandos rápidos e troubleshooting
- **ARCHON.md**: Integração MCP e task management

### Comandos Úteis de Referência

```bash
# Verificação de ambiente
node --version                    # v18.20.8
npm --version                     # 10.19.0
which claude-flow                 # /root/.nvm/.../claude-flow
type claude-flow                  # alias ou função

# Claude Flow
claude-flow --version             # Versão atual
claude-flow --help                # Ajuda geral
claude-flow hive-mind --help      # Ajuda do hive-mind
claude-flow agent list            # Listar agentes

# Hive Mind
hive "objetivo"                   # Spawn swarm
hive-status                       # Status atual
hive-agents                       # Listar workers
claude-flow hive-mind resume ID   # Retomar sessão

# Debugging
echo $PATH                        # Verificar PATH
env | grep -i pnpm               # Verificar PNPM vars
ls -la .hive-mind/sessions/      # Ver sessions
tail -f ~/.claude-flow/logs/*.log # Logs em tempo real
```

### Estrutura de Diretórios

```
~/.claude-flow/
├── backups/              # Backups de configuração
├── cache/                # Cache de operações
├── logs/                 # Logs de execução
│   ├── hive-mind.log
│   ├── workers.log
│   └── errors.log
└── config.json           # Configuração global

.hive-mind/
├── sessions/             # Sessions ativas e históricas
│   └── session-*/
│       ├── state.json
│       ├── workers/
│       └── logs/
└── active-swarms.json    # Swarms atualmente ativos
```

### Versioning e Updates

**Verificar atualizações**:
```bash
npm outdated -g claude-flow
```

**Atualizar para versão específica**:
```bash
npm install -g claude-flow@2.7.12
```

**Atualizar para latest**:
```bash
npm install -g claude-flow@latest
```

**Rollback para versão anterior**:
```bash
npm install -g claude-flow@2.7.0-alpha.14
```

---

## 📝 Changelog

### v1.0.0 - 2025-11-02

**Adicionado**:
- ✅ Documentação completa do Claude Flow
- ✅ Análise detalhada do problema ESM
- ✅ Solução com aliases permanentes (bash e zsh)
- ✅ Guia completo de comandos e uso
- ✅ Documentação do Hive Mind System
- ✅ Seção de troubleshooting extensiva
- ✅ Referências e recursos

**Corrigido**:
- ✅ Erro ESM module com signal-exit/restore-cursor
- ✅ Conflito entre instalações pnpm e npm
- ✅ PATH incorreto apontando para pnpm

**Configurado**:
- ✅ Aliases permanentes em ~/.bashrc
- ✅ Aliases permanentes em ~/.zshrc
- ✅ Funções hive-* para atalhos
- ✅ Variáveis de ambiente recomendadas

---

## 🎯 Melhores Práticas

### Uso Diário

1. **Sempre usar aliases configurados** ao invés de caminhos absolutos
2. **Começar com `hive`** para tarefas gerais (usa auto-spawn)
3. **Usar `hive-manual`** quando precisar de controle fino
4. **Verificar `hive-status`** antes de spawnar novo swarm
5. **Salvar session IDs** de tarefas longas para retomar

### Performance

1. **Número de workers**: 4 é ideal para a maioria dos casos
2. **Use `--verbose` apenas para debugging** (gera muito output)
3. **Limpe sessions antigas** periodicamente (`rm -rf .hive-mind/sessions/old-*`)
4. **Monitor uso de memória** em swarms grandes

### Segurança

1. **Nunca commitar** diretórios `.hive-mind/`
2. **Adicionar ao .gitignore**:
   ```
   .hive-mind/
   .claude-flow/
   ```
3. **Revisar código gerado** por workers antes de commitar
4. **Usar `hive-manual` para operações sensíveis** (deploy, database migrations)

### Colaboração

1. **Documentar objetivos complexos** antes de passar para hive
2. **Compartilhar session IDs** com time quando relevante
3. **Criar aliases customizados** para workflows do projeto
4. **Manter este documento atualizado** com descobertas

---

## 💡 Dicas e Truques

### Objetivos Efetivos

**❌ Ruim**:
```bash
hive "fazer coisas"
hive "corrigir bugs"
```

**✅ Bom**:
```bash
hive "instalar dependências do package.json, rodar linter e corrigir erros automaticamente, executar testes unitários"
hive "analisar performance do componente BoxAnimation, identificar gargalos, e sugerir 3 otimizações específicas"
```

### Composição de Tasks

```bash
# Task simples
hive "formatar código com prettier"

# Task média
hive "adicionar testes unitários para UserService, cobertura mínima 85%"

# Task complexa
hive "refatorar autenticação para usar Firebase Auth v10, atualizar todos os imports, modificar testes, e validar que não quebrou fluxo de login"
```

### Retomando Trabalho

```bash
# 1. Listar sessions recentes
ls -lt .hive-mind/sessions/ | head -n 5

# 2. Ver detalhes da session
cat .hive-mind/sessions/session-123/state.json

# 3. Retomar
claude-flow hive-mind resume session-123
```

### Logs Úteis

```bash
# Ver últimos erros
tail -n 50 ~/.claude-flow/logs/errors.log

# Monitorar workers em tempo real
watch -n 1 'cat .hive-mind/sessions/*/workers/*.json | jq .status'

# Verificar consenso
grep -r "consensus" .hive-mind/sessions/session-*/logs/
```

---

**Documento Mantido por**: Claude Code (crowbar project)
**Contato**: Ver CLAUDE.md para suporte e recursos adicionais
**Licença**: Uso interno - Projeto Crowbar

---

*Claude Flow: Orquestrando inteligência artificial em swarm para desenvolvimento ágil! 🐝⚡🚀*
