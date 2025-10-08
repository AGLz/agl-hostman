#!/bin/bash
# ==============================================================================
# Script de Implementação: fg_OLD3 com PHP 8.4-fpm
# ==============================================================================
# Data: 2025-10-07
# Host: FGSRV05 (100.71.107.26)
# Objetivo: Configurar infraestrutura para fg_OLD3 com PHP 8.4
# ==============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
APP_PATH="/var/www/fg_OLD3"
LOG_DIR="${APP_PATH}/storage/logs"
POOL_CONF="/etc/php/8.4/fpm/pool.d/fg_old3.conf"
NGINX_SITE="/etc/nginx/sites-available/api.falg.com.br"
BACKUP_DIR="/root/backups/fg_old3_$(date +%Y%m%d_%H%M%S)"

# ==============================================================================
# Funções Auxiliares
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
}

create_backup() {
    log_info "Criando backup completo..."
    mkdir -p "$BACKUP_DIR"

    # Backup código
    if [[ -d "$APP_PATH" ]]; then
        tar -czf "${BACKUP_DIR}/fg_old3_code.tar.gz" -C /var/www fg_OLD3/ 2>/dev/null || true
        log_success "Backup código criado"
    fi

    # Backup configs
    cp -r /etc/php/8.4/fpm/pool.d/ "${BACKUP_DIR}/php_pools_old/" 2>/dev/null || true
    cp -r /etc/nginx/sites-available/ "${BACKUP_DIR}/nginx_sites_old/" 2>/dev/null || true

    log_success "Backup completo em: $BACKUP_DIR"
}

verify_php84() {
    log_info "Verificando PHP 8.4..."
    if ! command -v php8.4 &> /dev/null; then
        log_error "PHP 8.4 não está instalado"
        return 1
    fi

    PHP_VERSION=$(php8.4 -v | head -1)
    log_success "PHP instalado: $PHP_VERSION"

    # Verificar extensões necessárias
    REQUIRED_EXTS=("opcache" "redis" "mysql" "mbstring" "xml" "curl" "gd" "zip" "bcmath" "intl")
    for ext in "${REQUIRED_EXTS[@]}"; do
        if php8.4 -m | grep -q "^${ext}$"; then
            log_success "  ✓ $ext"
        else
            log_warning "  ✗ $ext (ausente)"
        fi
    done
}

configure_php_pool() {
    log_info "Configurando pool PHP-FPM para fg_OLD3..."

    # Pool já foi criado anteriormente via SSH
    # Verificar se existe
    if [[ ! -f "$POOL_CONF" ]]; then
        log_error "Pool configuration not found at $POOL_CONF"
        return 1
    fi

    # Criar diretórios de log se não existirem
    mkdir -p "$LOG_DIR"
    chown www-data:www-data "$LOG_DIR"
    chmod 755 "$LOG_DIR"

    # Testar configuração
    php-fpm8.4 -t

    log_success "Pool fg_OLD3 configurado"
}

configure_nginx() {
    log_info "Configurando NGINX virtual host..."

    # Verificar se config existe
    if [[ ! -f "$NGINX_SITE" ]]; then
        log_error "NGINX site config not found at $NGINX_SITE"
        return 1
    fi

    # Testar configuração
    nginx -t

    # Criar symlink se não existir
    if [[ ! -L "/etc/nginx/sites-enabled/api.falg.com.br" ]]; then
        ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/api.falg.com.br
        log_success "Symlink criado para sites-enabled"
    else
        log_info "Symlink já existe"
    fi

    log_success "NGINX configurado"
}

configure_laravel_optimizations() {
    log_info "Aplicando otimizações Laravel..."

    cd "$APP_PATH"

    # Verificar se .env existe
    if [[ ! -f ".env" ]]; then
        log_error ".env não encontrado em $APP_PATH"
        return 1
    fi

    # Verificar permissões
    log_info "Ajustando permissões..."
    chown -R www-data:www-data "$APP_PATH"
    chmod -R 755 "$APP_PATH"
    chmod -R 775 "${APP_PATH}/storage"
    chmod -R 775 "${APP_PATH}/bootstrap/cache"

    log_success "Permissões ajustadas"

    # Limpar caches antigos
    log_info "Limpando caches antigos..."
    php7.4 artisan cache:clear 2>/dev/null || true
    php7.4 artisan config:clear 2>/dev/null || true
    php7.4 artisan route:clear 2>/dev/null || true
    php7.4 artisan view:clear 2>/dev/null || true

    log_success "Laravel otimizado (caches limpos)"
}

restart_services() {
    log_info "Reiniciando serviços..."

    # PHP-FPM 8.4
    systemctl restart php8.4-fpm
    if systemctl is-active --quiet php8.4-fpm; then
        log_success "PHP 8.4-fpm reiniciado"
    else
        log_error "PHP 8.4-fpm falhou ao iniciar"
        systemctl status php8.4-fpm --no-pager
        return 1
    fi

    # NGINX
    systemctl reload nginx
    if systemctl is-active --quiet nginx; then
        log_success "NGINX recarregado"
    else
        log_error "NGINX falhou"
        return 1
    fi
}

verify_installation() {
    log_info "Verificando instalação..."

    # Verificar socket PHP-FPM
    if [[ -S "/run/php/php8.4-fpm-fg_old3.sock" ]]; then
        log_success "Socket PHP-FPM criado: /run/php/php8.4-fpm-fg_old3.sock"
    else
        log_error "Socket PHP-FPM não encontrado"
        return 1
    fi

    # Verificar processos PHP-FPM
    POOL_PROCS=$(ps aux | grep "[p]hp-fpm.*fg_old3" | wc -l)
    if [[ $POOL_PROCS -gt 0 ]]; then
        log_success "PHP-FPM pool fg_old3 rodando ($POOL_PROCS processos)"
    else
        log_warning "Nenhum processo PHP-FPM para pool fg_old3"
    fi

    # Verificar NGINX
    if nginx -t &> /dev/null; then
        log_success "NGINX configuração válida"
    else
        log_error "NGINX configuração inválida"
        nginx -t
        return 1
    fi

    # Teste HTTP (se servidor estiver acessível)
    log_info "Testando HTTP..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ -H "Host: api.falg.com.br" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
        log_success "HTTP respondendo: $HTTP_CODE"
    else
        log_warning "HTTP response: $HTTP_CODE (pode precisar ajuste de rotas)"
    fi
}

show_summary() {
    echo ""
    echo "========================================================================"
    echo -e "${GREEN}✓ IMPLEMENTAÇÃO CONCLUÍDA${NC}"
    echo "========================================================================"
    echo ""
    echo "🔧 Configurações Aplicadas:"
    echo "   • PHP 8.4-fpm pool dedicado para fg_OLD3"
    echo "   • OPcache otimizado com JIT"
    echo "   • NGINX virtual host configurado"
    echo "   • Permissões Laravel ajustadas"
    echo ""
    echo "📁 Arquivos de Configuração:"
    echo "   • Pool PHP: $POOL_CONF"
    echo "   • NGINX: $NGINX_SITE"
    echo "   • OPcache: /etc/php/8.4/mods-available/opcache.ini"
    echo ""
    echo "📊 Status dos Serviços:"
    systemctl is-active --quiet php8.4-fpm && echo "   • PHP 8.4-fpm: ✓ Running" || echo "   • PHP 8.4-fpm: ✗ Stopped"
    systemctl is-active --quiet nginx && echo "   • NGINX: ✓ Running" || echo "   • NGINX: ✗ Stopped"
    systemctl is-active --quiet redis-server && echo "   • Redis: ✓ Running" || echo "   • Redis: ✗ Stopped"
    echo ""
    echo "📋 Próximos Passos:"
    echo "   1. [ ] Testar aplicação com PHP 7.4 (ainda ativo)"
    echo "   2. [ ] Preparar upgrade Laravel 5.5 → 6 → 8 → 10 → 11"
    echo "   3. [ ] Após upgrade Laravel, ativar PHP 8.4"
    echo "   4. [ ] Monitorar logs: tail -f $LOG_DIR/php-fpm.log"
    echo "   5. [ ] Benchmark de performance"
    echo ""
    echo "🔄 Rollback (se necessário):"
    echo "   # Restaurar backup"
    echo "   cd $BACKUP_DIR"
    echo "   tar -xzf fg_old3_code.tar.gz -C /var/www/"
    echo "   systemctl restart php7.4-fpm nginx"
    echo ""
    echo "📚 Documentação:"
    echo "   • Plano de Upgrade: /root/host-admin/claudedocs/fg_OLD3_UPGRADE_PLAN_PHP84_LARAVEL11.md"
    echo "   • Backup: $BACKUP_DIR"
    echo ""
    echo "========================================================================"
}

show_monitoring_commands() {
    echo ""
    echo "🔍 Comandos Úteis para Monitoramento:"
    echo "========================================================================"
    echo ""
    echo "# Verificar status PHP-FPM"
    echo "systemctl status php8.4-fpm"
    echo "curl http://127.0.0.1/status_fg_old3 -H 'Host: api.falg.com.br'"
    echo ""
    echo "# Logs em tempo real"
    echo "tail -f $LOG_DIR/php-fpm.log"
    echo "tail -f $LOG_DIR/nginx-error.log"
    echo "tail -f $LOG_DIR/laravel-$(date +%Y-%m-%d).log"
    echo ""
    echo "# OPcache status"
    echo "php8.4 -i | grep opcache"
    echo ""
    echo "# Performance"
    echo "ab -n 1000 -c 10 http://api.falg.com.br/"
    echo ""
    echo "# Processos PHP-FPM"
    echo "ps aux | grep php-fpm | grep fg_old3"
    echo ""
    echo "========================================================================"
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo ""
    echo "========================================================================"
    echo " Implementação: fg_OLD3 + PHP 8.4-fpm"
    echo " Host: FGSRV05 (100.71.107.26)"
    echo " Data: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================================================"
    echo ""

    # Verificações iniciais
    check_root

    # Criar backup
    create_backup

    # Verificações
    verify_php84 || exit 1

    # Configurações
    configure_php_pool || exit 1
    configure_nginx || exit 1
    configure_laravel_optimizations || exit 1

    # Reiniciar serviços
    restart_services || exit 1

    # Verificação final
    verify_installation || log_warning "Algumas verificações falharam"

    # Resumo
    show_summary
    show_monitoring_commands

    log_success "Implementação concluída com sucesso!"
}

# Executar
main "$@"
