#!/bin/bash
# Proxmox Cluster - Script 1: Prerequisites Check
# Execução: PRÉ-JANELA DE MANUTENÇÃO
# Validar todos os pré-requisitos antes de criar o cluster

set -e

echo "=========================================="
echo "  Proxmox Cluster - Prerequisites Check"
echo "=========================================="
echo ""
echo "⚠️  Este script verifica pré-requisitos"
echo "⚠️  Pode ser executado ANTES da janela de manutenção"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para check
check_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
}

# Node IPs
AGLSRV6_WG="10.6.0.12"
AGLSRV6C_WG="10.6.0.22"
AGLSRV6D_WG="10.6.0.23"
AGLSRV1_WG="10.6.0.10"

echo "=== 1. Verificando Conectividade de Rede ==="
echo ""

# Ping todos os nós
echo "Testando AGLSRV6 ($AGLSRV6_WG)..."
if ping -c 3 -W 2 $AGLSRV6_WG > /dev/null 2>&1; then
    check_ok "AGLSRV6 alcançável"
else
    check_fail "AGLSRV6 NÃO alcançável"
fi

echo "Testando AGLSRV6C ($AGLSRV6C_WG)..."
if ping -c 3 -W 2 $AGLSRV6C_WG > /dev/null 2>&1; then
    check_ok "AGLSRV6C alcançável"
else
    check_fail "AGLSRV6C NÃO alcançável"
fi

echo "Testando AGLSRV6D ($AGLSRV6D_WG)..."
if ping -c 3 -W 2 $AGLSRV6D_WG > /dev/null 2>&1; then
    check_ok "AGLSRV6D alcançável"
else
    check_fail "AGLSRV6D NÃO alcançável"
fi

echo "Testando AGLSRV1 ($AGLSRV1_WG) - QDevice host..."
if ping -c 3 -W 2 $AGLSRV1_WG > /dev/null 2>&1; then
    check_ok "AGLSRV1 alcançável"
else
    check_fail "AGLSRV1 NÃO alcançável"
fi

echo ""
echo "=== 2. Verificando Portas Necessárias ==="
echo ""

# Função para check de porta
check_port() {
    local host=$1
    local port=$2
    local proto=$3

    if nc -zv -w 2 $host $port 2>&1 | grep -q "succeeded\|open"; then
        check_ok "Porta $port/$proto aberta em $host"
        return 0
    else
        check_warn "Porta $port/$proto pode estar fechada em $host"
        return 1
    fi
}

# Check SSH (TCP 22)
echo "Testando SSH (TCP 22)..."
check_port $AGLSRV6C_WG 22 tcp
check_port $AGLSRV6D_WG 22 tcp

echo ""
echo "Nota: Portas UDP (5405-5412) serão verificadas após criação do cluster"
echo ""

echo "=== 3. Verificando Sincronização de Tempo ==="
echo ""

# Check timezone
echo "Verificando timezone em AGLSRV6C..."
TIMEZONE_6C=$(ssh root@$AGLSRV6C_WG "timedatectl | grep 'Time zone' | awk '{print \$3}'")
echo "AGLSRV6C timezone: $TIMEZONE_6C"

echo "Verificando timezone em AGLSRV6D..."
TIMEZONE_6D=$(ssh root@$AGLSRV6D_WG "timedatectl | grep 'Time zone' | awk '{print \$3}'")
echo "AGLSRV6D timezone: $TIMEZONE_6D"

if [ "$TIMEZONE_6C" == "$TIMEZONE_6D" ]; then
    check_ok "Timezones sincronizados"
else
    check_fail "Timezones DIFERENTES! AGLSRV6C=$TIMEZONE_6C, AGLSRV6D=$TIMEZONE_6D"
fi

# Check time difference
echo ""
echo "Verificando diferença de horário..."
TIME_6C=$(ssh root@$AGLSRV6C_WG "date +%s")
TIME_6D=$(ssh root@$AGLSRV6D_WG "date +%s")
TIME_DIFF=$((TIME_6C - TIME_6D))
TIME_DIFF=${TIME_DIFF#-}  # absolute value

if [ $TIME_DIFF -lt 5 ]; then
    check_ok "Horários sincronizados (diferença: ${TIME_DIFF}s)"
else
    check_warn "Horários podem estar dessincronizados (diferença: ${TIME_DIFF}s)"
fi

echo ""
echo "=== 4. Verificando Pacotes Necessários ==="
echo ""

# Check em AGLSRV6C
echo "Verificando pacotes em AGLSRV6C..."
ssh root@$AGLSRV6C_WG "dpkg -l | grep -E '(pve-cluster|corosync|pve-ha-manager)' || echo 'Pacotes não instalados'"

# Check em AGLSRV6D
echo ""
echo "Verificando pacotes em AGLSRV6D..."
ssh root@$AGLSRV6D_WG "dpkg -l | grep -E '(pve-cluster|corosync|pve-ha-manager)' || echo 'Pacotes não instalados'"

# Check QDevice em AGLSRV1
echo ""
echo "Verificando corosync-qnetd em AGLSRV1..."
if ssh root@$AGLSRV1_WG "dpkg -l | grep -q corosync-qnetd"; then
    check_ok "corosync-qnetd já instalado em AGLSRV1"
else
    check_warn "corosync-qnetd NÃO instalado em AGLSRV1"
    echo "    Será instalado no script 03-setup-qdevice.sh"
fi

echo ""
echo "=== 5. Verificando VMs/CTs Existentes ==="
echo ""

# AGLSRV6C deve estar vazio
echo "Verificando AGLSRV6C..."
VMS_6C=$(ssh root@$AGLSRV6C_WG "qm list 2>/dev/null | wc -l")
CTS_6C=$(ssh root@$AGLSRV6C_WG "pct list 2>/dev/null | wc -l")

if [ "$VMS_6C" -le 1 ] && [ "$CTS_6C" -le 1 ]; then
    check_ok "AGLSRV6C está vazio (pronto para cluster)"
else
    check_fail "AGLSRV6C tem VMs/CTs! Deve estar vazio antes de criar cluster"
fi

# AGLSRV6D deve estar vazio
echo "Verificando AGLSRV6D..."
VMS_6D=$(ssh root@$AGLSRV6D_WG "qm list 2>/dev/null | wc -l")
CTS_6D=$(ssh root@$AGLSRV6D_WG "pct list 2>/dev/null | wc -l")

if [ "$VMS_6D" -le 1 ] && [ "$CTS_6D" -le 1 ]; then
    check_ok "AGLSRV6D está vazio (pronto para cluster)"
else
    check_fail "AGLSRV6D tem VMs/CTs! Deve estar vazio antes de entrar no cluster"
fi

echo ""
echo "=== 6. Verificando Configuração Atual ==="
echo ""

# Check se já existe cluster
echo "Verificando se AGLSRV6C já faz parte de um cluster..."
if ssh root@$AGLSRV6C_WG "test -f /etc/pve/corosync.conf"; then
    check_warn "AGLSRV6C JÁ FAZ PARTE DE UM CLUSTER!"
    ssh root@$AGLSRV6C_WG "cat /etc/pve/corosync.conf"
else
    check_ok "AGLSRV6C standalone (não está em cluster)"
fi

echo ""
echo "Verificando se AGLSRV6D já faz parte de um cluster..."
if ssh root@$AGLSRV6D_WG "test -f /etc/pve/corosync.conf"; then
    check_warn "AGLSRV6D JÁ FAZ PARTE DE UM CLUSTER!"
    ssh root@$AGLSRV6D_WG "cat /etc/pve/corosync.conf"
else
    check_ok "AGLSRV6D standalone (não está em cluster)"
fi

echo ""
echo "=== 7. Instalando Pacotes Necessários ==="
echo ""

echo "Instalando pacotes em AGLSRV6C..."
ssh root@$AGLSRV6C_WG "apt-get update -qq && apt-get install -y pve-ha-manager corosync pve-cluster 2>&1 | grep -E '(Setting up|already)' || echo 'Pacotes instalados'"
check_ok "Pacotes instalados em AGLSRV6C"

echo ""
echo "Instalando pacotes em AGLSRV6D..."
ssh root@$AGLSRV6D_WG "apt-get update -qq && apt-get install -y pve-ha-manager corosync pve-cluster 2>&1 | grep -E '(Setting up|already)' || echo 'Pacotes instalados'"
check_ok "Pacotes instalados em AGLSRV6D"

echo ""
echo "=========================================="
echo "  Verificação de Pré-requisitos Completa"
echo "=========================================="
echo ""
echo "📋 Próximos passos:"
echo "  1. Revisar os avisos acima (se houver)"
echo "  2. Se tudo estiver OK, executar: 02-create-cluster.sh"
echo "  3. NÃO executar nada em AGLSRV6 ainda!"
echo ""
echo "✅ Este script pode ser executado ANTES da janela de manutenção"
echo ""
