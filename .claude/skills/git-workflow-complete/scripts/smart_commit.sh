#!/bin/bash
# Smart Commit Script - Conventional Commits com Auto-Detecção
# Uso: bash smart_commit.sh ["mensagem opcional"]

set -e

MESSAGE=${1:-}

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Smart Commit Script${NC}"
echo ""

# Verificar se há alterações para commit
if [[ -z $(git status --porcelain) ]]; then
    echo -e "${YELLOW}⚠️  Nenhuma alteração para commit${NC}"
    exit 0
fi

# Mostrar status
echo -e "${BLUE}📋 Git Status:${NC}"
git status --short
echo ""

# Se não houver mensagem, analisar e sugerir
if [[ -z "$MESSAGE" ]]; then
    echo -e "${BLUE}🔍 Analisando alterações...${NC}"

    # Obter arquivos alterados (staged ou working tree)
    # Reason: usar git status --porcelain para obter filenames preservando nomes com espaços
    CHANGED_FILES=$(git status --porcelain | sed 's/^...//')

    # Detectar escopo baseado nos arquivos alterados
    SCOPE="chore"
    if echo "$CHANGED_FILES" | grep -q "src/api"; then
        SCOPE="api"
    elif echo "$CHANGED_FILES" | grep -qE "src/(app|resources|routes)"; then
        SCOPE="laravel"
    elif echo "$CHANGED_FILES" | grep -q "config/litellm"; then
        SCOPE="litellm"
    elif echo "$CHANGED_FILES" | grep -qE "docker|docker-compose"; then
        SCOPE="docker"
    elif echo "$CHANGED_FILES" | grep -qE "^docs/|\.md$"; then
        SCOPE="docs"
    elif echo "$CHANGED_FILES" | grep -qE "^scripts/"; then
        SCOPE="scripts"
    elif echo "$CHANGED_FILES" | grep -qE "^tests?/|\.test\.|\.spec\."; then
        SCOPE="tests"
    fi

    # Detectar tipo baseado nos padrões de arquivo
    TYPE="feat"
    if echo "$CHANGED_FILES" | grep -qE "test|spec"; then
        TYPE="test"
    elif echo "$CHANGED_FILES" | grep -qE "\.md$|README|CHANGELOG"; then
        TYPE="docs"
    elif echo "$CHANGED_FILES" | grep -qE "^fix|hotfix"; then
        TYPE="fix"
    elif echo "$CHANGED_FILES" | grep -qE "refactor|restructure"; then
        TYPE="refactor"
    elif echo "$CHANGED_FILES" | grep -qE "^config|\.config\.|config/"; then
        TYPE="config"
    fi

    # Contar arquivos alterados - usar printf para evitar contagem incorreta de linhas vazias
    if [[ -z "$CHANGED_FILES" ]]; then
        FILE_COUNT=0
    else
        FILE_COUNT=$(printf '%s\n' "$CHANGED_FILES" | grep -c '^')
    fi

    MESSAGE="$TYPE($SCOPE): atualização em $FILE_COUNT arquivo(s)"

    echo -e "${GREEN}✅ Mensagem gerada: $MESSAGE${NC}"
fi

# Adicionar todas as alterações
echo -e "${BLUE}➕ Adicionando alterações...${NC}"
git add -A

# Criar commit com mensagem formatada
CLAUDE_FOOTER="

🤖 Autor: Claude Code
📅 Data: $(date '+%Y-%m-%d %H:%M:%S')"

echo -e "${BLUE}💾 Criando commit...${NC}"
git commit -m "$MESSAGE$CLAUDE_FOOTER"

# Push para remote
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}🚀 Push para origin/$CURRENT_BRANCH...${NC}"
git push -u origin "$CURRENT_BRANCH"

echo ""
echo -e "${GREEN}✅ Commit e push concluídos!${NC}"
echo -e "${GREEN}   Mensagem: $MESSAGE${NC}"

# Mostrar status final
echo ""
echo -e "${BLUE}📊 Status Final:${NC}"
git log --oneline -3
