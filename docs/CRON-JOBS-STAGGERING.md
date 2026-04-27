# 📅 ESCALONAR CRON JOBS - Hipótese 2 (50% probabilidade)

**Problema:** Múltiplos cron jobs rodando às 09:00 exato causam contenção de recursos
**Solução:** Distribuir jobs ao longo de 30 minutos
**Prioridade:** 🟡 ALTA (após reagendar backup)

---

## 🎯 OBJETIVO

Evitar que múltiplos jobs rodem simultaneamente às 09:00, distribuindo-os:
- **09:05** - Job 1
- **09:15** - Job 2
- **09:25** - Job 3
- **09:35** - Job 4

---

## 🔍 PASSO 1: IDENTIFICAR TODOS OS CRON JOBS (Todos os hosts)

### Em fgsrv3, fgsrv4, fgsrv5:

```bash
# Salvar inventário completo de cron jobs
{
  echo "=== CRON INVENTORY - $(hostname) - $(date) ==="
  echo ""
  echo "1. USER CRONTAB:"
  crontab -l 2>/dev/null || echo "No user crontab"
  echo ""
  echo "2. ROOT CRONTAB:"
  sudo crontab -l 2>/dev/null || echo "No root crontab"
  echo ""
  echo "3. SYSTEM CRONTAB:"
  sudo cat /etc/crontab
  echo ""
  echo "4. CRON.D DIRECTORY:"
  sudo ls -la /etc/cron.d/
  for file in /etc/cron.d/*; do
    echo "--- $file ---"
    sudo cat "$file"
  done
  echo ""
  echo "5. JOBS AT 9AM (all cron sources):"
  sudo grep -r "^[0-9]* 9" /etc/cron* /var/spool/cron/* 2>/dev/null || echo "None found"
  echo ""
  echo "6. JOBS WITH WILDCARDS (may run at 9am):"
  sudo grep -r "^\* \*" /etc/cron* 2>/dev/null | head -10
} | tee /tmp/cron-inventory-$(hostname).txt

# Exibir jobs que rodam às 9am
echo ""
echo "=== JOBS RUNNING AT 9AM ==="
sudo grep -r "^[0-9]* 9\|^0 9\|^5 9\|^10 9" /etc/cron* /var/spool/cron/* 2>/dev/null
```

---

## 📊 PASSO 2: ANALISAR E PRIORIZAR JOBS

Para cada job encontrado às 09:00, documentar:

```bash
# Criar matriz de análise
cat > /tmp/cron-analysis.txt <<'EOF'
=============================================================================
CRON JOBS ANALYSIS - 9AM WINDOW
=============================================================================

Job 1:
  - Comando: _______________
  - Duração estimada: _____ min
  - Criticidade: [LOW/MEDIUM/HIGH]
  - CPU uso: [LOW/MEDIUM/HIGH]
  - I/O uso: [LOW/MEDIUM/HIGH]
  - Pode ser movido? [YES/NO]
  - Novo horário sugerido: _____

Job 2:
  - Comando: _______________
  - Duração estimada: _____ min
  - Criticidade: [LOW/MEDIUM/HIGH]
  - CPU uso: [LOW/MEDIUM/HIGH]
  - I/O uso: [LOW/MEDIUM/HIGH]
  - Pode ser movido? [YES/NO]
  - Novo horário sugerido: _____

[... continuar para todos os jobs ...]

=============================================================================
STAGGERING PLAN
=============================================================================

09:05 - Job com menor impacto
09:15 - Job com média prioridade
09:25 - Job com maior prioridade
09:35 - Jobs adicionais (se houver)

Ou mover para outros horários:
- 08:30 - Jobs que podem rodar antes do pico
- 10:30 - Jobs que podem rodar depois do pico

=============================================================================
EOF

nano /tmp/cron-analysis.txt  # Editar e preencher
```

---

## 🛠️ PASSO 3: APLICAR ESCALONAMENTO

### Template de Escalonamento:

**ANTES (todos às 09:00):**
```cron
0 9 * * * /script1.sh
0 9 * * * /script2.sh
0 9 * * * /script3.sh
0 9 * * * /script4.sh
```

**DEPOIS (escalonados):**
```cron
5 9 * * * /script1.sh    # 09:05 - Menor impacto
15 9 * * * /script2.sh   # 09:15 - Média prioridade
25 9 * * * /script3.sh   # 09:25 - Maior prioridade
35 9 * * * /script4.sh   # 09:35 - Adicional
```

### Editar Cron Jobs:

#### Opção A: User Crontab
```bash
crontab -e

# Mudar horários conforme plano de escalonamento
# SALVAR
```

#### Opção B: Root Crontab
```bash
sudo crontab -e

# Mudar horários conforme plano de escalonamento
# SALVAR
```

#### Opção C: System Crontab
```bash
sudo nano /etc/crontab
# OU
sudo vi /etc/crontab

# Mudar horários conforme plano de escalonamento
# SALVAR
```

#### Opção D: Cron.d Files
```bash
# Listar arquivos
sudo ls -la /etc/cron.d/

# Editar cada arquivo relevante
sudo nano /etc/cron.d/[filename]

# Mudar horários conforme plano de escalonamento
# SALVAR
```

---

## ✅ PASSO 4: VERIFICAR MUDANÇAS

```bash
# Verificar todos os jobs após mudança
{
  echo "=== VERIFICATION - $(hostname) - $(date) ==="
  echo ""
  echo "Jobs at 09:00 (should be EMPTY or minimal):"
  sudo grep -r "^0 9" /etc/cron* /var/spool/cron/* 2>/dev/null || echo "✓ None found"
  echo ""
  echo "Jobs at 09:05:"
  sudo grep -r "^5 9" /etc/cron* /var/spool/cron/* 2>/dev/null || echo "None"
  echo ""
  echo "Jobs at 09:15:"
  sudo grep -r "^15 9" /etc/cron* /var/spool/cron/* 2>/dev/null || echo "None"
  echo ""
  echo "Jobs at 09:25:"
  sudo grep -r "^25 9" /etc/cron* /var/spool/cron/* 2>/dev/null || echo "None"
  echo ""
  echo "Jobs at 09:35:"
  sudo grep -r "^35 9" /etc/cron* /var/spool/cron/* 2>/dev/null || echo "None"
} | tee /tmp/cron-verification-$(hostname).txt
```

---

## 📝 EXEMPLOS PRÁTICOS

### Exemplo 1: Laravel Schedule Tasks (fgsrv5)

**ANTES:**
```cron
# Laravel scheduler rodando a cada minuto (inclui 09:00)
* * * * * cd /var/www/api.falg.com.br && php artisan schedule:run
```

**ANÁLISE:**
```bash
# Ver quais tasks o Laravel roda
cd /var/www/api.falg.com.br
php artisan schedule:list

# Identificar tasks que rodam às 9am
# Exemplo de output:
# 0 9 * * * php artisan emails:send
# 0 9 * * * php artisan reports:generate
# 0 9 * * * php artisan cache:clear
```

**SOLUÇÃO:**
Modificar `app/Console/Kernel.php`:

```php
// ANTES
protected function schedule(Schedule $schedule)
{
    $schedule->command('emails:send')->dailyAt('09:00');
    $schedule->command('reports:generate')->dailyAt('09:00');
    $schedule->command('cache:clear')->dailyAt('09:00');
}

// DEPOIS
protected function schedule(Schedule $schedule)
{
    $schedule->command('emails:send')->dailyAt('09:05');      // Escalonado
    $schedule->command('reports:generate')->dailyAt('09:15'); // Escalonado
    $schedule->command('cache:clear')->dailyAt('09:25');      // Escalonado
}
```

### Exemplo 2: Múltiplos Scripts de Manutenção (fgsrv3)

**ANTES:**
```cron
0 9 * * * /opt/scripts/cleanup.sh
0 9 * * * /opt/scripts/optimize-tables.sh
0 9 * * * /opt/scripts/check-disk.sh
```

**DEPOIS:**
```cron
30 8 * * * /opt/scripts/check-disk.sh        # Mover para ANTES (baixo impacto)
5 9 * * * /opt/scripts/cleanup.sh            # Escalonado
30 10 * * * /opt/scripts/optimize-tables.sh  # Mover para DEPOIS (alto impacto)
```

### Exemplo 3: Logs Rotation e Cleanup (todos os hosts)

**ANTES:**
```cron
0 9 * * * /usr/sbin/logrotate /etc/logrotate.conf
0 9 * * * find /var/log -name "*.gz" -mtime +30 -delete
```

**DEPOIS:**
```cron
0 3 * * * /usr/sbin/logrotate /etc/logrotate.conf     # Mover para madrugada
0 4 * * * find /var/log -name "*.gz" -mtime +30 -delete  # Mover para madrugada
```

---

## 🎯 ESTRATÉGIAS DE ESCALONAMENTO

### Estratégia 1: Distribuição Simples (Intervalos de 10 min)
```
09:00 - [vazio - reservado para tráfego normal]
09:10 - Job menos crítico
09:20 - Job média criticidade
09:30 - Job mais crítico
09:40 - Jobs adicionais
```

### Estratégia 2: Mover para Fora do Horário Crítico
```
08:00-08:30 - Jobs que podem rodar ANTES
10:30-11:00 - Jobs que podem rodar DEPOIS
02:00-04:00 - Jobs pesados (backups, otimizações)
```

### Estratégia 3: Baseada em Dependências
```
Se Job B depende de Job A:
09:05 - Job A (executa primeiro)
09:20 - Job B (executa após A ter tempo de completar)
```

---

## 📊 MONITORAMENTO PÓS-ESCALONAMENTO

### Verificar impacto após implementação:

```bash
# Durante a janela 09:00-10:00, monitorar:

# 1. CPU usage a cada minuto
while true; do
  echo "$(date +%H:%M) - CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')" >> /tmp/cpu-monitor.log
  sleep 60
done &

# 2. Processos ativos
while true; do
  echo "=== $(date +%H:%M) ===" >> /tmp/process-monitor.log
  ps aux | grep -E "php|mysql|nginx|cron" | grep -v grep >> /tmp/process-monitor.log
  sleep 60
done &

# 3. Load average
while true; do
  echo "$(date +%H:%M) - $(uptime)" >> /tmp/load-monitor.log
  sleep 60
done &

# Parar monitors após 10:30
# kill $(jobs -p)
```

---

## ✅ CHECKLIST DE EXECUÇÃO

### fgsrv3 (MySQL):
- [ ] Inventário completo de cron jobs
- [ ] Identificados jobs às 09:00
- [ ] Plano de escalonamento criado
- [ ] Jobs escalonados (5, 15, 25, 35 minutos)
- [ ] Verificação pós-mudança OK
- [ ] Documentação salva

### fgsrv4 (nginx/PHP5):
- [ ] Inventário completo de cron jobs
- [ ] Identificados jobs às 09:00
- [ ] Plano de escalonamento criado
- [ ] Jobs escalonados
- [ ] Verificação pós-mudança OK
- [ ] Documentação salva

### fgsrv5 (Laravel):
- [ ] Inventário completo de cron jobs
- [ ] Laravel schedule:list executado
- [ ] Kernel.php modificado (se aplicável)
- [ ] Jobs escalonados
- [ ] Verificação pós-mudança OK
- [ ] Código commitado (se Kernel.php mudou)

---

## 🚨 JOBS QUE NÃO DEVEM SER MOVIDOS

Cuidado com:
- **Backup do MySQL** - Já movemos para 02:30
- **Jobs críticos de negócio** - Confirmar com stakeholders antes
- **Jobs externos com SLA** - Podem ter horário fixo
- **Integrações com terceiros** - Verificar contratos

---

## 📝 DOCUMENTAR MUDANÇAS

```bash
{
  echo "=== CRON JOBS STAGGERING - $(date) ==="
  echo "Host: $(hostname)"
  echo ""
  echo "BEFORE:"
  cat /tmp/cron-inventory-$(hostname).txt | grep "^0 9"
  echo ""
  echo "AFTER:"
  sudo grep -r "^5 9\|^15 9\|^25 9\|^35 9" /etc/cron* /var/spool/cron/* 2>/dev/null
  echo ""
  echo "Changed by: $(whoami)"
  echo "Reason: Reduce resource contention during 9-10am window"
} > /tmp/cron-staggering-$(hostname)-$(date +%Y%m%d).txt

cat /tmp/cron-staggering-$(hostname)-*.txt
```

---

## 🎯 RESULTADO ESPERADO

### Imediato:
- ✅ Jobs distribuídos ao longo de 30-40 minutos
- ✅ Não mais que 1 job rodando simultaneamente
- ✅ Carga de CPU mais uniforme

### Amanhã às 09:00:
- ✅ Redução de 30-50% no spike de CPU
- ✅ Menos contenção de recursos
- ✅ Menor latência de resposta

---

**Prioridade:** 🟡 ALTA
**Tempo estimado:** 15-30 minutos (depende do número de jobs)
**Impacto esperado:** Redução de 50% do problema (complementar ao backup)

---

**Criado por:** Hive Mind Collective Intelligence
**Hipótese:** 50% probabilidade - Cron job clustering
**Complementa:** Reagendamento do backup MySQL
