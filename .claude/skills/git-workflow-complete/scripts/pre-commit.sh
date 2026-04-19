#!/bin/bash
#
# Pre-commit hook para verificações de segurança e qualidade
# Instalar: ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit
#

set -e

# Cores para output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo -e "\n${BLUE}🔍 Running pre-commit checks...${NC}\n"

# 1. Verificar segredos/credenciais no código
echo -e "${BLUE}1. Verificando segredos no código...${NC}"
# Reason: usar while loop para preservar filenames com espaços
FOUND_SECRETS=$(git diff --cached --name-only | while IFS= read -r file; do
    # Skip se o arquivo foi deletado
    if [[ ! -f "$file" ]]; then continue; fi
    # Padrões de segredos comuns
    if grep -l -i "password\|secret\|api_key\|apikey\|token\|private_key\|aws_access_key_id\|aws_secret_access_key" "$file" 2>/dev/null; then
        echo "$file"
    fi
done | sort -u)

if [[ -n "$FOUND_SECRETS" ]]; then
    echo -e "${RED}⚠️  Possíveis segredos detectados nos arquivos:${NC}"
    echo "$FOUND_SECRETS"
    echo -e "${YELLOW}Por favor, remova segredos do código antes de commitar.${NC}\n"
    # Não bloquear, apenas avisar (false positive é comum)
fi

# 2. Verificar arquivos .env
echo -e "${BLUE}2. Verificando arquivos de ambiente...${NC}"
# Reason: usar while loop para preservar nomes de arquivos com espaços
ENV_FILES=$(git diff --cached --name-only | while IFS= read -r file; do
    if [[ "$file" =~ \.env$|\.env\.local$|\.env\.production$ ]]; then
        echo "$file"
    fi
done)

if [[ -n "$ENV_FILES" ]]; then
    echo -e "${RED}❌ Arquivos de ambiente detectados no commit:${NC}"
    echo "$ENV_FILES"
    echo -e "${YELLOW}Arquivos .env não devem ser commitados. Adicione ao .gitignore.${NC}\n"
    exit 1
fi

# 3. Verificar console.log / debug statements
echo -e "${BLUE}3. Verificando debug statements...${NC}"
# Reason: iterar sobre arquivos preservando nomes com espaços, sem usar xargs
DEBUG_FOUND=false
JS_FOUND=false
git diff --cached --name-only | while IFS= read -r file; do
    # Verificar se é arquivo JS/TS
    if [[ "$file" =~ \.(js|ts|jsx|tsx)$ ]]; then
        JS_FOUND=true
        # Skip se o arquivo foi deletado
        if [[ ! -f "$file" ]]; then continue; fi
        # Procurar por debug statements
        MATCHES=$(grep -n "console\.log\|debugger;\|print(" "$file" 2>/dev/null || true)
        if [[ -n "$MATCHES" ]]; then
            DEBUG_FOUND=true
            echo -e "${YELLOW}   $file:${NC}"
            echo "$MATCHES" | sed 's/^/     /'
        fi
    fi
done

if [[ "$DEBUG_FOUND" == "true" ]]; then
    echo -e "${YELLOW}⚠️  Debug statements encontrados acima.${NC}\n"
fi

# 4. Verificar arquivos muito grandes (>1MB)
echo -e "${BLUE}4. Verificando tamanho dos arquivos...${NC}"
LARGE_FILES=$(git diff --cached --name-only | while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        if [[ $SIZE -gt 1048576 ]]; then
            echo "$file ($((SIZE / 1024 / 1024))MB)"
        fi
    fi
done)

if [[ -n "$LARGE_FILES" ]]; then
    echo -e "${YELLOW}⚠️  Arquivos grandes (>1MB) detectados:${NC}"
    echo "$LARGE_FILES"
    echo -e "${YELLOW}Considere usar Git LFS para arquivos grandes.${NC}\n"
fi

echo -e "${GREEN}✅ Pre-commit checks completed!${NC}\n"
exit 0
