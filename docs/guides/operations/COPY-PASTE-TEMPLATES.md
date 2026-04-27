# 📋 TEMPLATES COPY-PASTE - Execução Rápida

**Objetivo:** Comandos prontos para copiar e colar durante implementação e monitoramento
**Uso:** Ctrl+C → SSH → Ctrl+V

---

## 🔴 CORREÇÃO 1: BACKUP MYSQL (5 min)

### fgsrv3 - Identificar backup atual:
```bash
crontab -l | grep -E "backup|dump|9"
sudo crontab -l | grep -E "backup|dump|9"
```

### fgsrv3 - Editar e salvar (escolha um):
```bash
crontab -e
# OU
sudo crontab -e
```

**Procure por linhas com hora 9:**
```
0 9 * * * /path/to/backup.sh
```

**Mude para:**
```
30 2 * * * /path/to/backup.sh
```

**Salvar:** `Ctrl+X` → `Y` → `Enter`

### fgsrv3 - Verificar mudança:
```bash
crontab -l | grep -E "backup|dump"
sudo crontab -l | grep -E "backup|dump"
```

---

## 🟡 CORREÇÃO 2: CRON JOBS STAGGERING (15 min)

### Executar em TODOS os hosts (fgsrv3, fgsrv4, fgsrv5):

#### Passo 1: Identificar jobs às 09:00
```bash
# User crontab
crontab -l | grep "^[0-9]* 9"

# System crontab
sudo crontab -l | grep "^[0-9]* 9"

# System cron files
sudo grep -r "^[0-9]* 9" /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/ /etc/cron.monthly/ /etc/cron.weekly/ 2>/dev/null
```

#### Passo 2: Backup antes de editar
```bash
crontab -l > ~/crontab-backup-$(date +%Y%m%d).txt
sudo crontab -l > ~/root-crontab-backup-$(date +%Y%m%d).txt 2>/dev/null
```

#### Passo 3: Editar crontabs
```bash
# User crontab
crontab -e

# Root crontab
sudo crontab -e
```

#### Exemplo de escalonamento:
```
# ANTES (todos às 09:00)
0 9 * * * /job1.sh
0 9 * * * /job2.sh
0 9 * * * /job3.sh

# DEPOIS (escalonados 10-15 min)
5 9 * * * /job1.sh      # 09:05
15 9 * * * /job2.sh     # 09:15
25 9 * * * /job3.sh     # 09:25
```

#### Passo 4: Laravel scheduled tasks (apenas fgsrv5)
```bash
cd /var/www/api.falg.com.br  # Ajustar path
sudo nano app/Console/Kernel.php
```

**Procure por:**
```php
$schedule->command('some:command')->dailyAt('09:00');
```

**Mude para:**
```php
$schedule->command('some:command')->dailyAt('09:15');
```

#### Passo 5: Verificar mudanças
```bash
crontab -l | grep " 9 "
sudo crontab -l | grep " 9 "
```

---

## 🟡 CORREÇÃO 3: PHP-FPM OPTIMIZATION (30 min)

### Executar em fgsrv4 E fgsrv5:

#### Passo 1: Identificar versão PHP-FPM
```bash
php -v
ls /etc/php/*/fpm/pool.d/
```

#### Passo 2: Backup configuração
```bash
sudo cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.backup-$(date +%Y%m%d)
# Ajuste versão PHP conforme output do passo 1
```

#### Passo 3: Editar configuração
```bash
sudo nano /etc/php/7.4/fpm/pool.d/www.conf
# Ajuste versão PHP conforme sua instalação
```

#### Passo 4: Adicionar/modificar no arquivo:
**Procure pela seção `pm` e adicione estas linhas:**
```ini
; ==========================================
; VPS TIMEOUT FIX - 2025-10-22
; ==========================================

; Worker recycling (previne memory leaks)
pm.max_requests = 1000

; Timeout para processos pendurados
request_terminate_timeout = 300

; Slow log para debugging
slowlog = /var/log/php-fpm/slow.log
request_slowlog_timeout = 5s

; ==========================================
```

#### Passo 5: Criar diretório de logs
```bash
sudo mkdir -p /var/log/php-fpm
sudo chown www-data:www-data /var/log/php-fpm
```

#### Passo 6: Testar configuração
```bash
sudo php-fpm7.4 -t
# Deve retornar: "configuration file /etc/php/7.4/fpm/php-fpm.conf test is successful"
```

#### Passo 7: Reload PHP-FPM
```bash
sudo systemctl reload php7.4-fpm
# OU
sudo systemctl restart php7.4-fpm
```

#### Passo 8: Verificar se subiu
```bash
sudo systemctl status php7.4-fpm
```

#### Passo 9: Agendar restart diário às 05:00
```bash
sudo crontab -e
```

**Adicionar:**
```
0 5 * * * systemctl restart php7.4-fpm
```

---

## 🟢 CORREÇÃO 4: MYSQL SLOW QUERY LOG (15 min)

### Executar em fgsrv3:

#### Passo 1: Localizar arquivo MySQL config
```bash
ls -la /etc/mysql/my.cnf
ls -la /etc/my.cnf
ls -la /etc/mysql/mysql.conf.d/mysqld.cnf
```

#### Passo 2: Backup configuração
```bash
sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup-$(date +%Y%m%d)
# OU
sudo cp /etc/my.cnf /etc/my.cnf.backup-$(date +%Y%m%d)
```

#### Passo 3: Editar configuração
```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# OU
sudo nano /etc/my.cnf
```

#### Passo 4: Adicionar na seção [mysqld]:
```ini
# ==========================================
# SLOW QUERY LOG - VPS TIMEOUT FIX
# ==========================================

slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2
log_queries_not_using_indexes = 1
min_examined_row_limit = 1000
log_slow_admin_statements = 1
performance_schema = ON

# ==========================================
```

#### Passo 5: Criar diretório de logs
```bash
sudo mkdir -p /var/log/mysql
sudo chown mysql:mysql /var/log/mysql
sudo chmod 755 /var/log/mysql
```

#### Passo 6: Restart MySQL
```bash
sudo systemctl restart mysql
# OU
sudo systemctl restart mysqld
```

#### Passo 7: Verificar se subiu
```bash
sudo systemctl status mysql
```

#### Passo 8: Confirmar configuração
```bash
mysql -u root -p
```

**No MySQL:**
```sql
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
exit;
```

---

## 🟢 CORREÇÃO 5: NGINX OPTIMIZATION (20 min)

### Executar em fgsrv4 E fgsrv5:

#### Passo 1: Backup nginx config
```bash
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup-$(date +%Y%m%d)
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup-$(date +%Y%m%d)
```

#### Passo 2: Editar nginx.conf
```bash
sudo nano /etc/nginx/nginx.conf
```

#### Passo 3: Adicionar na seção http {}:
```nginx
# ==========================================
# VPS TIMEOUT FIX - Rate Limiting
# ==========================================

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=20r/s;

# Upstream com keepalive
upstream php-fpm {
    server unix:/run/php/php-fpm.sock;
    keepalive 32;
}

# ==========================================
```

#### Passo 4: Editar site config (falg.com.br no fgsrv4)
```bash
sudo nano /etc/nginx/sites-available/falg.com.br
# OU
sudo nano /etc/nginx/sites-available/default
```

#### Passo 5: Adicionar no server {}:
```nginx
# Rate limiting com burst
limit_req zone=general burst=20 nodelay;

# PHP-FPM location com keepalive
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass php-fpm;
    fastcgi_keep_conn on;
}
```

#### Passo 6: Repetir para api.falg.com.br (fgsrv5)
```bash
sudo nano /etc/nginx/sites-available/api.falg.com.br
```

**Mesma configuração acima.**

#### Passo 7: Testar configuração
```bash
sudo nginx -t
```

#### Passo 8: Reload nginx
```bash
sudo systemctl reload nginx
```

#### Passo 9: Verificar status
```bash
sudo systemctl status nginx
```

---

## 📊 MONITORAMENTO AMANHÃ (09:00-10:00)

### Pré-monitoramento (08:50):

#### Conectar aos 3 hosts (3 terminais):
```bash
# Terminal 1
ssh fgsrv3

# Terminal 2
ssh fgsrv4

# Terminal 3
ssh fgsrv5
```

#### Em CADA host, criar diretório:
```bash
mkdir -p /tmp/validation-$(date +%Y%m%d)
```

### Iniciar monitores (08:55):

#### fgsrv3 (MySQL):
```bash
nohup sh -c 'while true; do echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/validation-$(date +%Y%m%d)/mysql-monitor.log; mysql -e "SHOW STATUS LIKE \"Threads_connected\"; SELECT COUNT(*) as active_queries FROM information_schema.PROCESSLIST WHERE COMMAND != \"Sleep\"; SHOW PROCESSLIST;" >> /tmp/validation-$(date +%Y%m%d)/mysql-monitor.log 2>&1; echo "" >> /tmp/validation-$(date +%Y%m%d)/mysql-monitor.log; sleep 30; done' > /tmp/mysql-monitor.out 2>&1 &
echo "MySQL monitor started (PID: $!)"
```

#### fgsrv4 (nginx/PHP5):
```bash
nohup sh -c 'while true; do echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log; echo "Active connections: $(netstat -an | grep :80 | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log; echo "PHP-FPM processes: $(ps aux | grep php-fpm | grep -v grep | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log; echo "" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log; sleep 30; done' > /tmp/nginx-monitor.out 2>&1 &
echo "nginx monitor started (PID: $!)"
```

#### fgsrv5 (Laravel):
```bash
nohup sh -c 'while true; do echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log; echo "Active connections: $(netstat -an | grep :80 | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log; echo "PHP-FPM processes: $(ps aux | grep php-fpm | grep -v grep | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log; echo "Queue workers: $(ps aux | grep \"queue:work\" | grep -v grep | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log; echo "" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log; sleep 30; done' > /tmp/laravel-monitor.out 2>&1 &
echo "Laravel monitor started (PID: $!)"
```

### Verificações durante janela:

#### 09:00 - Início:
```bash
# Em todos os hosts
echo "09:00 - Janela iniciou" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt

# fgsrv3: Confirmar que backup NÃO está rodando
ps aux | grep mysqldump | grep -v grep || echo "✓ No backup at 09:00"

# fgsrv4 & fgsrv5: Testar sites
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s https://falg.com.br
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s https://api.falg.com.br
```

#### 09:05, 09:10, 09:15, etc (a cada 5 min):
```bash
# Sites respondendo?
curl -I https://falg.com.br 2>&1 | grep "HTTP" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt
curl -I https://api.falg.com.br 2>&1 | grep "HTTP" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt

# Recursos OK?
echo "$(date +%H:%M) - Load: $(uptime | awk -F'load average:' '{print $2}')" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt
```

#### 10:00 - Fim:
```bash
echo "10:00 - Janela encerrou" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt

# Verificação final
{
  echo "=== 10:00 END OF WINDOW ==="
  echo ""
  echo "Sites status:"
  curl -I https://falg.com.br 2>&1 | grep "HTTP"
  curl -I https://api.falg.com.br 2>&1 | grep "HTTP"
  echo ""
  echo "Any timeouts in logs?"
  sudo grep -i "timeout\|502\|504" /var/log/nginx/error.log | tail -10 || echo "No timeout errors"
} | tee /tmp/validation-$(date +%Y%m%d)/final-check-$(hostname).txt
```

### Parar monitores (10:05):
```bash
# Em cada host
kill $(ps aux | grep "validation.*monitor" | grep -v grep | awk '{print $2}') 2>/dev/null
```

### Coletar evidências (10:05):
```bash
# Em cada host
cd /tmp
tar -czf validation-evidence-$(hostname)-$(date +%Y%m%d).tar.gz validation-$(date +%Y%m%d)/
ls -lh validation-evidence-*.tar.gz
```

### Baixar para máquina local:
```bash
# Na máquina local
mkdir -p ~/vps-timeout-evidence
scp fgsrv3:/tmp/validation-evidence-*.tar.gz ~/vps-timeout-evidence/
scp fgsrv4:/tmp/validation-evidence-*.tar.gz ~/vps-timeout-evidence/
scp fgsrv5:/tmp/validation-evidence-*.tar.gz ~/vps-timeout-evidence/
```

---

## 🚨 COMANDOS DE EMERGÊNCIA

### Verificação rápida de saúde (10 segundos):
```bash
# Em qualquer host
{ echo "=== $(hostname) - $(date) ==="; echo "Load: $(uptime | awk -F'load average:' '{print $2}')"; echo "Memory: $(free -h | grep Mem)"; echo "Disk: $(df -h / | tail -1)"; echo "Processes: $(ps aux | wc -l)"; } | tee /tmp/health-check-$(hostname).txt
```

### MySQL bloqueado?
```bash
mysql -e "SHOW FULL PROCESSLIST;" | grep -v "Sleep"
mysql -e "SHOW STATUS LIKE 'Threads_connected';"
```

### PHP-FPM saturado?
```bash
ps aux | grep php-fpm | wc -l
sudo systemctl status php-fpm
```

### nginx com erro?
```bash
sudo nginx -t
sudo tail -50 /var/log/nginx/error.log
sudo systemctl status nginx
```

### Restart de emergência (último recurso):
```bash
# PHP-FPM
sudo systemctl restart php-fpm

# nginx
sudo systemctl restart nginx

# MySQL (CUIDADO - causa downtime)
sudo systemctl restart mysql
```

---

## 📋 CHECKLIST RÁPIDO

### Antes de começar:
- [ ] 3 terminais SSH abertos (fgsrv3, fgsrv4, fgsrv5)
- [ ] Backup de todos os configs feito
- [ ] Acesso root/sudo disponível

### Durante implementação:
- [ ] Testar cada config antes de reload (`-t` flags)
- [ ] Verificar status após cada restart (`status` commands)
- [ ] Documentar qualquer erro encontrado

### Após implementação:
- [ ] Todos os serviços rodando OK
- [ ] Backups agendados confirmados (`crontab -l`)
- [ ] Logs sendo gerados (`tail -f` nos logs)

### No dia seguinte:
- [ ] Monitores iniciados às 08:55
- [ ] Observações a cada 5 minutos
- [ ] Evidências coletadas às 10:05
- [ ] Análise completa até 11:00

---

**🎯 DICA FINAL:** Mantenha este arquivo aberto durante toda a execução para copy-paste rápido!

**Preparado por:** Hive Mind Collective Intelligence
**Data:** 2025-10-22
**Versão:** 1.0 Copy-Paste Ready
