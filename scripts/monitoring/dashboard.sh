#!/bin/bash

# Dashboard de Status do Sistema Proxmox
# Atualização automática a cada 5 segundos

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

while true; do
    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}            DASHBOARD PROXMOX - $(hostname) ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Data e Uptime
    echo -e "${GREEN}📅 Data/Hora:${NC} $(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "${GREEN}⏱️  Uptime:${NC} $(uptime -p)"
    echo ""
    
    # ZFS Pools
    echo -e "${BLUE}═══ STORAGE ZFS ═══${NC}"
    echo ""
    zpool list -o name,size,alloc,free,cap,health | while read line; do
        if [[ $line == *"NAME"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ $line == *"ONLINE"* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ $line == *"DEGRADED"* ]] || [[ $line == *"FAULTED"* ]]; then
            echo -e "${RED}$line${NC}"
        else
            echo "$line"
        fi
    done
    echo ""
    
    # Containers Status
    echo -e "${BLUE}═══ CONTAINERS LXC ═══${NC}"
    echo ""
    
    # Contagem de containers
    TOTAL=$(pct list 2>/dev/null | tail -n +2 | wc -l)
    RUNNING=$(pct list 2>/dev/null | grep running | wc -l)
    STOPPED=$(pct list 2>/dev/null | grep stopped | wc -l)
    
    echo -e "📊 Total: ${YELLOW}$TOTAL${NC} | ✅ Running: ${GREEN}$RUNNING${NC} | ⛔ Stopped: ${RED}$STOPPED${NC}"
    echo ""
    
    # Lista de containers com status colorido
    pct list 2>/dev/null | while read line; do
        if [[ $line == *"VMID"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ $line == *"running"* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ $line == *"stopped"* ]]; then
            echo -e "${RED}$line${NC}"
        else
            echo "$line"
        fi
    done
    echo ""
    
    # Recursos do Sistema
    echo -e "${BLUE}═══ RECURSOS DO SISTEMA ═══${NC}"
    echo ""
    
    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo -e "🖥️  CPU: ${YELLOW}${CPU_USAGE}%${NC} utilizado"
    
    # Memória
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_PERCENT=$(free | awk '/^Mem:/ {printf("%.1f", $3/$2 * 100)}')
    echo -e "💾 RAM: ${YELLOW}$MEM_USED${NC} / $MEM_TOTAL (${YELLOW}${MEM_PERCENT}%${NC})"
    
    # Swap
    SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
    SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
    echo -e "💱 Swap: ${YELLOW}$SWAP_USED${NC} / $SWAP_TOTAL"
    echo ""
    
    # Serviços Ativos
    echo -e "${BLUE}═══ SERVIÇOS PRINCIPAIS ═══${NC}"
    echo ""
    
    # Verificar portas importantes
    PORTS=(3306 6969 8096 9117 80 443 22)
    SERVICES=("MySQL" "qBittorrent" "Jellyfin" "Jackett" "HTTP" "HTTPS" "SSH")
    
    for i in "${!PORTS[@]}"; do
        if ss -tuln | grep -q ":${PORTS[$i]} "; then
            echo -e "✅ ${GREEN}${SERVICES[$i]}${NC} (porta ${PORTS[$i]})"
        else
            echo -e "⛔ ${RED}${SERVICES[$i]}${NC} (porta ${PORTS[$i]})"
        fi
    done
    echo ""
    
    # Avisos e Alertas
    echo -e "${BLUE}═══ ALERTAS ═══${NC}"
    echo ""
    
    # Verificar pools com alta utilização
    zpool list -H -o name,cap | while read pool cap; do
        cap_num=${cap%\%}
        if [ "$cap_num" -gt 90 ]; then
            echo -e "⚠️  ${RED}ALERTA: Pool $pool está ${cap} cheio!${NC}"
        elif [ "$cap_num" -gt 80 ]; then
            echo -e "⚠️  ${YELLOW}Atenção: Pool $pool está ${cap} cheio${NC}"
        fi
    done
    
    # Verificar containers parados que deveriam estar rodando
    CRITICAL_CONTAINERS="120"  # Adicionar IDs dos containers críticos
    for cid in $CRITICAL_CONTAINERS; do
        if pct status $cid 2>/dev/null | grep -q stopped; then
            NAME=$(pct config $cid | grep hostname | cut -d: -f2 | xargs)
            echo -e "⚠️  ${YELLOW}Container $cid ($NAME) está parado${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "Pressione ${YELLOW}Ctrl+C${NC} para sair | Atualização a cada 5 segundos"
    
    sleep 5
done
