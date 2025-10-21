# Claude Code Statusline - Melhores Práticas e Exemplos

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Configuração Rápida](#configuração-rápida)
3. [Melhores Práticas](#melhores-práticas)
4. [Exemplos de Implementação](#exemplos-de-implementação)
5. [Ferramentas Populares](#ferramentas-populares)
6. [Otimização de Performance](#otimização-de-performance)
7. [Troubleshooting](#troubleshooting)

---

## Visão Geral

O **statusline** do Claude Code é uma linha de status customizável exibida na parte inferior da interface, similar ao prompt do terminal (PS1) em shells como Oh-my-zsh. Ele permite monitorar informações contextuais em tempo real durante suas sessões.

### Como Funciona

- **Atualização**: Dispara quando mensagens da conversa mudam
- **Frequência**: Máximo a cada 300ms (otimizado para performance)
- **Input**: Recebe dados de contexto via stdin como JSON
- **Output**: Primeira linha do stdout se torna o status line
- **Estilo**: Suporta códigos de cor ANSI

### Estrutura JSON de Entrada

```json
{
  "session_id": "abc-123",
  "model": {
    "id": "claude-sonnet-4-5-20250929",
    "display_name": "Sonnet 4.5"
  },
  "workspace": {
    "current_dir": "/path/to/project",
    "project_dir": "/path/to/project"
  },
  "cwd": "/path/to/project",
  "cost": {
    "total_cost": 0.05,
    "duration_ms": 123456,
    "lines_added": 150,
    "lines_removed": 45
  },
  "version": "1.0.0",
  "output_style": "default"
}
```

---

## Configuração Rápida

### Método 1: Comando Interativo (Recomendado)

```bash
/statusline
```

Claude Code irá configurar automaticamente um statusline apropriado para seu ambiente.

### Método 2: Configuração Manual

Adicione ao `.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

---

## Melhores Práticas

### 🎯 Design e UX

1. **Mantenha Conciso**: Uma linha única, sem poluição visual
2. **Priorize Informações**: Mostre apenas dados críticos
3. **Use Cores Estrategicamente**:
   - 🟢 Verde: Status normal
   - 🟡 Amarelo: Avisos/warnings
   - 🔴 Vermelho: Erros ou uso excessivo
   - 🔵 Azul: Informações de caminho/contexto
4. **Emojis para Escaneabilidade**: Use ícones para identificação rápida
5. **Consistência Visual**: Mantenha padrões de cores e formatos

### 🛠️ Implementação Técnica

1. **Teste Antes de Deploy**:
   ```bash
   echo '{"model":{"display_name":"Sonnet"},"cwd":"/test"}' | ~/.claude/statusline.sh
   ```

2. **Permissões de Execução**:
   ```bash
   chmod +x ~/.claude/statusline.sh
   ```

3. **Error Handling**: Sempre inclua tratamento de erros
   ```bash
   #!/bin/bash
   set -euo pipefail  # Fail on errors
   ```

4. **Output Correto**: Certifique-se de que output vai para stdout, não stderr

5. **Cache Operações Custosas**: Git status, verificações de rede, etc.

### ⚡ Performance

1. **Evite**:
   - ❌ Network requests
   - ❌ Large-scale directory scanning
   - ❌ Complex filesystem calculations
   - ❌ Comandos externos pesados

2. **Prefira**:
   - ✅ Shell built-ins
   - ✅ Ferramentas eficientes (jq, git)
   - ✅ Caching (atualizar a cada 5s)
   - ✅ Processamento simples de dados

### 📊 Informações Úteis para Exibir

**Essenciais**:
- 🤖 Modelo atual
- 📂 Branch Git + status
- 💰 Custo da sessão
- 🕒 Duração da sessão
- 📊 Uso de tokens/contexto

**Opcionais**:
- 📍 Diretório atual
- ⏱️ Block timer (5h window)
- 📈 Linhas adicionadas/removidas
- 🔥 Burn rate (custo/hora)
- 🎯 Contexto disponível (%)

---

## Exemplos de Implementação

### Exemplo 1: Bash Básico com jq

```bash
#!/bin/bash
set -euo pipefail

# Lê JSON do stdin
INPUT=$(cat)

# Extrai informações
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Unknown"')
DIR=$(echo "$INPUT" | jq -r '.cwd | split("/") | last')
COST=$(echo "$INPUT" | jq -r '.cost.total_cost // 0')

# Branch Git (se disponível)
BRANCH=""
if [ -d .git ]; then
  BRANCH=" 🌿 $(git branch --show-current 2>/dev/null || echo 'no-branch')"
fi

# Formata output com cores ANSI
echo -e "\033[1;34m📂 $DIR\033[0m$BRANCH \033[1;35m🤖 $MODEL\033[0m \033[1;32m💰 \$$(printf "%.4f" $COST)\033[0m"
```

### Exemplo 2: Python com Git Status Completo

```python
#!/usr/bin/env python3
import json
import sys
import subprocess
from pathlib import Path

def get_git_info():
    """Retorna informações Git formatadas"""
    try:
        # Branch atual
        branch = subprocess.check_output(
            ['git', 'branch', '--show-current'],
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()

        # Status (clean/dirty)
        status = subprocess.check_output(
            ['git', 'status', '--porcelain'],
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()

        status_icon = "✓" if not status else "✗"
        return f"🌿 {branch} {status_icon}"
    except:
        return ""

def main():
    # Lê JSON do stdin
    data = json.load(sys.stdin)

    # Extrai informações
    model = data.get('model', {}).get('display_name', 'Unknown')
    cwd = Path(data.get('cwd', '/')).name
    cost = data.get('cost', {}).get('total_cost', 0)
    duration = data.get('cost', {}).get('duration_ms', 0) / 1000 / 60  # minutos

    # Git info
    git_info = get_git_info()
    git_str = f" {git_info}" if git_info else ""

    # Formata output com cores ANSI
    output = (
        f"\033[1;34m📂 {cwd}\033[0m"
        f"{git_str} "
        f"\033[1;35m🤖 {model}\033[0m "
        f"\033[1;32m💰 ${cost:.4f}\033[0m "
        f"\033[1;36m🕒 {duration:.1f}m\033[0m"
    )

    print(output)

if __name__ == '__main__':
    main()
```

### Exemplo 3: Node.js com Cache

```javascript
#!/usr/bin/env node
const fs = require('fs');
const { execSync } = require('child_process');

// Cache simples (atualiza a cada 5s)
let gitCache = { time: 0, value: '' };
const CACHE_TTL = 5000; // 5 segundos

function getGitInfo() {
  const now = Date.now();
  if (now - gitCache.time < CACHE_TTL) {
    return gitCache.value;
  }

  try {
    const branch = execSync('git branch --show-current', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    }).trim();

    const status = execSync('git status --porcelain', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    }).trim();

    const icon = status ? '✗' : '✓';
    gitCache = {
      time: now,
      value: `🌿 ${branch} ${icon}`
    };

    return gitCache.value;
  } catch {
    return '';
  }
}

// Lê stdin
let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  const data = JSON.parse(input);

  const model = data.model?.display_name || 'Unknown';
  const dir = data.cwd?.split('/').pop() || '/';
  const cost = data.cost?.total_cost || 0;
  const duration = (data.cost?.duration_ms || 0) / 1000 / 60;

  const git = getGitInfo();
  const gitStr = git ? ` ${git}` : '';

  // Output com cores ANSI
  const output = [
    `\x1b[1;34m📂 ${dir}\x1b[0m`,
    gitStr,
    `\x1b[1;35m🤖 ${model}\x1b[0m`,
    `\x1b[1;32m💰 $${cost.toFixed(4)}\x1b[0m`,
    `\x1b[1;36m🕒 ${duration.toFixed(1)}m\x1b[0m`
  ].join(' ');

  console.log(output);
});
```

### Exemplo 4: Statusline Avançado com Alertas

```bash
#!/bin/bash
set -euo pipefail

INPUT=$(cat)

# Extrai dados
MODEL=$(echo "$INPUT" | jq -r '.model.display_name')
DIR=$(echo "$INPUT" | jq -r '.cwd | split("/") | last')
COST=$(echo "$INPUT" | jq -r '.cost.total_cost')
TOKENS=$(echo "$INPUT" | jq -r '.usage.total_tokens // 0')
CONTEXT_PCT=$(echo "$INPUT" | jq -r '.context.usage_percentage // 0')

# Git info
BRANCH=$(git branch --show-current 2>/dev/null || echo "no-git")
GIT_STATUS=$(git status --porcelain 2>/dev/null | wc -l)
GIT_ICON="✓"
[[ $GIT_STATUS -gt 0 ]] && GIT_ICON="✗ $GIT_STATUS"

# Alertas baseados em thresholds
COST_COLOR="\033[1;32m"  # Verde
[[ $(echo "$COST > 0.50" | bc -l) -eq 1 ]] && COST_COLOR="\033[1;33m"  # Amarelo
[[ $(echo "$COST > 1.00" | bc -l) -eq 1 ]] && COST_COLOR="\033[1;31m"  # Vermelho

CONTEXT_COLOR="\033[1;32m"
[[ $(echo "$CONTEXT_PCT > 70" | bc -l) -eq 1 ]] && CONTEXT_COLOR="\033[1;33m"
[[ $(echo "$CONTEXT_PCT > 85" | bc -l) -eq 1 ]] && CONTEXT_COLOR="\033[1;31m"

# Output formatado
echo -e "\033[1;34m📂 $DIR\033[0m \033[1;36m🌿 $BRANCH $GIT_ICON\033[0m \033[1;35m🤖 $MODEL\033[0m ${COST_COLOR}💰 \$$(printf "%.4f" $COST)\033[0m ${CONTEXT_COLOR}📊 ${CONTEXT_PCT}%\033[0m"
```

---

## Ferramentas Populares

### 1. ccstatusline (Recomendado)

**Características**:
- ⚡ Zero configuração - funciona out-of-the-box
- 🎨 Interface interativa para customização
- 🔥 Suporte a Powerline com símbolos bonitos
- 📊 20+ widgets disponíveis
- 🪟 Suporte completo para Windows

**Instalação**:
```bash
# Executar diretamente (sem instalação)
npx ccstatusline@latest

# Ou com Bun (mais rápido)
bunx ccstatusline@latest
```

**Configuração no Claude Code**:
```json
{
  "statusLine": {
    "type": "command",
    "command": "npx ccstatusline@latest"
  }
}
```

**Widgets Disponíveis**:
- Model Name
- Git Branch + Status
- Session Clock
- Block Timer (5h window)
- Current Working Directory
- Token Usage
- Context Percentage
- Custom Text/Commands
- Separadores customizáveis

### 2. claude-powerline (Estilo Vim)

**Características**:
- 🎨 5 temas built-in (dark, light, nord, tokyo-night, rose-pine)
- 📈 Métricas de performance (response time, message count)
- 🌿 Integração Git avançada (ahead/behind, stash, SHA)
- 💰 Tracking de custos e billing window
- ⚡ 3 estilos de separadores (minimal, powerline, capsule)

**Instalação**:
```json
{
  "statusLine": {
    "type": "command",
    "command": "npx -y @owloops/claude-powerline@latest --style=powerline"
  }
}
```

**Configuração**: `.claude-powerline.json`, `~/.claude/claude-powerline.json`, ou `~/.config/claude-powerline/config.json`

**Requisitos**:
- Node.js 18+
- Git 2.0+
- Terminal com Nerd Font

### 3. ccusage statusline

**Características**:
- 💰 Foco em custos e usage tracking
- 📊 Session cost, daily total, burn rate
- 🔥 Block timer com indicadores visuais
- 📈 Compact, real-time view

**Ideal para**: Monitorar custos em tempo real

---

## Otimização de Performance

### ⚡ Estratégias de Cache

```bash
#!/bin/bash
# Cache file
CACHE_FILE="/tmp/claude_statusline_cache_$$"
CACHE_TTL=5  # segundos

# Função para cache de git
get_git_cached() {
  if [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE")))
    if [ $CACHE_AGE -lt $CACHE_TTL ]; then
      cat "$CACHE_FILE"
      return
    fi
  fi

  # Atualiza cache
  git branch --show-current 2>/dev/null > "$CACHE_FILE"
  cat "$CACHE_FILE"
}
```

### 🚀 Processamento Eficiente

```python
# Use bibliotecas eficientes
import orjson  # Mais rápido que json nativo

# Evite subprocess quando possível
from pathlib import Path

# Rápido: Path operations
cwd = Path.cwd().name

# Lento: subprocess
# cwd = subprocess.check_output(['pwd']).decode().strip().split('/')[-1]
```

### 📊 Benchmarking

```bash
# Teste de performance do seu script
time echo '{"model":{"display_name":"Test"},"cwd":"/test"}' | ~/.claude/statusline.sh

# Deve executar em < 100ms idealmente
```

---

## Troubleshooting

### ❌ Statusline não aparece

**Verificações**:
1. Script tem permissão de execução?
   ```bash
   ls -l ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Settings.json está correto?
   ```bash
   cat ~/.claude/settings.json
   ```

3. Script produz output?
   ```bash
   echo '{"model":{"display_name":"Test"},"cwd":"/test"}' | ~/.claude/statusline.sh
   ```

### ❌ Caracteres Estranhos / Símbolos Quebrados

**Solução**: Instale uma Nerd Font
- Download: https://www.nerdfonts.com/
- Recomendados: FiraCode Nerd Font, JetBrainsMono Nerd Font
- Configure no terminal

### ❌ Performance Ruim / Lag

**Diagnóstico**:
```bash
# Adicione logging ao script
exec 2>> /tmp/statusline_debug.log
set -x
```

**Soluções**:
- Implemente caching
- Remova network requests
- Simplifique operações Git
- Use ferramentas mais rápidas (ripgrep vs grep)

### ❌ JSON Parse Errors

**Verificação**:
```bash
# Teste o JSON recebido
cat << 'EOF' | ~/.claude/statusline.sh
{"model":{"display_name":"Test"},"cwd":"/test","cost":{"total_cost":0.05}}
EOF
```

**Solução**: Valide JSON parsing com error handling
```python
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f"⚠️ JSON Error", file=sys.stderr)
    sys.exit(1)
```

---

## Recursos Adicionais

### Documentação Oficial
- [Claude Code Statusline Docs](https://docs.claude.com/en/docs/claude-code/statusline)
- [Terminal Config](https://docs.claude.com/en/docs/claude-code/terminal-config)

### Ferramentas e Projetos
- [ccstatusline GitHub](https://github.com/sirmalloc/ccstatusline)
- [claude-powerline GitHub](https://github.com/Owloops/claude-powerline)
- [ccusage](https://ccusage.com/guide/statusline)

### Artigos e Tutoriais
- [SDpower Technical Analysis](https://blog.sd.idv.tw/en/posts/2025-08-10_claude-code-statusline-analysis/)
- [Productivity Dashboard Guide](https://www.vibesparking.com/en/blog/ai/claude-code/ccstatusline/2025-08-20-ccstatusline-productivity-dashboard-guide/)

### ANSI Color Reference
```bash
# Cores básicas
\033[0;30m # Preto
\033[0;31m # Vermelho
\033[0;32m # Verde
\033[0;33m # Amarelo
\033[0;34m # Azul
\033[0;35m # Magenta
\033[0;36m # Ciano
\033[0;37m # Branco

# Bold
\033[1;3Xm # X = cor acima

# Reset
\033[0m
```

---

## Exemplo Completo: Statusline Production-Ready

```bash
#!/bin/bash
set -euo pipefail

# ============================================
# Claude Code Statusline - Production Ready
# ============================================

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

**Documento criado**: 2025-10-16
**Última atualização**: 2025-10-16
**Versão**: 1.0.0
