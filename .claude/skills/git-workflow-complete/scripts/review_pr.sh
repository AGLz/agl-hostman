#!/bin/bash
# Code Review Script - Auxilia na revisão de PRs
# Uso: bash review_pr.sh <PR_NUMBER>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PR_NUMBER=${1:-}

if [[ -z "$PR_NUMBER" ]]; then
    echo -e "${RED}❌ Uso: bash review_pr.sh <PR_NUMBER>${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Code Review - PR #$PR_NUMBER${NC}"
echo ""

# Obter informações do PR
echo -e "${BLUE}📋 Informações do PR:${NC}"
gh pr view "$PR_NUMBER"
echo ""

# Mostrar diff stats
echo -e "${BLUE}📊 Estatísticas de alterações:${NC}"
gh pr diff "$PR_NUMBER" --stat 2>/dev/null || gh pr diff "$PR_NUMBER" | head -50
echo ""

# Verificar checks
echo -e "${BLUE}✅ Status dos checks:${NC}"
gh pr checks "$PR_NUMBER" 2>/dev/null || echo -e "${YELLOW}⚠️  Sem checks configurados${NC}"
echo ""

# Checkout do PR para testar localmente
echo -e "${BLUE}💻 Para testar localmente:${NC}"
echo -e "   gh pr checkout $PR_NUMBER"
echo ""

# Opções de review
echo -e "${BLUE}📝 Opções de review:${NC}"
echo -e "   ${GREEN}Aprovar:${NC}  gh pr review $PR_NUMBER --approve"
echo -e "   ${YELLOW}Solicitar mudanças:${NC}  gh pr review $PR_NUMBER --request-changes --body 'Descrição'"
echo -e "   ${YELLOW}Comentar:${NC}  gh pr review $PR_NUMBER --comment --body 'Comentário'"
echo ""

# Auto-review checklist
echo -e "${BLUE}✓ Checklist de Code Review:${NC}"
echo ""
echo "  [ ] Código segue padrões do projeto"
echo "  [ ] Nomes de variáveis/funções são claros"
echo "  [ ] Sem código duplicado"
echo "  [ ] Testes cobrem as mudanças"
echo "  [ ] Sem segredos/credenciais expostos"
echo "  [ ] Sem console.log/debug statements"
echo "  [ ] Tratamento de erros adequado"
echo "  [ ] Documentação atualizada (se necessário)"
echo "  [ ] Performance não degradada"
echo "  [ ] Sem breaking changes inesperados"
echo ""
