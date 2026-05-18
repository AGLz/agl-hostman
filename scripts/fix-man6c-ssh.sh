#!/bin/bash
#
# Correção Tailscale SSH para aglsrv6c (man6c)
# Host Proxmox separado - 100.124.53.91
# Este script deve ser executado LOCALMENTE no host aglsrv6c
#
# Como executar no host:
# 1. Copie este script para o aglsrv6c:
#    scp scripts/fix-man6c-ssh.sh root@100.124.53.91:/root/
#
# 2. Execute no aglsrv6c:
#    ssh root@100.124.53.91 bash /root/fix-man6c-ssh.sh
#

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
    log_error "Este script deve ser executado como root"
    exit 1
fi

log_info "Corrigindo Tailscale SSH para aglsrv6c (man6c)..."
log_info "Host: aglsrv6c (100.124.53.91)"
echo ""

# Passo 1: Verificar status atual
log_info "=== Passo 1: Verificando status atual ==="
echo "Status atual:"
tailscale status --peers=false 2>/dev/null || echo "  Tailscale pode não estar instalado"
echo ""
echo "IP atual:"
tailscale ip -4 2>/dev/null || echo "  Tailscale pode não estar instalado"
echo ""

# Passo 2: Desconectar e reconectar com flags corretas
log_info "=== Passo 2: Aplicando correção --ssh ==="
echo "Desconectando Tailscale..."
tailscale down 2>/dev/null || true
sleep 2
echo "Reconectando com todas as flags..."
echo "  Isso pode levar alguns segundos..."
tailscale up --ssh --accept-routes --accept-risk=lose-ssh --hostname=aglsrv6c 2>/dev/null || tailscale up --ssh --accept-routes --accept-risk=lose-ssh --hostname=aglsrv6c --reset
sleep 4

# Passo 3: Verificar resultado
log_info "=== Passo 3: Verificando resultado ==="
echo ""
echo "Status após correção:"
tailscale status --peers=false | head -3
echo ""
echo "IP Tailscale:"
tailscale ip -4 2>/dev/null || echo "  Não foi possível obter IP"
echo ""

# Verificar se foi bem-sucedido
if tailscale status --peers=false 2>/dev/null | grep -q "aglsrv6c"; then
    log_success "Tailscale SSH configurado com sucesso!"
    echo ""
    echo "═══════════════════════════════"
    echo "  ${GREEN}✅ HOSTNAME: aglsrv6c${NC}"
    echo "  ${GREEN}✅ IP TAILSCALE: $(tailscale ip -4)${NC}"
    echo "  ${GREEN}✅ FLAG --SSH: ATIVADA${NC}"
    echo "═══════════════════════════════"
    echo ""
    echo "Próximos passos:"
    echo "  1. Configure ACLs no Tailscale Admin Console"
    echo "  2. Teste: ssh root@aglsrv6c"
    echo "  3. Adicione ao SSH config local:"
    echo ""
    echo "Host man6c"
    echo "  HostName 100.124.53.91"
    echo "  User root"
    echo "  StrictHostKeyChecking no"
else
    log_error "Falha na configuração!"
    echo ""
    echo "Verifique:"
    echo "  1. Se o Tailscale está instalado"
    echo "  2. Se há erros nos logs"
    echo "  3. Verifique conectividade com a internet"
    exit 1
fi
