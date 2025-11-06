# Gemini Flow - Configuração e Uso

> **Última Atualização**: 2025-11-02 | **Versão**: 1.3.3

## 📖 Índice

1. [Visão Geral](#visão-geral)
2. [Problema Encontrado e Solução](#problema-encontrado-e-solução)
3. [Instalação e Configuração](#instalação-e-configuração)
4. [Comandos Disponíveis](#comandos-disponíveis)
5. [Arquitetura: Swarms e Agentes](#arquitetura-swarms-e-agentes)
6. [Protocolos: A2A e MCP](#protocolos-a2a-e-mcp)
7. [Aliases e Atalhos](#aliases-e-atalhos)
8. [Integração com Google AI Services](#integração-com-google-ai-services)
9. [Troubleshooting](#troubleshooting)
10. [Referências](#referências)

---

## 🎯 Visão Geral

**Gemini Flow** é uma plataforma revolucionária de orquestração de IA que transforma o Claude Flow para o ecossistema Google Gemini. Permite criar swarms de agentes AI especializados que trabalham colaborativamente para executar tarefas complexas.

### Características Principais

- 🌟 **87 Agentes Especializados**: Maior número de agentes que claude-flow
- 🔄 **Dual Protocol**: A2A (Agent-to-Agent) + MCP (Model Context Protocol)
- 🧠 **Hive Mind & Swarm**: Sistemas avançados de coordenação coletiva
- 🚀 **Performance**: 396,610 ops/segundo (validado em produção)
- 🎯 **Google AI Integration**: Acesso completo a 8 serviços Google AI
- ⚡ **Byzantine Consensus**: Tolerância a falhas e auto-recuperação
- 💾 **Memória Persistente**: Sessions e contexto entre execuções

### Versão Instalada

```bash
gemini-flow --version
# v1.3.3
```

**Features da Build Atual**:
- ✅ 87 Specialized Agents (vs 66 anterior)
- ✅ A2A + MCP Dual Protocol Support
- ✅ Complete Google AI Services Integration
- ✅ Quantum-enhanced processing
- ✅ Jules autonomous development integration
- ✅ Darwin Gödel Machine (self-improving system)

---

## 🚨 Problema Encontrado e Solução

### Erro Inicial: Dependências Não Resolvidas

Ao tentar instalar o `@clduab11/gemini-flow` via npm, encontramos erros críticos:

```bash
npm install -g @clduab11/gemini-flow
# Failed to load fallback CLI: Cannot find module 'cli-cursor'
# Failed to load fallback CLI: Cannot find module 'ansi-styles'
```

### Análise do Problema

**Sintomas**:
- ❌ `npm install` via pnpm não resolvia dependências corretamente
- ❌ Falta de `package-lock.json` no repositório
- ❌ Dependências transitivas (chalk → ansi-styles, ora → cli-cursor) não instaladas
- ❌ Cache do pnpm com módulos corrompidos

**Investigação Realizada**:

1. **Verificação de gerenciador de pacotes**:
   ```bash
   which npm
   # Output: /root/.pnpm/npm (incorreto!)
   ```
   - npm estava mapeado para pnpm
   - pnpm não conseguia resolver árvore de dependências corretamente

2. **Análise do Dockerfile**:
   ```dockerfile
   # Dependencies stage
   FROM base AS dependencies
   RUN npm ci --only=production && npm cache clean --force
   ```
   - Dockerfile usa `npm ci` (real npm)
   - Requer `package-lock.json` para instalação determinística

3. **Root Cause**: Sistema usando pnpm quando deveria usar npm real

### ✅ Solução Implementada

**Estratégia**: Instalação manual com npm real do NVM + package-lock generation

#### Passos Executados:

1. **Clonagem em diretório permanente**:
```bash
cd /opt
git clone https://github.com/clduab11/gemini-flow.git
cd gemini-flow
```

2. **Geração de package-lock.json**:
```bash
/root/.nvm/versions/node/v18.20.8/bin/npm install --package-lock-only
# ✅ package-lock.json criado (937 KB)
```

3. **Instalação limpa com npm real**:
```bash
rm -rf node_modules
/root/.nvm/versions/node/v18.20.8/bin/npm install
# ✅ added 440 packages in 11s
```

4. **Criação de links simbólicos globais**:
```bash
ln -sf /opt/gemini-flow/bin/gemini-flow /root/.nvm/versions/node/v18.20.8/bin/gemini-flow
ln -sf /opt/gemini-flow/bin/gemini-flow /root/.nvm/versions/node/v18.20.8/bin/gf
```

5. **Configuração de aliases permanentes** (bash + zsh)

**Resultado**: ✅ **100% Funcional!**

```bash
gemini-flow --version
# 1.3.3

gemini-flow doctor
# ✅ All checks passed! Gemini-Flow is ready for AI orchestration.
```

---

## 📦 Instalação e Configuração

### Pré-requisitos

- Node.js 18.0.0+ (via NVM)
- npm 8.0.0+
- Google Gemini API Key
- Git
- Shell: bash ou zsh
- (Opcional) Google Cloud Project com API access
- (Opcional) Redis para coordenação distribuída

### Instalação Completa (Método Recomendado)

#### 1. Clonar e Instalar

```bash
# Clone para diretório permanente
cd /opt
sudo git clone https://github.com/clduab11/gemini-flow.git
cd gemini-flow

# Gerar package-lock.json
/root/.nvm/versions/node/v18.20.8/bin/npm install --package-lock-only

# Instalação limpa
rm -rf node_modules
/root/.nvm/versions/node/v18.20.8/bin/npm install
```

#### 2. Criar Links Simbólicos

```bash
sudo ln -sf /opt/gemini-flow/bin/gemini-flow /root/.nvm/versions/node/v18.20.8/bin/gemini-flow
sudo ln -sf /opt/gemini-flow/bin/gemini-flow /root/.nvm/versions/node/v18.20.8/bin/gf
```

#### 3. Configurar Aliases

**Para Bash** (~/.bashrc):
```bash
# Gemini Flow aliases
alias gemini-flow="/root/.nvm/versions/node/v18.20.8/bin/gemini-flow"
alias gf="/root/.nvm/versions/node/v18.20.8/bin/gf"

# Gemini API Key
export GEMINI_API_KEY="sua-chave-aqui"

# Recarregar
source ~/.bashrc
```

**Para Zsh** (~/.zshrc):
```bash
# Gemini Flow aliases
alias gemini-flow="/root/.nvm/versions/node/v18.20.8/bin/gemini-flow"
alias gf="/root/.nvm/versions/node/v18.20.8/bin/gf"

# Shortcuts
alias gf-init='gemini-flow init'
alias gf-hive='gemini-flow hive-mind'
alias gf-swarm='gemini-flow swarm'
alias gf-agent='gemini-flow agent'

# Gemini API Key
export GEMINI_API_KEY="sua-chave-aqui"

# Recarregar
source ~/.zshrc
```

#### 4. Configurar API Key do Gemini

**Opção A: Variável de Ambiente** (Recomendado):
```bash
export GEMINI_API_KEY="sua-chave-aqui"
```

**Opção B: Arquivo .env**:
```bash
# No diretório do projeto
echo "GEMINI_API_KEY=sua-chave-aqui" >> .env
```

**Obter API Key**:
- Acesse: https://makersuite.google.com/app/apikey
- Crie um novo projeto ou selecione existente
- Gere uma API key
- Copie a chave

#### 5. Verificar Instalação

```bash
# Verificar versão
gemini-flow --version
# 1.3.3

# Health check
gemini-flow doctor
# ✅ All checks passed!

# Ver ajuda
gemini-flow --help
```

#### 6. Inicializar Projeto

```bash
# No diretório do seu projeto
cd /seu/projeto

# Inicializar
gemini-flow init --skip-git --skip-install

# Verificar estrutura criada
ls -la .gemini-flow/
```

---

## 🎮 Comandos Disponíveis

### Comandos Principais

```bash
# Informações
gemini-flow --version              # Versão instalada
gemini-flow --help                 # Ajuda geral
gemini-flow doctor                 # Health check do sistema

# Projeto
gemini-flow init [options]         # Inicializar projeto
gemini-flow config                 # Gerenciar configurações

# Agentes e Swarms
gemini-flow agent                  # Gerenciar 87+ agentes especializados
gemini-flow swarm                  # Gerenciar swarms de agentes
gemini-flow hive-mind              # Operações de inteligência coletiva

# Tarefas e Memória
gemini-flow task                   # Orquestrar tarefas
gemini-flow memory                 # Gerenciar memória persistente
gemini-flow workspace              # Gerenciar workspaces

# Metodologia
gemini-flow sparc                  # SPARC TDD methodology
gemini-flow hooks                  # Lifecycle hooks

# Avançado
gemini-flow optimize               # Otimizações de segurança/performance
gemini-flow quantum                # Quantum-enhanced processing
gemini-flow jules                  # Desenvolvimento autônomo
gemini-flow dgm                    # Darwin Gödel Machine (self-improving)
```

### Comandos de Agentes

```bash
# Listar agentes disponíveis
gemini-flow agent list

# Spawn agentes
gemini-flow agent spawn --count 5

# Ver tipos de agentes
gemini-flow agent types

# Informações de agente específico
gemini-flow agent info <agent-id>
```

### Comandos de Swarm

```bash
# Inicializar swarm
gemini-flow swarm init

# Spawn swarm with agents
gemini-flow agents spawn --count 20 --coordination "intelligent"

# Status do swarm
gemini-flow swarm status

# Monitor performance
gemini-flow monitor --protocols --performance
```

### Comandos Hive Mind

```bash
# Spawn hive mind
gemini-flow hive-mind spawn "objetivo do hive mind"

# Criar consenso
gemini-flow consensus create --topic "decisão importante"

# Status do hive mind
gemini-flow hive-mind status
```

### Opções Globais

```bash
-v, --verbose          # Enable verbose output
--debug                # Enable debug output
--quiet                # Suppress all output except errors
--config <file>        # Use custom config file
--profile <name>       # Use named configuration profile
--protocols <list>     # Protocols to use (a2a,mcp)
--gemini               # Enable Gemini CLI integration mode
--json                 # JSON output format
```

### Exemplos Práticos

```bash
# Inicializar projeto com template
gemini-flow init --template default

# Spawn 10 agentes para desenvolvimento
gemini-flow agent spawn --count 10 --type developer

# Criar swarm para análise de código
gemini-flow swarm init --name code-analysis --agents 15

# Executar tarefa com hive mind
gemini-flow hive-mind spawn "analisar performance do sistema e sugerir otimizações"

# Criar consenso entre agentes
gemini-flow consensus --agents 5 --algorithm byzantine

# Verificar memória e histórico
gemini-flow memory list --recent 10
```

---

## 🏗️ Arquitetura: Swarms e Agentes

### Estrutura Hierárquica

```
Hive Mind (Coordenação Global)
├── Swarm 1 (Conjunto de Agentes Especializados)
│   ├── Agent 1.1 (Researcher)
│   ├── Agent 1.2 (Coder)
│   ├── Agent 1.3 (Analyst)
│   └── Agent 1.4 (Tester)
├── Swarm 2 (Outro Conjunto)
│   ├── Agent 2.1 (Architect)
│   ├── Agent 2.2 (Security)
│   └── Agent 2.3 (Optimizer)
└── Consensus Layer (Byzantine Fault Tolerance)
```

### 87 Tipos de Agentes Especializados

| Categoria | Agentes | Responsabilidade |
|-----------|---------|------------------|
| **Development** | Architect, Coder, Debugger, Refactorer | Escrita e manutenção de código |
| **Quality** | Tester, Reviewer, Analyzer, Auditor | Garantia de qualidade |
| **Research** | Researcher, Explorer, Analyst, Investigator | Pesquisa e análise |
| **Operations** | DevOps, SRE, Monitor, Logger | Operações e infraestrutura |
| **Security** | Security, Penetration, Compliance, Audit | Segurança e compliance |
| **Data** | DataEngineer, Scientist, ML, AI | Ciência de dados e ML |
| **Documentation** | Writer, Documenter, Tutorial, API | Documentação técnica |
| **Design** | UX, UI, Product, System | Design e arquitetura |
| **Management** | ProjectManager, Scrum, Coordinator | Gestão de projetos |
| **Optimization** | Performance, Memory, CPU, Network | Otimizações |

**Total**: 87+ agentes especializados (vs 66 do claude-flow)

### Swarm Intelligence

**Características**:
- 🧠 **Inteligência Coletiva**: Agentes compartilham conhecimento
- 🔄 **Auto-organização**: Swarm se adapta dinamicamente
- ⚡ **Paralelização**: Múltiplos agentes trabalham simultaneamente
- 🎯 **Especialização**: Cada agente tem expertise específica
- 🤝 **Colaboração**: Protocolos A2A para comunicação

**Algoritmos de Consenso**:
- **Byzantine**: Tolerante a falhas e agentes maliciosos
- **Raft**: Consenso rápido para decisões simples
- **PBFT**: Practical Byzantine Fault Tolerance
- **Majority**: Voto majoritário simples
- **Weighted**: Voto ponderado por expertise

### Hive Mind

**O que é**:
- Sistema de coordenação global que gerencia múltiplos swarms
- Memória compartilhada entre todos os agentes
- Decisões coletivas via consenso distribuído

**Funcionamento**:
```
1. Objetivo recebido
   ↓
2. Hive Mind analisa e divide em sub-tarefas
   ↓
3. Distribui tarefas para swarms especializados
   ↓
4. Swarms coordenam seus agentes
   ↓
5. Agentes executam em paralelo
   ↓
6. Resultados agregados via consenso
   ↓
7. Hive Mind integra e valida resultado final
```

**Comandos Hive Mind**:
```bash
# Spawn com objetivo
gemini-flow hive-mind spawn "desenvolver feature X com testes"

# Status e progresso
gemini-flow hive-mind status

# Ver histórico de decisões
gemini-flow hive-mind history

# Criar votação/consenso
gemini-flow hive-mind consensus --topic "arquitetura do sistema"
```

---

## 🔄 Protocolos: A2A e MCP

### A2A (Agent-to-Agent Protocol)

**Definição**: Protocolo proprietário para comunicação direta entre agentes.

**Características**:
- ⚡ **Baixa Latência**: <75ms de routing
- 🔒 **Segurança**: Criptografia end-to-end
- 📊 **Telemetria**: Rastreamento de mensagens
- 🎯 **Routing Inteligente**: Entrega otimizada

**Estrutura de Mensagem A2A**:
```json
{
  "protocol": "a2a",
  "version": "1.0",
  "from": "agent-id-123",
  "to": "agent-id-456",
  "type": "task|query|result|consensus",
  "payload": {
    "task": "analyze-code",
    "data": {...}
  },
  "metadata": {
    "timestamp": "2025-11-02T21:00:00Z",
    "priority": "high",
    "requires_consensus": false
  }
}
```

**Uso**:
```bash
# Habilitar A2A
gemini-flow swarm init --protocols a2a

# Monitorar A2A
gemini-flow monitor --protocols
```

### MCP (Model Context Protocol)

**Definição**: Protocolo para gerenciar contexto entre modelos de IA.

**Características**:
- 🧠 **Contexto Compartilhado**: Todos os agentes têm acesso ao mesmo contexto
- 💾 **Persistência**: Contexto salvo entre sessões
- 🔄 **Sincronização**: Atualizações em tempo real
- 🎯 **Otimização**: Redução de tokens via contexto compartilhado

**Estrutura de Contexto MCP**:
```json
{
  "protocol": "mcp",
  "version": "2.0",
  "context_id": "ctx-789",
  "shared_memory": {
    "project": "crowbar",
    "phase": "development",
    "recent_decisions": [...]
  },
  "model_state": {
    "temperature": 0.7,
    "max_tokens": 2000,
    "model": "gemini-2.0-flash"
  }
}
```

**Uso**:
```bash
# Habilitar MCP
gemini-flow swarm init --protocols mcp

# Ver contexto atual
gemini-flow memory show --format mcp

# Limpar contexto
gemini-flow memory clear --protocol mcp
```

### Dual Protocol (A2A + MCP)

**Melhor dos dois mundos**:
- A2A para comunicação rápida entre agentes
- MCP para compartilhamento de contexto e memória

```bash
# Habilitar ambos (recomendado)
gemini-flow swarm init --protocols a2a,mcp

# Benefícios:
# ✅ Comunicação rápida (A2A)
# ✅ Contexto compartilhado (MCP)
# ✅ Redução de tokens (~40%)
# ✅ Performance otimizada
```

---

## ⚡ Aliases e Atalhos

### Aliases Configurados (Zsh)

```bash
# Comando principal
alias gemini-flow="/root/.nvm/versions/node/v18.20.8/bin/gemini-flow"
alias gf="/root/.nvm/versions/node/v18.20.8/bin/gf"

# Shortcuts para comandos comuns
alias gf-init='gemini-flow init'
alias gf-hive='gemini-flow hive-mind'
alias gf-swarm='gemini-flow swarm'
alias gf-agent='gemini-flow agent'
alias gf-help='gemini-flow --help'
alias gf-version='gemini-flow --version'
```

### Exemplos de Uso dos Aliases

```bash
# Rápido e direto
gf --version               # Ver versão
gf-help                    # Ver ajuda
gf-init                    # Inicializar projeto

# Comandos compostos
gf-agent spawn --count 10  # Spawn 10 agentes
gf-swarm status            # Ver status do swarm
gf-hive spawn "tarefa"     # Executar via hive mind
```

### Criando Seus Próprios Aliases

```bash
# Adicione ao ~/.zshrc ou ~/.bashrc

# Alias para comandos frequentes
alias gf-dev='gemini-flow agent spawn --count 5 --type developer'
alias gf-test='gemini-flow agent spawn --count 3 --type tester'
alias gf-analyze='gemini-flow hive-mind spawn "analisar codebase"'

# Alias para workflows específicos
alias gf-review='gemini-flow swarm init --name code-review && gemini-flow agent spawn --count 3 --type reviewer'
alias gf-optimize='gemini-flow optimize --security --performance'

# Reload
source ~/.zshrc
```

---

## 🌐 Integração com Google AI Services

Gemini Flow oferece integração completa com **8 serviços Google AI**:

### 1. Veo3 - Geração de Vídeo

```bash
# Gerar vídeo via agente
gemini-flow agent spawn --type video-generator --task "criar vídeo demo do produto"
```

**Features**:
- Geração de vídeo até 60s
- Qualidade 4K
- Controle de estilo e mood

### 2. Imagen4 - Geração de Imagens

```bash
# Gerar imagens via agente
gemini-flow agent spawn --type image-generator --task "criar thumbnails para docs"
```

**Features**:
- Alta qualidade e realismo
- Edição de imagens existentes
- Múltiplos estilos

### 3. Lyria - Geração de Música

```bash
# Gerar música de fundo
gemini-flow agent spawn --type music-generator --task "criar trilha para apresentação"
```

### 4. Chirp - Síntese de Voz

```bash
# Gerar narração
gemini-flow agent spawn --type voice-synthesizer --task "narrar tutorial"
```

### 5. Co-Scientist - Assistente Científico

```bash
# Análise científica
gemini-flow agent spawn --type scientific-analyst --task "analisar dados experimentais"
```

### 6. Mariner - Navegação Web

```bash
# Web scraping e análise
gemini-flow agent spawn --type web-navigator --task "extrair dados de competitors"
```

### 7. AgentSpace - Coordenação de Agentes

```bash
# Gerenciamento avançado de agentes
gemini-flow agentspace deploy --topology distributed
```

### 8. Streaming API

```bash
# Respostas em tempo real
gemini-flow agent spawn --streaming --task "chat interativo"
```

### Configuração Google Cloud (Opcional)

Para recursos avançados, configure Google Cloud:

```bash
# Variáveis de ambiente
export GOOGLE_CLOUD_PROJECT_ID="seu-projeto-id"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"

# Validar
gemini-flow doctor --check-gcp
```

---

## 🔧 Troubleshooting

### Problema: Erro de Dependências

**Sintoma**:
```
Cannot find module 'cli-cursor'
Cannot find module 'ansi-styles'
```

**Solução**:
```bash
# Use npm real, não pnpm
cd /opt/gemini-flow
rm -rf node_modules package-lock.json
/root/.nvm/versions/node/v18.20.8/bin/npm install
```

### Problema: Comando `gemini-flow` não encontrado

**Sintoma**:
```
zsh: command not found: gemini-flow
```

**Solução**:
```bash
# Verificar alias
type gemini-flow

# Recarregar configuração
source ~/.zshrc  # ou source ~/.bashrc

# Verificar link simbólico
ls -la /root/.nvm/versions/node/v18.20.8/bin/gemini-flow
```

### Problema: API Key Inválida

**Sintoma**:
```
❌ FAIL Gemini API key
```

**Solução**:
```bash
# Verificar API key
echo $GEMINI_API_KEY

# Reconfigurar
export GEMINI_API_KEY="sua-nova-chave"

# Adicionar permanentemente ao ~/.bashrc ou ~/.zshrc
echo 'export GEMINI_API_KEY="sua-chave"' >> ~/.bashrc
source ~/.bashrc

# Verificar novamente
gemini-flow doctor
```

### Problema: Swarm não inicializa

**Sintoma**:
```
Error initializing swarm
```

**Solução**:
```bash
# Verificar configuração
ls -la .gemini-flow/

# Reinicializar
gemini-flow init --force

# Verificar logs
tail -f .gemini-flow/logs/*.log
```

### Problema: Agentes não respondem

**Sintoma**: Agentes ficam stuck ou não executam tarefas

**Solução**:
```bash
# Verificar status
gemini-flow swarm status

# Reiniciar swarm
gemini-flow swarm restart

# Limpar cache
gemini-flow memory clear --cache

# Verificar recursos
gemini-flow doctor --verbose
```

### Problema: Performance Lenta

**Sintoma**: Operações demorando muito

**Solução**:
```bash
# Ativar otimizações
gemini-flow optimize --performance

# Reduzir número de agentes
gemini-flow swarm scale --count 5

# Usar protocolos mais leves
gemini-flow config set protocols a2a

# Limpar memória antiga
gemini-flow memory clean --older-than 7d
```

### Debug Mode

**Ativar logs detalhados**:
```bash
# Variável de ambiente
export DEBUG=gemini-flow:*

# Executar com debug
gemini-flow --debug agent spawn --count 5

# Ver logs em tempo real
tail -f .gemini-flow/logs/*.log
```

### Limpeza Completa (Reset)

**Se tudo falhar**:
```bash
# 1. Backup (opcional)
cp -r .gemini-flow .gemini-flow.backup

# 2. Remover configurações locais
rm -rf .gemini-flow

# 3. Reinicializar
gemini-flow init

# 4. Reconfigurar
export GEMINI_API_KEY="sua-chave"
gemini-flow doctor
```

---

## 📚 Referências

### Documentação Oficial

- **Gemini Flow GitHub**: https://github.com/clduab11/gemini-flow
- **Google Gemini API**: https://makersuite.google.com/
- **Claude Flow (Original)**: https://github.com/ruvnet/claude-flow
- **Gemini CLI**: https://github.com/google-gemini/gemini-cli

### Recursos do Projeto Crowbar

- **CLAUDE-FLOW.md**: Documentação do Claude Flow
- **WORKFLOWS.md**: Metodologias de desenvolvimento
- **RULES.md**: Padrões de código
- **QUICK-START.md**: Comandos rápidos

### Comandos Úteis de Referência

```bash
# Verificação de Ambiente
node --version                    # v18.20.8
npm --version                     # 10.19.0
which gemini-flow                 # Link para executável
type gemini-flow                  # Alias configurado

# Gemini Flow
gemini-flow --version             # 1.3.3
gemini-flow --help                # Ajuda completa
gemini-flow doctor                # Health check
gemini-flow config show           # Ver configuração atual

# Swarms e Agentes
gemini-flow agent list            # Listar agentes
gemini-flow swarm status          # Status do swarm
gemini-flow hive-mind status      # Status do hive mind

# Debugging
echo $GEMINI_API_KEY             # Verificar API key
ls -la .gemini-flow/             # Ver estrutura local
tail -f .gemini-flow/logs/*.log  # Logs em tempo real
```

### Estrutura de Diretórios

```
/opt/gemini-flow/              # Instalação global
├── bin/
│   └── gemini-flow            # Executável principal
├── dist/                      # Código compilado
├── src/                       # Código fonte
├── node_modules/              # Dependências
└── package.json

.gemini-flow/                  # Configuração local do projeto
├── agents/                    # Definições de agentes
├── swarms/                    # Configurações de swarms
├── cache/                     # Cache de operações
├── logs/                      # Logs de execução
└── config.json                # Configuração local
```

### Comparação: Gemini Flow vs Claude Flow

| Feature | Claude Flow | Gemini Flow | Diferença |
|---------|-------------|-------------|-----------|
| **Agentes** | 66 | 87 | +21 agentes |
| **Protocolos** | MCP | A2A + MCP | Dual protocol |
| **Performance** | ~250k ops/s | 396k ops/s | +58% mais rápido |
| **AI Services** | Claude | Google AI (8 serviços) | Ecossistema completo |
| **Consenso** | Majority | Byzantine + Raft + PBFT | Mais robusto |
| **Quantum** | ❌ | ✅ | Quantum-enhanced |
| **Auto-melhoria** | ❌ | ✅ Darwin Gödel Machine | Self-improving |

### Versioning e Updates

**Verificar atualizações**:
```bash
cd /opt/gemini-flow
git fetch origin
git log --oneline HEAD..origin/main
```

**Atualizar**:
```bash
cd /opt/gemini-flow
git pull origin main
/root/.nvm/versions/node/v18.20.8/bin/npm install
```

**Rollback**:
```bash
cd /opt/gemini-flow
git log --oneline
git checkout <commit-hash>
/root/.nvm/versions/node/v18.20.8/bin/npm install
```

---

## 📝 Changelog

### v1.3.3 - 2025-11-02 (Instalação no Projeto Crowbar)

**Adicionado**:
- ✅ Instalação completa via npm real do NVM
- ✅ Configuração de API key do Gemini
- ✅ Aliases para bash e zsh
- ✅ Links simbólicos globais (gemini-flow + gf)
- ✅ Inicialização do projeto crowbar
- ✅ Documentação completa em português

**Corrigido**:
- ✅ Erro de dependências não resolvidas (uso de pnpm)
- ✅ Falta de package-lock.json
- ✅ Módulos faltantes (cli-cursor, ansi-styles, etc.)

**Configurado**:
- ✅ Aliases permanentes em ~/.bashrc e ~/.zshrc
- ✅ GEMINI_API_KEY em variáveis de ambiente
- ✅ Estrutura .gemini-flow/ no projeto
- ✅ Health check 100% passando

---

## 🎯 Melhores Práticas

### Uso Diário

1. **Sempre verificar health antes de começar**:
   ```bash
   gemini-flow doctor
   ```

2. **Usar protocolos dual (A2A + MCP)**:
   ```bash
   gemini-flow swarm init --protocols a2a,mcp
   ```

3. **Limitar número de agentes** (performance):
   ```bash
   gemini-flow agent spawn --count 5  # Ao invés de 50
   ```

4. **Monitorar recursos**:
   ```bash
   gemini-flow monitor --performance
   ```

5. **Limpar cache regularmente**:
   ```bash
   gemini-flow memory clean --older-than 7d
   ```

### Performance

1. **Usar consenso adequado**:
   - **Majority**: Tarefas simples
   - **Byzantine**: Decisões críticas
   - **Raft**: Performance + confiabilidade

2. **Otimizar protocolos**:
   ```bash
   # A2A para comunicação rápida
   gemini-flow config set primary-protocol a2a

   # MCP para compartilhamento de contexto
   gemini-flow config set context-protocol mcp
   ```

3. **Escalar dinamicamente**:
   ```bash
   # Aumentar sob demanda
   gemini-flow swarm scale --auto
   ```

### Segurança

1. **Nunca commitar**:
   - `.gemini-flow/` (dados locais)
   - Arquivos com API keys
   - Logs com informações sensíveis

2. **Usar .gitignore** (já configurado):
   ```gitignore
   .gemini-flow/
   *.log
   .env
   ```

3. **Rotacionar API keys** regularmente

4. **Revisar código gerado** antes de usar em produção

### Colaboração

1. **Compartilhar configurações** (não secrets):
   ```bash
   cp .gemini-flow/config.json .gemini-flow/config.example.json
   git add .gemini-flow/config.example.json
   ```

2. **Documentar decisões** do hive mind:
   ```bash
   gemini-flow hive-mind history --export decisions.md
   ```

3. **Criar aliases personalizados** para o time

---

**Documento Mantido por**: Claude Code (projeto crowbar)
**Instalação**: 2025-11-02
**Localização**: `/opt/gemini-flow` + `/mnt/overpower/apps/dev/agl/crowbar/.gemini-flow`
**Licença**: MIT - Uso interno Projeto Crowbar

---

*Gemini Flow: Orquestrando 87 agentes especializados para desenvolvimento ágil e inteligente! 🌟🚀⚡*
