#!/bin/bash

#############################################################################
# VPS Timeout Fix - Interactive Implementation Script
#############################################################################
#
# Este script guia você através da implementação passo-a-passo
# de todas as correções necessárias para resolver os timeouts.
#
# Uso: bash INTERACTIVE-IMPLEMENTATION.sh
#
#############################################################################

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Variáveis
COMPLETION_LOG="/tmp/vps-timeout-fix-progress.log"
EVIDENCE_DIR="/tmp/vps-timeout-fix-evidence-$(date +%Y%m%d)"

#############################################################################
# Funções de Interface
#############################################################################

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                                          ║${NC}"
    echo -e "${BLUE}║${CYAN}   🚀 VPS TIMEOUT FIX - IMPLEMENTAÇÃO INTERATIVA                        ${BLUE}║${NC}"
    echo -e "${BLUE}║                                                                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

ask_continue() {
    echo ""
    echo -e "${YELLOW}Pressione ENTER para continuar...${NC}"
    read -r
}

ask_yes_no() {
    local question="$1"
    local response
    while true; do
        echo -e "${YELLOW}$question (s/n): ${NC}\c"
        read -r response
        case "$response" in
            [Ss]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Por favor, responda s ou n.";;
        esac
    done
}

log_completion() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$COMPLETION_LOG"
}

#############################################################################
# Menu Principal
#############################################################################

show_menu() {
    print_header

    echo -e "${CYAN}Escolha uma ação:${NC}"
    echo ""
    echo "  ${GREEN}1)${NC} Implementação Completa (85 minutos)"
    echo "  ${GREEN}2)${NC} Apenas Backup MySQL (5 minutos) - 70% impacto"
    echo "  ${GREEN}3)${NC} Apenas Cron Jobs (15 minutos) - 50% impacto"
    echo "  ${GREEN}4)${NC} Apenas PHP-FPM (30 minutos) - 30% impacto"
    echo "  ${GREEN}5)${NC} Apenas MySQL Slow Query (15 minutos)"
    echo "  ${GREEN}6)${NC} Apenas nginx (20 minutos)"
    echo "  ${GREEN}7)${NC} Ver progresso atual"
    echo "  ${GREEN}8)${NC} Guias de implementação manual"
    echo "  ${GREEN}9)${NC} Verificar pré-requisitos"
    echo "  ${GREEN}0)${NC} Sair"
    echo ""
    echo -e "${YELLOW}Opção: ${NC}\c"
}

#############################################################################
# Verificação de Pré-requisitos
#############################################################################

check_prerequisites() {
    print_header
    print_section "VERIFICAÇÃO DE PRÉ-REQUISITOS"

    local all_ok=true

    # Verificar conectividade SSH
    print_step "Verificando conectividade SSH aos hosts..."

    for host in fgsrv3 fgsrv4 fgsrv5; do
        if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "$host" "echo 'OK'" &>/dev/null; then
            print_success "$host: SSH OK"
        else
            print_warning "$host: SSH sem chave pública (requer senha)"
        fi
    done

    echo ""
    print_step "Verificando ferramentas necessárias..."

    # Verificar ferramentas locais
    local tools=("ssh" "scp" "mysql" "curl" "tar")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            print_success "$tool: Instalado"
        else
            print_error "$tool: NÃO instalado"
            all_ok=false
        fi
    done

    echo ""
    if [ "$all_ok" = true ]; then
        print_success "Todos os pré-requisitos OK!"
    else
        print_warning "Alguns pré-requisitos faltando. Instale as ferramentas necessárias."
    fi

    ask_continue
}

#############################################################################
# Implementação 1: Backup MySQL
#############################################################################

implement_backup_mysql() {
    print_header
    print_section "1️⃣ REAGENDAR BACKUP MYSQL (70% impacto)"

    print_info "Esta é a correção mais crítica!"
    print_info "Tempo estimado: 5 minutos"
    print_info "Host: fgsrv3"
    echo ""

    if ! ask_yes_no "Continuar com esta implementação?"; then
        return
    fi

    print_step "Passo 1: Conecte-se ao fgsrv3"
    echo ""
    echo -e "${CYAN}Execute em outro terminal:${NC}"
    echo -e "${YELLOW}  ssh fgsrv3${NC}"
    echo ""
    ask_continue

    print_step "Passo 2: Localizar backup no cron"
    echo ""
    echo -e "${CYAN}Execute no fgsrv3:${NC}"
    echo ""
    cat << 'COMMANDS'
# Verificar cron do usuário
crontab -l | grep -E "backup|dump|9"

# Verificar cron do root
sudo crontab -l | grep -E "backup|dump|9"

# Verificar sistema
sudo grep -E "backup|dump|9" /etc/crontab

# Verificar cron.d
sudo grep -rE "backup|dump|9" /etc/cron.d/
COMMANDS
    echo ""
    ask_continue

    print_step "Passo 3: Identificou o backup?"
    echo ""

    if ask_yes_no "Encontrou a linha do backup?"; then
        echo ""
        print_step "Passo 4: Editar cron"
        echo ""
        echo -e "${CYAN}Se o backup está no cron do usuário:${NC}"
        echo -e "${YELLOW}  crontab -e${NC}"
        echo ""
        echo -e "${CYAN}Se o backup está no cron do root:${NC}"
        echo -e "${YELLOW}  sudo crontab -e${NC}"
        echo ""
        echo -e "${CYAN}Se está em /etc/crontab:${NC}"
        echo -e "${YELLOW}  sudo nano /etc/crontab${NC}"
        echo ""
        ask_continue

        print_step "Passo 5: Mudar horário"
        echo ""
        echo -e "${RED}DE (exemplo):${NC}"
        echo -e "${YELLOW}  0 9 * * * /path/to/backup.sh${NC}"
        echo ""
        echo -e "${GREEN}PARA:${NC}"
        echo -e "${YELLOW}  30 2 * * * /path/to/backup.sh${NC}"
        echo ""
        echo "  (Mudou de 09:00 para 02:30)"
        echo ""
        ask_continue

        print_step "Passo 6: Verificar mudança"
        echo ""
        echo -e "${CYAN}Execute no fgsrv3:${NC}"
        echo ""
        echo -e "${YELLOW}  crontab -l | grep backup${NC}"
        echo -e "${YELLOW}  # OU${NC}"
        echo -e "${YELLOW}  sudo crontab -l | grep backup${NC}"
        echo ""
        ask_continue

        if ask_yes_no "Horário foi mudado com sucesso?"; then
            print_success "Backup MySQL reagendado com sucesso!"
            log_completion "fgsrv3: Backup MySQL reagendado de 09:00 para 02:30"

            echo ""
            print_step "Passo 7: Parar backup atual (se estiver rodando)"
            echo ""
            echo -e "${CYAN}Execute no fgsrv3:${NC}"
            echo ""
            echo -e "${YELLOW}  ps aux | grep -E 'mysqldump|backup' | grep -v grep${NC}"
            echo ""
            echo "Se houver processo rodando e travado, anote o PID e execute:"
            echo -e "${YELLOW}  sudo kill [PID]${NC}"
            echo ""
            ask_continue
        else
            print_error "Verifique a configuração novamente"
        fi
    else
        print_warning "Backup não encontrado. Verifique os comandos novamente."
        print_info "Consulte: /docs/BACKUP-RESCHEDULE-NOW.md"
    fi

    ask_continue
}

#############################################################################
# Implementação 2: Cron Jobs
#############################################################################

implement_cron_staggering() {
    print_header
    print_section "2️⃣ ESCALONAR CRON JOBS (50% impacto)"

    print_info "Distribuir jobs ao longo de 30 minutos"
    print_info "Tempo estimado: 15 minutos"
    print_info "Hosts: fgsrv3, fgsrv4, fgsrv5"
    echo ""

    if ! ask_yes_no "Continuar com esta implementação?"; then
        return
    fi

    for host in fgsrv3 fgsrv4 fgsrv5; do
        echo ""
        print_step "Processando $host..."
        echo ""

        echo -e "${CYAN}1. Conecte-se ao $host em outro terminal:${NC}"
        echo -e "${YELLOW}  ssh $host${NC}"
        echo ""
        ask_continue

        echo -e "${CYAN}2. Inventário de cron jobs:${NC}"
        echo ""
        cat << 'INVENTORY'
{
  echo "=== CRON INVENTORY ==="
  crontab -l 2>/dev/null || echo "No user crontab"
  echo "---"
  sudo crontab -l 2>/dev/null || echo "No root crontab"
  echo "---"
  sudo cat /etc/crontab
  echo "---"
  sudo grep -r "^[0-9]* 9" /etc/cron* 2>/dev/null
} | tee /tmp/cron-inventory.txt
INVENTORY
        echo ""
        ask_continue

        echo -e "${CYAN}3. Identificar jobs às 09:00:${NC}"
        echo ""
        echo -e "${YELLOW}  sudo grep -r '^0 9' /etc/cron* 2>/dev/null${NC}"
        echo ""
        ask_continue

        if ask_yes_no "Encontrou jobs às 09:00 em $host?"; then
            echo ""
            echo -e "${CYAN}4. Escalonar jobs:${NC}"
            echo ""
            echo "Estratégia recomendada:"
            echo ""
            echo -e "${GREEN}Job leve/rápido:${NC}    5 9 * * * /script1.sh  ${BLUE}(09:05)${NC}"
            echo -e "${GREEN}Job médio:${NC}         15 9 * * * /script2.sh ${BLUE}(09:15)${NC}"
            echo -e "${GREEN}Job pesado:${NC}        25 9 * * * /script3.sh ${BLUE}(09:25)${NC}"
            echo ""
            echo "OU mover para fora da janela:"
            echo -e "${GREEN}Antes do pico:${NC}     30 8 * * * /script.sh  ${BLUE}(08:30)${NC}"
            echo -e "${GREEN}Depois do pico:${NC}    30 10 * * * /script.sh ${BLUE}(10:30)${NC}"
            echo ""
            ask_continue

            echo -e "${CYAN}5. Editar cron (escolha o apropriado):${NC}"
            echo ""
            echo -e "${YELLOW}  crontab -e          ${NC}# Cron do usuário"
            echo -e "${YELLOW}  sudo crontab -e     ${NC}# Cron do root"
            echo -e "${YELLOW}  sudo nano /etc/crontab${NC}  # Cron do sistema"
            echo ""
            ask_continue

            if ask_yes_no "Jobs foram escalonados em $host?"; then
                print_success "$host: Cron jobs escalonados com sucesso!"
                log_completion "$host: Cron jobs escalonados"
            fi
        else
            print_info "$host: Nenhum job às 09:00 encontrado (OK)"
            log_completion "$host: Nenhum cron job às 09:00"
        fi
    done

    ask_continue
}

#############################################################################
# Implementação 3: PHP-FPM
#############################################################################

implement_php_fpm() {
    print_header
    print_section "3️⃣ OTIMIZAR PHP-FPM (30% impacto)"

    print_info "Worker recycling + restart diário"
    print_info "Tempo estimado: 30 minutos"
    print_info "Hosts: fgsrv4, fgsrv5"
    echo ""

    if ! ask_yes_no "Continuar com esta implementação?"; then
        return
    fi

    for host in fgsrv4 fgsrv5; do
        echo ""
        print_step "Processando $host..."
        echo ""

        echo -e "${CYAN}1. Conecte-se ao $host:${NC}"
        echo -e "${YELLOW}  ssh $host${NC}"
        echo ""
        ask_continue

        echo -e "${CYAN}2. Localizar configuração PHP-FPM:${NC}"
        echo ""
        echo -e "${YELLOW}  find /etc -name 'www.conf' 2>/dev/null${NC}"
        echo ""
        echo "Geralmente:"
        echo "  • /etc/php/7.x/fpm/pool.d/www.conf (Ubuntu/Debian)"
        echo "  • /etc/php-fpm.d/www.conf (CentOS/RHEL)"
        echo ""
        ask_continue

        echo -e "${CYAN}3. Backup da configuração:${NC}"
        echo ""
        echo -e "${YELLOW}  sudo cp /etc/php/*/fpm/pool.d/www.conf /etc/php/*/fpm/pool.d/www.conf.backup${NC}"
        echo ""
        ask_continue

        echo -e "${CYAN}4. Editar configuração:${NC}"
        echo ""
        echo -e "${YELLOW}  sudo nano /etc/php/*/fpm/pool.d/www.conf${NC}"
        echo ""
        echo "Adicionar/modificar estas linhas na seção [www]:"
        echo ""
        cat << 'CONFIG'
pm = dynamic
pm.max_children = 30
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.max_requests = 1000              ← WORKER RECYCLING!
request_terminate_timeout = 300
slowlog = /var/log/php-fpm/slow.log
request_slowlog_timeout = 5s
CONFIG
        echo ""
        ask_continue

        echo -e "${CYAN}5. Testar configuração:${NC}"
        echo ""
        echo -e "${YELLOW}  sudo php-fpm -t${NC}"
        echo ""
        ask_continue

        echo -e "${CYAN}6. Reload PHP-FPM:${NC}"
        echo ""
        echo -e "${YELLOW}  sudo systemctl reload php-fpm${NC}"
        echo ""
        ask_continue

        echo -e "${CYAN}7. Criar script de restart diário:${NC}"
        echo ""
        cat << 'SCRIPT'
sudo tee /opt/scripts/php-fpm-daily-restart.sh > /dev/null <<'EOF'
#!/bin/bash
LOG_FILE="/var/log/php-fpm-restart.log"
echo "[$(date)] Restarting PHP-FPM..." | tee -a "$LOG_FILE"
systemctl restart php-fpm && echo "[$(date)] Success" | tee -a "$LOG_FILE"
EOF

sudo chmod +x /opt/scripts/php-fpm-daily-restart.sh
SCRIPT
        echo ""
        ask_continue

        echo -e "${CYAN}8. Agendar restart diário (05:00):${NC}"
        echo ""
        echo -e "${YELLOW}  sudo crontab -e${NC}"
        echo ""
        echo "Adicionar linha:"
        echo -e "${GREEN}  0 5 * * * /opt/scripts/php-fpm-daily-restart.sh${NC}"
        echo ""
        ask_continue

        if ask_yes_no "PHP-FPM configurado com sucesso em $host?"; then
            print_success "$host: PHP-FPM otimizado!"
            log_completion "$host: PHP-FPM otimizado com worker recycling e restart diário"
        fi
    done

    ask_continue
}

#############################################################################
# Ver Progresso
#############################################################################

show_progress() {
    print_header
    print_section "PROGRESSO DA IMPLEMENTAÇÃO"

    if [ ! -f "$COMPLETION_LOG" ]; then
        print_info "Nenhuma implementação registrada ainda."
    else
        cat "$COMPLETION_LOG"
    fi

    echo ""
    print_info "Log completo: $COMPLETION_LOG"

    ask_continue
}

#############################################################################
# Mostrar Guias
#############################################################################

show_guides() {
    print_header
    print_section "GUIAS DE IMPLEMENTAÇÃO MANUAL"

    echo "Documentação completa disponível em:"
    echo ""
    echo -e "${GREEN}Guias Principais:${NC}"
    echo "  • /docs/ALL-IN-ONE-IMPLEMENTATION.md    (Guia consolidado)"
    echo "  • /docs/IMMEDIATE-ACTION-GUIDE.md       (Ações imediatas)"
    echo "  • /docs/CHEAT-SHEET.md                  (Referência rápida)"
    echo ""
    echo -e "${GREEN}Implementações Específicas:${NC}"
    echo "  • /docs/BACKUP-RESCHEDULE-NOW.md        (5 min, 70% impacto)"
    echo "  • /docs/CRON-JOBS-STAGGERING.md         (15 min, 50% impacto)"
    echo "  • /docs/PHP-FPM-OPTIMIZATION.md         (30 min, 30% impacto)"
    echo "  • /docs/MYSQL-SLOW-QUERY-LOGGING.md     (15 min)"
    echo "  • /docs/NGINX-OPTIMIZATION.md           (20 min)"
    echo ""
    echo -e "${GREEN}Scripts:${NC}"
    echo "  • /scripts/diagnostics/emergency-one-liners.sh"
    echo "  • /scripts/diagnostics/morning-monitor.sh"
    echo ""

    if ask_yes_no "Abrir um guia agora?"; then
        echo ""
        echo "Qual guia deseja ver?"
        echo "  1) ALL-IN-ONE-IMPLEMENTATION.md"
        echo "  2) BACKUP-RESCHEDULE-NOW.md"
        echo "  3) CRON-JOBS-STAGGERING.md"
        echo "  4) PHP-FPM-OPTIMIZATION.md"
        echo "  5) emergency-one-liners.sh"
        echo ""
        echo -e "${YELLOW}Opção (1-5): ${NC}\c"
        read -r guide_choice

        case "$guide_choice" in
            1) cat /mnt/overpower/apps/dev/agl/agl-hostman/docs/ALL-IN-ONE-IMPLEMENTATION.md | less;;
            2) cat /mnt/overpower/apps/dev/agl/agl-hostman/docs/BACKUP-RESCHEDULE-NOW.md | less;;
            3) cat /mnt/overpower/apps/dev/agl/agl-hostman/docs/CRON-JOBS-STAGGERING.md | less;;
            4) cat /mnt/overpower/apps/dev/agl/agl-hostman/docs/PHP-FPM-OPTIMIZATION.md | less;;
            5) cat /mnt/overpower/apps/dev/agl/agl-hostman/scripts/diagnostics/emergency-one-liners.sh | less;;
            *) print_warning "Opção inválida";;
        esac
    fi

    ask_continue
}

#############################################################################
# Implementação Completa
#############################################################################

implement_all() {
    print_header
    print_section "IMPLEMENTAÇÃO COMPLETA (85 minutos)"

    print_info "Esta opção guia você através de TODAS as 5 correções:"
    echo ""
    echo "  1. Backup MySQL (5 min) - 70% impacto"
    echo "  2. Cron Jobs (15 min) - 50% impacto"
    echo "  3. PHP-FPM (30 min) - 30% impacto"
    echo "  4. MySQL Slow Query (15 min)"
    echo "  5. nginx (20 min)"
    echo ""
    echo "  Total: ~85 minutos"
    echo ""

    if ! ask_yes_no "Continuar com implementação completa?"; then
        return
    fi

    implement_backup_mysql
    implement_cron_staggering
    implement_php_fpm

    print_header
    print_section "PRÓXIMOS PASSOS"

    echo "Você completou as 3 correções principais (1, 2, 3)!"
    echo ""
    echo "Correções opcionais restantes:"
    echo "  • MySQL Slow Query Logging (diagnóstico contínuo)"
    echo "  • nginx Optimization (melhorias de performance)"
    echo ""
    echo "Consulte os guias para implementar manualmente:"
    echo "  • /docs/MYSQL-SLOW-QUERY-LOGGING.md"
    echo "  • /docs/NGINX-OPTIMIZATION.md"
    echo ""

    ask_continue
}

#############################################################################
# Loop Principal
#############################################################################

mkdir -p "$EVIDENCE_DIR"

while true; do
    show_menu
    read -r choice

    case "$choice" in
        1) implement_all;;
        2) implement_backup_mysql;;
        3) implement_cron_staggering;;
        4) implement_php_fpm;;
        5)
            print_info "Consulte: /docs/MYSQL-SLOW-QUERY-LOGGING.md"
            ask_continue
            ;;
        6)
            print_info "Consulte: /docs/NGINX-OPTIMIZATION.md"
            ask_continue
            ;;
        7) show_progress;;
        8) show_guides;;
        9) check_prerequisites;;
        0)
            print_header
            print_success "Obrigado por usar o assistente de implementação!"
            echo ""
            print_info "Próximos passos:"
            echo "  • Validar amanhã às 09:00-10:00"
            echo "  • Coletar métricas"
            echo "  • Confirmar zero timeouts"
            echo ""
            print_info "Consulte: /docs/FINAL-SUMMARY.md"
            echo ""
            exit 0
            ;;
        *)
            print_error "Opção inválida"
            sleep 2
            ;;
    esac
done
