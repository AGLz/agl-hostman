#!/bin/bash
# Setup Tailscale no CT178 (aglfs1) do AGLSRV1
# Adiciona o container ao Tailscale para acesso remoto

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CT_ID=178
CT_HOSTNAME="aglfs1"
AGLSRV1_IP="192.168.0.245"

echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} Tailscale Setup - CT178 (aglfs1)${NC}"
echo -e "${BOLD}======================================${NC}"
echo ""

# Verificar se estamos no host correto ou podemos acessar o AGLSRV1
if [[ ! -f /etc/pve/lxc/${CT_ID}.conf ]]; then
    echo -e "${YELLOW}⚠️  Script deve ser executado no AGLSRV1 ou via SSH${NC}"
    echo -e "${YELLOW}   Executando via SSH no AGLSRV1...${NC}"
    echo ""
    
    # Executar via SSH se não estivermos no host
    ssh root@${AGLSRV1_IP} "bash -s" < "$0"
    exit $?
fi

# Verificar se o container existe
if ! pct status ${CT_ID} &>/dev/null; then
    echo -e "${RED}❌ Container CT${CT_ID} não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Container CT${CT_ID} encontrado${NC}"
echo ""

# Verificar se o container está rodando
if ! pct status ${CT_ID} | grep -q "running"; then
    echo -e "${YELLOW}⚠️  Container não está rodando. Iniciando...${NC}"
    pct start ${CT_ID}
    sleep 5
fi

echo -e "${BOLD}Passo 1: Instalando Tailscale no CT${CT_ID}${NC}"
echo ""

# Instalar Tailscale dentro do container
pct exec ${CT_ID} -- bash -c "
    set -e
    
    # Verificar se já está instalado
    if command -v tailscale &> /dev/null; then
        echo 'Tailscale já está instalado'
        tailscale --version
    else
        echo 'Instalando Tailscale...'
        curl -fsSL https://tailscale.com/install.sh | sh
        echo '✅ Tailscale instalado'
    fi
"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Tailscale instalado com sucesso${NC}"
else
    echo -e "${RED}❌ Falha na instalação do Tailscale${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}Passo 2: Configurando Tailscale${NC}"
echo ""

# Verificar se já está autenticado
AUTH_STATUS=$(pct exec ${CT_ID} -- tailscale status --peers=false 2>/dev/null | head -1 || echo "")

if echo "$AUTH_STATUS" | grep -q "Logged in"; then
    echo -e "${GREEN}✅ Tailscale já está autenticado${NC}"
    echo ""
    echo -e "${BOLD}Status atual:${NC}"
    pct exec ${CT_ID} -- tailscale status --peers=false
    echo ""
    
    # Obter IP do Tailscale
    TAILSCALE_IP=$(pct exec ${CT_ID} -- tailscale ip -4 2>/dev/null || echo "")
    if [[ -n "$TAILSCALE_IP" ]]; then
        echo -e "${GREEN}✅ IP Tailscale: ${TAILSCALE_IP}${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Tailscale precisa ser autenticado${NC}"
    echo ""
    echo -e "${BOLD}Iniciando autenticação...${NC}"
    echo ""
    
    # Iniciar Tailscale (vai gerar URL de autenticação)
    pct exec ${CT_ID} -- tailscale up --accept-routes || true
    
    echo ""
    echo -e "${YELLOW}⚠️  Se uma URL de autenticação foi exibida acima,${NC}"
    echo -e "${YELLOW}   visite-a no navegador para completar a autenticação.${NC}"
    echo ""
    echo -e "${YELLOW}   Ou execute manualmente dentro do container:${NC}"
    echo -e "${BOLD}   pct exec ${CT_ID} -- tailscale up${NC}"
    echo ""
    
    read -p "Pressione Enter após completar a autenticação..."
    
    # Verificar status após autenticação
    echo ""
    echo -e "${BOLD}Verificando status...${NC}"
    pct exec ${CT_ID} -- tailscale status --peers=false
    
    # Obter IP do Tailscale
    TAILSCALE_IP=$(pct exec ${CT_ID} -- tailscale ip -4 2>/dev/null || echo "")
    if [[ -n "$TAILSCALE_IP" ]]; then
        echo ""
        echo -e "${GREEN}✅ IP Tailscale obtido: ${TAILSCALE_IP}${NC}"
    fi
fi

echo ""
echo -e "${BOLD}Passo 3: Configurando serviço para iniciar automaticamente${NC}"
echo ""

# Habilitar serviço do Tailscale
pct exec ${CT_ID} -- bash -c "
    systemctl enable tailscaled 2>/dev/null || true
    systemctl start tailscaled 2>/dev/null || true
    systemctl status tailscaled --no-pager | head -5 || true
"

echo ""
echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} Setup Completo!${NC}"
echo -e "${BOLD}======================================${NC}"
echo ""

# Obter informações finais
TAILSCALE_IP=$(pct exec ${CT_ID} -- tailscale ip -4 2>/dev/null || echo "N/A")
TAILSCALE_STATUS=$(pct exec ${CT_ID} -- tailscale status --peers=false 2>/dev/null | head -1 || echo "N/A")

echo -e "${GREEN}✅ CT${CT_ID} (${CT_HOSTNAME}) configurado no Tailscale${NC}"
echo ""
echo "Informações:"
echo "  Container: CT${CT_ID} (${CT_HOSTNAME})"
echo "  LAN IP: 192.168.0.178"
if [[ "$TAILSCALE_IP" != "N/A" ]]; then
    echo -e "  ${GREEN}Tailscale IP: ${TAILSCALE_IP}${NC}"
fi
echo "  Status: ${TAILSCALE_STATUS}"
echo ""
echo "Acesso via Tailscale:"
if [[ "$TAILSCALE_IP" != "N/A" ]]; then
    echo "  SSH: ssh root@${TAILSCALE_IP}"
    echo "  NFS: ${TAILSCALE_IP}:/mnt/shares"
    echo "  SMB: \\\\${TAILSCALE_IP}\\shares"
fi
echo ""
echo "Para verificar status:"
echo "  pct exec ${CT_ID} -- tailscale status"
echo ""

