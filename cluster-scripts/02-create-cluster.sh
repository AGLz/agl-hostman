#!/bin/bash
# Proxmox Cluster - Script 2: Create Cluster Base
# Execução: PRÉ-JANELA DE MANUTENÇÃO
# Criar cluster com AGLSRV6C e adicionar AGLSRV6D

set -e

echo "=========================================="
echo "  Proxmox Cluster - Create Cluster Base"
echo "=========================================="
echo ""
echo "⚠️  Este script cria o cluster com AGLSRV6C e AGLSRV6D"
echo "⚠️  NÃO mexe em AGLSRV6 (produção)"
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

# Node IPs
AGLSRV6C_WG="10.6.0.22"
AGLSRV6D_WG="10.6.0.23"
CLUSTER_NAME="agl-cluster"

echo "=== Confirmação ==="
echo ""
echo "Cluster name: $CLUSTER_NAME"
echo "Master node: AGLSRV6C ($AGLSRV6C_WG)"
echo "Second node: AGLSRV6D ($AGLSRV6D_WG)"
echo ""
read -p "Continuar? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operação cancelada."
    exit 1
fi

echo ""
echo "=== 1. Criando Cluster em AGLSRV6C ==="
echo ""

# Verificar se já existe cluster
if ssh root@$AGLSRV6C_WG "test -f /etc/pve/corosync.conf"; then
    check_warn "Cluster já existe em AGLSRV6C"
    ssh root@$AGLSRV6C_WG "pvecm status"
    echo ""
    read -p "Deseja recriar o cluster? Isso apagará a configuração atual! (yes/no): " RECREATE
    if [ "$RECREATE" == "yes" ]; then
        echo "Parando serviços..."
        ssh root@$AGLSRV6C_WG "systemctl stop pve-cluster corosync"
        echo "Removendo configuração antiga..."
        ssh root@$AGLSRV6C_WG "rm -rf /etc/pve/corosync.conf /etc/corosync/*"
        echo "Aguardando 5 segundos..."
        sleep 5
    else
        echo "Pulando criação do cluster..."
        echo "Indo direto para adição de nós..."
        sleep 2
    fi
fi

echo "Criando cluster '$CLUSTER_NAME' em AGLSRV6C..."
ssh root@$AGLSRV6C_WG "pvecm create $CLUSTER_NAME --link0 $AGLSRV6C_WG" || {
    check_fail "Erro ao criar cluster"
    exit 1
}

check_ok "Cluster criado com sucesso"

echo ""
echo "Aguardando cluster estabilizar (10 segundos)..."
sleep 10

echo ""
echo "Status do cluster:"
ssh root@$AGLSRV6C_WG "pvecm status"

echo ""
echo "=== 2. Adicionando AGLSRV6D ao Cluster ==="
echo ""

# Verificar se AGLSRV6D já está no cluster
if ssh root@$AGLSRV6D_WG "test -f /etc/pve/corosync.conf"; then
    check_warn "AGLSRV6D já faz parte de um cluster"
    ssh root@$AGLSRV6D_WG "pvecm status"
    echo ""
    read -p "Deseja removê-lo e readicionar? (yes/no): " READD
    if [ "$READD" == "yes" ]; then
        echo "Parando serviços em AGLSRV6D..."
        ssh root@$AGLSRV6D_WG "systemctl stop pve-cluster corosync"
        echo "Removendo configuração antiga..."
        ssh root@$AGLSRV6D_WG "rm -rf /etc/pve/corosync.conf /etc/corosync/*"
        echo "Aguardando 5 segundos..."
        sleep 5
    else
        echo "Pulando adição de AGLSRV6D..."
        exit 0
    fi
fi

echo "Obtendo fingerprint SSH de AGLSRV6C..."
FINGERPRINT=$(ssh root@$AGLSRV6C_WG "ssh-keyscan localhost 2>/dev/null | ssh-keygen -lf - | awk '{print \$2}'")
echo "Fingerprint: $FINGERPRINT"

echo ""
echo "Adicionando AGLSRV6D ao cluster..."
echo "⚠️  Você pode ser solicitado a confirmar o fingerprint SSH"
echo "⚠️  Digite 'yes' se o fingerprint acima estiver correto"
echo ""

ssh root@$AGLSRV6D_WG "pvecm add $AGLSRV6C_WG --link0 $AGLSRV6D_WG" || {
    check_fail "Erro ao adicionar AGLSRV6D ao cluster"
    exit 1
}

check_ok "AGLSRV6D adicionado ao cluster"

echo ""
echo "Aguardando cluster estabilizar (15 segundos)..."
sleep 15

echo ""
echo "=== 3. Verificando Status do Cluster ==="
echo ""

echo "Status em AGLSRV6C:"
ssh root@$AGLSRV6C_WG "pvecm status"

echo ""
echo "Status em AGLSRV6D:"
ssh root@$AGLSRV6D_WG "pvecm status"

echo ""
echo "=== 4. Configurando Quorum 2/4 ==="
echo ""

echo "Ajustando quorum para 2/4 (permite 1 nó + QDevice operar)..."
ssh root@$AGLSRV6C_WG "pvecm expected 2"
check_ok "Quorum ajustado para 2/4"

echo ""
echo "Verificando configuração de quorum:"
ssh root@$AGLSRV6C_WG "pvecm status | grep -E '(Expected|Quorum)'"

echo ""
echo "Nós do cluster:"
ssh root@$AGLSRV6C_WG "pvecm nodes"

echo ""
echo "Configuração do Corosync:"
ssh root@$AGLSRV6C_WG "cat /etc/pve/corosync.conf"

echo ""
echo "=========================================="
echo "  Cluster Base Criado com Sucesso!"
echo "=========================================="
echo ""
echo "✅ Cluster: $CLUSTER_NAME"
echo "✅ Nós: AGLSRV6C ($AGLSRV6C_WG), AGLSRV6D ($AGLSRV6D_WG)"
echo "✅ Quorum: 2/2 votes"
echo ""
echo "📋 Próximos passos:"
echo "  1. Executar: 03-setup-qdevice.sh (adicionar voto externo)"
echo "  2. Executar: 04-test-cluster.sh (testar failover)"
echo "  3. NÃO adicionar AGLSRV6 ainda (esperar janela de manutenção)"
echo ""
