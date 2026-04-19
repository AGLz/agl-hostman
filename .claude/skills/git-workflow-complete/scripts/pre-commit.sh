#!/bin/bash
# Pre-Commit Hook - Validações antes do commit

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Running pre-commit checks...${NC}"
echo ""

# Contador de erros
ERRORS=0

# 1. Verificar segredos/credenciais no código
echo -e "${BLUE}1. Verificando segredos no código...${NC}"
STAGED_FILES=$(git diff --cached --name-only)
if [[ -n "$STAGED_FILES" ]]; then
    # Padrões de segredos comuns
    SECRET_PATTERNS="password|secret|api_key|apikey|token|private_key|aws_access_key_id|aws_secret_access_key"
    
    FOUND_SECRETS=$(echo "$STAGED_FILES" | xargs grep -l -i "$SECRET_PATTERNS" 2>/dev/null || true)
    if [[ -n "$FOUND_SECRETS" ]]; then
        echo -e "${YELLOW}⚠️  Arquivos com possíveis segredos encontrados:${NC}"
        echo "$FOUND_SECRETS"
        echo -e "${YELLOW}   Verifique manualmente se não há credenciais expostas${NC}"
    else
        echo -e "${GREEN}   ✅ Nenhum segredo óbvio encontrado${NC}"
    fi
fi
echo ""

# 2. Verificar arquivos .env
echo -e "${BLUE}2. Verificando arquivos de ambiente...${NC}"
ENV_FILES=$(echo "$STAGED_FILES" | grep -E "\.env|\.env\.local|\.env\.production" || true)
if [[ -n "$ENV_FILES" ]]; then
    echo -e "${RED}❌ Arquivos .env detectados no staged:${NC}"
    echo "$ENV_FILES"
    echo -e "${RED}   Remova do commit: git restore --staged <arquivo>${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}   ✅ Nenhum arquivo .env no commit${NC}"
fi
echo ""

# 3. Verificar console.log / debug statements
echo -e "${BLUE}3. Verificando debug statements...${NC}"
JS_FILES=$(echo "$STAGED_FILES" | grep -E "\.(js|ts|jsx|tsx)$" || true)
if [[ -n "$JS_FILES" ]]; then
    DEBUG_LINES=$(echo "$JS_FILES" | xargs grep -n "console\.log\|debugger;\|print(" 2>/dev/null || true)
    if [[ -n "$DEBUG_LINES" ]]; then
        echo -e "${YELLOW}⚠️  Debug statements encontrados:${NC}"
        echo "$DEBUG_LINES"
        echo -e "${YELLOW}   Considere remover antes do commit${NC}"
    else
        echo -e "${GREEN}   ✅ Nenhum debug statement encontrado${NC}"
    fi
fi
echo ""

# 4. Rodar linter se disponível
echo -e "${BLUE}4. Rodando linter...${NC}"
if [[ -f "package.json" && -n $(cat package.json | grep '"lint"' 2>/dev/null || true) ]]; then
    npm run lint --silent 2>/dev/null || true
    echo -e "${GREEN}   ✅ Linter concluído${NC}"
elif [[ -f "composer.json" ]]; then
    if [[ -f "vendor/bin/pint" ]]; then
        vendor/bin/pint --dirty 2>/dev/null || true
        echo -e "${GREEN}   ✅ Pint concluído${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Pint não disponível${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  Nenhum linter configurado${NC}"
fi
echo ""

# 5. Verificar testes se disponíveis
echo -e "${BLUE}5. Verificando testes...${NC}"
if [[ -f "package.json" && -n $(cat package.json | grep '"test"' 2>/dev/null || true) ]]; then
    echo -e "${YELLOW}   ℹ️  Testes disponíveis (npm test)${NC}"
elif [[ -f "phpunit.xml" || -f "phpunit.xml.dist" || -f "artisan" ]]; then
    echo -e "${YELLOW}   ℹ️  Testes disponíveis (php artisan test)${NC}"
else
    echo -e "${YELLOW}   ⚠️  Nenhum teste configurado${NC}"
fi
echo ""

# 6. Validar mensagem de commit (se fornecida)
if [[ -n "$1" ]]; then
    COMMIT_MSG="$1"
    echo -e "${BLUE}6. Validando mensagem de commit...${NC}"
    
    # Verificar Conventional Commits
    if echo "$COMMIT_MSG" | grep -qE "^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z-]+\))?: .+"; then
        echo -e "${GREEN}   ✅ Mensagem segue Conventional Commits${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Mensagem não segue Conventional Commits${NC}"
        echo -e "${YELLOW}   Formato esperado: type(scope): description${NC}"
    fi
fi
echo ""

# Resultado
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}❌ Pre-commit falhou com $ERRORS erro(s)${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Pre-commit checks passaram!${NC}"
    exit 0
fi
