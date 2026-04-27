#!/bin/bash

################################################################################
# EXECUTE-NOW.sh - Guia de Execução Imediata
# VPS Timeout Fix - Implementation Assistant
#
# Este script NÃO executa mudanças automaticamente.
# Ele GUIA você através dos passos necessários com comandos prontos.
#
# Uso: bash EXECUTE-NOW.sh
################################################################################

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Símbolos
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"
STAR="${YELLOW}★${NC}"

################################################################################
# Funções auxiliares
################################################################################

print_header() {
    echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${BOLD}${CYAN}▶ $1${NC}\n"
}

print_step() {
    echo -e "${ARROW} $1"
}

print_success() {
    echo -e "${CHECK} ${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  ${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${CROSS} ${RED}$1${NC}"
}

print_command() {
    echo -e "\n${BOLD}${CYAN}Execute:${NC}"
    echo -e "${BLUE}$1${NC}\n"
}

press_enter() {
    echo -e "\n${YELLOW}Pressione ENTER para continuar...${NC}"
    read -r
}

################################################################################
# Verificações Pré-Execução
################################################################################

pre_flight_checks() {
    print_header "PRÉ-FLIGHT CHECKS"

    local all_good=true

    print_section "Verificando arquivos de documentação"

    if [ -f "docs/COPY-PASTE-TEMPLATES.md" ]; then
        print_success "COPY-PASTE-TEMPLATES.md encontrado"
    else
        print_error "COPY-PASTE-TEMPLATES.md NÃO encontrado"
        all_good=false
    fi

    if [ -f "docs/VALIDATION-CHECKLIST-PRINTABLE.md" ]; then
        print_success "VALIDATION-CHECKLIST-PRINTABLE.md encontrado"
    else
        print_error "VALIDATION-CHECKLIST-PRINTABLE.md NÃO encontrado"
        all_good=false
    fi

    if [ -f "docs/METRICS-DASHBOARD.md" ]; then
        print_success "METRICS-DASHBOARD.md encontrado"
    else
        print_error "METRICS-DASHBOARD.md NÃO encontrado"
        all_good=false
    fi

    if [ -f "docs/ALL-IN-ONE-IMPLEMENTATION.md" ]; then
        print_success "ALL-IN-ONE-IMPLEMENTATION.md encontrado"
    else
        print_error "ALL-IN-ONE-IMPLEMENTATION.md NÃO encontrado"
        all_good=false
    fi

    print_section "Verificando scripts"

    if [ -f "scripts/INTERACTIVE-IMPLEMENTATION.sh" ]; then
        print_success "INTERACTIVE-IMPLEMENTATION.sh encontrado"
        if [ -x "scripts/INTERACTIVE-IMPLEMENTATION.sh" ]; then
            print_success "Script é executável"
        else
            print_warning "Script não é executável (será corrigido)"
            chmod +x scripts/INTERACTIVE-IMPLEMENTATION.sh 2>/dev/null || true
        fi
    else
        print_error "INTERACTIVE-IMPLEMENTATION.sh NÃO encontrado"
        all_good=false
    fi

    print_section "Verificando conectividade SSH"

    print_step "Testando acesso SSH aos hosts..."
    echo ""

    for host in fgsrv3 fgsrv4 fgsrv5; do
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" "echo ok" &>/dev/null; then
            print_success "$host acessível"
        else
            print_warning "$host não acessível (verifique ~/.ssh/config ou use IP)"
        fi
    done

    if [ "$all_good" = true ]; then
        echo ""
        print_success "Todos os arquivos necessários estão prontos!"
    else
        echo ""
        print_error "Alguns arquivos estão faltando. Execute o Hive Mind novamente."
        return 1
    fi

    press_enter
}

################################################################################
# Guia de Execução
################################################################################

show_execution_guide() {
    print_header "GUIA DE EXECUÇÃO - 3 OPÇÕES"

    echo -e "${BOLD}Escolha como você quer executar as correções:${NC}\n"

    echo -e "${STAR} ${BOLD}OPÇÃO 1: Script Interativo (RECOMENDADO)${NC}"
    echo -e "   ${ARROW} Guiado passo-a-passo com menu"
    echo -e "   ${ARROW} Mais fácil para iniciantes"
    echo -e "   ${ARROW} Progresso salvo automaticamente"
    print_command "bash scripts/INTERACTIVE-IMPLEMENTATION.sh"

    echo -e "${STAR} ${BOLD}OPÇÃO 2: Templates Copy-Paste (RÁPIDO)${NC}"
    echo -e "   ${ARROW} Comandos prontos para copiar"
    echo -e "   ${ARROW} Ideal para quem conhece os sistemas"
    echo -e "   ${ARROW} Máxima velocidade"
    print_command "cat docs/COPY-PASTE-TEMPLATES.md"

    echo -e "${STAR} ${BOLD}OPÇÃO 3: Guia Consolidado (COMPLETO)${NC}"
    echo -e "   ${ARROW} Explicações detalhadas"
    echo -e "   ${ARROW} 85 minutos de implementação"
    echo -e "   ${ARROW} Entendimento completo"
    print_command "cat docs/ALL-IN-ONE-IMPLEMENTATION.md"

    echo -e "\n${BOLD}${YELLOW}Qual opção você prefere? [1/2/3]:${NC} "
    read -r choice

    case $choice in
        1)
            run_interactive_script
            ;;
        2)
            show_copy_paste_templates
            ;;
        3)
            show_consolidated_guide
            ;;
        *)
            print_error "Opção inválida"
            show_execution_guide
            ;;
    esac
}

################################################################################
# Opção 1: Script Interativo
################################################################################

run_interactive_script() {
    print_header "SCRIPT INTERATIVO"

    print_section "Preparando para executar script interativo"

    if [ -f "scripts/INTERACTIVE-IMPLEMENTATION.sh" ]; then
        print_step "Script encontrado: scripts/INTERACTIVE-IMPLEMENTATION.sh"
        print_step "Este script irá guiá-lo através de cada correção"
        print_step "Você poderá escolher quais correções executar"

        echo ""
        print_warning "IMPORTANTE: O script abrirá um menu interativo"
        print_warning "Você precisará ter acesso SSH aos 3 hosts (fgsrv3, fgsrv4, fgsrv5)"

        echo ""
        echo -e "${BOLD}Pronto para começar? [s/N]:${NC} "
        read -r confirm

        if [[ $confirm =~ ^[SsYy]$ ]]; then
            print_success "Iniciando script interativo..."
            echo ""
            bash scripts/INTERACTIVE-IMPLEMENTATION.sh
        else
            print_warning "Execução cancelada"
            show_execution_guide
        fi
    else
        print_error "Script não encontrado!"
        print_step "Criando script..."
        # Aqui o script seria criado, mas já deve existir
    fi
}

################################################################################
# Opção 2: Templates Copy-Paste
################################################################################

show_copy_paste_templates() {
    print_header "TEMPLATES COPY-PASTE"

    print_section "Abrindo arquivo de templates"

    if [ -f "docs/COPY-PASTE-TEMPLATES.md" ]; then
        print_success "Arquivo encontrado"
        print_step "Abrindo com visualizador..."

        echo ""
        print_warning "Este arquivo contém comandos prontos para cada correção"
        print_warning "Copie e cole nos respectivos hosts via SSH"

        echo ""
        echo -e "${BOLD}Como você quer visualizar? [1=less, 2=cat, 3=editor]:${NC} "
        read -r view_choice

        case $view_choice in
            1)
                less docs/COPY-PASTE-TEMPLATES.md
                ;;
            2)
                cat docs/COPY-PASTE-TEMPLATES.md
                press_enter
                ;;
            3)
                ${EDITOR:-nano} docs/COPY-PASTE-TEMPLATES.md
                ;;
            *)
                cat docs/COPY-PASTE-TEMPLATES.md
                press_enter
                ;;
        esac

        show_next_steps
    else
        print_error "Arquivo não encontrado!"
    fi
}

################################################################################
# Opção 3: Guia Consolidado
################################################################################

show_consolidated_guide() {
    print_header "GUIA CONSOLIDADO"

    print_section "Abrindo guia completo"

    if [ -f "docs/ALL-IN-ONE-IMPLEMENTATION.md" ]; then
        print_success "Arquivo encontrado"
        print_step "Este guia contém todas as 5 correções detalhadas"
        print_step "Tempo estimado: 85 minutos"

        echo ""
        echo -e "${BOLD}Como você quer visualizar? [1=less, 2=cat, 3=editor]:${NC} "
        read -r view_choice

        case $view_choice in
            1)
                less docs/ALL-IN-ONE-IMPLEMENTATION.md
                ;;
            2)
                cat docs/ALL-IN-ONE-IMPLEMENTATION.md
                press_enter
                ;;
            3)
                ${EDITOR:-nano} docs/ALL-IN-ONE-IMPLEMENTATION.md
                ;;
            *)
                cat docs/ALL-IN-ONE-IMPLEMENTATION.md
                press_enter
                ;;
        esac

        show_next_steps
    else
        print_error "Arquivo não encontrado!"
    fi
}

################################################################################
# Próximos Passos
################################################################################

show_next_steps() {
    print_header "PRÓXIMOS PASSOS"

    echo -e "${BOLD}Após executar as correções:${NC}\n"

    print_step "1. Prepare para monitoramento amanhã (09:00-10:00)"
    print_command "cat docs/TOMORROW-MONITORING-GUIDE.md"

    print_step "2. Imprima o checklist de validação"
    print_command "cat docs/VALIDATION-CHECKLIST-PRINTABLE.md | lp"

    print_step "3. Deixe o dashboard de métricas aberto"
    print_command "cat docs/METRICS-DASHBOARD.md"

    echo ""
    print_success "Boa sorte com a implementação!"

    echo ""
    echo -e "${BOLD}Quer ver outra opção? [s/N]:${NC} "
    read -r again

    if [[ $again =~ ^[SsYy]$ ]]; then
        show_execution_guide
    else
        print_success "Execução finalizada. Até amanhã!"
    fi
}

################################################################################
# Ações Rápidas
################################################################################

quick_actions_menu() {
    print_header "AÇÕES RÁPIDAS"

    echo -e "${BOLD}Escolha uma ação:${NC}\n"

    echo "1) Abrir SSH em 3 terminais (fgsrv3, fgsrv4, fgsrv5)"
    echo "2) Verificar status atual dos hosts"
    echo "3) Backup de configurações atuais"
    echo "4) Ver documentação completa"
    echo "5) Voltar ao menu principal"
    echo "0) Sair"

    echo ""
    echo -e "${BOLD}Opção:${NC} "
    read -r action

    case $action in
        1)
            open_ssh_terminals
            ;;
        2)
            check_hosts_status
            ;;
        3)
            backup_configs
            ;;
        4)
            show_docs_menu
            ;;
        5)
            show_execution_guide
            ;;
        0)
            print_success "Até logo!"
            exit 0
            ;;
        *)
            print_error "Opção inválida"
            quick_actions_menu
            ;;
    esac
}

open_ssh_terminals() {
    print_section "Abrindo terminais SSH"

    print_step "Tentando abrir 3 terminais..."

    # Tenta detectar o terminal emulator
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "ssh fgsrv3; bash" &
        gnome-terminal -- bash -c "ssh fgsrv4; bash" &
        gnome-terminal -- bash -c "ssh fgsrv5; bash" &
        print_success "3 terminais gnome-terminal abertos"
    elif command -v xterm &> /dev/null; then
        xterm -e "ssh fgsrv3" &
        xterm -e "ssh fgsrv4" &
        xterm -e "ssh fgsrv5" &
        print_success "3 terminais xterm abertos"
    else
        print_warning "Não foi possível detectar terminal emulator"
        print_step "Execute manualmente em 3 terminais separados:"
        echo ""
        echo "Terminal 1: ssh fgsrv3"
        echo "Terminal 2: ssh fgsrv4"
        echo "Terminal 3: ssh fgsrv5"
    fi

    press_enter
    quick_actions_menu
}

check_hosts_status() {
    print_section "Verificando status dos hosts"

    for host in fgsrv3 fgsrv4 fgsrv5; do
        echo ""
        print_step "Verificando $host..."

        if ssh -o ConnectTimeout=5 "$host" "hostname && uptime" 2>/dev/null; then
            print_success "$host OK"
        else
            print_error "$host não acessível"
        fi
    done

    press_enter
    quick_actions_menu
}

backup_configs() {
    print_section "Backup de configurações"

    print_warning "Esta ação criará backups das configurações atuais"
    echo ""
    echo -e "${BOLD}Continuar? [s/N]:${NC} "
    read -r confirm

    if [[ $confirm =~ ^[SsYy]$ ]]; then
        print_step "Criando backups..."

        # Aqui seriam executados os comandos de backup em cada host
        print_command "ssh fgsrv3 'sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup-\$(date +%Y%m%d)'"
        print_command "ssh fgsrv4 'sudo cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.backup-\$(date +%Y%m%d)'"
        print_command "ssh fgsrv5 'sudo cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.backup-\$(date +%Y%m%d)'"

        print_warning "Copie e execute os comandos acima em cada host"
    fi

    press_enter
    quick_actions_menu
}

show_docs_menu() {
    print_header "DOCUMENTAÇÃO DISPONÍVEL"

    echo -e "${BOLD}Escolha o documento:${NC}\n"

    echo "1) COPY-PASTE-TEMPLATES.md - Comandos prontos"
    echo "2) ALL-IN-ONE-IMPLEMENTATION.md - Guia consolidado"
    echo "3) TOMORROW-MONITORING-GUIDE.md - Monitoramento amanhã"
    echo "4) VALIDATION-CHECKLIST-PRINTABLE.md - Checklist impressa"
    echo "5) METRICS-DASHBOARD.md - Dashboard de métricas"
    echo "6) FINAL-SUMMARY.md - Sumário executivo"
    echo "7) CHEAT-SHEET.md - Referência rápida"
    echo "0) Voltar"

    echo ""
    echo -e "${BOLD}Opção:${NC} "
    read -r doc_choice

    local doc_file=""

    case $doc_choice in
        1) doc_file="docs/COPY-PASTE-TEMPLATES.md" ;;
        2) doc_file="docs/ALL-IN-ONE-IMPLEMENTATION.md" ;;
        3) doc_file="docs/TOMORROW-MONITORING-GUIDE.md" ;;
        4) doc_file="docs/VALIDATION-CHECKLIST-PRINTABLE.md" ;;
        5) doc_file="docs/METRICS-DASHBOARD.md" ;;
        6) doc_file="docs/FINAL-SUMMARY.md" ;;
        7) doc_file="docs/CHEAT-SHEET.md" ;;
        0) quick_actions_menu; return ;;
        *) print_error "Opção inválida"; show_docs_menu; return ;;
    esac

    if [ -f "$doc_file" ]; then
        less "$doc_file"
    else
        print_error "Arquivo não encontrado: $doc_file"
    fi

    show_docs_menu
}

################################################################################
# Main
################################################################################

main() {
    clear

    print_header "VPS TIMEOUT FIX - EXECUÇÃO IMEDIATA"

    echo -e "${BOLD}Bem-vindo ao assistente de execução!${NC}"
    echo -e "Este script irá guiá-lo através da implementação das correções.\n"

    print_warning "IMPORTANTE: Você precisará ter acesso SSH aos hosts:"
    echo -e "  ${ARROW} fgsrv3 (MySQL)"
    echo -e "  ${ARROW} fgsrv4 (nginx/PHP5 - falg.com.br)"
    echo -e "  ${ARROW} fgsrv5 (Laravel - api.falg.com.br)"

    press_enter

    # Verificações pré-execução
    pre_flight_checks || exit 1

    # Menu principal
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}Menu Principal:${NC}\n"
        echo "1) Guia de Execução (3 opções)"
        echo "2) Ações Rápidas"
        echo "3) Documentação"
        echo "0) Sair"

        echo ""
        echo -e "${BOLD}Opção:${NC} "
        read -r main_choice

        case $main_choice in
            1)
                show_execution_guide
                ;;
            2)
                quick_actions_menu
                ;;
            3)
                show_docs_menu
                ;;
            0)
                print_success "Até logo!"
                exit 0
                ;;
            *)
                print_error "Opção inválida"
                ;;
        esac
    done
}

# Executar
main "$@"
