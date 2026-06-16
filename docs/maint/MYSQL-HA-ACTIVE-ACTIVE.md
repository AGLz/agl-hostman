# MariaDB HA activo-activo (mysql7 ↔ mysql5)

**Estado:** aplicado em **2026-06-15** — réplicação circular GTID entre **CT561 (mysql7, FGSRV7)** e **CT535 (mysql5, AGLSRV5)**.

## Topologia

```
                    Tailscale
    mysql7 (CT561)  100.93.174.11  ◄────────────────►  100.98.1.119  mysql5 (CT535)
    server_id=235                                      server_id=135
    auto_increment_offset=1                            auto_increment_offset=2
    read_only=OFF                                      read_only=OFF
    log_slave_updates=ON                               log_slave_updates=ON
```

- **Ambos aceitam escritas** (`read_only=OFF`).
- **Réplicação nos dois sentidos** (GTID circular).
- `auto_increment_increment=2` + offsets diferentes reduzem colisões de `AUTO_INCREMENT` (IDs ímpares no mysql7, pares no mysql5).

## Endpoints

| Nó     | CT  | Tailscale     | LAN            |
| ------ | --- | ------------- | -------------- |
| mysql7 | 561 | 100.93.174.11 | 192.168.70.235 |
| mysql5 | 535 | 100.98.1.119  | 172.2.2.135    |

Partner (ngrok): continua a apontar para **mysql7** (`1.tcp.sa.ngrok.io:22485`). Escritas no mysql5: LAN `172.2.2.135` ou Tailscale `100.98.1.119`.

## Riscos (ler antes de usar em produção)

1. **Conflitos de dados** — se duas apps alterarem a **mesma linha** nos dois nós, há divergência; GTID não resolve merge automático.
2. **DDL em paralelo** — `CREATE`/`ALTER` nos dois lados ao mesmo tempo pode partir a réplica; preferir DDL num nó só.
3. **Contas `mysql.*`** — utilizadores/grants **não** replicam de forma fiável; aplicar nos dois CTs ou só no nó onde se gere admin.
4. **Failover DNS** (`mysql-failover.sh`) — **desactivado** em modo activo-activo; não promover slave automaticamente.

## Operação

### Estado

```bash
# No FGSRV7 (mysql7)
pct exec 561 -- mysql -uroot -p -e "SHOW SLAVE STATUS\G" | grep -E "Running|Behind|Master_Host|Last_.*Error"
pct exec 561 -- mysql -uroot -p -e "SELECT @@gtid_current_pos, @@read_only;"

# No AGLSRV5 (mysql5)
pct exec 535 -- mysql -uroot -p -e "SHOW SLAVE STATUS\G" | grep -E "Running|Behind|Master_Host|Last_.*Error"
```

### Reaplicar / recuperar (script no repo)

```bash
export MYSQL7_ROOT_PASSWORD='...'
export MYSQL5_ROOT_PASSWORD='...'
export MYSQL_REPL_PASSWORD='...'
bash scripts/mysql-ha/setup-active-active-gtid.sh status
# Se divergência GTID: janela de manutenção
bash scripts/mysql-ha/setup-active-active-gtid.sh resync-mysql5-from-mysql7
bash scripts/mysql-ha/setup-active-active-gtid.sh apply
```

### Disco mysql5 (AGLSRV5)

O CT535 usa pool ZFS `base`. Snapshots automáticos podem encher o dataset — monitorizar `df` e `zfs list base/subvol-535-disk-0`. Réplica parada com `Waiting for someone to free space` = **disco cheio**.

## Ficheiros de config (em cada CT)

- `/etc/mysql/mariadb.conf.d/50-ha-replication.cnf` — legado (binlog, server_id)
- `/etc/mysql/mariadb.conf.d/51-active-active-node.cnf` — `read_only=OFF`, `log_slave_updates`, `auto_increment_*`

## Histórico

- **2026-04:** master/slave unidireccional (mysql7 → mysql5, `read_only=ON`).
- **2026-06-15:** activo-activo; resync mysql5 após disco cheio + GTID divergente; teste `__ha_probe` OK nos dois sentidos.
