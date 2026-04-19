# 📊 DASHBOARD DE MÉTRICAS - VPS Timeout Monitoring

**Objetivo:** Acompanhar métricas em tempo real durante validação (09:00-10:00)
**Uso:** Manter aberto em terminal/navegador durante monitoramento

---

## 🎯 VISÃO GERAL - MÉTRICAS ESPERADAS

### Baseline (Normal Operation)
```
┌─────────────────────────────────────────────────────────┐
│ FGSRV3 (MySQL)                                          │
├─────────────────────────────────────────────────────────┤
│ CPU Usage:              15-30%        ✅ NORMAL         │
│ Memory Usage:           40-60%        ✅ NORMAL         │
│ Threads Connected:      20-40         ✅ NORMAL         │
│ Max Connections:        151           ✅ NORMAL         │
│ Active Queries:         5-15          ✅ NORMAL         │
│ Slow Queries:           0-5/hour      ✅ NORMAL         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ FGSRV4 (nginx/PHP5 - falg.com.br)                      │
├─────────────────────────────────────────────────────────┤
│ CPU Usage:              20-40%        ✅ NORMAL         │
│ Memory Usage:           50-70%        ✅ NORMAL         │
│ PHP-FPM Processes:      8-15          ✅ NORMAL         │
│ nginx Connections:      20-50         ✅ NORMAL         │
│ Response Time:          200-400ms     ✅ NORMAL         │
│ Error Rate:             0%            ✅ NORMAL         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ FGSRV5 (Laravel - api.falg.com.br)                     │
├─────────────────────────────────────────────────────────┤
│ CPU Usage:              20-40%        ✅ NORMAL         │
│ Memory Usage:           50-70%        ✅ NORMAL         │
│ PHP-FPM Processes:      10-20         ✅ NORMAL         │
│ Queue Workers:          2-5           ✅ NORMAL         │
│ Response Time:          100-300ms     ✅ NORMAL         │
│ Error Rate:             0%            ✅ NORMAL         │
└─────────────────────────────────────────────────────────┘
```

### Thresholds de Alerta
```
⚠️  WARNING:  Aproximando do limite
🚨 CRITICAL:  Limite excedido - ação necessária

FGSRV3 (MySQL):
├─ CPU:                ⚠️ 60%    🚨 80%
├─ Memory:             ⚠️ 75%    🚨 85%
├─ Connections:        ⚠️ 70%    🚨 90% of max
├─ Active Queries:     ⚠️ 30     🚨 50
└─ Slow Queries:       ⚠️ 10     🚨 20/hour

FGSRV4 & FGSRV5 (nginx/PHP):
├─ CPU:                ⚠️ 70%    🚨 85%
├─ Memory:             ⚠️ 80%    🚨 90%
├─ PHP-FPM Processes:  ⚠️ 25     🚨 29 (max_children)
├─ Response Time:      ⚠️ 1s     🚨 3s
└─ Error Rate:         ⚠️ 0.1%   🚨 1%
```

---

## 📊 TEMPLATE DE TRACKING (COPIE E PREENCHA)

### 09:00 - INÍCIO DA JANELA CRÍTICA

```
┌─────────────────────────────────────────────────────────┐
│ 09:00:00 - INÍCIO                                       │
├─────────────────────────────────────────────────────────┤
│ FGSRV3 (MySQL)                                          │
│ ├─ CPU: ____%      ├─ Memory: ____%                     │
│ ├─ Connections: ____/151                                │
│ ├─ Active Queries: ____                                 │
│ └─ Backup Running: [ ] YES  [ ] NO                      │
│                                                          │
│ FGSRV4 (falg.com.br)                                    │
│ ├─ CPU: ____%      ├─ Memory: ____%                     │
│ ├─ PHP-FPM: ____   ├─ nginx Conn: ____                  │
│ ├─ Response: ____ms                                     │
│ └─ HTTP Status: [ ] 200  [ ] 502  [ ] 504  [ ] Other   │
│                                                          │
│ FGSRV5 (api.falg.com.br)                                │
│ ├─ CPU: ____%      ├─ Memory: ____%                     │
│ ├─ PHP-FPM: ____   ├─ Queue Workers: ____               │
│ ├─ Response: ____ms                                     │
│ └─ HTTP Status: [ ] 200  [ ] 502  [ ] 504  [ ] Other   │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:05 - Checkpoint 1

```
┌─────────────────────────────────────────────────────────┐
│ 09:05:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:10 - Checkpoint 2

```
┌─────────────────────────────────────────────────────────┐
│ 09:10:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:15 - Checkpoint 3

```
┌─────────────────────────────────────────────────────────┐
│ 09:15:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ CRON JOBS: (escalonados rodando agora?)                 │
│ ├─ Job 1 (09:05): [ ] Executou  [ ] Não detectado      │
│ ├─ Job 2 (09:15): [ ] Executando [ ] Não detectado     │
│ └─ Job 3 (09:25): [ ] Pendente                          │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:20 - Checkpoint 4

```
┌─────────────────────────────────────────────────────────┐
│ 09:20:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:25 - Checkpoint 5

```
┌─────────────────────────────────────────────────────────┐
│ 09:25:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ CRON JOBS: (job 3 rodando agora?)                       │
│ └─ Job 3 (09:25): [ ] Executando [ ] Não detectado     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:30 - MEIO DA JANELA (SNAPSHOT DETALHADO)

```
┌─────────────────────────────────────────────────────────┐
│ 09:30:00 - SNAPSHOT DETALHADO                           │
├─────────────────────────────────────────────────────────┤
│ FGSRV3 (MySQL)                                          │
│ ├─ CPU: ____%      Status: [ ] ✅ [ ] ⚠️ [ ] 🚨        │
│ ├─ Memory: ____%   Status: [ ] ✅ [ ] ⚠️ [ ] 🚨        │
│ ├─ Connections: ____/151 (___%)                         │
│ ├─ Active Queries: ____                                 │
│ ├─ Slow Queries (last 30min): ____                      │
│ └─ Longest Query Time: ____ seconds                     │
│                                                          │
│ FGSRV4 (nginx/PHP5)                                     │
│ ├─ CPU: ____%      Status: [ ] ✅ [ ] ⚠️ [ ] 🚨        │
│ ├─ Memory: ____%   Status: [ ] ✅ [ ] ⚠️ [ ] 🚨        │
│ ├─ PHP-FPM Processes: ____/30                           │
│ ├─ nginx Connections: ____                              │
│ ├─ Response Time: ____ms                                │
│ └─ Errors (last 30min): ____                            │
│                                                          │
│ FGSRV5 (Laravel)                                        │
│ ├─ CPU: ____%      Status: [ ] ✅ [ ] ⚠️ [ ] 🚨        │
│ ├─ Memory: ____%   Status: [ ] ✅ [ ] ⚠️ [ ] 🚨        │
│ ├─ PHP-FPM Processes: ____/30                           │
│ ├─ Queue Workers: ____                                  │
│ ├─ Response Time: ____ms                                │
│ └─ Failed Jobs (last 30min): ____                       │
│                                                          │
│ OBSERVAÇÕES CRÍTICAS:                                   │
│ ___________________________________________________     │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:35 - Checkpoint 6

```
┌─────────────────────────────────────────────────────────┐
│ 09:35:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:40 - Checkpoint 7

```
┌─────────────────────────────────────────────────────────┐
│ 09:40:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:45 - Checkpoint 8

```
┌─────────────────────────────────────────────────────────┐
│ 09:45:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:50 - Checkpoint 9

```
┌─────────────────────────────────────────────────────────┐
│ 09:50:00                                                │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 09:55 - Checkpoint 10 (Pré-finalização)

```
┌─────────────────────────────────────────────────────────┐
│ 09:55:00 - PRÉ-FINALIZAÇÃO                              │
├─────────────────────────────────────────────────────────┤
│ Sites: [ ] ✅ OK  [ ] ⚠️ Slow  [ ] ❌ Down              │
│ Timeouts: [ ] ZERO  [ ] Detected: ____                  │
│ Load Average: ____, ____, ____                          │
│                                                          │
│ MySQL Connections: ____/151 (___%)                      │
│ PHP-FPM fgsrv4: ____   fgsrv5: ____                     │
│                                                          │
│ PREPARAÇÃO FINAL:                                       │
│ ├─ Monitores rodando: [ ] SIM  [ ] NÃO                  │
│ ├─ Logs sendo gerados: [ ] SIM  [ ] NÃO                 │
│ └─ 5 minutos para fim: [ ] PRONTO                       │
│                                                          │
│ OBSERVAÇÕES:                                            │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

### 10:00 - FIM DA JANELA CRÍTICA

```
┌─────────────────────────────────────────────────────────┐
│ 10:00:00 - FIM DA JANELA                                │
├─────────────────────────────────────────────────────────┤
│ RESULTADO FINAL:                                        │
│ ├─ Total Timeouts: ____                                 │
│ ├─ Total Errors: ____                                   │
│ ├─ Uptime Sites: ____%                                  │
│ └─ Status: [ ] ✅ SUCESSO  [ ] ⚠️ PARCIAL  [ ] ❌ FALHA │
│                                                          │
│ Sites Status:                                           │
│ ├─ falg.com.br: HTTP ____ (___ms)                       │
│ └─ api.falg.com.br: HTTP ____ (___ms)                   │
│                                                          │
│ MÉTRICAS FINAIS:                                        │
│                                                          │
│ FGSRV3:                                                 │
│ ├─ CPU Pico: ____%                                      │
│ ├─ Memory Pico: ____%                                   │
│ ├─ Connections Pico: ____/151                           │
│ └─ Slow Queries Total: ____                             │
│                                                          │
│ FGSRV4:                                                 │
│ ├─ CPU Pico: ____%                                      │
│ ├─ Memory Pico: ____%                                   │
│ ├─ PHP-FPM Pico: ____                                   │
│ └─ Response Time Médio: ____ms                          │
│                                                          │
│ FGSRV5:                                                 │
│ ├─ CPU Pico: ____%                                      │
│ ├─ Memory Pico: ____%                                   │
│ ├─ PHP-FPM Pico: ____                                   │
│ └─ Response Time Médio: ____ms                          │
│                                                          │
│ OBSERVAÇÕES FINAIS:                                     │
│ ___________________________________________________     │
│ ___________________________________________________     │
│ ___________________________________________________     │
└─────────────────────────────────────────────────────────┘
```

---

## 📈 GRÁFICO DE TENDÊNCIAS (TRACKING VISUAL)

### MySQL Connections (0-151)
```
09:00 [____________________] ____
09:05 [____________________] ____
09:10 [____________________] ____
09:15 [____________________] ____
09:20 [____________________] ____
09:25 [____________________] ____
09:30 [____________________] ____
09:35 [____________________] ____
09:40 [____________________] ____
09:45 [____________________] ____
09:50 [____________________] ____
09:55 [____________________] ____
10:00 [____________________] ____

Legenda: Desenhe barras proporcionais ao número de connections
```

### PHP-FPM Processes (0-30)
```
         fgsrv4                    fgsrv5
09:00 [__________] ____    [__________] ____
09:05 [__________] ____    [__________] ____
09:10 [__________] ____    [__________] ____
09:15 [__________] ____    [__________] ____
09:20 [__________] ____    [__________] ____
09:25 [__________] ____    [__________] ____
09:30 [__________] ____    [__________] ____
09:35 [__________] ____    [__________] ____
09:40 [__________] ____    [__________] ____
09:45 [__________] ____    [__________] ____
09:50 [__________] ____    [__________] ____
09:55 [__________] ____    [__________] ____
10:00 [__________] ____    [__________] ____
```

### Response Times (ms)
```
         falg.com.br              api.falg.com.br
09:00    ____ms                   ____ms
09:05    ____ms                   ____ms
09:10    ____ms                   ____ms
09:15    ____ms                   ____ms
09:20    ____ms                   ____ms
09:25    ____ms                   ____ms
09:30    ____ms                   ____ms
09:35    ____ms                   ____ms
09:40    ____ms                   ____ms
09:45    ____ms                   ____ms
09:50    ____ms                   ____ms
09:55    ____ms                   ____ms
10:00    ____ms                   ____ms

Meta: < 500ms ✅  |  500-1000ms ⚠️  |  > 1000ms 🚨
```

---

## 🎯 COMPARAÇÃO: ANTES vs DEPOIS

### Preencher após coleta:

```
┌──────────────────────────────────────────────────────────────┐
│ COMPARAÇÃO DE MÉTRICAS                                       │
├──────────────────────────────────────────────────────────────┤
│                          ANTES        DEPOIS      MELHORIA   │
├──────────────────────────────────────────────────────────────┤
│ Timeouts (09:00-10:00)  ____         ____        ____%      │
│ MySQL Connections Pico  ____         ____        ____%      │
│ PHP-FPM Processes Pico  ____         ____        ____%      │
│ Response Time Médio     ____ms       ____ms      ____%      │
│ CPU Usage Pico          ____%        ____%       ____%      │
│ Memory Usage Pico       ____%        ____%       ____%      │
│ Error Rate              ____%        ____%       ____%      │
└──────────────────────────────────────────────────────────────┘

OBSERVAÇÕES:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

## 🚨 COMANDOS DE COLETA RÁPIDA

### Durante checkpoints, executar em cada host:

```bash
# Quick metrics (copie e cole)
{
  echo "=== $(date +%H:%M:%S) ==="
  echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
  echo "MySQL: $(mysql -e 'SHOW STATUS LIKE "Threads_connected";' 2>/dev/null | tail -1 | awk '{print $2}')/151"
  echo "PHP-FPM: $(ps aux | grep php-fpm | grep -v grep | wc -l)"
  curl -w "falg: %{http_code} %{time_total}s\n" -o /dev/null -s https://falg.com.br
  curl -w "api: %{http_code} %{time_total}s\n" -o /dev/null -s https://api.falg.com.br
} | tee -a /tmp/validation-$(date +%Y%m%d)/quick-metrics.log
```

---

**Preparado por:** Hive Mind Collective Intelligence
**Data:** 2025-10-22
**Versão:** 1.0 Metrics Dashboard

**💡 DICA:** Mantenha este dashboard aberto em tela split durante todo o monitoramento!
