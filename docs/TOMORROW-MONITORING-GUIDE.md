# 📊 GUIA DE MONITORAMENTO - Dia Seguinte (Validação)

**Data:** Para executar amanhã (2025-10-23)
**Janela crítica:** 09:00-10:00
**Objetivo:** Validar que as correções funcionaram

---

## ⏰ TIMELINE DO DIA

```
08:30 - Preparação e baseline
08:45 - Conexão aos hosts
08:55 - Iniciar monitoramento
09:00 - JANELA CRÍTICA começa
10:00 - JANELA CRÍTICA termina
10:05 - Verificação inicial
10:30 - Coleta de evidências
11:00 - Análise e validação
```

---

## 🎯 MÉTRICAS DE SUCESSO

### Critérios Primários (MUST HAVE)
- ✅ **ZERO timeouts** em falg.com.br
- ✅ **ZERO timeouts** em api.falg.com.br
- ✅ **ZERO erros 502/504** nos logs nginx

### Critérios Secundários (SHOULD HAVE)
- ✅ MySQL Threads_connected < 70% do max_connections
- ✅ PHP-FPM active processes < 25
- ✅ Response time < 500ms
- ✅ CPU usage < 80%
- ✅ Memory usage < 85%

### Critérios de Validação
- ✅ Backup MySQL NÃO rodando às 09:00
- ✅ Cron jobs distribuídos (não todos às 09:00)
- ✅ PHP-FPM workers < pm.max_children

---

## 📋 PRÉ-MONITORAMENTO (08:30-08:55)

### 1. Conectar aos 3 hosts (08:45)

```bash
# Terminal 1
ssh fgsrv3  # MySQL

# Terminal 2
ssh fgsrv4  # nginx/PHP5

# Terminal 3
ssh fgsrv5  # Laravel
```

### 2. Coletar Baseline (08:50)

#### Em todos os hosts:

```bash
# Criar diretório para logs
mkdir -p /tmp/validation-$(date +%Y%m%d)

# Snapshot pré-janela
{
  echo "=== BASELINE - $(hostname) - $(date +%H:%M) ==="
  echo ""
  echo "CPU & Memory:"
  top -bn1 | head -15
  echo ""
  echo "Disk I/O:"
  iostat -x 1 2 2>/dev/null || echo "iostat not available"
  echo ""
  echo "Network connections:"
  netstat -an | grep -E ":80|:3306" | wc -l
} | tee /tmp/validation-$(date +%Y%m%d)/baseline-$(hostname)-$(date +%H%M).txt
```

#### fgsrv3 (MySQL) específico:

```bash
# MySQL baseline
mysql -e "
  SHOW STATUS LIKE 'Threads_connected';
  SHOW STATUS LIKE 'Max_used_connections';
  SHOW VARIABLES LIKE 'max_connections';
  SHOW PROCESSLIST;
" | tee /tmp/validation-$(date +%Y%m%d)/mysql-baseline-$(date +%H%M).txt

# Verificar que backup NÃO está rodando
ps aux | grep -E "mysqldump|backup" | grep -v grep | tee -a /tmp/validation-$(date +%Y%m%d)/mysql-baseline-$(date +%H%M).txt || echo "✓ No backup running"
```

#### fgsrv4 & fgsrv5 (nginx/PHP) específico:

```bash
# PHP-FPM baseline
ps aux | grep php-fpm | wc -l | tee /tmp/validation-$(date +%Y%m%d)/phpfpm-baseline-$(hostname)-$(date +%H%M).txt

# nginx connections baseline
netstat -an | grep :80 | wc -l | tee -a /tmp/validation-$(date +%Y%m%d)/phpfpm-baseline-$(hostname)-$(date +%H%M).txt
```

---

## 🚀 MONITORAMENTO ATIVO (08:55-10:05)

### Iniciar Monitores (08:55)

#### fgsrv3 (MySQL) - Terminal 1:

```bash
# Monitor contínuo MySQL
nohup sh -c 'while true; do
  echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/validation-$(date +%Y%m%d)/mysql-monitor.log
  mysql -e "SHOW STATUS LIKE \"Threads_connected\"; SELECT COUNT(*) as active_queries FROM information_schema.PROCESSLIST WHERE COMMAND != \"Sleep\"; SHOW PROCESSLIST;" >> /tmp/validation-$(date +%Y%m%d)/mysql-monitor.log 2>&1
  echo "" >> /tmp/validation-$(date +%Y%m%d)/mysql-monitor.log
  sleep 30
done' > /tmp/mysql-monitor.out 2>&1 &

echo "MySQL monitor started (PID: $!)"
```

#### fgsrv4 (nginx/PHP5) - Terminal 2:

```bash
# Monitor contínuo nginx + PHP-FPM
nohup sh -c 'while true; do
  echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log
  echo "Active connections: $(netstat -an | grep :80 | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log
  echo "PHP-FPM processes: $(ps aux | grep php-fpm | grep -v grep | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log
  echo "" >> /tmp/validation-$(date +%Y%m%d)/nginx-monitor.log
  sleep 30
done' > /tmp/nginx-monitor.out 2>&1 &

echo "nginx monitor started (PID: $!)"
```

#### fgsrv5 (Laravel) - Terminal 3:

```bash
# Monitor contínuo Laravel
nohup sh -c 'while true; do
  echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log
  echo "Active connections: $(netstat -an | grep :80 | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log
  echo "PHP-FPM processes: $(ps aux | grep php-fpm | grep -v grep | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log
  echo "Queue workers: $(ps aux | grep \"queue:work\" | grep -v grep | wc -l)" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log
  echo "" >> /tmp/validation-$(date +%Y%m%d)/laravel-monitor.log
  sleep 30
done' > /tmp/laravel-monitor.out 2>&1 &

echo "Laravel monitor started (PID: $!)"
```

---

## 👀 OBSERVAÇÃO DURANTE JANELA (09:00-10:00)

### Checklist Minuto-a-Minuto

#### 09:00 - Início da Janela

```bash
# Em todos os hosts
echo "09:00 - Janela iniciou" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt

# fgsrv3: Confirmar que backup NÃO está rodando
ps aux | grep mysqldump | grep -v grep || echo "✓ No backup at 09:00"

# fgsrv4 & fgsrv5: Testar sites
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s https://falg.com.br
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s https://api.falg.com.br
```

#### 09:05, 09:10, 09:15, etc - Verificações Periódicas

```bash
# A cada 5 minutos, verificar:

# 1. Sites respondendo?
curl -I https://falg.com.br 2>&1 | grep "HTTP" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt
curl -I https://api.falg.com.br 2>&1 | grep "HTTP" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt

# 2. Cron jobs rodando? (verificar jobs escalonados)
ps aux | grep cron | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt

# 3. Recursos OK?
echo "$(date +%H:%M) - Load: $(uptime | awk -F'load average:' '{print $2}')" | tee -a /tmp/validation-$(date +%Y%m%d)/observations.txt
```

#### 09:30 - Meio da Janela

```bash
# Snapshot detalhado
{
  echo "=== 09:30 MID-WINDOW SNAPSHOT ==="
  echo "Host: $(hostname)"
  echo ""

  # MySQL (fgsrv3)
  mysql -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null || echo "Not MySQL host"

  # PHP-FPM (fgsrv4, fgsrv5)
  ps aux | grep php-fpm | wc -l

  # nginx (fgsrv4, fgsrv5)
  netstat -an | grep :80 | wc -l

  # System
  free -h
  echo ""
  top -bn1 | head -10
} | tee /tmp/validation-$(date +%Y%m%d)/snapshot-0930-$(hostname).txt
```

#### 10:00 - Fim da Janela

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

---

## 🛑 PARAR MONITORES (10:05)

```bash
# Em cada host, parar os monitores
kill $(ps aux | grep "validation.*monitor" | grep -v grep | awk '{print $2}') 2>/dev/null
# OU
killall -9 sh 2>/dev/null

# Verificar que pararam
ps aux | grep monitor | grep -v grep
```

---

## 📦 COLETAR EVIDÊNCIAS (10:05-10:30)

### Em cada host:

```bash
# Criar tarball com todas as evidências
cd /tmp
tar -czf validation-evidence-$(hostname)-$(date +%Y%m%d).tar.gz validation-$(date +%Y%m%d)/

# Verificar tamanho
ls -lh validation-evidence-*.tar.gz

# Copiar para máquina local (executar na máquina local)
mkdir -p ~/vps-timeout-evidence
scp fgsrv3:/tmp/validation-evidence-*.tar.gz ~/vps-timeout-evidence/
scp fgsrv4:/tmp/validation-evidence-*.tar.gz ~/vps-timeout-evidence/
scp fgsrv5:/tmp/validation-evidence-*.tar.gz ~/vps-timeout-evidence/
```

---

## 📊 ANÁLISE DE RESULTADOS (10:30-11:00)

### Análise Automatizada:

```bash
# Na máquina local
cd ~/vps-timeout-evidence

# Extrair tarballs
for file in *.tar.gz; do tar -xzf "$file"; done

# Análise consolidada
cat > analyze-results.sh <<'ANALYSIS'
#!/bin/bash

echo "═══════════════════════════════════════════════════"
echo "ANÁLISE DE VALIDAÇÃO - VPS TIMEOUT FIX"
echo "═══════════════════════════════════════════════════"
echo ""

# 1. Verificar timeouts
echo "1. TIMEOUTS DETECTADOS:"
grep -i "timeout\|502\|504" */observations.txt */final-check-*.txt 2>/dev/null || echo "✓ Nenhum timeout detectado"
echo ""

# 2. Backup MySQL
echo "2. BACKUP MYSQL ÀS 09:00:"
grep -i "backup\|mysqldump" */mysql-baseline-*.txt 2>/dev/null || echo "✓ Nenhum backup rodando"
echo ""

# 3. MySQL connections
echo "3. MYSQL CONNECTIONS:"
grep "Threads_connected" */mysql-monitor.log | tail -5
echo ""

# 4. PHP-FPM processes
echo "4. PHP-FPM PROCESSES (pico):"
grep "PHP-FPM processes:" */nginx-monitor.log */laravel-monitor.log | awk '{print $NF}' | sort -rn | head -1
echo ""

# 5. Sites response
echo "5. SITES STATUS:"
grep "HTTP" */final-check-*.txt
echo ""

echo "═══════════════════════════════════════════════════"
echo "RESULTADO: "
if ! grep -qi "timeout\|502\|504" */observations.txt */final-check-*.txt 2>/dev/null; then
  echo "✅ SUCESSO - Zero timeouts detectados!"
else
  echo "⚠️  INVESTIGAR - Timeouts ainda presentes"
fi
echo "═══════════════════════════════════════════════════"
ANALYSIS

chmod +x analyze-results.sh
./analyze-results.sh
```

---

## ✅ CHECKLIST DE VALIDAÇÃO

### Critérios de Sucesso

- [ ] **Sites acessíveis durante toda janela 09:00-10:00**
- [ ] **Zero erros de timeout nos logs**
- [ ] **Backup MySQL NÃO rodou às 09:00** (fgsrv3)
- [ ] **MySQL connections abaixo de 70%** (fgsrv3)
- [ ] **PHP-FPM processes < 25** (fgsrv4, fgsrv5)
- [ ] **Cron jobs escalonados** (distribuídos ao longo de 30 min)
- [ ] **Response time < 1s** para ambos os sites
- [ ] **Nenhum spike de CPU/Memory**

### Se TODAS as marcações acima = ✅

**RESULTADO:** 🎉 **PROBLEMA RESOLVIDO COM SUCESSO!**

### Se alguma marcação = ❌

**AÇÃO:** Investigar usando os guias:
- `/docs/research/morning-timeout-analysis.md`
- `/docs/analysis/diagnostic-framework.md`
- Verificar logs detalhados em `/tmp/validation-*/`

---

## 📝 RELATÓRIO FINAL

### Template de Relatório:

```markdown
# RELATÓRIO DE VALIDAÇÃO - VPS TIMEOUT FIX
Data: [DATA]
Janela monitorada: 09:00-10:00

## RESULTADO GERAL
[ ] ✅ SUCESSO - Zero timeouts
[ ] ⚠️ PARCIAL - Melhorias mas ainda há timeouts
[ ] ❌ FALHA - Timeouts persistem

## MÉTRICAS COLETADAS

### fgsrv3 (MySQL)
- Backup às 09:00: [SIM/NÃO]
- Threads_connected pico: [NÚMERO] / [MAX] ([%]%)
- Queries lentas detectadas: [NÚMERO]

### fgsrv4 (nginx/PHP5 - falg.com.br)
- Timeouts detectados: [NÚMERO]
- PHP-FPM processes pico: [NÚMERO]
- nginx connections pico: [NÚMERO]
- Response time médio: [TEMPO]s

### fgsrv5 (Laravel - api.falg.com.br)
- Timeouts detectados: [NÚMERO]
- PHP-FPM processes pico: [NÚMERO]
- Queue workers ativos: [NÚMERO]
- Response time médio: [TEMPO]s

## OBSERVAÇÕES
[Descrever comportamento durante janela]

## PRÓXIMOS PASSOS
[Se sucesso: manter monitoramento]
[Se falha: ações corretivas]

## EVIDÊNCIAS
- Logs coletados: ~/vps-timeout-evidence/
- Análise automatizada: analyze-results.sh

═══════════════════════════════════════════════════
Relatório gerado em: [DATA E HORA]
```

---

## 🎯 PRÓXIMOS PASSOS APÓS VALIDAÇÃO

### Se SUCESSO (Zero timeouts):

1. **Monitorar por mais 7 dias** - Confirmar estabilidade
2. **Analisar slow query log** - Otimizar queries lentas
3. **Implementar monitoring permanente** - Prometheus/Grafana
4. **Documentar lições aprendidas**
5. **Celebrar! 🎉**

### Se FALHA (Timeouts persistem):

1. **Analisar logs detalhados** - Identificar padrão
2. **Verificar implementações** - Confirmar que foram aplicadas
3. **Revisar hipótese 4** - Infraestrutura Locaweb (20%)
4. **Abrir ticket com Locaweb** - Reportar padrão
5. **Consultar framework diagnóstico** - Investigação profunda

---

## 📞 CONTATOS DE EMERGÊNCIA

Se houver problemas durante monitoramento:

- **Locaweb Suporte:** [PREENCHER]
- **DBA:** [PREENCHER]
- **DevOps:** [PREENCHER]
- **Gerente:** [PREENCHER]

---

**Preparado por:** Hive Mind Collective Intelligence
**Para execução:** 2025-10-23 (Dia seguinte)
**Duração:** ~2 horas de monitoramento ativo
**Resultado esperado:** ✅ Zero timeouts!
