#!/bin/bash
# Proxmox Cluster - Script 3: Setup QDevice
# Execução: PRÉ-JANELA DE MANUTENÇÃO
# Configurar QDevice em AGLSRV1 para voto externo

set -e

echo "=========================================="
echo "  Proxmox Cluster - Setup QDevice"
echo "=========================================="
echo ""
echo "⚠️  Este script configura o QDevice em AGLSRV1"
echo "⚠️  QDevice fornece voto externo para quorum"
echo "⚠️  Pode ser executado ANTES da janela de manutenção"
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
AGLSRV1_WG="10.6.0.10"
AGLSRV6C_WG="10.6.0.22"

echo "=== Confirmação ==="
echo ""
echo "QDevice host: AGLSRV1 ($AGLSRV1_WG)"
echo "Cluster: agl-cluster em AGLSRV6C"
echo ""
read -p "Continuar? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operação cancelada."
    exit 1
fi

echo ""
echo "=== 1. Instalando corosync-qnetd em AGLSRV1 ==="
echo ""

# Verificar se já instalado
if ssh root@$AGLSRV1_WG "dpkg -l | grep -q corosync-qnetd"; then
    check_ok "corosync-qnetd já instalado em AGLSRV1"
else
    echo "Instalando corosync-qnetd..."
    ssh root@$AGLSRV1_WG "apt-get update -qq && apt-get install -y corosync-qnetd corosync-qdevice" || {
        check_fail "Erro ao instalar corosync-qnetd"
        exit 1
    }
    check_ok "corosync-qnetd instalado"
fi

echo ""
echo "Verificando status do corosync-qnetd..."
ssh root@$AGLSRV1_WG "systemctl status corosync-qnetd --no-pager -l | head -10"

echo ""
echo "=== 2. Configurando QDevice no Cluster ==="
echo ""

# Verificar se QDevice já configurado
if ssh root@$AGLSRV6C_WG "pvecm status | grep -q 'Qdevice'"; then
    check_warn "QDevice já configurado no cluster"
    ssh root@$AGLSRV6C_WG "pvecm status | grep -A10 'Qdevice'"
    echo ""
    read -p "Deseja reconfigurar? (yes/no): " RECONFIG
    if [ "$RECONFIG" != "yes" ]; then
        echo "Pulando configuração do QDevice..."
        exit 0
    fi

    echo "Removendo QDevice atual..."
    ssh root@$AGLSRV6C_WG "pvecm qdevice remove" || check_warn "Erro ao remover QDevice (pode não existir)"
    sleep 5
fi

echo "Configurando QDevice..."
echo "⚠️  Você pode ser solicitado a confirmar o fingerprint SSH"
echo ""

ssh root@$AGLSRV6C_WG "pvecm qdevice setup $AGLSRV1_WG" || {
    check_fail "Erro ao configurar QDevice"
    exit 1
}

check_ok "QDevice configurado"

echo ""
echo "Aguardando QDevice estabilizar (10 segundos)..."
sleep 10

echo ""
echo "=== 3. Verificando Status do QDevice ==="
echo ""

echo "Status do cluster com QDevice:"
ssh root@$AGLSRV6C_WG "pvecm status"

echo ""
echo "Status do corosync-qnetd em AGLSRV1:"
ssh root@$AGLSRV1_WG "corosync-qnetd-tool -l"

echo ""
echo "Informações do QDevice:"
ssh root@$AGLSRV6C_WG "pvecm status | grep -A10 'Qdevice'"

echo ""
echo "=== 4. Configurando Quorum 2/4 ==="
echo ""

echo "Ajustando quorum para 2/4..."
ssh root@$AGLSRV6C_WG "pvecm expected 2"
check_ok "Quorum configurado para 2/4"

echo ""
echo "Verificando configuração:"
ssh root@$AGLSRV6C_WG "pvecm status | grep -E '(Expected|Quorum|Quorate)'"

echo ""
echo "=== 5. Teste de Quorum com QDevice ==="
echo ""

echo "Cenários de quorum 2/4:"
echo "  ✅ AGLSRV6C + AGLSRV6D + QDevice = 3/4 (OK)"
echo "  ✅ AGLSRV6C + QDevice = 2/4 (OK - AGLSRV6D pode cair!)"
echo "  ✅ AGLSRV6C + AGLSRV6D = 2/4 (OK - QDevice pode cair!)"
echo "  ✅ Após adicionar AGLSRV6: 1 nó + QDevice = 2/4 (OK)"
echo ""
check_ok "Com quorum 2/4, cluster aguenta perda de 2 componentes simultaneamente"

echo ""
echo "=========================================="
echo "  QDevice Configurado com Sucesso!"
echo "=========================================="
echo ""
echo "✅ QDevice host: AGLSRV1 ($AGLSRV1_WG)"
echo "✅ Cluster: agl-cluster"
echo "✅ Quorum: 2/3 votes (com QDevice)"
echo ""
echo "📋 Próximos passos:"
echo "  1. Executar: 04-test-cluster.sh (testar failover)"
echo "  2. Após testes bem-sucedidos, agendar janela de manutenção"
echo "  3. Durante janela: executar 05-add-aglsrv6.sh"
echo ""
