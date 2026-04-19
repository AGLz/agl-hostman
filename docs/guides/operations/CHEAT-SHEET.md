# 📋 VPS Timeout - CHEAT SHEET (1 Página)

## ⏰ TIMELINE CRÍTICA
```
08:41 ✅ Preparação completa
08:45 🔄 Conectar aos hosts
08:55 ⚡ Iniciar monitoramento
09:00 🚨 JANELA DO PROBLEMA (observar e coletar)
10:00 ✓ Analisar e corrigir
```

## 🎯 HIPÓTESES (Prioridade)
1. **70%** - MySQL backup às 09:00 → Reagendar para 02:00
2. **50%** - Cron jobs clustering → Escalonar (9:05, 9:15, 9:25)
3. **30%** - PHP-FPM memory leak → Restart diário
4. **20%** - Infraestrutura Locaweb → Contatar suporte

## 🚀 3 PASSOS RÁPIDOS

### 1. CONECTAR (2 min)
```bash
ssh fgsrv3  # MySQL
ssh fgsrv4  # nginx/PHP5
ssh fgsrv5  # Laravel
```

### 2. AUDIT (5 min - TODOS OS HOSTS)
```bash
{ echo "=== Cron $(hostname) $(date) ==="; crontab -l 2>/dev/null; sudo crontab -l 2>/dev/null; sudo cat /etc/crontab; sudo grep -r "0 9" /etc/cron* 2>/dev/null; } | tee /tmp/cron-audit-$(hostname).txt
```

### 3. MONITOR (ÀS 08:55)

**fgsrv3:**
```bash
nohup sh -c 'while true; do echo "=== $(date +%H:%M:%S) ===" >> /tmp/mysql-monitor.log; mysql -e "SHOW STATUS LIKE \"Threads_connected\"; SHOW PROCESSLIST;" >> /tmp/mysql-monitor.log 2>&1; sleep 5; done' &
```

**fgsrv4 & fgsrv5:**
```bash
nohup sh -c 'while true; do echo "=== $(date +%H:%M:%S) ===" >> /tmp/nginx-monitor.log; echo "Conns: $(netstat -an | grep :80 | wc -l)" >> /tmp/nginx-monitor.log; sleep 5; done' &
```

## 🔥 DURANTE TIMEOUT (09:00)

### MySQL Emergency (fgsrv3):
```bash
mysql -e "SHOW FULL PROCESSLIST; SHOW STATUS LIKE 'Threads%'; SHOW OPEN TABLES WHERE In_use > 0;" | tee /tmp/mysql-emergency-$(date +%H%M).txt
```

### nginx Emergency (fgsrv4/fgsrv5):
```bash
{ sudo tail -50 /var/log/nginx/error.log; netstat -an | grep :80 | wc -l; ps aux | grep php-fpm | wc -l; } | tee /tmp/nginx-emergency-$(date +%H%M).txt
```

## 💊 CORREÇÕES RÁPIDAS

```bash
# Backup MySQL travado
sudo killall -9 mysqldump

# PHP-FPM esgotado
sudo systemctl restart php-fpm

# Conexões MySQL idle
mysql -e "SHOW PROCESSLIST;" | grep Sleep | awk '{print $1}' | xargs -I {} mysql -e "KILL {};"
```

## 📊 O QUE PROCURAR

**Backup MySQL (70%):**
- [ ] `ps aux | grep mysqldump` mostra processo
- [ ] `Threads_connected` alto
- [ ] `SHOW OPEN TABLES` com `In_use > 0`

**Cron Clustering (50%):**
- [ ] Múltiplos jobs às 09:00 exato
- [ ] CPU spike repentino

**PHP-FPM Leak (30%):**
- [ ] Processos php-fpm > 500MB
- [ ] Log: "max children reached"

## 📦 COLETAR EVIDÊNCIAS (10:00)

```bash
mkdir -p /tmp/evidence-$(date +%Y%m%d)
cp /tmp/*-monitor*.log /tmp/*-audit*.txt /tmp/*-emergency*.txt /tmp/evidence-$(date +%Y%m%d)/
tar -czf /tmp/evidence-$(hostname)-$(date +%Y%m%d).tar.gz -C /tmp evidence-$(date +%Y%m%d)/
```

## 📁 ARQUIVOS IMPORTANTES

```
/docs/IMMEDIATE-ACTION-GUIDE.md        ← Guia completo
/scripts/diagnostics/emergency-one-liners.sh  ← Todos os comandos
/docs/DEPLOYMENT-READY-SUMMARY.md      ← Sumário executivo
```

## ✅ CHECKLIST

**Pré-Execução:**
- [ ] SSH funcionando (3 hosts)
- [ ] Permissões sudo OK
- [ ] Backup de configs críticas

**Durante (08:45-09:00):**
- [ ] Cron audit executado
- [ ] Backups identificados
- [ ] Monitoramento iniciado 08:55

**Janela (09:00-10:00):**
- [ ] MySQL PROCESSLIST monitorado
- [ ] Snapshots capturados
- [ ] Hora exata registrada

**Pós (10:00+):**
- [ ] Evidências coletadas
- [ ] Monitores parados
- [ ] Hipótese confirmada
- [ ] Correção aplicada

## 🎯 SUCESSO = ZERO TIMEOUTS AMANHÃ!

**Hive Mind Collective Intelligence** | 2025-10-22 08:41
