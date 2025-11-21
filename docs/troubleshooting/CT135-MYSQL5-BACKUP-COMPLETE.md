# CT135 (mysql5) - COMPLETE Backup Configuration

**Data**: 2025-11-17 (Atualizado)
**CT**: 135 (mysql5 - TurnKey Linux MariaDB)
**Host**: aglsrv5 (Proxmox VE)
**Status**: ✅ **BACKUP COMPLETO CONFIGURADO - TODOS OS 6 DATABASES**

---

## 📋 Sumário Executivo

### ✅ **BACKUP COMPLETO IMPLEMENTADO**

Todos os databases do servidor **fgsrv3 (191.252.201.205)** estão agora protegidos com backup automático diário:

| Database | Tamanho | Backup (Comprimido) | Tabelas | Status |
|----------|---------|---------------------|---------|--------|
| **Bkp_falg** | 430 MB | 44 MB | 129 | ✅ Ativo |
| **falgimoveis11** | 420 MB | 44 MB | 129 | ✅ Ativo |
| **eed001** | 363 MB | 36 MB | 129 | ✅ Ativo |
| **portalville1** | 194 MB | 21 MB | 131 | ✅ Ativo |
| **api9_dev** | 50 MB | 865 KB | 183 | ✅ Ativo |
| **fgdev** | 15 MB | 110 KB | 152 | ✅ Ativo |

**Total**: 1.472 GB → 145 MB comprimido (~90% compressão)

---

## 🎯 Configuração Atual

### Arquivos de Configuração

#### `/root/.mysql-fgsrv3.cnf`
Credenciais para conexão com fgsrv3:
```ini
[client]
host=191.252.201.205
user=root
password=power@123
```
**Permissões**: 600 (rw-------)

#### `/root/backup-fgsrv3-all.sh` (NOVO)
Script completo de backup de todos os databases:
```bash
#!/bin/bash
# Complete MySQL backup of ALL databases from fgsrv3
# Scheduled at 02:00 to avoid Proxmox vzdump (04:00-04:06)
# Created: 2025-11-17 | Version: 2.0 (Complete Backup)

BACKUP_DIR="/backup/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/backup-fgsrv3.log"
MYSQL_CNF="/root/.mysql-fgsrv3.cnf"
ERROR_COUNT=0

# Databases to backup (excluding system databases)
DATABASES="Bkp_falg falgimoveis11 eed001 portalville1 api9_dev fgdev"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Check if credentials file exists
if [ ! -f "${MYSQL_CNF}" ]; then
    echo "$(date): ERROR - Credentials file not found: ${MYSQL_CNF}" >> "${LOG_FILE}"
    exit 1
fi

# Start backup process
echo "$(date): ========================================" >> "${LOG_FILE}"
echo "$(date): Starting COMPLETE backup of fgsrv3 databases" >> "${LOG_FILE}"
echo "$(date): Databases: ${DATABASES}" >> "${LOG_FILE}"
echo "$(date): ========================================" >> "${LOG_FILE}"

# Backup each database
for DB in ${DATABASES}; do
    BACKUP_FILE="${BACKUP_DIR}/fgsrv3-${DB}-${DATE}.sql.gz"
    TEMP_SQL="${BACKUP_DIR}/temp-${DB}-${DATE}.sql"

    echo "$(date): [${DB}] Starting backup to ${BACKUP_FILE}" >> "${LOG_FILE}"

    # Dump to temp file first (so we can check exit code)
    mysqldump --defaults-extra-file="${MYSQL_CNF}" \
              --single-transaction \
              --quick \
              --lock-tables=false \
              --routines \
              --triggers \
              --events \
              "${DB}" 2>> "${LOG_FILE}" > "${TEMP_SQL}"

    DUMP_STATUS=$?

    # Check if dump was successful
    if [ $DUMP_STATUS -eq 0 ]; then
        # Compress the dump
        gzip < "${TEMP_SQL}" > "${BACKUP_FILE}"
        GZIP_STATUS=$?

        # Remove temp file
        rm -f "${TEMP_SQL}"

        if [ $GZIP_STATUS -eq 0 ]; then
            SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
            echo "$(date): [${DB}] Backup successful - ${BACKUP_FILE} (size: ${SIZE})" >> "${LOG_FILE}"
        else
            echo "$(date): [${DB}] ERROR - Compression FAILED" >> "${LOG_FILE}"
            rm -f "${BACKUP_FILE}"
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
    else
        echo "$(date): [${DB}] ERROR - Backup FAILED (exit code: $DUMP_STATUS)" >> "${LOG_FILE}"
        rm -f "${TEMP_SQL}"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
done

# Clean old backups (keep last 7 days for each database)
echo "$(date): Cleaning old backups (keeping last 7 days)..." >> "${LOG_FILE}"
for DB in ${DATABASES}; do
    DELETED=$(find "${BACKUP_DIR}" -name "fgsrv3-${DB}-*.sql.gz" -mtime +7 -delete -print | wc -l)
    if [ $DELETED -gt 0 ]; then
        echo "$(date): [${DB}] Removed ${DELETED} old backup(s)" >> "${LOG_FILE}"
    fi
done

# Summary
echo "$(date): ========================================" >> "${LOG_FILE}"
if [ $ERROR_COUNT -eq 0 ]; then
    echo "$(date): COMPLETE backup finished successfully - All databases OK" >> "${LOG_FILE}"
    echo "$(date): ========================================" >> "${LOG_FILE}"
    exit 0
else
    echo "$(date): COMPLETE backup finished with ${ERROR_COUNT} ERROR(S)" >> "${LOG_FILE}"
    echo "$(date): ========================================" >> "${LOG_FILE}"
    exit 1
fi
```

**Permissões**: 755 (rwxr-xr-x)

**Funcionalidades**:
- ✅ Backup de 6 databases em arquivos separados
- ✅ Compressão automática com gzip
- ✅ Logs detalhados por database
- ✅ Contagem de erros e relatório final
- ✅ Rotação independente para cada database (7 dias)
- ✅ Include routines, triggers e events

### Crontab Configuration

**Agendamento**: Diário às 02:00 (2 AM)

```cron
# Backup COMPLETO diário de todos os databases do fgsrv3
# Executado às 02:00 (evita conflito com vzdump do Proxmox às 04:00-04:06)
0 2 * * * /root/backup-fgsrv3-all.sh >/dev/null 2>&1
```

**Motivo do horário**: Evita conflito com backup do Proxmox (vzdump) que roda entre 04:00-04:06.

---

## 📊 Validação de Integridade

### Teste Executado em 2025-11-17 23:41 UTC

| Database | Arquivo | Tamanho | Gzip OK? | Tabelas |
|----------|---------|---------|----------|---------|
| Bkp_falg | fgsrv3-Bkp_falg-20251118_004114.sql.gz | 44M | ✅ OK | 129 |
| falgimoveis11 | fgsrv3-falgimoveis11-20251118_004114.sql.gz | 44M | ✅ OK | 129 |
| eed001 | fgsrv3-eed001-20251118_004114.sql.gz | 36M | ✅ OK | 129 |
| portalville1 | fgsrv3-portalville1-20251118_004114.sql.gz | 21M | ✅ OK | 131 |
| api9_dev | fgsrv3-api9_dev-20251118_004114.sql.gz | 865K | ✅ OK | 183 |
| fgdev | fgsrv3-fgdev-20251118_004114.sql.gz | 110K | ✅ OK | 152 |

**Resultado**: ✅ **TODOS OS 6 BACKUPS VALIDADOS COM SUCESSO**

---

## 📈 Estatísticas de Performance

### Tempo de Execução por Database

| Database | Tempo Médio | Observações |
|----------|-------------|-------------|
| Bkp_falg | ~60s | Maior database (430 MB) |
| falgimoveis11 | ~60s | Segundo maior (420 MB) |
| eed001 | ~60s | Terceiro maior (363 MB) |
| portalville1 | ~60s | 194 MB |
| api9_dev | ~30s | 50 MB |
| fgdev | ~10s | Menor database (15 MB) |

**Total**: ~4-5 minutos por execução completa

### Taxa de Compressão

```
Dados originais: 1.472 GB
Backup comprimido: 145 MB
Taxa de compressão: ~90%
```

### Espaço em Disco

```
Por dia: 145 MB
Por semana (7 dias): ~1 GB
Rotação automática: Mantém últimos 7 dias
```

---

## 🔧 Manutenção e Troubleshooting

### Verificar Status de Todos os Backups

```bash
# Ver últimos backups de TODOS os databases
ssh root@aglsrv5 'pct exec 135 -- bash -c "
  for db in Bkp_falg falgimoveis11 eed001 portalville1 api9_dev fgdev; do
    echo \"Database: \$db\"
    ls -lh /backup/mysql/fgsrv3-\${db}-*.sql.gz | tail -1
    echo
  done
"'

# Ver log completo
ssh root@aglsrv5 'pct exec 135 -- tail -50 /var/log/backup-fgsrv3.log'

# Testar backup manualmente
ssh root@aglsrv5 'pct exec 135 -- bash /root/backup-fgsrv3-all.sh'
```

### Restaurar um Database

```bash
# Listar backups disponíveis para um database específico
ssh root@aglsrv5 'pct exec 135 -- ls -lht /backup/mysql/fgsrv3-Bkp_falg-*.sql.gz'

# Restaurar (substitua DATABASE e TIMESTAMP)
ssh root@aglsrv5 'pct exec 135 -- bash -c "
  zcat /backup/mysql/fgsrv3-DATABASE-YYYYMMDD_HHMMSS.sql.gz | \
  mysql --defaults-extra-file=/root/.mysql-fgsrv3.cnf DATABASE
"'
```

### Validar Integridade de Todos os Backups

```bash
ssh root@aglsrv5 'pct exec 135 -- bash -c "
  for db in Bkp_falg falgimoveis11 eed001 portalville1 api9_dev fgdev; do
    LATEST=\$(ls -t /backup/mysql/fgsrv3-\${db}-*.sql.gz 2>/dev/null | head -1)
    if [ -n \"\$LATEST\" ]; then
      echo \"Database: \$db\"
      echo -n \"  Integridade: \"
      gzip -t \"\$LATEST\" 2>&1 && echo \"✅ OK\" || echo \"❌ ERRO\"
      echo -n \"  Tabelas: \"
      zcat \"\$LATEST\" | grep -c \"^CREATE TABLE\" 2>/dev/null
      echo
    fi
  done
"'
```

### Alterar Databases no Backup

Editar `/root/backup-fgsrv3-all.sh` e modificar a linha:
```bash
# Adicionar ou remover databases desta lista:
DATABASES="Bkp_falg falgimoveis11 eed001 portalville1 api9_dev fgdev novo_db"
```

### Alterar Retenção de Backups

Editar `/root/backup-fgsrv3-all.sh` e modificar:
```bash
# De: -mtime +7 (7 dias)
# Para: -mtime +14 (14 dias)
find "${BACKUP_DIR}" -name "fgsrv3-${DB}-*.sql.gz" -mtime +14 -delete
```

---

## 🔒 Segurança Implementada

### Correções Aplicadas

1. **Permissões dos arquivos .cnf**: 777 → 644 ✅
2. **Arquivo de credenciais**: 600 (apenas root) ✅
3. **Senha root MariaDB**: Resetada para `Mysql@CT135#2024` ✅
4. **Hardening MySQL**: Performance config aplicado ✅

### Performance Configuration

`/etc/mysql/mariadb.conf.d/99-custom-performance.cnf`:
```ini
[mysqld]
innodb_buffer_pool_size = 512M
query_cache_size = 32M
max_connections = 50
slow_query_log = 1
skip-name-resolve
local-infile = 0
```

---

## 📊 Comparação: Antes vs Depois

| Métrica | Antes (12/Nov) | Depois (17/Nov) |
|---------|----------------|-----------------|
| **Databases com backup** | 1 | 6 |
| **Dados protegidos** | 430 MB (29%) | 1.472 GB (100%) |
| **Dados em risco** | 1.042 GB (71%) | 0 GB (0%) |
| **Espaço backup/dia** | 44 MB | 145 MB |
| **Tempo execução** | 1 min | 4-5 min |
| **Taxa sucesso** | 100% | 100% |

---

## 📝 Histórico de Mudanças

### 2025-11-17 - Versão 2.0 (COMPLETE Backup)
- ✅ Adicionados 5 novos databases ao backup
- ✅ Script reescrito para backup múltiplo
- ✅ Logs detalhados por database
- ✅ Rotação independente por database
- ✅ Validação completa de integridade
- ✅ 100% dos dados do fgsrv3 protegidos

### 2025-11-12 - Versão 1.0 (Single Database)
- ✅ Backup inicial apenas de Bkp_falg
- ✅ Correção de segurança (permissões 777)
- ✅ Reset de senha root
- ✅ Performance config aplicado

---

## 🎯 Próximos Passos Recomendados

### Opcional: Melhorias Futuras

1. **Backup Remoto**:
   - Copiar backups para servidor secundário
   - Implementar replicação offsite

2. **Monitoramento Ativo**:
   - Alertas se backup falhar
   - Dashboard de status

3. **Compressão Adicional**:
   - Testar xz ou bzip2 para maior compressão
   - Trade-off: tempo vs espaço

4. **Backup Incremental**:
   - Para databases grandes (>500 MB)
   - Binary logs do MySQL

---

## 📋 Checklist Final

- [x] Todos os 6 databases identificados
- [x] Script de backup completo criado
- [x] Crontab atualizado para 02:00 diário
- [x] Teste manual executado com sucesso
- [x] Integridade de todos os backups validada
- [x] Logs detalhados funcionando
- [x] Rotação automática configurada (7 dias)
- [x] Documentação completa atualizada
- [x] 100% dos dados do fgsrv3 protegidos

---

**Status Final**: ✅ **BACKUP COMPLETO IMPLEMENTADO - 100% DOS DADOS PROTEGIDOS**

**Databases**: 6/6 com backup ativo
**Horário**: 02:00 UTC (diário)
**Retenção**: 7 dias por database
**Espaço**: ~145 MB/dia, ~1 GB/semana
**Próxima Execução**: Amanhã (18/Nov) às 02:00 UTC

**Última Atualização**: 2025-11-17 23:50 UTC
**Mantido Por**: Claude Code (agl-hostman project)
