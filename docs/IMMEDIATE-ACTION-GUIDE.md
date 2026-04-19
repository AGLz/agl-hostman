# ⚡ Guia de Ação Imediata - VPS Timeout Troubleshooting

**Data:** 2025-10-22
**Hora Atual:** 08:41 (Brasil)
**Janela do Problema:** 09:00 - 10:00 (COMEÇA EM 19 MINUTOS!)

---

## 🚨 SITUAÇÃO ATUAL

### Horário Crítico
- ⏰ **Agora:** 08:41
- 🎯 **Janela do problema:** 09:00 - 10:00
- ⚠️ **Tempo até início:** 19 minutos

### Hosts Afetados
1. **fgsrv3** - MySQL server
2. **fgsrv4** - nginx/PHP5 (https://falg.com.br)
3. **fgsrv5** - nginx/Laravel (https://api.falg.com.br)

### Hipótese Principal (70% confiança)
**Backups do MySQL às 09:00 causando locks de tabela e esgotamento do connection pool**

---

## ⚡ AÇÕES IMEDIATAS (Próximos 20 minutos)

### 1. CONECTAR AOS HOSTS (AGORA!)

```bash
# Abrir 3 terminais separados, um para cada host
ssh fgsrv3  # Terminal 1 - MySQL
ssh fgsrv4  # Terminal 2 - nginx/PHP5
ssh fgsrv5  # Terminal 3 - nginx/Laravel
```

### 2. VERIFICAR CRON JOBS (URGENTE - 5 minutos)

Em cada host, execute:

```bash
# Verificar cron jobs do usuário atual
crontab -l

# Verificar cron jobs do root
sudo crontab -l

# Verificar cron jobs do sistema
sudo cat /etc/crontab

# Verificar cron.d
sudo ls -la /etc/cron.d/
sudo cat /etc/cron.d/*

# Verificar cron.hourly (pode ter scripts às 09:00)
sudo ls -la /etc/cron.hourly/

# CRITICAL: Procurar por jobs agendados para 09:00
sudo grep -r "0 9\|9 \*" /etc/cron* /var/spool/cron* 2>/dev/null
```

**SALVAR OUTPUT:**
```bash
{
  echo "=== Cron Audit - $(hostname) - $(date) ==="
  echo ""
  echo "User crontab:"
  crontab -l 2>/dev/null || echo "No user crontab"
  echo ""
  echo "Root crontab:"
  sudo crontab -l 2>/dev/null || echo "No root crontab"
  echo ""
  echo "System crontab:"
  sudo cat /etc/crontab
  echo ""
  echo "Cron.d directory:"
  sudo ls -la /etc/cron.d/
  echo ""
  echo "9am jobs search:"
  sudo grep -r "0 9\|9 \*" /etc/cron* 2>/dev/null
} > /tmp/cron-audit-$(hostname)-$(date +%Y%m%d-%H%M).txt
```

### 3. VERIFICAR BACKUPS DO MYSQL (APENAS fgsrv3 - 3 minutos)

```bash
# Procurar scripts de backup
sudo find /etc /opt /usr/local /var -name "*backup*" -o -name "*dump*" 2>/dev/null

# Verificar processos de backup em execução
ps aux | grep -i "backup\|dump\|mysqldump"

# Procurar em logs recentes
sudo grep -i "backup\|dump" /var/log/syslog | tail -50
sudo grep -i "backup\|dump" /var/log/cron* | tail -50

# Verificar scripts comuns de backup
ls -la /root/backup* /home/*/backup* /opt/backup* 2>/dev/null
```

**SALVAR OUTPUT:**
```bash
{
  echo "=== MySQL Backup Audit - $(date) ==="
  echo ""
  echo "Backup scripts found:"
  sudo find /etc /opt /usr/local /var -name "*backup*" -o -name "*dump*" 2>/dev/null
  echo ""
  echo "Current backup processes:"
  ps aux | grep -i "backup\|dump\|mysqldump"
  echo ""
  echo "Recent backup activity:"
  sudo grep -i "backup\|dump" /var/log/syslog | tail -20
} > /tmp/backup-audit-$(date +%Y%m%d-%H%M).txt
```

### 4. MONITORAMENTO EM TEMPO REAL (08:55 - 10:05)

**ÀS 08:55 (5 MINUTOS ANTES), INICIAR MONITORAMENTO:**

#### Terminal 1 - fgsrv3 (MySQL):
```bash
# Monitorar conexões MySQL em tempo real
watch -n 2 'mysql -e "SHOW PROCESSLIST;" | head -20'

# OU em segundo plano com log:
while true; do
  mysql -e "SHOW STATUS LIKE 'Threads_connected'; SHOW PROCESSLIST;" >> /tmp/mysql-monitor-$(date +%Y%m%d).log
  echo "--- $(date) ---" >> /tmp/mysql-monitor-$(date +%Y%m%d).log
  sleep 5
done
```

#### Terminal 2 - fgsrv4 (nginx/PHP5):
```bash
# Monitorar conexões nginx
watch -n 2 'netstat -an | grep :80 | wc -l; ps aux | grep php-fpm | wc -l'

# OU em segundo plano:
while true; do
  echo "=== $(date) ===" >> /tmp/nginx-monitor-$(date +%Y%m%d).log
  netstat -an | grep :80 | wc -l >> /tmp/nginx-monitor-$(date +%Y%m%d).log
  ps aux | grep php-fpm | wc -l >> /tmp/nginx-monitor-$(date +%Y%m%d).log
  sleep 5
done
```

#### Terminal 3 - fgsrv5 (Laravel):
```bash
# Monitorar queue workers e processos PHP
watch -n 2 'ps aux | grep -E "queue:work|php artisan" | grep -v grep'

# OU em segundo plano:
while true; do
  echo "=== $(date) ===" >> /tmp/laravel-monitor-$(date +%Y%m%d).log
  ps aux | grep -E "queue:work|php artisan" >> /tmp/laravel-monitor-$(date +%Y%m%d).log
  sleep 5
done
```

---

## 📊 COMANDOS DE DIAGNÓSTICO DURANTE A JANELA (09:00-10:00)

### QUANDO OS TIMEOUTS COMEÇAREM:

#### fgsrv3 (MySQL):
```bash
# Capturar snapshot do estado MySQL
{
  echo "=== MySQL Emergency Snapshot - $(date) ==="
  mysql -e "SHOW FULL PROCESSLIST;"
  mysql -e "SHOW ENGINE INNODB STATUS\G"
  mysql -e "SHOW STATUS LIKE 'Threads%';"
  mysql -e "SHOW STATUS LIKE 'Max_used_connections';"
  mysql -e "SHOW VARIABLES LIKE 'max_connections';"
  mysql -e "SHOW OPEN TABLES WHERE In_use > 0;"
} > /tmp/mysql-emergency-$(date +%Y%m%d-%H%M).txt

# Verificar locks de tabela
mysql -e "SHOW OPEN TABLES WHERE In_use > 0;"

# Verificar transações longas
mysql -e "SELECT * FROM information_schema.INNODB_TRX;"
```

#### fgsrv4 & fgsrv5 (nginx):
```bash
# Capturar erro logs
sudo tail -100 /var/log/nginx/error.log > /tmp/nginx-errors-$(date +%Y%m%d-%H%M).txt

# Verificar conexões ativas
netstat -an | grep :80 > /tmp/nginx-connections-$(date +%Y%m%d-%H%M).txt

# Status do PHP-FPM
sudo systemctl status php-fpm > /tmp/php-fpm-status-$(date +%Y%m%d-%H%M).txt
```

#### Todos os hosts - Recursos do sistema:
```bash
# Snapshot de recursos
{
  echo "=== System Resources - $(date) ==="
  echo "CPU:"
  top -bn1 | head -20
  echo ""
  echo "Memory:"
  free -h
  echo ""
  echo "Disk I/O:"
  iostat -x 1 3
  echo ""
  echo "Network:"
  netstat -s | grep -i error
} > /tmp/system-snapshot-$(hostname)-$(date +%Y%m%d-%H%M).txt
```

---

## 🎯 O QUE PROCURAR (Validação das Hipóteses)

### 1. Hipótese: Backup do MySQL (70%)
**Sinais confirmadores:**
- [ ] Processo `mysqldump` rodando às 09:00
- [ ] `SHOW PROCESSLIST` mostra queries bloqueadas
- [ ] `Threads_connected` aumenta drasticamente
- [ ] `SHOW OPEN TABLES` mostra tabelas com `In_use > 0`
- [ ] Logs de cron mostram backup agendado para 09:00

**Se confirmado:**
```bash
# AÇÃO IMEDIATA: Desabilitar backup temporariamente
sudo crontab -e
# Comentar linha do backup (adicionar # no início)

# AÇÃO PERMANENTE: Reagendar para 02:00
# Mudar de: 0 9 * * * /path/to/backup.sh
# Para:     0 2 * * * /path/to/backup.sh
```

### 2. Hipótese: Cron Jobs Clustering (50%)
**Sinais confirmadores:**
- [ ] Múltiplos jobs rodando às 09:00 exato
- [ ] CPU spike às 09:00
- [ ] Múltiplos processos PHP/artisan iniciando simultaneamente

**Se confirmado:**
```bash
# Escalonar jobs:
# Ao invés de todos às 09:00, distribuir:
5 9 * * * /job1.sh   # 09:05
15 9 * * * /job2.sh  # 09:15
25 9 * * * /job3.sh  # 09:25
```

### 3. Hipótese: PHP-FPM Memory Leak (30%)
**Sinais confirmadores:**
- [ ] Processos `php-fpm` com alta memória (>500MB cada)
- [ ] `pm.max_children` atingido
- [ ] Logs PHP-FPM mostram "max children reached"

**Se confirmado:**
```bash
# Reiniciar PHP-FPM imediatamente
sudo systemctl restart php-fpm

# Adicionar restart automático ao cron (diariamente às 05:00)
0 5 * * * systemctl restart php-fpm
```

---

## 📝 CHECKLIST DE COLETA DE DADOS

### Antes de 09:00 (08:55):
- [ ] Conectado aos 3 hosts via SSH
- [ ] Monitoramento em tempo real iniciado
- [ ] Auditoria de cron jobs completa
- [ ] Scripts de backup identificados
- [ ] Logs de baseline coletados

### Durante 09:00-10:00:
- [ ] Monitorar MySQL PROCESSLIST continuamente
- [ ] Capturar snapshots quando timeout começar
- [ ] Registrar hora exata do início do problema
- [ ] Documentar quando volta ao normal
- [ ] Salvar todos os outputs em /tmp/

### Depois de 10:00:
- [ ] Coletar todos os arquivos de /tmp/
- [ ] Analisar padrões nos logs
- [ ] Comparar com hipóteses da Hive Mind
- [ ] Documentar achados
- [ ] Planejar correção

---

## 💾 COLETAR EVIDÊNCIAS

### Depois que o problema passar (10:30):

```bash
# Criar arquivo de evidências
mkdir -p /tmp/vps-evidence-$(date +%Y%m%d)

# Copiar todos os logs coletados
cp /tmp/*-monitor-*.log /tmp/vps-evidence-$(date +%Y%m%d)/
cp /tmp/*-audit-*.txt /tmp/vps-evidence-$(date +%Y%m%d)/
cp /tmp/*-emergency-*.txt /tmp/vps-evidence-$(date +%Y%m%d)/
cp /tmp/*-snapshot-*.txt /tmp/vps-evidence-$(date +%Y%m%d)/

# Criar tarball
tar -czf /tmp/vps-evidence-$(date +%Y%m%d).tar.gz -C /tmp vps-evidence-$(date +%Y%m%d)/

# Copiar para máquina local
scp fgsrv3:/tmp/vps-evidence-*.tar.gz ~/evidence/
scp fgsrv4:/tmp/vps-evidence-*.tar.gz ~/evidence/
scp fgsrv5:/tmp/vps-evidence-*.tar.gz ~/evidence/
```

---

## 🚀 QUICK WINS (Ações que podem ser tomadas AGORA)

### 1. Enable MySQL Slow Query Log (fgsrv3):
```bash
mysql -e "SET GLOBAL slow_query_log = 'ON';"
mysql -e "SET GLOBAL long_query_time = 2;"
mysql -e "SET GLOBAL log_queries_not_using_indexes = 'ON';"
```

### 2. Increase PHP-FPM Verbosity (fgsrv4, fgsrv5):
```bash
# Editar /etc/php-fpm.conf ou /etc/php/7.x/fpm/pool.d/www.conf
# Adicionar:
# log_level = debug
# slowlog = /var/log/php-fpm/slow.log
# request_slowlog_timeout = 5s

# Depois:
sudo systemctl reload php-fpm
```

### 3. Enable nginx Access Logging com Timing:
```bash
# Adicionar ao nginx.conf:
# log_format timing '$remote_addr - $remote_user [$time_local] '
#                   '"$request" $status $body_bytes_sent '
#                   '"$http_referer" "$http_user_agent" '
#                   'rt=$request_time uct="$upstream_connect_time" '
#                   'uht="$upstream_header_time" urt="$upstream_response_time"';
#
# access_log /var/log/nginx/access-timing.log timing;

sudo nginx -t && sudo systemctl reload nginx
```

---

## 📞 CONTATOS DE EMERGÊNCIA

**Locaweb Suporte:**
- [ ] Contato: _______________
- [ ] Ticket aberto: _______________

**Equipe Interna:**
- [ ] DBA: _______________
- [ ] DevOps: _______________
- [ ] Gerente: _______________

---

## 📊 FORMATO DE RELATÓRIO

Após a coleta de dados, preencher:

```
=============================================================================
VPS TIMEOUT INCIDENT REPORT - $(date +%Y-%m-%d)
=============================================================================

TIMELINE:
- Início do monitoramento: 08:55
- Primeiro timeout observado: _____
- Pico do problema: _____
- Retorno ao normal: _____

SINTOMAS OBSERVADOS:
[ ] Timeouts em falg.com.br
[ ] Timeouts em api.falg.com.br
[ ] MySQL connections spike
[ ] CPU spike
[ ] Memory spike
[ ] Disk I/O spike

ROOT CAUSE IDENTIFICADA:
[ ] MySQL backup (70% hipótese)
[ ] Cron job clustering (50% hipótese)
[ ] PHP-FPM memory leak (30% hipótese)
[ ] Outro: _______________

EVIDÊNCIAS COLETADAS:
- Cron audit: /tmp/cron-audit-*.txt
- MySQL processlist: /tmp/mysql-monitor-*.log
- nginx connections: /tmp/nginx-monitor-*.log
- System resources: /tmp/system-snapshot-*.txt

AÇÃO CORRETIVA RECOMENDADA:
_______________

VALIDAÇÃO NECESSÁRIA:
_______________

=============================================================================
```

---

## ⏰ TIMELINE DE AÇÃO

| Horário | Ação |
|---------|------|
| **08:41** | ✅ Guia criado |
| **08:45** | Conectar aos hosts |
| **08:45-08:55** | Auditar cron jobs e backups |
| **08:55** | Iniciar monitoramento em tempo real |
| **09:00-10:00** | **JANELA CRÍTICA - Coletar dados** |
| **10:05** | Verificar se problema cessou |
| **10:10-10:30** | Coletar evidências finais |
| **10:30-11:00** | Analisar dados e confirmar hipótese |
| **11:00-12:00** | Implementar correção temporária |
| **Amanhã** | Validar correção durante próxima janela |

---

## 🎯 OBJETIVO

**Confirmar em 60 minutos qual das hipóteses está correta e implementar correção imediata.**

**Sucesso = Zero timeouts amanhã às 09:00!**

---

**PREPARADO PELA:** Hive Mind Collective Intelligence
**HORA DE CRIAÇÃO:** 2025-10-22 08:41
**VALIDADE:** PRÓXIMAS 2 HORAS (janela crítica)

🚨 **AÇÃO URGENTE REQUERIDA - 19 MINUTOS ATÉ A JANELA DO PROBLEMA!** 🚨
