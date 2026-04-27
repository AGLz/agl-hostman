# 🐬 MYSQL SLOW QUERY LOGGING - Monitoramento Permanente

**Objetivo:** Habilitar logging permanente de queries lentas para diagnóstico contínuo
**Prioridade:** 🟡 MÉDIA
**Host:** fgsrv3 (MySQL)

---

## 🎯 BENEFÍCIOS

1. **Identificar queries problemáticas** automaticamente
2. **Análise histórica** de performance
3. **Alertas proativos** antes que problemas ocorram
4. **Otimização contínua** do banco de dados

---

## 🔍 PASSO 1: VERIFICAR CONFIGURAÇÃO ATUAL

```bash
# Conectar ao MySQL
mysql -u root -p

# Ver configuração atual
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
SHOW VARIABLES LIKE 'log_queries_not_using_indexes';

# Verificar se slow query log está habilitado
SHOW VARIABLES LIKE 'slow_query_log';

# Ver localização do arquivo de log
SHOW VARIABLES LIKE 'slow_query_log_file';

# Sair
exit;
```

---

## 🛠️ PASSO 2: HABILITAR SLOW QUERY LOG PERMANENTEMENTE

### Método 1: Configuração Permanente (Recomendado)

```bash
# Localizar arquivo de configuração MySQL
ls -la /etc/mysql/my.cnf
ls -la /etc/my.cnf
ls -la /etc/mysql/mysql.conf.d/mysqld.cnf

# Backup da configuração
sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup-$(date +%Y%m%d)
# OU
sudo cp /etc/my.cnf /etc/my.cnf.backup-$(date +%Y%m%d)

# Editar configuração
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# OU
sudo nano /etc/my.cnf
```

### Adicionar/modificar na seção [mysqld]:

```ini
[mysqld]

# =========================================================================
# SLOW QUERY LOG CONFIGURATION
# =========================================================================

# Habilitar slow query log
slow_query_log = 1

# Localização do arquivo de log
slow_query_log_file = /var/log/mysql/mysql-slow.log

# Tempo mínimo para considerar query "lenta" (em segundos)
# 2 segundos é um bom starting point
long_query_time = 2

# Logar queries que não usam índices (útil para otimização)
log_queries_not_using_indexes = 1

# Limitar logging de queries sem índices (evitar log gigante)
# Logar no máximo 10 queries sem índice por minuto
min_examined_row_limit = 1000

# Logar queries administrativas lentas (ALTER TABLE, etc)
log_slow_admin_statements = 1

# =========================================================================
# PERFORMANCE SCHEMA (para análise avançada - opcional)
# =========================================================================

# Habilitar performance schema
performance_schema = ON

# =========================================================================
# GENERAL LOG (usar apenas para debug - muito verbose)
# =========================================================================

# NÃO habilitar em produção (impacto de performance)
# general_log = 0
# general_log_file = /var/log/mysql/mysql.log
```

### Criar diretório de logs se não existir:

```bash
sudo mkdir -p /var/log/mysql
sudo chown mysql:mysql /var/log/mysql
sudo chmod 755 /var/log/mysql
```

### Restart MySQL:

```bash
# Verificar configuração antes de restart
sudo mysqld --help --verbose | grep -A 1 "Default options"

# Restart MySQL
sudo systemctl restart mysql
# OU
sudo systemctl restart mysqld

# Verificar se subiu corretamente
sudo systemctl status mysql
sudo systemctl status mysqld
```

### Verificar se foi aplicado:

```bash
mysql -u root -p

SHOW VARIABLES LIKE 'slow_query%';
# Deve mostrar:
# slow_query_log = ON
# slow_query_log_file = /var/log/mysql/mysql-slow.log

SHOW VARIABLES LIKE 'long_query_time';
# Deve mostrar: 2.000000

SHOW VARIABLES LIKE 'log_queries_not_using_indexes';
# Deve mostrar: ON

exit;
```

---

## 📊 PASSO 3: ANALISAR SLOW QUERIES

### Ver arquivo de log:

```bash
# Ver últimas queries lentas
sudo tail -50 /var/log/mysql/mysql-slow.log

# Contar queries lentas hoje
sudo grep "Query_time" /var/log/mysql/mysql-slow.log | grep "$(date +%y%m%d)" | wc -l

# Ver queries mais lentas
sudo grep -A 5 "Query_time" /var/log/mysql/mysql-slow.log | tail -50
```

### Usar mysqldumpslow (ferramenta oficial):

```bash
# Resumo das 10 queries mais lentas
sudo mysqldumpslow -s t -t 10 /var/log/mysql/mysql-slow.log

# Queries mais frequentes
sudo mysqldumpslow -s c -t 10 /var/log/mysql/mysql-slow.log

# Queries que examinam mais linhas
sudo mysqldumpslow -s r -t 10 /var/log/mysql/mysql-slow.log

# Help
mysqldumpslow --help
```

### Usar pt-query-digest (Percona Toolkit - opcional):

```bash
# Instalar Percona Toolkit
sudo apt-get install percona-toolkit -y
# OU
sudo yum install percona-toolkit -y

# Análise completa
sudo pt-query-digest /var/log/mysql/mysql-slow.log > /tmp/slow-query-analysis.txt

# Ver relatório
less /tmp/slow-query-analysis.txt

# Top 10 queries
sudo pt-query-digest --limit 10 /var/log/mysql/mysql-slow.log
```

---

## 🔄 PASSO 4: ROTAÇÃO AUTOMÁTICA DE LOGS

### Configurar logrotate:

```bash
# Criar configuração logrotate
sudo tee /etc/logrotate.d/mysql-slow > /dev/null <<'EOF'
/var/log/mysql/mysql-slow.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        # Fazer MySQL reabrir arquivo de log
        if [ -f /var/run/mysqld/mysqld.pid ]; then
            /usr/bin/mysqladmin flush-logs
        fi
    endscript
}
EOF

# Testar rotação
sudo logrotate -d /etc/logrotate.d/mysql-slow

# Forçar rotação (teste)
sudo logrotate -f /etc/logrotate.d/mysql-slow

# Verificar
ls -lh /var/log/mysql/
```

---

## 📈 PASSO 5: MONITORAMENTO E ALERTAS

### Script de análise diária:

```bash
sudo tee /opt/scripts/mysql-slow-query-daily-report.sh > /dev/null <<'EOF'
#!/bin/bash

#############################################################################
# MySQL Slow Query Daily Report
#############################################################################

SLOW_LOG="/var/log/mysql/mysql-slow.log"
REPORT_FILE="/var/log/mysql/slow-query-report-$(date +%Y%m%d).txt"
EMAIL_TO="admin@falg.com.br"  # Ajustar email
ALERT_THRESHOLD=100  # Alertar se mais de 100 queries lentas por dia

# Contar queries lentas hoje
TODAY=$(date +%y%m%d)
SLOW_COUNT=$(sudo grep "Query_time" "$SLOW_LOG" 2>/dev/null | grep -c "$TODAY" || echo 0)

# Gerar relatório
{
    echo "=== MySQL Slow Query Report - $(date) ==="
    echo ""
    echo "Total slow queries today: $SLOW_COUNT"
    echo ""

    if [ "$SLOW_COUNT" -gt 0 ]; then
        echo "Top 10 slowest queries:"
        echo ""
        sudo mysqldumpslow -s t -t 10 "$SLOW_LOG" 2>/dev/null || echo "mysqldumpslow not available"
        echo ""

        echo "Most frequent slow queries:"
        echo ""
        sudo mysqldumpslow -s c -t 10 "$SLOW_LOG" 2>/dev/null
    else
        echo "No slow queries detected today!"
    fi

    echo ""
    echo "=== End of Report ==="
} > "$REPORT_FILE"

# Log
cat "$REPORT_FILE"

# Alert se acima do threshold
if [ "$SLOW_COUNT" -gt "$ALERT_THRESHOLD" ]; then
    echo "ALERT: $SLOW_COUNT slow queries detected (threshold: $ALERT_THRESHOLD)" | \
        mail -s "MySQL Slow Query Alert - $(hostname)" "$EMAIL_TO" < "$REPORT_FILE" 2>/dev/null || \
        echo "Email alert failed (mail not configured)"
fi
EOF

sudo chmod +x /opt/scripts/mysql-slow-query-daily-report.sh

# Agendar execução diária às 23:00
sudo crontab -e

# Adicionar:
0 23 * * * /opt/scripts/mysql-slow-query-daily-report.sh
```

### Script de monitoramento em tempo real:

```bash
sudo tee /opt/scripts/mysql-slow-query-monitor.sh > /dev/null <<'EOF'
#!/bin/bash

#############################################################################
# MySQL Slow Query Real-Time Monitor
#############################################################################

SLOW_LOG="/var/log/mysql/mysql-slow.log"

echo "Monitoring slow queries in real-time..."
echo "Press Ctrl+C to stop"
echo ""

# Seguir log em tempo real
sudo tail -f "$SLOW_LOG" | while read line; do
    if [[ "$line" =~ "Query_time:" ]]; then
        echo ""
        echo "=== SLOW QUERY DETECTED - $(date) ==="
    fi
    echo "$line"
done
EOF

sudo chmod +x /opt/scripts/mysql-slow-query-monitor.sh

# Executar quando necessário:
# sudo /opt/scripts/mysql-slow-query-monitor.sh
```

---

## 🔍 PASSO 6: ANÁLISE COM PERFORMANCE SCHEMA

### Habilitar instrumentação:

```sql
-- Conectar ao MySQL
mysql -u root -p

-- Ver tabelas do Performance Schema
USE performance_schema;
SHOW TABLES;

-- Ver queries mais lentas (usando Performance Schema)
SELECT
    DIGEST_TEXT as query,
    COUNT_STAR as exec_count,
    ROUND(AVG_TIMER_WAIT/1000000000, 2) as avg_time_ms,
    ROUND(MAX_TIMER_WAIT/1000000000, 2) as max_time_ms,
    ROUND(SUM_TIMER_WAIT/1000000000, 2) as total_time_ms
FROM events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Ver queries que fazem full table scans
SELECT
    DIGEST_TEXT as query,
    COUNT_STAR as exec_count,
    SUM_NO_INDEX_USED as full_scans,
    SUM_NO_GOOD_INDEX_USED as bad_index_scans
FROM events_statements_summary_by_digest
WHERE SUM_NO_INDEX_USED > 0
ORDER BY SUM_NO_INDEX_USED DESC
LIMIT 10;
```

---

## 🛠️ PASSO 7: OTIMIZAÇÕES BASEADAS EM SLOW QUERIES

### Identificar queries para otimizar:

```bash
# Análise completa com pt-query-digest
sudo pt-query-digest --limit 20 /var/log/mysql/mysql-slow.log > /tmp/slow-queries-to-optimize.txt

# Revisar manualmente
less /tmp/slow-queries-to-optimize.txt
```

### Para cada query lenta, executar EXPLAIN:

```sql
-- Exemplo de análise
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';

-- Se não usa índice, criar:
CREATE INDEX idx_users_email ON users(email);

-- Verificar melhoria
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';
```

### Script para sugerir índices:

```bash
sudo tee /opt/scripts/mysql-suggest-indexes.sh > /dev/null <<'EOF'
#!/bin/bash

SLOW_LOG="/var/log/mysql/mysql-slow.log"

echo "=== MySQL Index Suggestions ==="
echo ""
echo "Analyzing slow queries for missing indexes..."
echo ""

# Usar pt-index-usage (Percona Toolkit)
if command -v pt-index-usage &> /dev/null; then
    sudo pt-index-usage /var/log/mysql/mysql-slow.log
else
    echo "pt-index-usage not installed. Install: sudo apt-get install percona-toolkit"
    echo ""
    echo "Manual analysis: Review queries without indexes"
    sudo grep -i "no.*index" "$SLOW_LOG" | head -20
fi
EOF

sudo chmod +x /opt/scripts/mysql-suggest-indexes.sh
```

---

## ✅ CHECKLIST DE EXECUÇÃO

- [ ] Backup da configuração MySQL
- [ ] slow_query_log habilitado permanentemente
- [ ] long_query_time configurado (2 segundos)
- [ ] log_queries_not_using_indexes habilitado
- [ ] Diretório /var/log/mysql/ criado com permissões
- [ ] MySQL restartado com sucesso
- [ ] Verificado que slow query log está funcionando
- [ ] Logrotate configurado (rotação diária, 30 dias)
- [ ] Script de relatório diário criado e agendado
- [ ] Script de monitoramento em tempo real criado
- [ ] Performance Schema habilitado
- [ ] Documentação salva

---

## 📊 QUERIES ÚTEIS PARA ANÁLISE

```sql
-- Ver status atual do slow query log
SHOW STATUS LIKE 'Slow_queries';

-- Reset counter (para teste)
FLUSH STATUS;

-- Ver todas as variáveis relacionadas
SHOW VARIABLES LIKE '%slow%';
SHOW VARIABLES LIKE '%long_query%';

-- Forçar flush dos logs (após rotação)
FLUSH SLOW LOGS;

-- Ver queries em execução agora
SHOW FULL PROCESSLIST;

-- Matar query específica
KILL QUERY [process_id];
```

---

## 🎯 RESULTADO ESPERADO

### Imediato:
- ✅ Slow query log habilitado permanentemente
- ✅ Queries > 2s sendo logadas
- ✅ Queries sem índices sendo identificadas

### Diário:
- ✅ Relatório automático de slow queries
- ✅ Rotação automática de logs
- ✅ Alertas se threshold excedido

### Longo prazo:
- ✅ Identificação proativa de problemas
- ✅ Database otimizado com índices adequados
- ✅ Histórico de performance

---

## 💡 DICAS E BEST PRACTICES

1. **long_query_time**: Começar com 2s, ajustar conforme necessário
2. **Rotação de logs**: 30 dias é suficiente, mais que isso ocupa muito espaço
3. **Análise semanal**: Revisar pt-query-digest toda semana
4. **Índices**: Sempre testar impacto antes de criar em produção
5. **Performance Schema**: Usar para análise mais profunda quando necessário

---

**Prioridade:** 🟡 MÉDIA
**Tempo estimado:** 15 minutos
**Impacto:** Diagnóstico contínuo e otimização proativa

---

**Criado por:** Hive Mind Collective Intelligence
**Complementa:** Todas as otimizações de MySQL
**Nota:** Ferramenta essencial para manutenção preventiva
