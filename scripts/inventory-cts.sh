#!/bin/bash
# ============================================================================
# INVENTÁRIO DE CTs - AGLSRV1
# Data: 2026-04-18
# Responsável: Jarvis AI
# ============================================================================

echo "=========================================="
echo "INVENTÁRIO DE CTs - AGLSRV1"
echo "Data: $(date)"
echo "=========================================="
echo ""

# Listar todos os CTs
echo "=== LISTA DE TODOS OS CTs ==="
pct list
echo ""

# Função para verificar status de um CT
check_ct() {
    local CT_ID=$1
    local CT_NAME=$2
    
    echo "=========================================="
    echo "CT-$CT_ID: $CT_NAME"
    echo "=========================================="
    
    # Status
    echo "Status:"
    pct status $CT_ID
    
    # Configuração
    echo "Configuração:"
    pct config $CT_ID | grep -E "(memory|cores|net0|rootfs)"
    
    # IP
    echo "IP:"
    pct exec $CT_ID -- ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' || echo "Não acessível"
    
    echo ""
}

# Verificar CTs existentes do projeto
echo "=== CTs EXISTENTES - INFRASTRUCTURE ==="
check_ct 131 "mysql"
check_ct 137 "redis"
check_ct 149 "postgres"
check_ct 180 "dokploy"
check_ct 182 "harbor"
check_ct 183 "archon"
check_ct 184 "supabase"

echo "=== CTs EXISTENTES - AI/ML ==="
check_ct 200 "ollama"
check_ct 202 "n8n"

echo "=== CTs NÃO UTILIZADOS ==="
check_ct 201 "amp-server"
check_ct 210 "(existente)"

echo "=== CTs DISPONÍVEIS (LIVRES) ==="
echo "CT-203: Disponível"
echo "CT-204: Disponível"
echo "CT-205: Disponível"
echo "CT-206: Disponível"
echo "CT-207: Disponível (será LiteLLM)"
echo "CT-208: Disponível (reservado)"
echo "CT-209: Disponível"

echo ""
echo "=========================================="
echo "FIM DO INVENTÁRIO"
echo "=========================================="
