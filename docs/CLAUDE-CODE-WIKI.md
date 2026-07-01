# Claude Code Wiki - Histórico Completo e Configuração AGL

> **Última Atualização**: 2026-07-01 | **Versão**: 2.0.0  
> **Abrangência**: Histórico completo do claude-code desde sempre, integração ruflo/claude-flow, e configuração atual do ambiente de desenvolvimento

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Histórico Completo do Claude Code](#histórico-completo-do-claude-code)
3. [Integração Ruflo/Claude Flow](#integração-rufloclaude-flow)
4. [Arquitetura e Componentes](#arquitetura-e-componentes)
5. [Configuração AGL](#configuração-agl)
6. [Modelos e Provedores](#modelos-e-provedores)
7. [Scripts e Ferramentas](#scripts-e-ferramentas)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)
10. [Roadmap e Evolução](#roadmap-e-evolução)

---

## 🎯 Visão Geral

Este documento documenta o ecossistema completo do **Claude Code** na AGL, incluindo sua evolução histórica, integração com o **Ruflo/Claude Flow**, e toda a configuração atual do ambiente de desenvolvimento.

### Elementos Principais

- **Claude Code**: Interface principal para interação com modelos AI
- **Ruflo/Claude Flow**: Sistema de orquestração de agentes em swarm
- **LiteLLM Gateway**: Proxy para múltiplos provedores de modelos
- **AGL Configuration**: Configuração customizada para a agência AGL
- **Status Line**: Sistema de monitoramento em tempo real

---

## 📚 Histórico Completo do Claude Code

### Era 0: Configuração Inicial (2024)

#### Primeira Configuração Básica
```json
// .claude/settings.json inicial
{
  "statusLine": {
    "type": "command",
    "command": "node .claude/helpers/statusline.cjs"
  }
}
```

#### Problemas Iniciais
- Erros de módulos ESM com pnpm
- Conflito entre instalações npm e pnpm
- PATH configuration issues

### Era 1: Ruflo/Claude Flow Integration (2024-2025)

#### V2.7.0-alpha.14 Alpha 128
- **Build System Fixed**: Remoção de 32 arquivos UI, compilação limpa
- **Memory Coordination**: Validação MCP tools totalmente operacional
- **Agent Updates**: Todos os agentes core com MCP tool integration
- **Hive-Mind Agents**: 5 novos agentes com memory coordination
- **Command System**: Todos os CLI commands testados e funcionando

#### Solução do Problema ESM Module
```bash
# Problema: SyntaxError: The requested module 'signal-exit' does not provide an export named 'default'
# Causa: Incompatibilidade de módulos ESM no ecossistema pnpm
# Solução: Forçar uso do executável do NVM via aliases permanentes
```

**Aliases Implementados**:
```bash
# ~/.bashrc e ~/.zshrc
alias claude-flow="/root/.nvm/versions/node/v18.20.8/bin/claude-flow"
```

### Era 2: AGL Configuration (2025-2026)

#### Multi-Provider Setup
```bash
# Configuração de múltiplos provedores
export CC_PROVIDER=litellm          # LiteLLM Gateway CT186
export CC_PROVIDER=direct           # Acesso direto
export CC_PROVIDER=anthropic        # Anthropic Cloud
```

#### Status Line Evolution
- **Versão 1.0**: Básico com modelo e diretório
- **Versão 2.0**: Git status, custo, duração
- **Versão 3.0**: Context percentage, alerts
- **Versão 4.0**: Production ready com cache e alerts avançados

### Era 3: Agent Teams Integration (2026)

#### V3.0.0 com Agent Teams
- **Enabled**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`
- **Swarm Topology**: Hierarchical-mesh
- **Max Agents**: 15
- **Memory Backend**: Hybrid com HNSW
- **Neural**: Enabled com learning bridge

---

## 🐝 Integração Ruflo/Claude Flow

### Arquitetura Completa

#### Hive Mind System
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

### Configuração do Ruflo

#### environment.d/hive-mind.env
```bash
# Hive Mind - Coordenação multi-agente Ruflo
HIVE_MIND_TOPOLOGY="${HIVE_MIND_TOPOLOGY:-mesh}"
HIVE_MIND_MAX_AGENTS="${HIVE_MIND_MAX_AGENTS:-8}"
HIVE_MIND_CONSENSUS="${HIVE_MIND_CONSENSUS:-raft}"
HIVE_MIND_QUEEN_TYPE="${HIVE_MIND_QUEEN_TYPE:-tactical}"
```

#### agent-os-swarm.yml
```yaml
# Configuração do swarm Ruflo
topology: hierarchical-mesh
max_agents: 15
consensus: raft
queen_type: strategic
```

### Aliases e Funções Zsh

#### Sistema de Aliases
```bash
# aliases principais
alias hive='_hive_auto'              # Modo auto-spawn completo
alias hive-quick='_hive_quick'        # Modo rápido (menos verbose)
alias hive-manual='_hive_manual'      # Controle manual (sem auto-spawn)
alias hive-seq='_hive_seq'            # Modo sequencial (sem paralelização)

# aliases utilitários
alias hive-help='claude-flow hive-mind --help'
alias hive-status='claude-flow hive-mind status'
alias hive-agents='claude-flow hive-mind list-agents'
```

#### Funções Zsh
```bash
# _hive_auto (Recomendado para uso geral)
_hive_auto() {
    claude-flow hive-mind spawn "$*" --claude
}

# _hive_manual (Para controle fino)
_hive_manual() {
    claude-flow hive-mind spawn "$*" --claude --verbose
}
```

---

## ⚙️ Arquitetura e Componentes

### Claude Code Settings (.claude/settings.json)

#### Configuração Completa V3.0.0
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/helpers/hook-handler.cjs pre-bash",
            "timeout": 5000
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/helpers/hook-handler.cjs post-edit",
            "timeout": 10000
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/helpers/hook-handler.cjs session-restore",
            "timeout": 15000
          },
          {
            "type": "command",
            "command": "node .claude/helpers/auto-memory-hook.mjs import",
            "timeout": 8000
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "node .claude/helpers/statusline.cjs"
  },
  "permissions": {
    "allow": [
      "Bash(npx @claude-flow*)",
      "Bash(npx claude-flow*)",
      "Bash(node .claude/*)",
      "mcp__claude-flow__:*"
    ]
  },
  "attribution": {
    "commit": "Co-Authored-By: claude-flow <ruv@ruv.net>",
    "pr": "🤖 Generated with [claude-flow](https://github.com/ruvnet/claude-flow)"
  },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_FLOW_V3_ENABLED": "true",
    "CLAUDE_FLOW_HOOKS_ENABLED": "true",
    "LITELLM_GATEWAY_URL": "http://100.125.249.8:4000"
  },
  "claudeFlow": {
    "version": "3.0.0",
    "enabled": true,
    "modelPreferences": {
      "default": "claude-opus-4-6",
      "routing": "claude-haiku-4-5-20251001"
    },
    "agentTeams": {
      "enabled": true,
      "teammateMode": "auto",
      "taskListEnabled": true,
      "mailboxEnabled": true,
      "coordination": {
        "autoAssignOnIdle": true,
        "trainPatternsOnComplete": true,
        "notifyLeadOnComplete": true,
        "sharedMemoryNamespace": "agent-teams"
      }
    },
    "swarm": {
      "topology": "hierarchical-mesh",
      "maxAgents": 15
    },
    "memory": {
      "backend": "hybrid",
      "enableHNSW": true,
      "learningBridge": {
        "enabled": true
      },
      "memoryGraph": {
        "enabled": true
      },
      "agentScopes": {
        "enabled": true
      }
    },
    "neural": {
      "enabled": true
    },
    "daemon": {
      "autoStart": true,
      "workers": [
        "map",
        "audit",
        "optimize",
        "consolidate",
        "testgaps",
        "ultralearn",
        "deepdive",
        "document",
        "refactor",
        "benchmark"
      ],
      "schedules": {
        "audit": {
          "interval": "1h",
          "priority": "critical"
        },
        "optimize": {
          "interval": "30m",
          "priority": "high"
        },
        "consolidate": {
          "interval": "2h",
          "priority": "low"
        },
        "document": {
          "interval": "1h",
          "priority": "normal",
          "triggers": [
            "adr-update",
            "api-change"
          ]
        },
        "deepdive": {
          "interval": "4h",
          "priority": "normal",
          "triggers": [
            "complex-change"
          ]
        }
      }
    },
    "learning": {
      "enabled": true,
      "autoTrain": true,
      "patterns": [
        "coordination",
        "optimization",
        "prediction"
      ],
      "retention": {
        "shortTerm": "24h",
        "longTerm": "30d"
      }
    },
    "adr": {
      "autoGenerate": true,
      "directory": "/docs/adr",
      "template": "madr"
    },
    "ddd": {
      "trackDomains": true,
      "validateBoundedContexts": true,
      "directory": "/docs/ddd"
    },
    "security": {
      "autoScan": true,
      "scanOnEdit": true,
      "cveCheck": true,
      "threatModel": true
    }
  }
}
```

### Sistema de Hooks

#### Session Management
```bash
# SessionStart: Restaurar sessão + importar memória
"SessionStart": [
  {
    "command": "node .claude/helpers/hook-handler.cjs session-restore",
    "timeout": 15000
  },
  {
    "command": "node .claude/helpers/auto-memory-hook.mjs import",
    "timeout": 8000
  }
]
```

#### Auto-Memory System
```javascript
// auto-memory-hook.mjs
export async function import() {
  // Importar memória de sessões anteriores
  // Sincronizar com sistema de memória híbrida
}

export async function sync() {
  // Salvar memória ao encerrar sessão
  // Atualizar gráfico de memória
}
```

---

## 🏢 Configuração AGL

### Template de Configuração zshrc-claude-code.template.zsh

#### Variáveis de Ambiente
```bash
# URLs e chaves (substituir placeholders)
export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://TAILSCALE_CT186_IP:4000}"
export LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-}"

export GLM_URL="${GLM_URL:-https://api.z.ai/api/anthropic}"
export ZAI_API_KEY="${ZAI_API_KEY:-your-zai-api-key}"

export KIMI_URL="${KIMI_URL:-https://api.moonshot.ai/anthropic}"
export MOONSHOT_API_KEY="${MOONSHOT_API_KEY:-your-moonshot-key}"

export DEEPSEEK_URL="${DEEPSEEK_URL:-https://api.deepseek.com/anthropic}"
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-your-deepseek-key}"

export OPENROUTER_URL="${OPENROUTER_URL:-https://openrouter.ai/api}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-your-openrouter-key}"
```

#### Funções Provider Settings
```bash
# Configuração de provedores
_cc_provider_settings_args() {
  case "${CC_PROVIDER:-litellm}" in
    litellm)
      local settings="${HOME}/.claude/settings-litellm.json"
      if [[ -f ".claude/settings.litellm.json" ]]; then
        settings="$(pwd)/.claude/settings.litellm.json"
      fi
      [[ -f "$settings" ]] || return 1
      export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-${LITELLM_GATEWAY_URL}}"
      export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-${AGL_CC_MODEL_DEFAULT:-agl-primary}}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL:-${AGL_CC_MODEL_SONNET:-agl-primary}}"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL:-${AGL_CC_MODEL_OPUS:-agl-primary-strong}}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}}"
      export ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}}"
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
      REPLY=(--bare --settings "$settings")
      return 0
      ;;
    direct)
      local base="${ANTHROPIC_BASE_URL:-${MODEL_BASE_URL:-}}"
      [[ -n "$base" ]] || return 1
      REPLY=(--bare --settings "{\"env\":{\"ANTHROPIC_BASE_URL\":\"${base}\",\"ANTHROPIC_API_KEY\":\"${ANTHROPIC_AUTH_TOKEN:-${MODEL_AUTH_TOKEN:-}}\",\"ANTHROPIC_AUTH_TOKEN\":\"\"}}")
      return 0
      ;;
    anthropic|*)
      local settings="${HOME}/.claude/settings-anthropic.json"
      [[ -f "$settings" ]] || return 1
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
      unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL
      unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_SMALL_FAST_MODEL
      REPLY=(--settings "$settings")
      return 0
      ;;
  esac
}
```

#### Aliases de Acesso
```bash
# cc  — sessão interactiva (TUI)
cc() {
    local -a cmd=()
    if _cc_provider_settings_args; then cmd=("${REPLY[@]}"); fi
    if _claude_use_dsp; then
        claude "${cmd[@]}" --dangerously-skip-permissions "$@"
    else
        claude "${cmd[@]}" "$@"
    fi
}

# ccs — one-shot (claude -p), imprime e sai
ccs() {
    local -a cmd=(claude)
    if _cc_provider_settings_args; then cmd+=("${REPLY[@]}"); fi
    cmd+=(-p --output-format text)
    if _claude_use_dsp; then
        cmd+=(--dangerously-skip-permissions)
    elif [[ $EUID -eq 0 && -n "${IS_SANDBOX:-}" && "${IS_SANDBOX}" != "0" ]]; then
        cmd+=(--dangerously-skip-permissions)
    fi
    [[ $# -gt 0 ]] || { echo "Uso: ccs 'prompt'" >&2; return 1; }
    "${cmd[@]}" "$@" < /dev/null
}

# cccl — Anthropic Cloud (OAuth / Pro)
cccl() {
    cc_envs3
    echo "✅ Anthropic Cloud (CC_PROVIDER=anthropic, OAuth)"
}

# ccll — LiteLLM gateway CT186
ccll() {
    export CC_PROVIDER=litellm
    export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://TAILSCALE_CT186_IP:4000}"
    export ANTHROPIC_BASE_URL="${LITELLM_GATEWAY_URL}"
    export ANTHROPIC_MODEL="${AGL_CC_MODEL_DEFAULT:-agl-primary-zai-glm-flash}"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="${AGL_CC_MODEL_SONNET:-agl-primary-zai-glm-flash}"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="${AGL_CC_MODEL_OPUS:-agl-primary-strong}"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}"
    export ANTHROPIC_SMALL_FAST_MODEL="${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}"
    if [[ -z "${LITELLM_MASTER_KEY:-}" && -r "${HOME}/.openclaw/litellm-master.secret.env" ]]; then
        source "${HOME}/.openclaw/litellm-master.secret.env"
    fi
    unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
    echo "✓ LiteLLM: $ANTHROPIC_BASE_URL [${AGL_CC_MODEL_DEFAULT:-agl-primary-zai-glm-flash}]"
}

# ccz — Z.AI directo (GLM-5)
ccz() {
    export MODEL_ROBUST="glm-5"
    export MODEL_FAST="glm-5-air"
    export MODEL_BASE_URL="$GLM_URL"
    export MODEL_AUTH_TOKEN="$ZAI_API_KEY"
    cc_envs
    echo "✓ Z.AI directo ($MODEL_BASE_URL)"
}
```

---

## 🤖 Modelos e Provedores

### AGL Model Configuration

#### LiteLLM Gateway (CT186)
```json
{
  "model": "claude-sonnet-5",
  "env": {
    "ANTHROPIC_BASE_URL": "http://100.125.249.8:4000",
    "LITELLM_GATEWAY_URL": "http://100.125.249.8:4000",
    "ANTHROPIC_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001",
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-haiku-4-5-20251001"
  }
}
```

#### Custom AGL Models
```bash
# Modelos customizados da AGL
export AGL_CC_MODEL_DEFAULT="agl-primary-zai-glm-flash"
export AGL_CC_MODEL_SONNET="agl-primary-zai-glm-flash"
export AGL_CC_MODEL_OPUS="agl-primary-strong"
export AGL_CC_MODEL_HAIKU="agl-primary-zai-glm-flash"
```

### Provedores Suportados

#### 1. LiteLLM Gateway (Padrão)
- **URL**: `http://100.125.249.8:4000`
- **Modelos**: Claude Sonnet 5, Claude Opus 4.8, Claude Haiku 4.5
- **Vantagens**: Multi-provedor, load balancing, caching

#### 2. Acesso Direto
- **URL**: Custom (Z.AI, Kimi, DeepSeek, OpenRouter)
- **Modelos**: GLM-5, Moonshot, etc.
- **Vantagens**: Latência menor, controle total

#### 3. Anthropic Cloud
- **URL**: Anthropic official
- **Modelos**: Claude 3.5 Sonnet, Claude 3 Opus
- **Vantagens**: Official support, OAuth integration

---

## 🛠️ Scripts e Ferramentas

### ccll.sh - LiteLLM Configuration
```bash
#!/usr/bin/env bash
# ccll — Configura Claude Code / Claude-Flow para usar LiteLLM
# Uso: source scripts/ccll.sh   ou   . scripts/ccll.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="$("$REPO_ROOT/.claude/helpers/get-litellm-key.sh")"

if [[ -z "$KEY" ]]; then
  echo "⚠️  ccll: LITELLM_MASTER_KEY não encontrado em config/litellm/.env ou /opt/litellm/.env"
  echo "   Usando fallback sk-litellm-default (pode falhar com 401)"
  KEY="sk-litellm-default"
fi

export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://localhost:4000}"
export ANTHROPIC_BASE_URL="${LITELLM_GATEWAY_URL}"
export ANTHROPIC_AUTH_TOKEN="$KEY"
export ANTHROPIC_API_KEY="$KEY"

echo "✓ Claude Code/Claude-Flow → LiteLLM ($LITELLM_GATEWAY_URL)"
```

### claude-flow - Local Wrapper
```bash
#!/usr/bin/env bash
# Claude-Flow local wrapper
# This script ensures claude-flow runs from your project directory

# Save the current directory
PROJECT_DIR="${PWD}"

# Set environment to ensure correct working directory
export PWD="${PROJECT_DIR}"
export CLAUDE_WORKING_DIR="${PROJECT_DIR}"

# Try to find claude-flow binary
# 1. Local node_modules
if [ -f "${PROJECT_DIR}/node_modules/.bin/claude-flow" ]; then
  cd "${PROJECT_DIR}"
  exec "${PROJECT_DIR}/node_modules/.bin/claude-flow" "$@"
# 2. Parent directory node_modules
elif [ -f "${PROJECT_DIR}/../node_modules/.bin/claude-flow" ]; then
  cd "${PROJECT_DIR}"
  exec "${PROJECT_DIR}/../node_modules/.bin/claude-flow" "$@"
# 3. Global installation
elif command -v claude-flow &> /dev/null; then
  cd "${PROJECT_DIR}"
  exec claude-flow "$@"
# 4. Fallback to npx
else
  cd "${PROJECT_DIR}"
  exec npx claude-flow@latest "$@"
fi
```

### Status Line Production-Ready
```bash
#!/bin/bash
set -euo pipefail

# Cache configuration
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
CACHE_FILE="$CACHE_DIR/git_cache"
CACHE_TTL=5
mkdir -p "$CACHE_DIR"

# Colors
readonly COLOR_RESET='\033[0m'
readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_GREEN='\033[1;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[1;31m'
readonly COLOR_MAGENTA='\033[1;35m'
readonly COLOR_CYAN='\033[1;36m'

# Read JSON from stdin
INPUT=$(cat)

# Parse JSON with jq (with defaults)
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Unknown"')
DIR=$(echo "$INPUT" | jq -r '.cwd | split("/") | last // "/"')
COST=$(echo "$INPUT" | jq -r '.cost.total_cost // 0')
DURATION_MS=$(echo "$INPUT" | jq -r '.cost.duration_ms // 0')
TOKENS=$(echo "$INPUT" | jq -r '.usage.total_tokens // 0')
CONTEXT_PCT=$(echo "$INPUT" | jq -r '.context.usage_percentage // 0')

# Calculate duration in minutes
DURATION=$(echo "scale=1; $DURATION_MS / 60000" | bc)

# Git information (cached)
get_git_info() {
  local cache_age=999999
  
  if [ -f "$CACHE_FILE" ]; then
    cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
  fi
  
  if [ $cache_age -lt $CACHE_TTL ] && [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
  else
    if [ -d .git ]; then
      local branch=$(git branch --show-current 2>/dev/null || echo "detached")
      local status=$(git status --porcelain 2>/dev/null | wc -l)
      local icon="✓"
      [ "$status" -gt 0 ] && icon="✗ $status"
      echo "🌿 $branch $icon" > "$CACHE_FILE"
      cat "$CACHE_FILE"
    else
      echo "" > "$CACHE_FILE"
      cat "$CACHE_FILE"
    fi
  fi
}

GIT_INFO=$(get_git_info)
GIT_STR=""
[ -n "$GIT_INFO" ] && GIT_STR=" $GIT_INFO"

# Cost color based on threshold
COST_COLOR="$COLOR_GREEN"
if (( $(echo "$COST > 0.50" | bc -l) )); then
  COST_COLOR="$COLOR_YELLOW"
fi
if (( $(echo "$COST > 1.00" | bc -l) )); then
  COST_COLOR="$COLOR_RED"
fi

# Context color based on threshold
CONTEXT_COLOR="$COLOR_GREEN"
if (( $(echo "$CONTEXT_PCT > 70" | bc -l) )); then
  CONTEXT_COLOR="$COLOR_YELLOW"
fi
if (( $(echo "$CONTEXT_PCT > 85" | bc -l) )); then
  CONTEXT_COLOR="$COLOR_RED"
fi

# Build output
OUTPUT="${COLOR_BLUE}📂 $DIR${COLOR_RESET}"
OUTPUT+="$GIT_STR"
OUTPUT+=" ${COLOR_MAGENTA}🤖 $MODEL${COLOR_RESET}"
OUTPUT+=" ${COST_COLOR}💰 \$$(printf "%.4f" $COST)${COLOR_RESET}"
OUTPUT+=" ${COLOR_CYAN}🕒 ${DURATION}m${COLOR_RESET}"
OUTPUT+=" ${CONTEXT_COLOR}📊 ${CONTEXT_PCT}%${COLOR_RESET}"

# Print output
echo -e "$OUTPUT"

# Cleanup old cache files (> 1 hour)
find "$CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null || true
```

---

## 🎯 Best Practices

### Performance Optimization

#### Status Line
1. **Cache Git operations**: Atualizar a cada 5s
2. **Use shell built-ins**: Evitar subprocesses pesados
3. **Limit output**: Manter conciso e informativo
4. **Error handling**: Sempre incluir tratamento de erros

#### Claude Flow
1. **Always use aliases**: Nunca usar caminhos absolutos
2. **Start with `hive`**: Para tarefas gerais (auto-spawn)
3. **Use `hive-manual`**: Para controle fino
4. **Check `hive-status`**: Antes de spawnar novo swarm

### Security Practices

1. **Never commit** directories: `.hive-mind/`, `.claude-flow/`
2. **Add to .gitignore**:
   ```
   .hive-mind/
   .claude-flow/
   node_modules/
   ```

3. **Review generated code**: Antes de commitar
4. **Use manual mode**: Para operações sensíveis (deploy, migrations)

### Collaboration

1. **Document complex objectives**: Antes de passar para hive
2. **Share session IDs**: Com time quando relevante
3. **Create custom aliases**: Para workflows do projeto
4. **Keep this document updated**: Com descobertas

---

## 🔧 Troubleshooting

### Common Issues

#### 1. ESM Module Error
```bash
# Sintoma: SyntaxError: The requested module 'signal-exit' does not provide an export named 'default'
# Solução: Verificar que está usando o alias correto
type claude-flow
# Deve mostrar: claude-flow is an alias for /root/.nvm/...

# Se não estiver, recarregar shell
source ~/.bashrc  # ou source ~/.zshrc
```

#### 2. Comando `hive` não encontrado
```bash
# Verificar se ~/.zshrc tem as funções
grep "_hive_auto" ~/.zshrc

# Recarregar configuração
source ~/.zshrc

# Testar em shell interativo
zsh -i -c "type hive"
```

#### 3. Claude Flow não encontra npm
```bash
# Verificar que NVM está ativo
nvm current

# Usar versão correta do Node
nvm use 18.20.8

# Reinstalar claude-flow
npm install -g claude-flow@latest
```

#### 4. Sessions não salvam
```bash
# Verificar diretório de sessions
ls -la .hive-mind/sessions/

# Verificar permissões
chmod -R 755 .hive-mind/

# Verificar variável de ambiente
echo $CLAUDE_FLOW_CHECKPOINTS_ENABLED
# Deve ser: true
```

### Performance Issues

#### Statusline Lag
```bash
# Teste de performance
time echo '{"model":{"display_name":"Test"},"cwd":"/test"}' | ~/.claude/statusline.sh

# Deve executar em < 100ms idealmente
```

#### Memory Usage
```bash
# Monitorar uso de memória em swarms grandes
watch -n 1 'cat .hive-mind/sessions/*/workers/*.json | jq .memory_usage'
```

---

## 🚀 Roadmap e Evolução

### Versão 3.0.0 (Atual - 2026)

#### ✅ Implementado
- Agent Teams com múltiplos agentes
- Memory backend híbrido com HNSW
- Neural learning enabled
- Daemon workers agendados
- Security scanning automático

#### 🔄 Em Progresso
- Integration com llm-wiki AGLz
- Melhoria no sistema de hooks
- Otimização de performance do swarm

### Versão 4.0.0 (Planejado)

#### 📋 Roadmap
- **Multi-Agent Coordination**: Sistema de coordenação avançado entre swarms
- **Enhanced Memory**: Graph database integration
- **Security**: Advanced threat modeling
- **Performance**: Distributed caching
- **Integration**: MCP tools expansion

#### 🎯 Metas
- Suportar até 50 agentes simultâneos
- Tempo de resposta < 100ms para todas as operações
- 99.9% uptime do sistema swarm
- Zero-touch deployment

### Histórico de Versões

| Versão | Data | Principais Mudanças |
|--------|------|-------------------|
| 1.0.0 | 2024 | Configuração inicial básica |
| 2.0.0 | 2025 | Ruflo/Claude Flow integration |
| 2.7.0 | 2025 | Agent Teams, Memory coordination |
| 3.0.0 | 2026 | V3 Alpha, Neural learning, Security |

---

## 📚 Documentos Relacionados

- [CLAUDE-FLOW.md](./CLAUDE-FLOW.md) - Documentação detalhada do Claude Flow
- [CLAUDE_CODE_STATUSLINE_BEST_PRACTICES.md](./CLAUDE_CODE_STATUSLINE_BEST_PRACTICES.md) - Melhores práticas da status line
- [LLM-WIKI-AGENCY-INTEGRATION.md](./LLM-WIKI-AGENCY-INTEGRATION.md) - Integração com llm-wiki AGLz
- [SIX-REPOS-MULTI-AGENT-PLAN.md](../ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md) - Plano Six Repos

---

## 📝 Changelog

### v2.0.0 - 2026-07-01
- ✅ **Histórico completo**: Documentação desde o início do claude-code
- ✅ **Integração Ruflo/Claude Flow**: Documentação completa do sistema swarm
- ✅ **Configuração AGL**: Templates e variáveis de ambiente
- ✅ **Scripts**: Documentação de todos os scripts utilitários
- ✅ **Best Practices**: Diretrizes completas de uso
- ✅ **Troubleshooting**: Soluções para problemas comuns

### v1.0.0 - 2025-11-02
- ✅ Documentação inicial do Claude Flow
- ✅ Análise detalhada do problema ESM
- ✅ Solução com aliases permanentes
- ✅ Guia completo de comandos e uso

---

**Documento mantido por**: Claude Code (AGL Hostman Project)  
**Contato**: Ver documentos relacionados para suporte  
**Licença**: Uso interno - AGL Agency

---

*Claude Code: Orquestrando inteligência artificial em swarm para desenvolvimento ágil! 🐝⚡🚀*