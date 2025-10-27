# ⚡ GUIA RÁPIDO DE MONITORAMENTO - 23/10/2025

## 🕐 08:55 - PREPARAÇÃO (5 minutos)

### Terminal 1 - fgsrv3 (MySQL)
```bash
# Conectar
ssh fgsrv3

# Preparar monitoring
watch -n 5 "echo '=== MySQL Connections ===' && mysql -e 'SHOW PROCESSLIST' | wc -l && echo && echo '=== Load ===' && uptime"
```

### Terminal 2 - fgsrv4 (Web/PHP5)
```bash
# Conectar
ssh fgsrv4

# Preparar monitoring
watch -n 5 "echo '=== PHP-FPM ===' && systemctl status php5.6-fpm php8.2-fpm | grep -E 'Active|Memory' && echo && echo '=== Load ===' && uptime && echo && echo '=== Crons ===' && ps aux | grep -E '(log-analyzer|service-monitor|performance-monitor)' | grep -v grep"
```

### Terminal 3 - fgsrv5 (Laravel)
```bash
# Conectar
ssh fgsrv5

# Preparar monitoring
watch -n 5 "echo '=== PHP-FPM ===' && systemctl status php*.fpm | grep -E 'Active|Memory' | head -12 && echo && echo '=== Load ===' && uptime"
```

---

## 🔴 09:00-09:10 - JANELA CRÍTICA

### OBSERVAR:

1. **Load average** nos 3 hosts deve ficar < 2.0
2. **PHP-FPM processes** devem ficar < 25 por pool
3. **MySQL connections** devem ficar < 100
4. **NO Terminal 2 (fgsrv4):** Verificar que NENHUM cron roda às 09:00:00

### TESTAR SITES:

```bash
# Em paralelo, novo terminal
watch -n 10 "echo '=== falg.com.br ===' && curl -o /dev/null -s -w '%{http_code} - %{time_total}s\n' https://falg.com.br && echo && echo '=== api.falg.com.br ===' && curl -o /dev/null -s -w '%{http_code} - %{time_total}s\n' https://api.falg.com.br"
```

**Esperado:**
- HTTP 200
- Response time < 1s

---

## ✅ 09:10 - COLETAR EVIDÊNCIAS

### Slow Query Log (fgsrv3)
```bash
ssh fgsrv3 "grep '2025-10-23.*09:' /var/log/mysql/slow-query.log | wc -l"
# Esperado: 0 ou muito poucos
```

### Cron Execution (fgsrv4)
```bash
ssh fgsrv4 "grep -E '(log-analyzer|service-monitor|performance-monitor)' /var/log/syslog | grep '2025-10-23.*09:0' | head -20"
# Esperado: Jobs em 09:03, 09:05, 09:07 - NÃO em 09:00
```

### nginx Errors (fgsrv4 e fgsrv5)
```bash
ssh fgsrv4 "grep '2025-10-23.*09:' /var/log/nginx/error.log | wc -l"
ssh fgsrv5 "grep '2025-10-23.*09:' /var/log/nginx/error.log | wc -l"
# Esperado: 0 ou muito poucos
```

---

## 🎯 CRITÉRIOS DE SUCESSO

- [ ] Sites acessíveis 100% do tempo (09:00-09:10)
- [ ] Response time < 1s
- [ ] Sem erros 502/504
- [ ] Load < 2.0 em todos os hosts
- [ ] Nenhum cron rodou às 09:00:00 exato
- [ ] Slow queries < 5 durante janela crítica

---

## 🚨 SE HOUVER PROBLEMA

### Sites deram timeout
1. Verificar qual host: fgsrv4 ou fgsrv5
2. Ver load: `uptime`
3. Ver PHP-FPM: `systemctl status php*.fpm`
4. Ver nginx: `ss -s` (connections)

### Load alto em fgsrv3
1. Ver connections: `mysql -e "SHOW PROCESSLIST" | wc -l`
2. Ver slow queries: `tail -20 /var/log/mysql/slow-query.log`

### Cron rodou às 09:00
1. Ver crontab: `crontab -l`
2. Pode ter sido sobrescrito - reaplicar correção #2

---

## 📊 RELATÓRIO RÁPIDO (09:15)

```bash
# Executar isto e copiar resultado:
cat > /tmp/morning-report.txt <<'EOF'
RELATÓRIO MATINAL - $(date)

=== Sites ===
falg.com.br: [OK/TIMEOUT]
api.falg.com.br: [OK/TIMEOUT]

=== Loads (09:00-09:10) ===
fgsrv3: [valor]
fgsrv4: [valor]
fgsrv5: [valor]

=== Slow Queries (09:00-09:10) ===
Total: [número]

=== Crons fgsrv4 ===
09:00 exato: [SIM/NÃO - CRÍTICO!]
09:03: service-monitor [OK]
09:05: log-analyzer [OK]
09:07: performance-monitor [OK]

=== Erros nginx ===
fgsrv4: [número]
fgsrv5: [número]

RESULTADO FINAL: [✅ SUCESSO / ❌ FALHOU]
EOF

cat /tmp/morning-report.txt
```

---

## 🎉 SE TUDO OK

**Parabéns!** As correções funcionaram. Mantenha monitoring por mais 6 dias para confirmar.

## ❌ SE FALHOU

Veja `/mnt/overpower/apps/dev/agl/agl-hostman/docs/IMPLEMENTATION-REPORT-2025-10-22.md` seção "CHECKLIST DE ROLLBACK"
