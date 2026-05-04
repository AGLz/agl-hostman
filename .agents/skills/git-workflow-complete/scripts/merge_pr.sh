#!/bin/bash
# Merge PR Script - Automatiza o merge de PRs com verificações
# Uso: bash merge_pr.sh <PR_NUMBER> [--squash|--merge|--rebase]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PR_NUMBER=${1:-}
MERGE_TYPE=${2:---squash}

if [[ -z "$PR_NUMBER" ]]; then
    echo -e "${RED}❌ Uso: bash merge_pr.sh <PR_NUMBER> [--squash|--merge|--rebase]${NC}"
    exit 1
fi

echo -e "${BLUE}🔄 Merge PR #$PR_NUMBER${NC}"
echo ""

# Verificar se o PR existe
echo -e "${BLUE}📋 Verificando PR...${NC}"
PR_INFO=$(gh pr view "$PR_NUMBER" --json state,mergeable,headRefName,baseRefName,title 2>/dev/null || true)

if [[ -z "$PR_INFO" ]]; then
    echo -e "${RED}❌ PR #$PR_NUMBER não encontrado${NC}"
    exit 1
fi

PR_STATE=$(echo "$PR_INFO" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
if [[ "$PR_STATE" == "MERGED" ]]; then
    echo -e "${YELLOW}⚠️  PR #$PR_NUMBER já foi mergeado${NC}"
    exit 0
fi

# Verificar checks
echo -e "${BLUE}🔍 Verificando checks...${NC}"
gh pr checks "$PR_NUMBER" 2>/dev/null || echo -e "${YELLOW}⚠️  Checks pendentes ou falhos${NC}"
echo ""

# Mostrar info do PR
echo -e "${BLUE}📄 Informações do PR:${NC}"
gh pr view "$PR_NUMBER" --json title,author,url
echo ""

# Confirmar merge
echo -e "${YELLOW}⚠️  Confirma o merge com $MERGE_TYPE?${NC}"
echo -e "${YELLOW}   Digite 'yes' para confirmar:${NC}"
read -r CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}❌ Merge cancelado${NC}"
    exit 0
fi

# Executar merge
echo -e "${BLUE}🚀 Executando merge...${NC}"
gh pr merge "$PR_NUMBER" "$MERGE_TYPE" --delete-branch

echo ""
echo -e "${GREEN}✅ PR #$PR_NUMBER mergeado com sucesso!${NC}"
echo ""
echo -e "${BLUE}📊 Branches locais:${NC}"
git branch -vv | head -10
