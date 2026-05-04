Reset feito nos dois CTs com mariadbd --skip-grant-tables --skip-networking (paragem breve do serviço). O root por socket não funcionava nos dois (MariaDB 10.11).

Novas senhas root@localhost (guarda já no cofre / gestor de passwords)
Nó	Onde ligar (Workbench / cliente)	Palavra-passe root
CT235 (mysql7, FGSRV07)
LAN 192.168.70.135 ou Tailscale 100.83.7.16, porta 3306
19d4ce288f382920734edb4f955d7f82
CT135 (mysql5, AGLSRV5)
Tailscale **100.98.1.119**, porta **3306**; **LAN `172.2.2.135/24`** em **eth1** (`vmbr1`, gw **172.2.2.254**); **mariadbd** escuta **`0.0.0.0:3306`** (validado 2026-04-29 em AGLSRV5 — tráfego LAN para **172.2.2.135:3306** OK).
95b4d5faa65c198b635fb9d96f54f1a4
Validação: em ambos correu SELECT 'reset_ok' com login por -p após arranque normal do mariadb.

Notas rápidas
Firewall / ACL Tailscale: garante que o teu desktop pode aceder a 100.83.7.16 e 100.98.1.119 na porta 3306 (política Tailscale no admin).
Réplicação HA: se existia utilizador repl ou CHANGE MASTER, pode ser preciso recriar/realinhar credenciais — isto só mexeu em root@localhost.
Segurança: estas strings ficaram neste chat; se o canal não for totalmente privado, convém voltar a definir senhas fortes com ALTER USER dentro de cada CT depois de testares no Workbench.
No Workbench: nova conexão → hostname = IP Tailscale acima → utilizador root → colar a senha → Store in Keychain (macOS) ou equivalente.

## Replicação MariaDB (GTID) — configurado 2026-04-28

| Papel | CT | Escuta (Tailscale / LAN) |
|-------|-----|---------------------------|
| **Master** | CT235 (`mysql7`) | **100.83.7.16** · LAN **192.168.70.135** · `server_id` **235** · `log_bin=ON` |
| **Slave (read_only)** | CT135 (`mysql5`) | **100.98.1.119** · LAN **`172.2.2.135`** (`172.2.2.0/24`) · `server_id` **135** |

- Utilizador replicação: **`repl`@`100.98.1.119`** (só o slave CT135 liga ao master por Tailscale).
- Palavra-passe `repl`: **479119178d2f862e51528d9bce0577a7**
- Ficheiros em cada CT: `/etc/mysql/mariadb.conf.d/50-ha-replication.cnf`; no CT235 foi corrigido também `60-replication.cnf` (antes `server-id=2` + `read_only=ON` — papel slave antigo).
- Estado verificado: `Slave_IO_Running` / `Slave_SQL_Running` = Yes; `Seconds_Behind_Master` = 0; teste `__repl_probe` escrita no master e leitura no slave OK.

**Nota:** o alinhamento GTID no slave (`gtid_slave_pos` = posição do master) assume bases já equivalentes; se no futuro houver divergência de dados, repetir `mysqldump` coordenado ou clone inicial.

### Escuta LAN **172.2.2.x** no CT135 (mysql5)

Objectivo: clientes na rede **172.2.2.0/24** (ex.: estações em `vmbr1` no **AGLSRV5**, ver `docs/TOPOLOGY.md`) acederem ao MariaDB/MySQL na porta **3306** além do Tailscale.

1. **Proxmox (AGLSRV5)** — segundo interface no CT135, por exemplo (ajustar IP livre e gateway da rede 172.2.2.x):
   - `pct set 135 -net1 name=eth1,bridge=vmbr1,ip=172.2.2.<IP>/24,gw=172.2.2.1` (confirmar `gw` e máscara com a rede real).
   - Reiniciar o CT se o `pct` pedir.
2. **MariaDB** — ficheiro em `/etc/mysql/mariadb.conf.d/` (ex.: `50-bind-address.cnf`):
   - Incluir o novo IP **`172.2.2.<IP>`** na política de escuta (conforme a vossa versão: um `bind-address` por ficheiro incluído, **ou** sintaxe suportada para múltiplos sockets; evitar `0.0.0.0` salvo com **firewall** estrito em `3306`).
   - `systemctl restart mariadb` (ou `mysql`) após validar `mariadb --validate-config`.
3. **Privilégios** — `GRANT … TO 'utilizador'@'172.2.2.%' IDENTIFIED BY '…';` + `FLUSH PRIVILEGES;` para contas que devam aceder só pela LAN secundária.
4. **Firewall** no CT e no host — permitir **3306/tcp** desde `172.2.2.0/24` (e manter réplica **repl** apenas desde o IP Tailscale do slave → master, conforme política actual).
5. **Validação:** `ss -lntp | grep 3306` dentro do CT135; `mysql -h 172.2.2.<IP> -u … -p -e "SELECT 1"` a partir de um cliente na mesma VLAN.

## Migração BD `fg_antigo` → mysql7 (2026-04)

| Item | Detalhe |
|------|---------|
| Origem | MySQL público FGSRV03 / legado **`191.252.201.205:3306`** (`falgimoveis11`; credenciais históricas em `arcabouco/constantes.php`). |
| Destino | **CT235 (`mysql7`)** — LAN **`192.168.70.135:3306`** (Tailscale **`100.83.7.16`**). |
| Import | Dump remoto → MariaDB 10.11 no CT235 (**129 tabelas**); utilizador **`root`@`192.168.70.%`** criado para clientes na LAN `192.168.70.0/24`. |
| Réplica | CT135 realinhada com **`repl`**; GTID master verificado **`0-235-1006`** após operações de conta LAN. |
| App legacy | **CT243 (`fg-legacy`)** — **`www5.falg.com.br`**: HTTP na origem **`192.168.70.243:80`** (Nginx); acesso público via tunnel Cloudflare (**CT170**) conforme `docs/maint/FGSRV07-fg-antigo-ct-provisioning.md`. |
| Config PHP actualizada | `arcabouco/constantes.php` → `MYSQL_HOST` **`192.168.70.135`**; `system/model.php` (PDO); `BB01/db.php` (`$hostname`). |

**Nota:** SSH directo FGSRV03 pela Tailscale (`100.67.99.115`) falhou por timeout num teste de jump (2026-04); não bloqueou a migração (dump/cliente por IP público onde aplicável).