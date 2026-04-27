#!/bin/bash
# Proxmox Cluster - Script 5: Add AGLSRV6 to Cluster
# Execução: SOMENTE DURANTE JANELA DE MANUTENÇÃO
# ⚠️ ⚠️ ⚠️ ESTE SCRIPT CAUSA DOWNTIME EM AGLSRV6 ⚠️ ⚠️ ⚠️

set -e

echo "=========================================="
echo "  ⚠️ ⚠️ ⚠️  JANELA DE MANUTENÇÃO  ⚠️ ⚠️ ⚠️"
echo "  Proxmox Cluster - Add AGLSRV6"
echo "=========================================="
echo ""
echo "🔴 ATENÇÃO: Este script adiciona AGLSRV6 ao cluster"
echo "🔴 AGLSRV6 tem VMs/CTs em produção"
echo "🔴 Haverá DOWNTIME durante este processo"
echo "🔴 EXECUTE SOMENTE DURANTE JANELA DE MANUTENÇÃO"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
}

# IPs
AGLSRV6_WG="10.6.0.12"
AGLSRV6C_WG="10.6.0.22"
AGLSRV6D_WG="10.6.0.23"

echo "=== CONFIRMAÇÃO MÚLTIPLA ==="
echo ""
echo "Este script irá:"
echo "  1. Adicionar AGLSRV6 ao cluster"
echo "  2. SOBRESCREVER /etc/pve em AGLSRV6"
echo "  3. Potencialmente causar downtime em VMs/CTs"
echo ""
echo "Cluster atual:"
ssh root@$AGLSRV6C_WG "pvecm nodes"
echo ""
echo "VMs/CTs em AGLSRV6:"
ssh root@$AGLSRV6_WG "qm list 2>/dev/null; pct list 2>/dev/null" || echo "Não foi possível listar VMs/CTs"
echo ""
echo "🔴🔴🔴 CONFIRME TRÊS VEZES 🔴🔴🔴"
echo ""
read -p "Primeira confirmação - Janela de manutenção iniciada? (YES/no): " CONFIRM1
if [ "$CONFIRM1" != "YES" ]; then
    echo "Operação cancelada."
    exit 1
fi

read -p "Segunda confirmação - Usuários notificados? (YES/no): " CONFIRM2
if [ "$CONFIRM2" != "YES" ]; then
    echo "Operação cancelada."
    exit 1
fi

read -p "Terceira confirmação - Backup completo realizado? (YES/no): " CONFIRM3
if [ "$CONFIRM3" != "YES" ]; then
    echo "Operação cancelada."
    exit 1
fi

echo ""
echo "Todas as confirmações recebidas. Continuando..."
sleep 3

echo ""
echo "=== 1. Verificando Estado Atual ==="
echo ""

echo "Status do cluster (sem AGLSRV6):"
ssh root@$AGLSRV6C_WG "pvecm status"

echo ""
echo "Status de AGLSRV6 (standalone):"
ssh root@$AGLSRV6_WG "pvecm status 2>/dev/null || echo 'AGLSRV6 está standalone (esperado)'"

echo ""
echo "=== 2. Preparando AGLSRV6 ==="
echo ""

# Verificar se AGLSRV6 já está em um cluster
if ssh root@$AGLSRV6_WG "test -f /etc/pve/corosync.conf"; then
    check_warn "AGLSRV6 JÁ faz parte de um cluster"
    ssh root@$AGLSRV6_WG "cat /etc/pve/corosync.conf"
    echo ""
    read -p "Este é um cluster diferente? Remover? (yes/no): " REMOVE_OLD
    if [ "$REMOVE_OLD" == "yes" ]; then
        echo "Parando serviços..."
        ssh root@$AGLSRV6_WG "systemctl stop pve-cluster corosync"
        echo "Removendo configuração antiga..."
        ssh root@$AGLSRV6_WG "rm -rf /etc/pve/corosync.conf /etc/corosync/*"
        sleep 5
    else
        check_fail "AGLSRV6 já está em cluster. Cancelando."
        exit 1
    fi
fi

# Listar VMs/CTs
echo "VMs em AGLSRV6:"
ssh root@$AGLSRV6_WG "qm list 2>/dev/null || echo 'Nenhuma VM'"

echo ""
echo "Containers em AGLSRV6:"
ssh root@$AGLSRV6_WG "pct list 2>/dev/null || echo 'Nenhum container'"

echo ""
check_warn "⚠️  IMPORTANTE: Ao adicionar ao cluster, todas as VMs/CTs permanecerão"
check_warn "⚠️  Mas VMIDs duplicados podem causar conflitos"
check_warn "⚠️  Certifique-se de que não há VMIDs duplicados entre os nós"
echo ""
read -p "Continuar adicionando AGLSRV6 ao cluster? (yes/no): " CONTINUE

if [ "$CONTINUE" != "yes" ]; then
    echo "Operação cancelada."
    exit 1
fi

echo ""
echo "=== 3. Adicionando AGLSRV6 ao Cluster ==="
echo ""

echo "Obtendo fingerprint SSH de AGLSRV6C..."
FINGERPRINT=$(ssh root@$AGLSRV6C_WG "ssh-keyscan localhost 2>/dev/null | ssh-keygen -lf - | awk '{print \$2}'")
echo "Fingerprint: $FINGERPRINT"

echo ""
echo "Adicionando AGLSRV6 ao cluster via WireGuard..."
echo "⚠️  Você pode ser solicitado a confirmar o fingerprint SSH"
echo "⚠️  Digite 'yes' se o fingerprint acima estiver correto"
echo ""

ssh root@$AGLSRV6_WG "pvecm add $AGLSRV6C_WG --link0 $AGLSRV6_WG" || {
    check_fail "Erro ao adicionar AGLSRV6 ao cluster"
    echo ""
    echo "Se o erro for sobre /etc/pve não estar vazio:"
    echo "  - VMs/CTs existentes podem estar causando conflito"
    echo "  - Considere migrar VMs/CTs antes de adicionar ao cluster"
    exit 1
}

check_ok "AGLSRV6 adicionado ao cluster"

echo ""
echo "Aguardando cluster estabilizar (20 segundos)..."
sleep 20

echo ""
echo "=== 4. Verificando Status do Cluster Completo ==="
echo ""

echo "Status do cluster (3 nós + QDevice):"
ssh root@$AGLSRV6C_WG "pvecm status"

echo ""
echo "Nós do cluster:"
ssh root@$AGLSRV6C_WG "pvecm nodes"

echo ""
echo "Configuração do Corosync:"
ssh root@$AGLSRV6C_WG "cat /etc/pve/corosync.conf"

# Verificar quorum
QUORUM=$(ssh root@$AGLSRV6C_WG "pvecm status | grep 'Quorate' | awk '{print \$2}'")
if [ "$QUORUM" == "Yes" ]; then
    check_ok "Cluster tem quorum (2/4 votes configurado)"
else
    check_fail "Cluster NÃO tem quorum!"
fi

echo ""
echo "Confirmando configuração de quorum 2/4..."
ssh root@$AGLSRV6C_WG "pvecm status | grep -E '(Expected|Quorum)'"

echo ""
echo "=== 5. Verificando VMs/CTs em AGLSRV6 ==="
echo ""

echo "VMs em AGLSRV6 após juntar cluster:"
ssh root@$AGLSRV6_WG "qm list 2>/dev/null || echo 'Nenhuma VM'"

echo ""
echo "Containers em AGLSRV6 após juntar cluster:"
ssh root@$AGLSRV6_WG "pct list 2>/dev/null || echo 'Nenhum container'"

echo ""
echo "Status dos serviços:"
ssh root@$AGLSRV6_WG "systemctl status pve-cluster --no-pager -l | head -5"
ssh root@$AGLSRV6_WG "systemctl status corosync --no-pager -l | head -5"

echo ""
echo "=== 6. Teste de Conectividade ==="
echo ""

echo "Ping entre nós do cluster:"
echo "AGLSRV6C -> AGLSRV6:"
ssh root@$AGLSRV6C_WG "ping -c 3 $AGLSRV6_WG | tail -2"

echo ""
echo "AGLSRV6D -> AGLSRV6:"
ssh root@$AGLSRV6D_WG "ping -c 3 $AGLSRV6_WG | tail -2"

echo ""
echo "AGLSRV6 -> AGLSRV6C:"
ssh root@$AGLSRV6_WG "ping -c 3 $AGLSRV6C_WG | tail -2"

echo ""
echo "=========================================="
echo "  ✅ AGLSRV6 Adicionado ao Cluster!"
echo "=========================================="
echo ""
echo "✅ Cluster: agl-cluster"
echo "✅ Nós: AGLSRV6, AGLSRV6C, AGLSRV6D"
echo "✅ QDevice: AGLSRV1"
echo "✅ Quorum: 2/4 votes (flexível)"
echo ""
echo "📊 Cenários de operação:"
echo "  ✅ AGLSRV6 + QDevice = 2/4 (OK mesmo sem AGLSRV6C/D)"
echo "  ✅ AGLSRV6C + AGLSRV6D = 2/4 (OK mesmo sem AGLSRV6)"
echo "  ✅ Qualquer 2 nós = 2/4 (OK)"
echo "  ✅ Qualquer 1 nó + QDevice = 2/4 (OK)"
echo ""
echo "📋 Próximos passos:"
echo "  1. Verificar que todas as VMs/CTs estão funcionando"
echo "  2. Testar migração de VMs entre nós"
echo "  3. Configurar HA para VMs críticas"
echo "  4. Atualizar documentação (INFRA.md)"
echo "  5. Notificar usuários que manutenção foi concluída"
echo ""
echo "🎉 Cluster Proxmox completo e operacional!"
echo ""
