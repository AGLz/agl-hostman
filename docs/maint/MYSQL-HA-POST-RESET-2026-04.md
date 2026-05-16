# MariaDB HA — reset root, nova topologia GTID e migração (2026-04)

> **Segredos:** palavras-passe `root`, utilizador `repl` e chaves API **não** devem constar neste repositório. Guardar apenas no cofre / gestor de passwords da equipa. Se alguma string sensível passou por canal não totalmente privado, **rodar `ALTER USER` de novo** após validação.

## Reset `root@localhost` (MariaDB 10.11)

Em **ambos** os CTs foi usado arranque breve com `mariadbd --skip-grant-tables --skip-networking` para repor password (root por *socket* não era fiável nesta versão).

| Nó | Cliente (Workbench / CLI) | Notas |
|----|---------------------------|--------|
| **CT235** (mysql7, FGSRV7) | LAN `192.168.70.135` ou Tailscale `100.83.7.16`, porta **3306** | Password `root` atual → **cofre** (não documentar aqui). |
| **CT135** (mysql5, AGLSRV5) | Tailscale `100.98.1.119`, porta **3306**; LAN **172.2.2.135/24** em **eth1** (vmbr1, gw **172.2.2.254**); `mariadbd` escuta `0.0.0.0:3306` (validado 2026-04-29). | Password `root` atual → **cofre**. |

Validação reportada: `SELECT 'reset_ok'` com login `-p` após arranque normal do serviço em ambos.

## Réplicação MariaDB (GTID) — topologia actual (2026-04-28)

| Papel | CT | Escuta (referência) |
|--------|-----|------------------------|
| **Master** | CT235 (mysql7) | Tailscale `100.83.7.16`, LAN `192.168.70.135`, `server_id` **235**, `log_bin=ON` |
| **Slave (read_only)** | CT135 (mysql5) | Tailscale `100.98.1.119`, LAN `172.2.2.135` (rede `172.2.2.0/24`), `server_id` **135** |

- Utilizador de réplica: **`repl`** com host conforme GRANT no master (ex. ligação do slave ao master por Tailscale); password **`repl`** → **cofre**.
- Ficheiros de config em cada CT: `/etc/mysql/mariadb.conf.d/50-ha-replication.cnf`; no CT235 foi corrigido também `60-replication.cnf` (removido papel antigo `server-id=2` + `read_only=ON` incorrecto para master actual).
- Estado verificado: `Slave_IO_Running` / `Slave_SQL_Running` = Yes; `Seconds_Behind_Master` = 0; teste de escrita no master e leitura no slave OK.

**Nota GTID:** alinhamento `gtid_slave_pos` assume bases já equivalentes; em divergência futura, planear `mysqldump` coordenado ou clone inicial.

### LAN `172.2.2.x` no CT135

Objectivo: clientes na VLAN `172.2.2.0/24` acederem ao MariaDB na porta **3306** além do Tailscale.

1. Proxmox (AGLSRV5): segunda interface no CT135 (`eth1` → `vmbr1`, IP/gw da rede real).
2. MariaDB: política de *bind* / includes em `/etc/mysql/mariadb.conf.d/`; `restart` após `mariadb --validate-config`.
3. `GRANT … TO 'utilizador'@'172.2.2.%' …;` + `FLUSH PRIVILEGES;` para contas só-LAN.
4. Firewall no CT e no host: `3306/tcp` desde `172.2.2.0/24`; manter política de réplica (`repl`) só do IP Tailscale do slave → master.
5. Validar: `ss -lntp | grep 3306` no CT135; `mysql -h 172.2.2.135 -u … -p -e "SELECT 1"` a partir de cliente na VLAN.

## Migração BD legado → mysql7 (2026-04)

| Item | Detalhe |
|------|---------|
| Origem | MySQL em FGSRV03 / legado `191.252.201.205:3306` (`falgimoveis11`; credenciais históricas em código legado — migrar para cofre). |
| Destino | **CT235** — LAN `192.168.70.135:3306`, Tailscale `100.83.7.16`. |
| Import | Dump remoto → MariaDB 10.11 no CT235 (~129 tabelas); utilizador **`root@192.168.70.%`** para clientes na LAN `192.168.70.0/24` (ajustar GRANTs conforme política). |
| Réplica | CT135 realinhada com `repl`; GTID master verificado após operações de conta LAN. |
| App legacy | **CT243** (`fg-legacy`) — `www5.falg.com.br`: HTTP origem `192.168.70.243:80` (Nginx); público via túnel Cloudflare (CT170) conforme doc de provisioning FGSRV07. |
| Config PHP actualizada | `arcabouco/constantes.php` → `MYSQL_HOST` **192.168.70.135**; `system/model.php` (PDO); `BB01/db.php` (`$hostname`). |

**Nota:** SSH directo a FGSRV03 por Tailscale (`100.67.99.115`) pode falhar por timeout em alguns caminhos; não bloqueou a migração quando o dump/cliente usava IP público aplicável.

## Firewall / Tailscale

Garantir ACLs para que postos autorizados acedam a `100.83.7.16` e `100.98.1.119` na porta **3306** conforme política no admin Tailscale.

## Script `mysql-failover.sh` (implementação no repo — 2026-04-29)

- **Onde correr:** apenas no **CT135** (slave), com `ROLE=slave` e `MASTER_MYSQL_IP=100.83.7.16`.
- **DNS após promoção:** `mysql-ha` / `db-ha` → túnel **AGLSRV5** (`CF_MASTER_TUNNEL` no template).
- **Estado “master saudável”:** `CURRENT_MASTER` usa o túnel **FGSRV7** (`CF_SLAVE_TUNNEL` no template legado), alinhado ao master CT235.
- **Operação:** instalar ficheiros no CT135 (`setup-failover.sh` ou `scp` + `pct push`), preencher `/etc/mysql-ha/mysql-failover.conf` (cofre), `chmod +x /usr/local/bin/mysql-failover.sh`, testar, cron no **CT135**; **remover** cron no **CT235** se existir.
- Detalhe: `scripts/mysql-ha/README.md` e `scripts/mysql-ha/mysql-failover.sh`.
