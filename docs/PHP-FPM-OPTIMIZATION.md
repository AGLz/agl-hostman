# 🔧 PHP-FPM OTIMIZAÇÃO - Hipótese 3 (30% probabilidade)

**Problema:** Workers PHP-FPM acumulam memória overnight, atingindo níveis críticos pela manhã
**Solução:** Implementar worker recycling e restart automático
**Prioridade:** 🟡 MÉDIA (após backup e cron jobs)

---

## 🎯 OBJETIVOS

1. Configurar PHP-FPM para reciclar workers automaticamente
2. Implementar restart diário do PHP-FPM
3. Otimizar pool settings para evitar exhaustion
4. Monitorar memory leaks

---

## 🔍 PASSO 1: DIAGNOSTICAR ESTADO ATUAL (fgsrv4 & fgsrv5)

### Verificar configuração PHP-FPM:

```bash
# Localizar arquivo de configuração
php-fpm -i | grep "Configuration File"
# OU
find /etc -name "php-fpm.conf" 2>/dev/null
find /etc -name "www.conf" 2>/dev/null

# Configurações comuns:
# - /etc/php-fpm.conf
# - /etc/php/7.x/fpm/php-fpm.conf
# - /etc/php/7.x/fpm/pool.d/www.conf

# Ver configuração atual do pool
sudo cat /etc/php/*/fpm/pool.d/www.conf | grep -E "pm\.|listen"
# OU
sudo cat /etc/php-fpm.d/www.conf | grep -E "pm\.|listen"
```

### Verificar uso atual de memória:

```bash
# Memória por processo PHP-FPM
ps aux | grep php-fpm | awk '{sum+=$6} END {print "Total PHP-FPM Memory: " sum/1024 " MB"}'

# Processos individuais ordenados por memória
ps aux | grep php-fpm | sort -k6 -nr | head -10

# Número de workers ativos
ps aux | grep php-fpm | grep -v grep | wc -l

# Status do PHP-FPM
sudo systemctl status php-fpm
```

### Verificar logs de erro:

```bash
# Localizar logs PHP-FPM
sudo find /var/log -name "*php-fpm*" 2>/dev/null

# Ver erros recentes
sudo tail -100 /var/log/php-fpm/error.log
# OU
sudo tail -100 /var/log/php*/fpm-error.log

# Procurar por "max children"
sudo grep -i "max.*children" /var/log/php*/error.log | tail -20
```

---

## 🛠️ PASSO 2: CONFIGURAR WORKER RECYCLING

### Localizar arquivo de configuração do pool:

```bash
# Geralmente em:
# - Ubuntu/Debian: /etc/php/7.x/fpm/pool.d/www.conf
# - CentOS/RHEL: /etc/php-fpm.d/www.conf

# Backup antes de editar
sudo cp /etc/php/*/fpm/pool.d/www.conf /etc/php/*/fpm/pool.d/www.conf.backup
# OU
sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.backup
```

### Editar configuração do pool:

```bash
sudo nano /etc/php/*/fpm/pool.d/www.conf
# OU
sudo nano /etc/php-fpm.d/www.conf
```

### Configurações recomendadas:

```ini
; ============================================================================
; PHP-FPM POOL CONFIGURATION - Optimized for Memory Management
; ============================================================================

[www]

; Process Manager Settings
; -----------------------
; Use 'dynamic' for variable traffic (recommended)
pm = dynamic

; Maximum number of child processes
; Calcular: (RAM disponível - RAM sistema) / (memória média por processo)
; Exemplo: (2GB - 512MB) / 50MB = ~30 processos
pm.max_children = 30

; Number of child processes created on startup
pm.start_servers = 5

; Minimum number of idle processes
pm.min_spare_servers = 5

; Maximum number of idle processes
pm.max_spare_servers = 10

; ============================================================================
; WORKER RECYCLING - Previne memory leaks
; ============================================================================

; Number of requests each child should execute before respawning
; Isto RECICLA workers automaticamente após N requisições
pm.max_requests = 1000

; Maximum time (in seconds) a process can execute
; Mata processos que ficam travados
request_terminate_timeout = 300

; ============================================================================
; SLOW REQUEST LOGGING
; ============================================================================

; Enable slow request logging
slowlog = /var/log/php-fpm/slow.log
request_slowlog_timeout = 5s

; ============================================================================
; STATUS PAGE (para monitoramento)
; ============================================================================

pm.status_path = /php-fpm-status

; ============================================================================
; MEMORY LIMITS
; ============================================================================

; Uncomment and set if not in php.ini
; php_admin_value[memory_limit] = 256M
```

### Salvar e testar configuração:

```bash
# Testar configuração
sudo php-fpm -t
# OU
sudo php-fpm7.4 -t  # Ajustar versão

# Se OK, reload PHP-FPM
sudo systemctl reload php-fpm
# OU
sudo systemctl reload php7.4-fpm  # Ajustar versão

# Verificar status
sudo systemctl status php-fpm
```

---

## 🔄 PASSO 3: IMPLEMENTAR RESTART AUTOMÁTICO DIÁRIO

### Criar script de restart inteligente:

```bash
sudo tee /opt/scripts/php-fpm-daily-restart.sh > /dev/null <<'EOF'
#!/bin/bash

#############################################################################
# PHP-FPM Daily Restart - Previne memory leaks
#############################################################################

LOG_FILE="/var/log/php-fpm-restart.log"
MAX_MEMORY_MB=1500  # Restart se PHP-FPM usar mais que 1.5GB

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Get current PHP-FPM memory usage
get_memory_usage() {
    ps aux | grep php-fpm | awk '{sum+=$6} END {print int(sum/1024)}'
}

# Main
log "=== PHP-FPM Daily Restart Script ==="

CURRENT_MEMORY=$(get_memory_usage)
log "Current PHP-FPM memory usage: ${CURRENT_MEMORY}MB"

if [ "$CURRENT_MEMORY" -gt "$MAX_MEMORY_MB" ]; then
    log "Memory usage exceeds ${MAX_MEMORY_MB}MB threshold. Forcing restart."
    FORCE_RESTART=1
else
    log "Memory usage OK. Performing graceful restart."
    FORCE_RESTART=0
fi

# Restart PHP-FPM
log "Restarting PHP-FPM..."
if systemctl restart php-fpm; then
    log "✓ PHP-FPM restarted successfully"

    # Wait for service to stabilize
    sleep 5

    # Verify
    NEW_MEMORY=$(get_memory_usage)
    log "New memory usage: ${NEW_MEMORY}MB"

    # Check if service is running
    if systemctl is-active --quiet php-fpm; then
        log "✓ PHP-FPM is running"
    else
        log "✗ ERROR: PHP-FPM failed to start!"
        exit 1
    fi
else
    log "✗ ERROR: Failed to restart PHP-FPM"
    exit 1
fi

log "=== Restart completed successfully ==="
EOF

# Tornar executável
sudo chmod +x /opt/scripts/php-fpm-daily-restart.sh

# Testar script
sudo /opt/scripts/php-fpm-daily-restart.sh
```

### Agendar restart diário no cron:

```bash
# Adicionar ao cron (rodar às 05:00 AM - horário de baixo tráfego)
sudo crontab -e

# Adicionar linha:
0 5 * * * /opt/scripts/php-fpm-daily-restart.sh

# Salvar e verificar
sudo crontab -l | grep php-fpm
```

---

## 📊 PASSO 4: CONFIGURAR MONITORAMENTO PHP-FPM

### Habilitar status page do PHP-FPM:

```bash
# Já configuramos pm.status_path = /php-fpm-status no pool

# Configurar nginx para expor status
sudo tee /etc/nginx/conf.d/php-fpm-status.conf > /dev/null <<'EOF'
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /php-fpm-status {
        access_log off;
        allow 127.0.0.1;
        deny all;
        fastcgi_pass unix:/run/php/php-fpm.sock;  # Ajustar path do socket
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# Ajustar path do socket se necessário:
# - Ubuntu: /run/php/php7.4-fpm.sock
# - CentOS: /var/run/php-fpm/www.sock

# Reload nginx
sudo nginx -t && sudo systemctl reload nginx
```

### Testar status page:

```bash
# Ver status PHP-FPM
curl http://127.0.0.1:8080/php-fpm-status

# Ver status detalhado
curl http://127.0.0.1:8080/php-fpm-status?full

# Output exemplo:
# pool:                 www
# process manager:      dynamic
# start time:           22/Oct/2025:08:41:23 -0300
# accepted conn:        12345
# listen queue:         0
# max listen queue:     5
# idle processes:       8
# active processes:     2
# total processes:      10
```

### Script de monitoramento contínuo:

```bash
sudo tee /opt/scripts/monitor-php-fpm-health.sh > /dev/null <<'EOF'
#!/bin/bash

#############################################################################
# PHP-FPM Health Monitor
#############################################################################

LOG_FILE="/var/log/php-fpm-health.log"
ALERT_THRESHOLD_MEMORY=1200  # Alert se > 1.2GB
ALERT_THRESHOLD_PROCESSES=25  # Alert se > 25 processos

# Get metrics
MEMORY_MB=$(ps aux | grep php-fpm | awk '{sum+=$6} END {print int(sum/1024)}')
PROCESS_COUNT=$(ps aux | grep php-fpm | grep -v grep | wc -l)
POOL_STATUS=$(curl -s http://127.0.0.1:8080/php-fpm-status)

# Log
{
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "Memory: ${MEMORY_MB}MB"
    echo "Processes: ${PROCESS_COUNT}"
    echo "Status: $POOL_STATUS"
    echo ""
} >> "$LOG_FILE"

# Alert if thresholds exceeded
if [ "$MEMORY_MB" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
    echo "ALERT: PHP-FPM memory usage is ${MEMORY_MB}MB (threshold: ${ALERT_THRESHOLD_MEMORY}MB)" | tee -a "$LOG_FILE"
fi

if [ "$PROCESS_COUNT" -gt "$ALERT_THRESHOLD_PROCESSES" ]; then
    echo "ALERT: PHP-FPM process count is ${PROCESS_COUNT} (threshold: ${ALERT_THRESHOLD_PROCESSES})" | tee -a "$LOG_FILE"
fi
EOF

sudo chmod +x /opt/scripts/monitor-php-fpm-health.sh

# Agendar monitoramento a cada 5 minutos
sudo crontab -e

# Adicionar:
*/5 * * * * /opt/scripts/monitor-php-fpm-health.sh
```

---

## 🚀 PASSO 5: OTIMIZAÇÕES ADICIONAIS

### A. Aumentar OPcache (se disponível):

```bash
# Editar php.ini
sudo nano /etc/php/*/fpm/php.ini
# OU
sudo nano /etc/php.ini

# Procurar seção [opcache] e ajustar:
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60

# Reload PHP-FPM
sudo systemctl reload php-fpm
```

### B. Configurar nginx keepalive:

```bash
# Editar configuração nginx
sudo nano /etc/nginx/nginx.conf

# Adicionar/ajustar na seção http:
http {
    ...

    # Keepalive connections to PHP-FPM
    upstream php-fpm {
        server unix:/run/php/php-fpm.sock;
        keepalive 32;
    }

    ...
}

# Reload nginx
sudo nginx -t && sudo systemctl reload nginx
```

### C. Desabilitar PHP functions desnecessárias:

```bash
# Editar php.ini
sudo nano /etc/php/*/fpm/php.ini

# Adicionar (segurança e performance):
disable_functions = exec,passthru,shell_exec,system,proc_open,popen

# Reload PHP-FPM
sudo systemctl reload php-fpm
```

---

## ✅ CHECKLIST DE EXECUÇÃO

### fgsrv4 (nginx/PHP5):
- [ ] Backup da configuração atual
- [ ] pm.max_requests = 1000 configurado
- [ ] request_terminate_timeout configurado
- [ ] Slow log habilitado
- [ ] Configuração testada (php-fpm -t)
- [ ] PHP-FPM recarregado
- [ ] Script de restart diário criado
- [ ] Cron job de restart agendado (05:00)
- [ ] Status page configurada
- [ ] Monitoramento agendado
- [ ] Documentação salva

### fgsrv5 (Laravel):
- [ ] Backup da configuração atual
- [ ] pm.max_requests = 1000 configurado
- [ ] request_terminate_timeout configurado
- [ ] Slow log habilitado
- [ ] Configuração testada
- [ ] PHP-FPM recarregado
- [ ] Script de restart diário criado
- [ ] Cron job de restart agendado (05:00)
- [ ] Status page configurada
- [ ] Monitoramento agendado
- [ ] Queue workers configurados para restart
- [ ] Documentação salva

---

## 🎯 CONFIGURAÇÕES ESPECÍFICAS LARAVEL (fgsrv5)

### Queue Workers com Supervisor:

```bash
# Instalar supervisor (se não estiver)
sudo apt-get install supervisor -y
# OU
sudo yum install supervisor -y

# Criar configuração do queue worker
sudo tee /etc/supervisor/conf.d/laravel-worker.conf > /dev/null <<'EOF'
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/api.falg.com.br/artisan queue:work --sleep=3 --tries=3 --max-time=3600 --max-jobs=1000
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/api.falg.com.br/storage/logs/worker.log
stopwaitsecs=3600
EOF

# Atualizar supervisor
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start laravel-worker:*

# Verificar status
sudo supervisorctl status
```

**Nota:** `--max-jobs=1000` faz o worker reciclar automaticamente após 1000 jobs!

---

## 📊 MONITORAR IMPACTO

### Durante próximos dias:

```bash
# Ver log de restarts
sudo tail -f /var/log/php-fpm-restart.log

# Ver log de health monitoring
sudo tail -f /var/log/php-fpm-health.log

# Ver slow requests
sudo tail -f /var/log/php-fpm/slow.log
```

---

## 🎯 RESULTADO ESPERADO

### Imediato:
- ✅ Workers reciclando após 1000 requisições
- ✅ Processos limitados a 300s de execução
- ✅ Slow requests sendo logados

### Diário:
- ✅ Restart automático às 05:00
- ✅ Memória limpa todo dia
- ✅ Log de health checks

### Longo prazo:
- ✅ Sem memory leaks acumulando
- ✅ Performance estável
- ✅ Menos crashes de PHP-FPM

---

**Prioridade:** 🟡 MÉDIA
**Tempo estimado:** 20-30 minutos por host
**Impacto esperado:** Redução de 30% do problema (complementar)

---

**Criado por:** Hive Mind Collective Intelligence
**Hipótese:** 30% probabilidade - PHP-FPM memory leaks
**Complementa:** Backup MySQL + Cron staggering
