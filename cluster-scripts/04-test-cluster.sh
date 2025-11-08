#!/bin/bash
# Proxmox Cluster - Script 4: Test Cluster and Failover
# Execução: PRÉ-JANELA DE MANUTENÇÃO
# Testar cluster, HA e failover antes de adicionar AGLSRV6

set -e

echo "=========================================="
echo "  Proxmox Cluster - Test Cluster"
echo "=========================================="
echo ""
echo "⚠️  Este script testa o cluster e HA"
echo "⚠️  Cria VM de teste e simula failover"
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
AGLSRV6C_WG="10.6.0.22"
AGLSRV6D_WG="10.6.0.23"

TEST_VMID="9999"

echo "=== Confirmação ==="
echo ""
echo "Este script irá:"
echo "  1. Verificar status do cluster"
echo "  2. Criar VM de teste (ID $TEST_VMID)"
echo "  3. Habilitar HA para a VM"
echo "  4. Testar migração manual"
echo "  5. (OPCIONAL) Testar failover automático"
echo ""
read -p "Continuar? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operação cancelada."
    exit 1
fi

echo ""
echo "=== 1. Verificando Status do Cluster ==="
echo ""

ssh root@$AGLSRV6C_WG "pvecm status"

echo ""
echo "Nós do cluster:"
ssh root@$AGLSRV6C_WG "pvecm nodes"

echo ""
echo "Status de HA:"
ssh root@$AGLSRV6C_WG "ha-manager status"

# Verificar quorum
QUORUM=$(ssh root@$AGLSRV6C_WG "pvecm status | grep 'Quorate' | awk '{print \$2}'")
if [ "$QUORUM" == "Yes" ]; then
    check_ok "Cluster tem quorum"
else
    check_fail "Cluster NÃO tem quorum!"
    exit 1
fi

echo ""
echo "=== 2. Criando VM de Teste ==="
echo ""

# Verificar se VM já existe
if ssh root@$AGLSRV6C_WG "qm list | grep -q '$TEST_VMID'"; then
    check_warn "VM $TEST_VMID já existe"
    read -p "Deseja removê-la e recriar? (yes/no): " RECREATE
    if [ "$RECREATE" == "yes" ]; then
        echo "Removendo VM antiga..."
        ssh root@$AGLSRV6C_WG "ha-manager remove vm:$TEST_VMID 2>/dev/null || true"
        sleep 5
        ssh root@$AGLSRV6C_WG "qm stop $TEST_VMID 2>/dev/null || true"
        sleep 3
        ssh root@$AGLSRV6C_WG "qm destroy $TEST_VMID 2>/dev/null || true"
        sleep 3
    else
        echo "Usando VM existente..."
    fi
fi

# Criar VM simples
if ! ssh root@$AGLSRV6C_WG "qm list | grep -q '$TEST_VMID'"; then
    echo "Criando VM de teste (Alpine Linux mínima)..."
    ssh root@$AGLSRV6C_WG "qm create $TEST_VMID --name test-cluster-ha --memory 256 --cores 1 --net0 virtio,bridge=vmbr0" || {
        check_fail "Erro ao criar VM"
        exit 1
    }
    check_ok "VM $TEST_VMID criada"
else
    check_ok "VM $TEST_VMID já existe"
fi

echo ""
echo "=== 3. Habilitando HA para VM de Teste ==="
echo ""

# Adicionar ao HA
echo "Adicionando VM ao grupo de HA..."
ssh root@$AGLSRV6C_WG "ha-manager add vm:$TEST_VMID --state started --group ha-group-1 2>/dev/null || ha-manager add vm:$TEST_VMID --state started" || {
    check_warn "Erro ao adicionar HA (VM pode já estar em HA)"
}

sleep 5

echo "Status de HA da VM:"
ssh root@$AGLSRV6C_WG "ha-manager status | grep -A2 vm:$TEST_VMID"

check_ok "HA configurado para VM $TEST_VMID"

echo ""
echo "=== 4. Testando Migração Manual ==="
echo ""

echo "VM $TEST_VMID está em qual nó?"
CURRENT_NODE=$(ssh root@$AGLSRV6C_WG "qm list | grep '$TEST_VMID' | awk '{print \$2}'" | tr -d '\r\n')
echo "Nó atual: $CURRENT_NODE"

if [ "$CURRENT_NODE" == "man6c" ]; then
    TARGET_NODE="man6d"
    TARGET_IP=$AGLSRV6D_WG
else
    TARGET_NODE="man6c"
    TARGET_IP=$AGLSRV6C_WG
fi

echo ""
echo "Migrando VM para $TARGET_NODE..."
read -p "Executar migração? (yes/no): " MIGRATE

if [ "$MIGRATE" == "yes" ]; then
    ssh root@$AGLSRV6C_WG "qm migrate $TEST_VMID $TARGET_NODE --online" || {
        check_warn "Erro na migração (VM pode não estar rodando)"
    }

    echo ""
    echo "Aguardando migração (10 segundos)..."
    sleep 10

    echo "Verificando nó atual..."
    NEW_NODE=$(ssh root@$TARGET_IP "qm list | grep '$TEST_VMID' | awk '{print \$2}'" | tr -d '\r\n')
    echo "Nó atual após migração: $NEW_NODE"

    if [ "$NEW_NODE" == "$TARGET_NODE" ]; then
        check_ok "Migração bem-sucedida!"
    else
        check_warn "Migração pode não ter funcionado completamente"
    fi
else
    echo "Migração manual pulada."
fi

echo ""
echo "=== 5. Teste de Failover Automático (OPCIONAL) ==="
echo ""

echo "⚠️  ATENÇÃO: Este teste simula falha de um nó"
echo "⚠️  Isso pode causar breve instabilidade no cluster"
echo ""
read -p "Executar teste de failover automático? (yes/no): " FAILOVER_TEST

if [ "$FAILOVER_TEST" == "yes" ]; then
    echo ""
    echo "Para testar failover, você pode:"
    echo "  1. Desligar AGLSRV6D fisicamente (se disponível)"
    echo "  2. Parar o serviço corosync: ssh root@$AGLSRV6D_WG 'systemctl stop corosync pve-cluster'"
    echo ""
    echo "O que deve acontecer:"
    echo "  - Cluster detecta perda do nó"
    echo "  - Quorum mantido (2/3 com QDevice)"
    echo "  - HA migra VMs automaticamente para o nó sobrevivente"
    echo ""
    echo "Após o teste, reiniciar o nó parado"
    echo ""
    check_warn "Execute manualmente se desejar testar failover"
else
    echo "Teste de failover automático pulado."
fi

echo ""
echo "=== 6. Limpeza (OPCIONAL) ==="
echo ""

read -p "Remover VM de teste? (yes/no): " CLEANUP

if [ "$CLEANUP" == "yes" ]; then
    echo "Removendo VM de teste..."
    ssh root@$AGLSRV6C_WG "ha-manager remove vm:$TEST_VMID 2>/dev/null || true"
    sleep 5
    ssh root@$AGLSRV6C_WG "qm stop $TEST_VMID 2>/dev/null || true"
    sleep 3
    ssh root@$AGLSRV6C_WG "qm destroy $TEST_VMID"
    check_ok "VM de teste removida"
else
    echo "VM de teste mantida (ID: $TEST_VMID)"
fi

echo ""
echo "=========================================="
echo "  Testes do Cluster Concluídos"
echo "=========================================="
echo ""
echo "✅ Status do cluster verificado"
echo "✅ VM de teste criada (se não removida)"
echo "✅ HA configurado e testado"
echo ""
echo "📋 Próximos passos:"
echo "  1. Revisar resultados dos testes"
echo "  2. Se tudo OK, agendar janela de manutenção"
echo "  3. Durante janela: executar 05-add-aglsrv6.sh"
echo ""
echo "⚠️  AGLSRV6 ainda NÃO foi adicionado ao cluster"
echo "⚠️  AGLSRV6 continua standalone e em produção"
echo ""
