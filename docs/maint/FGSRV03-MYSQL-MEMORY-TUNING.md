# FGSRV3 — MySQL (191.252.201.205) e memória do host

**Contexto:** servidor de base de dados público usado por apps FALG (`falgimoveis11`, backups, etc.). Janela anterior: binlog / disco em `TASK-INFRA-FGSRV3-2026-04` (ver `src/ai-docs/tasks/TASKS.md`).

## 1. Reinício (validação de config) — **executar tu no host**

Não há reinício remoto a partir do repositório. No **FGSRV3** (SSH):

```bash
# Só o motor (recomendado após alterar my.cnf)
sudo systemctl restart mysql
# em muitas instalações:
# sudo systemctl restart mariadb

# Estado
systemctl is-active mysql mariadb 2>/dev/null
mysql -e "SELECT VERSION(); SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; SHOW VARIABLES LIKE 'max_connections';"
```

Reinício completo do VPS (só se precisares de kernel/limite `vm.*`):

```bash
sudo reboot
```

## 2. Orçamento de RAM (regra prática)

Objetivo: **`mysqld`** não exceder RAM física (evitar thrash de swap e OOM).

### 2.1 Estado aplicado — FGSRV3 (2026-04-28)

**Host:** `vps14419` (SSH `Host FGSRV03` / IP `191.252.201.205`, key `~/.ssh/FGSRV03.pem`). Percona Server **5.7**; único serviço relevante no VPS.

| Medida | Valor |
|--------|--------|
| RAM total (`free -b`) | ~2 025 730 048 bytes (~1,89 GiB) |
| **`innodb_buffer_pool_size`** | **1738 M** (~90 % da RAM física) |
| **`innodb_buffer_pool_instances`** | **2** |

Configuração efectiva: `/etc/mysql/percona-server.conf.d/mysqld.cnf` (com comentário de referência ao doc). Após `systemctl restart mysql`, o log deve mostrar algo como «Initializing buffer pool, total size = 1.75G, instances = 2».

**Nota:** usar ~90 % da RAM no buffer pool é aceitável quando MySQL é **quase** exclusivo; convém monitorizar swap e OOM. Se noutro VPS houver Nginx/PHP no mesmo host, não replicar esta percentagem (voltar à tabela geral abaixo).

| Componente | Orientação |
|--------------|------------|
| **`innodb_buffer_pool_size`** | Se o host for **só / quase só MySQL**, típico **50–70 %** da RAM do sistema. Se houver outros serviços pesados no mesmo VPS, reduzir para **40–55 %**. Nunca “reservar zero” para SO: deixar **≥1–2 GiB** + margem para buffers de ligação e picos. |
| **`max_connections`** | Cada ligação pode usar buffers (`sort_buffer_size`, `join_buffer_size`, …). Quanto **maior `max_connections`**, mais tens de **subir buffers acumulados possíveis** ou **baixar `max_connections`**. Começar conservador (ex. **150–300**) e monitorizar `Threads_connected`. |
| **Binlog** | Já tratado em parte (rotação/size); manter `expire_logs_days` / tamanho compatíveis com disco. |

**Fórmula grosseira:**
`RAM_mysql ≈ innodb_buffer_pool + (max_connections × custo_por_conn)` — o “custo por conn” depende da versão e dos `*_buffer_size`; por isso após subir `innodb_buffer_pool_size` **ver** `free -h`, `htop` e `SHOW GLOBAL STATUS` sob carga.

## 3. Ficheiros no repositório

| Ficheiro | Uso |
|----------|-----|
| `scripts/maint/templates/mysql-fgsrv03-mysqld-snippet.cnf` | Fragmento **`[mysqld]`** com placeholders — **fundir** no `my.cnf` / `mysql.conf.d/*.cnf` real do servidor após **`free -h`** e backup. |

**Slow query:** alinhar com **`docs/MYSQL-SLOW-QUERY-LOGGING.md`** (activo quando fores perfilar fg_antigo/API).

## 4. Checklist após aplicar valores

```bash
free -h
mysql -e "SHOW VARIABLES WHERE Variable_name IN (
  'innodb_buffer_pool_size','max_connections','innodb_buffer_pool_instances',
  'tmp_table_size','max_heap_table_size','table_open_cache'
);"

# Sob carga (horário utilizador): Threads_running, InnoDB métricas
mysql -e "SHOW GLOBAL STATUS LIKE 'Threads_%'; SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_%';"
```

**Última actualização:** 2026-04-28
