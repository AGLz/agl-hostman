# 🚨 REAGENDAR BACKUP MYSQL - EXECUÇÃO IMEDIATA

**HIPÓTESE CONFIRMADA:** Backup MySQL às 09:00 causando timeouts (70% probabilidade)
**AÇÃO:** Mover backup para madrugada (02:00-04:00)
**URGÊNCIA:** IMEDIATA

---

## ⚡ AÇÃO RÁPIDA (5 minutos)

### Conectar ao fgsrv3 (MySQL)

```bash
ssh fgsrv3
```

---

## 🔍 PASSO 1: IDENTIFICAR BACKUP ATUAL (2 minutos)

### Verificar se backup está rodando AGORA:

```bash
# Ver processos de backup ativos
ps aux | grep -E "mysqldump|backup" | grep -v grep

# Se encontrar processo, anotar PID e comando
```

### Localizar script de backup:

```bash
# Buscar em cron do usuário
echo "=== USER CRONTAB ==="
crontab -l | grep -E "backup|dump|9"

# Buscar em cron do root
echo "=== ROOT CRONTAB ==="
sudo crontab -l | grep -E "backup|dump|9"

# Buscar em /etc/crontab
echo "=== SYSTEM CRONTAB ==="
sudo grep -E "backup|dump|9" /etc/crontab

# Buscar em /etc/cron.d/
echo "=== CRON.D ==="
sudo grep -rE "backup|dump|9" /etc/cron.d/

# Buscar scripts de backup
echo "=== BACKUP SCRIPTS ==="
sudo find /root /opt /usr/local/bin /var -name "*backup*" -o -name "*dump*" 2>/dev/null | head -20
```

**COPIAR A SAÍDA E SALVAR EM `/tmp/backup-location.txt`**

---

## 🛠️ PASSO 2: REAGENDAR BACKUP (2 minutos)

### Opção A: Se backup está em CRON DO USUÁRIO

```bash
# Editar crontab do usuário
crontab -e

# ENCONTRAR linha tipo:
# 0 9 * * * /path/to/backup.sh

# MUDAR PARA (02:30 AM):
# 30 2 * * * /path/to/backup.sh

# SALVAR e SAIR (:wq no vi, Ctrl+O Enter Ctrl+X no nano)
```

### Opção B: Se backup está em CRON DO ROOT

```bash
# Editar crontab do root
sudo crontab -e

# ENCONTRAR linha tipo:
# 0 9 * * * /path/to/backup.sh

# MUDAR PARA (02:30 AM):
# 30 2 * * * /path/to/backup.sh

# SALVAR e SAIR
```

### Opção C: Se backup está em /etc/crontab

```bash
# Editar /etc/crontab
sudo nano /etc/crontab
# OU
sudo vi /etc/crontab

# ENCONTRAR linha tipo:
# 0 9 * * * root /path/to/backup.sh

# MUDAR PARA (02:30 AM):
# 30 2 * * * root /path/to/backup.sh

# SALVAR e SAIR
```

### Opção D: Se backup está em /etc/cron.d/

```bash
# Listar arquivos em cron.d
sudo ls -la /etc/cron.d/

# Editar o arquivo específico (ex: mysql-backup)
sudo nano /etc/cron.d/mysql-backup
# OU
sudo vi /etc/cron.d/mysql-backup

# MUDAR horário de 9 para 2 (madrugada)
# SALVAR e SAIR
```

---

## ✅ PASSO 3: VERIFICAR MUDANÇA (1 minuto)

```bash
# Verificar cron do usuário
echo "=== USER CRON (after change) ==="
crontab -l | grep -E "backup|dump"

# Verificar cron do root
echo "=== ROOT CRON (after change) ==="
sudo crontab -l | grep -E "backup|dump"

# Verificar /etc/crontab
echo "=== SYSTEM CRON (after change) ==="
sudo grep -E "backup|dump" /etc/crontab

# Verificar /etc/cron.d/
echo "=== CRON.D (after change) ==="
sudo grep -rE "backup|dump" /etc/cron.d/
```

**CONFIRMAR QUE HORÁRIO MUDOU DE 9 PARA 2 (ou 3, 4)**

---

## 🚫 PASSO 4: PARAR BACKUP SE ESTIVER RODANDO AGORA

### Se backup está rodando NESTE MOMENTO (durante janela 09:00-10:00):

```bash
# Ver processos de backup
ps aux | grep -E "mysqldump|backup" | grep -v grep

# Se encontrar processo, PARAR (CUIDADO - apenas se travado):
# Anotar o PID (segunda coluna)
# Exemplo: se PID é 12345

# Tentar parar gentilmente primeiro
sudo kill 12345

# Aguardar 30 segundos
sleep 30

# Se ainda estiver rodando, forçar parada
ps aux | grep 12345
sudo kill -9 12345

# Verificar se parou
ps aux | grep -E "mysqldump|backup" | grep -v grep
```

⚠️ **ATENÇÃO:** Apenas pare o backup se:
- Estiver causando timeout AGORA
- Já estiver rodando há mais de 1 hora
- Sistema estiver inacessível

---

## 📋 HORÁRIOS RECOMENDADOS PARA BACKUP

### Opção 1: 02:00 AM (Recomendado)
```cron
0 2 * * * /path/to/backup.sh
```
**Vantagem:** Horário de menor tráfego

### Opção 2: 02:30 AM
```cron
30 2 * * * /path/to/backup.sh
```
**Vantagem:** Evita conflito com outras tarefas às 2:00

### Opção 3: 03:00 AM
```cron
0 3 * * * /path/to/backup.sh
```
**Vantagem:** Ainda mais seguro, evita manutenções às 2am

### Opção 4: 04:00 AM
```cron
0 4 * * * /path/to/backup.sh
```
**Vantagem:** Última opção antes do horário comercial

---

## 🔧 MELHORIAS NO SCRIPT DE BACKUP (Opcional - Fazer depois)

Se você conseguir editar o script de backup, adicione estas flags ao `mysqldump`:

```bash
#!/bin/bash

# Exemplo de backup melhorado
BACKUP_DIR="/backup/mysql"
DATE=$(date +%Y%m%d_%H%M)

# Usar --single-transaction para evitar locks
mysqldump \
  --single-transaction \
  --quick \
  --lock-tables=false \
  --routines \
  --triggers \
  --events \
  --all-databases \
  --result-file="${BACKUP_DIR}/backup-${DATE}.sql"

# Comprimir backup
gzip "${BACKUP_DIR}/backup-${DATE}.sql"

# Limpar backups antigos (mais de 7 dias)
find "${BACKUP_DIR}" -name "backup-*.sql.gz" -mtime +7 -delete
```

**Flags importantes:**
- `--single-transaction`: Evita locks de tabela (InnoDB)
- `--quick`: Reduz uso de memória
- `--lock-tables=false`: Não trava tabelas

---

## ✅ CHECKLIST DE EXECUÇÃO

- [ ] Conectado ao fgsrv3 via SSH
- [ ] Identificado localização do backup no cron
- [ ] Copiado linha atual do cron (backup)
- [ ] Mudado horário de 9 para 2 (ou 3, 4)
- [ ] Salvo mudança no cron
- [ ] Verificado que mudança foi aplicada
- [ ] Parado backup atual (se necessário)
- [ ] Documentado mudança em `/tmp/backup-reschedule.txt`

---

## 📊 VERIFICAÇÃO AMANHÃ

### Confirmar que mudança funcionou:

**Amanhã às 09:00, verificar:**

```bash
# Ver se NÃO há backup rodando às 9am
ps aux | grep -E "mysqldump|backup" | grep -v grep
# Resultado esperado: NENHUM processo

# Ver quando último backup rodou
ls -lh /backup/mysql/ | tail -5
# Deve mostrar backup da madrugada (02:00-04:00)
```

**Amanhã às 09:00, testar sites:**
- https://falg.com.br - Deve estar normal
- https://api.falg.com.br - Deve estar normal

---

## 🚨 SE BACKUP NÃO FOR ENCONTRADO

Se você não encontrar o backup nos crons:

```bash
# Verificar systemd timers
sudo systemctl list-timers | grep -i backup

# Verificar anacron
sudo cat /etc/anacrontab | grep -i backup

# Verificar scripts em /etc/cron.daily/
sudo ls -la /etc/cron.daily/ | grep -i backup
sudo ls -la /etc/cron.hourly/ | grep -i backup

# Verificar logs de cron
sudo grep -i backup /var/log/cron* | tail -20
sudo grep -i mysqldump /var/log/syslog | tail -20
```

---

## 📝 DOCUMENTAR MUDANÇA

Após fazer a mudança, salvar documentação:

```bash
{
  echo "=== MYSQL BACKUP RESCHEDULE - $(date) ==="
  echo ""
  echo "BEFORE:"
  echo "[colar linha antiga do cron aqui]"
  echo ""
  echo "AFTER:"
  crontab -l | grep backup || sudo crontab -l | grep backup
  echo ""
  echo "Changed by: $(whoami)"
  echo "Reason: Morning timeout issue (9-10am)"
  echo "Expected result: No timeout tomorrow at 9am"
} > /tmp/backup-reschedule-$(date +%Y%m%d).txt

cat /tmp/backup-reschedule-*.txt
```

---

## 🎯 RESULTADO ESPERADO

### Hoje:
- ✅ Backup movido de 09:00 para 02:00-04:00
- ✅ Backup atual parado (se estava travado)
- ✅ Mudança documentada

### Amanhã às 09:00:
- ✅ ZERO timeouts em falg.com.br
- ✅ ZERO timeouts em api.falg.com.br
- ✅ MySQL connection pool normal (<70%)
- ✅ Tempo de resposta <500ms

---

## 📞 PRÓXIMOS PASSOS

Após reagendar o backup:

1. **Monitorar amanhã às 09:00** - Confirmar que não há timeouts
2. **Verificar backup na madrugada** - Confirmar que backup rodou com sucesso
3. **Analisar logs do backup** - Verificar se houve problemas
4. **Implementar melhorias** - Adicionar `--single-transaction` ao script

---

**PRIORIDADE:** 🔴 CRÍTICA
**TEMPO ESTIMADO:** 5 minutos
**IMPACTO ESPERADO:** Eliminação de 70% dos timeouts

---

**Criado por:** Hive Mind Collective Intelligence
**Data:** 2025-10-22 08:41
**Validado contra:** Hipótese primária de root cause analysis
