#!/bin/bash
# Status Check - Verifica o estado atual do repositório
# Uso: bash status_check.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}       GIT WORKFLOW STATUS CHECK          ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""

# Branch atual
echo -e "${BLUE}🌿 Branch Atual:${NC}"
current_branch=$(git branch --show-current)
echo -e "   ${GREEN}$current_branch${NC}"
echo ""

# Status do repositório
echo -e "${BLUE}📋 Status do Repositório:${NC}"
if [[ -z $(git status --porcelain) ]]; then
    echo -e "   ${GREEN}✅ Working directory limpo${NC}"
else
    echo -e "   ${YELLOW}⚠️  Alterações pendentes:${NC}"
    git status --short
fi
echo ""

# Últimos commits
echo -e "${BLUE}📜 Últimos 5 Commits:${NC}"
git log --oneline -5 --color=always
echo ""

# Branch remotas
echo -e "${BLUE}🔄 Branches Remotas:${NC}"
git fetch --quiet 2>/dev/null || true
git branch -vv | while read line; do
    if echo "$line" | grep -q "ahead"; then
        echo -e "   ${GREEN}$line${NC}"
    elif echo "$line" | grep -q "behind"; then
        echo -e "   ${YELLOW}$line${NC}"
    elif echo "$line" | grep -q "gone"; then
        echo -e "   ${RED}$line${NC}"
    else
        echo "   $line"
    fi
done
echo ""

# PRs abertos (se gh disponível)
if command -v gh &> /dev/null; then
    echo -e "${BLUE}🔀 PRs Abertos (${current_branch}):${NC}"
    gh pr list --head "$current_branch" --state open 2>/dev/null || echo -e "   ${YELLOW}Nenhum PR aberto desta branch${NC}"
    echo ""
fi

# Stashes
echo -e "${BLUE}💾 Stashes:${NC}"
stash_count=$(git stash list | wc -l)
if [[ $stash_count -gt 0 ]]; then
    echo -e "   ${YELLOW}⚠️  $stash_count stash(es)${NC}"
    git stash list | head -3
else
    echo -e "   ${GREEN}✅ Nenhum stash${NC}"
fi
echo ""

# Resumo
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Resumo:${NC}"
echo -e "   Branch: ${GREEN}$current_branch${NC}"
echo -e "   Remotes: $(git remote -v | head -1 | awk '{print $2}')"
echo -e "   Último commit: $(git log -1 --format=%cd --date=short)"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
