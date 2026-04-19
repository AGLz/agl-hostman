#!/bin/bash
#
# PegaProx - Deploy remoto para aglsrv1
# Executa a instalação via SSH a partir de CT179 ou outra máquina
#
# Uso: ./deploy-remote.sh [aglsrv1-ip]
# Exemplo: ./deploy-remote.sh 192.168.0.245
#          ./deploy-remote.sh 100.107.113.33  # via Tailscale
#

set -euo pipefail

AGLSRV1="${1:-192.168.0.245}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="/tmp/pegaprox-deploy-$(date +%s)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  PegaProx - Deploy remoto para aglsrv1${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Testar conectividade
echo -e "\n${BLUE}[1/3]${NC} Verificando conectividade com $AGLSRV1..."
if ! ping -c 2 "$AGLSRV1" &>/dev/null; then
    echo -e "${RED}Erro: Não foi possível alcançar $AGLSRV1${NC}"
    echo "  Tente: 192.168.0.245 (LAN) ou 100.107.113.33 (Tailscale)"
    exit 1
fi

echo -e "\n${BLUE}[2/3]${NC} Verificando SSH..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes root@"$AGLSRV1" "echo OK" &>/dev/null; then
    echo -e "${RED}Erro: SSH para root@$AGLSRV1 falhou${NC}"
    echo "  Configure: ssh-copy-id root@$AGLSRV1"
    exit 1
fi

echo -e "\n${BLUE}[3/3]${NC} Transferindo e executando instalação..."
ssh root@"$AGLSRV1" "mkdir -p $REMOTE_DIR"
scp -q "$SCRIPT_DIR/create-ct-and-install.sh" root@"$AGLSRV1":"$REMOTE_DIR/"
ssh root@"$AGLSRV1" "chmod +x $REMOTE_DIR/create-ct-and-install.sh && $REMOTE_DIR/create-ct-and-install.sh"

echo -e "\n${GREEN}Deploy concluído!${NC}"
echo -e "Acesse: ${BLUE}https://192.168.0.210:5000${NC}"
