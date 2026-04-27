#!/bin/bash

################################################################################
# discover-vps-hosts.sh - Descobrir IPs dos VPS Locaweb
#
# Objetivo: Encontrar IPs de fgsrv3, fgsrv4, fgsrv5 via múltiplos métodos
# Uso: bash discover-vps-hosts.sh
################################################################################

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Símbolos
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  VPS HOST DISCOVERY - Locaweb Infrastructure${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

################################################################################
# Função: Testar SSH
################################################################################

test_ssh() {
    local host=$1
    local ip=$2
    local timeout=3

    if timeout $timeout ssh -o ConnectTimeout=$timeout -o BatchMode=yes "$ip" "hostname" 2>/dev/null | grep -qi "$host"; then
        echo -e "${CHECK} ${GREEN}$host encontrado em $ip${NC}"
        return 0
    else
        return 1
    fi
}

################################################################################
# Método 1: DNS Resolution
################################################################################

echo -e "${CYAN}▶ Método 1: Resolução DNS${NC}\n"

echo "Resolvendo falg.com.br..."
if FGSRV4_IP=$(host -t A falg.com.br 2>/dev/null | grep "has address" | awk '{print $4}' | head -1); then
    echo -e "${ARROW} falg.com.br = $FGSRV4_IP"
    if timeout 2 ping -c 1 "$FGSRV4_IP" &>/dev/null; then
        echo -e "${CHECK} $FGSRV4_IP responde (possível fgsrv4)"
    fi
else
    echo -e "${CROSS} Não foi possível resolver falg.com.br"
fi

echo ""
echo "Resolvendo api.falg.com.br..."
if FGSRV5_IP=$(host -t A api.falg.com.br 2>/dev/null | grep "has address" | awk '{print $4}' | head -1); then
    echo -e "${ARROW} api.falg.com.br = $FGSRV5_IP"
    if timeout 2 ping -c 1 "$FGSRV5_IP" &>/dev/null; then
        echo -e "${CHECK} $FGSRV5_IP responde (possível fgsrv5)"
    fi
else
    echo -e "${CROSS} Não foi possível resolver api.falg.com.br"
fi

echo -e "\n${BLUE}───────────────────────────────────────────────────────${NC}\n"

################################################################################
# Método 2: WireGuard Peers
################################################################################

echo -e "${CYAN}▶ Método 2: WireGuard Peers${NC}\n"

if command -v wg &> /dev/null; then
    echo "Listando peers WireGuard conhecidos:"
    wg show all 2>/dev/null | grep -E "peer:|endpoint:|allowed ips:" || echo -e "${CROSS} Nenhum peer WireGuard encontrado"

    echo ""
    echo "Testando conectividade com peers WireGuard..."

    # IPs conhecidos da documentação
    KNOWN_WG_IPS=(
        "10.6.0.5:fgsrv6"
        "10.6.0.11:fgsrv5"
        "10.6.0.10:aglsrv1"
        "10.6.0.12:aglsrv6"
        "10.6.0.19:ct179"
    )

    for entry in "${KNOWN_WG_IPS[@]}"; do
        IFS=':' read -r ip hostname <<< "$entry"
        echo -e "${ARROW} Testando $hostname ($ip)..."
        if timeout 2 ping -c 1 "$ip" &>/dev/null; then
            echo -e "${CHECK} $ip responde"
            if timeout 3 ssh -o ConnectTimeout=2 -o BatchMode=yes "root@$ip" "hostname" &>/dev/null; then
                ACTUAL_HOSTNAME=$(ssh -o ConnectTimeout=2 -o BatchMode=yes "root@$ip" "hostname" 2>/dev/null)
                echo -e "   ${GREEN}SSH OK! Hostname: $ACTUAL_HOSTNAME${NC}"
            fi
        else
            echo -e "${CROSS} $ip não responde"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC}  WireGuard não instalado ou não configurado"
fi

echo -e "\n${BLUE}───────────────────────────────────────────────────────${NC}\n"

################################################################################
# Método 3: Scan WireGuard Network
################################################################################

echo -e "${CYAN}▶ Método 3: Network Scan (10.6.0.0/24)${NC}\n"

if command -v nmap &> /dev/null; then
    echo "Escaneando rede WireGuard..."
    nmap -sn 10.6.0.0/24 2>/dev/null | grep -E "Nmap scan report|Host is up" || echo -e "${CROSS} Nenhum host encontrado"
else
    echo -e "${YELLOW}⚠${NC}  nmap não instalado, tentando ping manual..."

    echo "Testando IPs 10.6.0.1-20..."
    for i in {1..20}; do
        ip="10.6.0.$i"
        if timeout 1 ping -c 1 "$ip" &>/dev/null; then
            echo -e "${CHECK} $ip responde"
        fi
    done
fi

echo -e "\n${BLUE}───────────────────────────────────────────────────────${NC}\n"

################################################################################
# Método 4: SSH Known Hosts
################################################################################

echo -e "${CYAN}▶ Método 4: SSH Known Hosts${NC}\n"

if [ -f ~/.ssh/known_hosts ]; then
    echo "Buscando hosts conhecidos..."
    grep -E "fgsrv|falg|10\.6\.0" ~/.ssh/known_hosts 2>/dev/null || echo -e "${CROSS} Nenhum host relevante em known_hosts"
else
    echo -e "${CROSS} Arquivo ~/.ssh/known_hosts não encontrado"
fi

echo -e "\n${BLUE}───────────────────────────────────────────────────────${NC}\n"

################################################################################
# Método 5: Tentar SSHs Diretos
################################################################################

echo -e "${CYAN}▶ Método 5: Tentativas SSH Diretas${NC}\n"

# Lista de possíveis IPs baseados na documentação
POSSIBLE_IPS=(
    "10.6.0.11"  # fgsrv5 (documentado)
    "10.6.0.3"   # possível fgsrv3
    "10.6.0.4"   # possível fgsrv4
    "10.6.0.13"
    "10.6.0.14"
    "10.6.0.15"
)

for ip in "${POSSIBLE_IPS[@]}"; do
    echo -e "${ARROW} Tentando SSH em $ip..."
    if timeout 3 ssh -o ConnectTimeout=2 -o BatchMode=yes "root@$ip" "hostname" 2>/dev/null; then
        HOSTNAME=$(ssh -o ConnectTimeout=2 -o BatchMode=yes "root@$ip" "hostname" 2>/dev/null)
        echo -e "${CHECK} ${GREEN}SSH OK! Hostname: $HOSTNAME em $ip${NC}"

        # Detectar tipo de serviço
        if ssh -o ConnectTimeout=2 -o BatchMode=yes "root@$ip" "which mysql" &>/dev/null; then
            echo -e "   ${ARROW} MySQL detectado (possível fgsrv3)"
        fi
        if ssh -o ConnectTimeout=2 -o BatchMode=yes "root@$ip" "which nginx" &>/dev/null; then
            echo -e "   ${ARROW} nginx detectado (possível fgsrv4 ou fgsrv5)"
        fi
    else
        echo -e "${CROSS} SSH falhou ou host não responde"
    fi
done

echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  RESUMO DOS RESULTADOS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

# Resumo
echo -e "${YELLOW}Hosts Conhecidos:${NC}"
echo "  fgsrv6: 186.202.57.120 / 10.6.0.5 ✅"
echo "  fgsrv5: ${FGSRV5_IP:-'?'} (via DNS) / 10.6.0.11 (via WG)"
echo "  fgsrv4: ${FGSRV4_IP:-'?'} (via DNS)"
echo "  fgsrv3: ❓ Ainda não descoberto"

echo -e "\n${YELLOW}Próximos Passos:${NC}"
echo "1. Se algum IP foi descoberto, testar SSH manualmente:"
echo "   ssh root@[IP]"
echo ""
echo "2. Se nenhum IP foi descoberto, consultar:"
echo "   - Painel de controle Locaweb"
echo "   - Documentação de infraestrutura"
echo "   - Administrador do sistema"
echo ""
echo "3. Após descobrir IPs, configurar ~/.ssh/config:"
echo "   nano ~/.ssh/config"
echo ""
echo "4. Então executar:"
echo "   bash /mnt/overpower/apps/dev/agl/agl-hostman/EXECUTE-NOW.sh"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}\n"
