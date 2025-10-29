#!/bin/bash
# Verificação de Deployment agl-hostman no Dokploy
# Usage: ./scripts/verify-deployment.sh <APP_URL>
# Example: ./scripts/verify-deployment.sh http://192.168.0.180:8080

set -e

APP_URL="${1:-http://localhost:3000}"
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🔍 VERIFICAÇÃO DE DEPLOYMENT - agl-hostman"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "URL da Aplicação: ${APP_URL}"
echo ""

# Função para verificar endpoint
check_endpoint() {
    local endpoint=$1
    local description=$2
    local expected_status=${3:-200}

    echo -n "Verificando ${description}... "

    http_code=$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}${endpoint}" 2>/dev/null || echo "000")

    if [ "$http_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✅ OK${NC} (HTTP ${http_code})"
        return 0
    else
        echo -e "${RED}❌ FALHOU${NC} (HTTP ${http_code}, esperado ${expected_status})"
        return 1
    fi
}

# Função para verificar JSON response
check_json_endpoint() {
    local endpoint=$1
    local description=$2

    echo -n "Verificando ${description}... "

    response=$(curl -s "${APP_URL}${endpoint}" 2>/dev/null || echo "{}")

    if echo "$response" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC} (JSON válido)"
        echo "$response" | jq . | head -20
        return 0
    else
        echo -e "${RED}❌ FALHOU${NC} (resposta não é JSON válido)"
        echo "Response: $response"
        return 1
    fi
}

echo "───────────────────────────────────────────────────────────────"
echo "  📊 VERIFICAÇÕES DE CONECTIVIDADE"
echo "───────────────────────────────────────────────────────────────"
echo ""

# Health Check
check_endpoint "/health" "Health Check" 200
HEALTH_STATUS=$?

echo ""

# API Overview
check_json_endpoint "/api/overview" "API Overview"
OVERVIEW_STATUS=$?

echo ""

# API Containers
check_endpoint "/api/containers" "API Containers" 200
CONTAINERS_STATUS=$?

echo ""

# API Network
check_endpoint "/api/network" "API Network" 200
NETWORK_STATUS=$?

echo ""

# Root / (se tiver interface web)
check_endpoint "/" "Interface Web" 200
WEB_STATUS=$?

echo ""
echo "───────────────────────────────────────────────────────────────"
echo "  📋 RESUMO"
echo "───────────────────────────────────────────────────────────────"
echo ""

TOTAL_CHECKS=5
PASSED_CHECKS=0

[ $HEALTH_STATUS -eq 0 ] && ((PASSED_CHECKS++))
[ $OVERVIEW_STATUS -eq 0 ] && ((PASSED_CHECKS++))
[ $CONTAINERS_STATUS -eq 0 ] && ((PASSED_CHECKS++))
[ $NETWORK_STATUS -eq 0 ] && ((PASSED_CHECKS++))
[ $WEB_STATUS -eq 0 ] && ((PASSED_CHECKS++))

echo "Testes Passados: ${PASSED_CHECKS}/${TOTAL_CHECKS}"
echo ""

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}${BOLD}✅ DEPLOYMENT VERIFICADO COM SUCESSO!${NC}"
    echo ""
    echo "A aplicação está rodando corretamente em: ${APP_URL}"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}❌ DEPLOYMENT COM PROBLEMAS${NC}"
    echo ""
    echo "Alguns endpoints não estão respondendo corretamente."
    echo "Verifique os logs da aplicação no Dokploy."
    echo ""
    exit 1
fi
