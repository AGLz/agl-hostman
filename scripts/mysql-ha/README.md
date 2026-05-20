# MySQL HA Failover System

Automatic MySQL failover with Cloudflare Tunnel DNS integration.

> **Topologia MariaDB (2026-04, GTID):** **master = CT235 (mysql7, FGSRV7)** · **slave read_only = CT135 (mysql5, AGLSRV5)**. Detalhe operacional, reset `root`, LAN `172.2.2.x` no CT135 e migração `falgimoveis11`: **`docs/maint/MYSQL-HA-POST-RESET-2026-04.md`**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FGSRV7 (100.109.181.93 Tailscale)         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT170 (cloudflared7) - Tunnel: fgsrv7                    │    │
│  │ Tunnel ID: 513cec7b-754d-4dd8-a69d-d15942180fe4         │    │
│  │ Ingress (exemplo; confirmar config.yml actual):         │    │
│  │   mysql-slave.* / tcp → CT235:3306                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT235 (mysql7) - MASTER (replicação GTID, log_bin)      │    │
│  │ Tailscale: 100.83.7.16 · LAN: 192.168.70.135 (vmbr70)   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                    MariaDB replication (GTID)
                    slave → master (ex.: repl por Tailscale)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        AGLSRV5 (100.119.223.113 Tailscale)       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT130 (cloudflared5) - Tunnel: aglsrv5                   │    │
│  │ Ingress (exemplo; confirmar config.yml actual):         │    │
│  │   mysql-ha / mysql-master / tcp → destino actual        │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT135 (mysql5) - SLAVE (read_only=ON)                   │    │
│  │ Tailscale: 100.98.1.119                                 │    │
│  │ LAN secundária: 172.2.2.135/24 (eth1 / vmbr1)           │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## DNS Flow (Tunnel-based)

Os nomes DNS (`mysql-master`, `mysql-slave`, `mysql-ha`, …) podem manter-se como **labels** históricos; o **destino TCP** em cada `cloudflared` deve ser validado na consola Cloudflare e nos ficheiros `config.yml` dos CTs de túnel (CT130 / CT170). A matriz abaixo descreve o desenho **clássico** (antes da inversão master/slave); ver documento `docs/maint/MYSQL-HA-POST-RESET-2026-04.md` para o estado actual.

```
Static Endpoints (referência — validar):
  mysql-master.falg.com.br → túnel aglsrv5 → (destino actual do master)
  mysql-slave.falg.com.br  → túnel fgsrv7  → (destino actual; tipicamente CT235:3306)

Failover Endpoints:
  mysql-ha.falg.com.br → CNAME (switched on failover)
  db-ha.falg.com.br    → CNAME (switched on failover)
```

### `mysql-failover.sh`

O script no repositório assume **slave no FGSRV7** a monitorizar o master noutro IP. Com **CT235 como master**, rever `ROLE`, `MASTER_MYSQL_IP` e o alvo dos túneis **antes** de confiar no cron de failover — ou desactivar o cron até haver patch alinhado.

## Cloudflare Configuration

### Zone: falg.com.br (ID: 01ce76a70c797ca510bb56bf61f3a75e)

### DNS Records:
| Name | Type | ID | Content |
|------|------|-----|---------|
| mysql-ha | CNAME | c1629d07520b0d5becfddf028c88dd54 | aglsrv5 tunnel |
| db-ha | CNAME | 9a1a01ec203f16e16ed598ed8532ec44 | aglsrv5 tunnel |
| mysql-master | CNAME | c2198a41a98af99cbf9e0edf60421e2f | aglsrv5 tunnel |
| mysql-slave | CNAME | d2039a6265049f1f5490771bea26d46a | fgsrv7 tunnel |

### Tunnels:
| Name | ID | Location |
|------|-----|----------|
| aglsrv5 | 02d57187-83ba-4042-a5cc-8bb752a6b65a | CT130 (AGLSRV5) |
| fgsrv7 | 513cec7b-754d-4dd8-a69d-d15942180fe4 | CT170 (FGSRV7) |

## Failover Script

**Deploy no CT135 (slave, AGLSRV5)** — o script promove o MariaDB local e mexe nos CNAME `mysql-ha` / `db-ha`. Não deve correr no CT235 (master).

- Script: `/usr/local/bin/mysql-failover.sh`
- Config: `/etc/mysql-ha/mysql-failover.conf` (ver template `mysql-failover.conf` no repo)
- State: `/var/lib/mysql-ha/failover.state`
- Logs: `/var/log/mysql-failover.log`
- Cron (root **dentro do CT135**): `*/1 * * * * /usr/local/bin/mysql-failover.sh >> /var/log/mysql-failover.log 2>&1`

**Remover** o cron equivalente no **CT235**, se existir de uma instalação antiga.

Instalação rápida a partir do repo (no host com `pct` ao CT135, ex. AGLSRV5):

```bash
./scripts/mysql-ha/install-failover-on-ct135.sh
```

## Manual Operations

### Check Failover Status
```bash
# No host AGLSRV5 (CT135 = mysql5)
ssh root@100.119.223.113
pct exec 135 -- cat /var/lib/mysql-ha/failover.state
pct exec 135 -- tail -50 /var/log/mysql-failover.log
```

### Manual Failover Test
```bash
# Executar manualmente no CT135 (cuidado: dispara lógica real se master estiver DOWN)
pct exec 135 -- /usr/local/bin/mysql-failover.sh
```

### Reset DNS to Master
```bash
curl -X PUT \
  "https://api.cloudflare.com/client/v4/zones/01ce76a70c797ca510bb56bf61f3a75e/dns_records/c1629d07520b0d5becfddf028c88dd54" \
  -H "X-Auth-Email: carlos@aguileraz.net" \
  -H "X-Auth-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  --data '{"type":"CNAME","name":"mysql-ha","content":"02d57187-83ba-4042-a5cc-8bb752a6b65a.cfargotunnel.com","ttl":60,"proxied":false}'
```

### Replication Management

Passwords **no cofre** — não usar exemplos com credenciais em claro.

```bash
# Slave (CT135): estado de réplica
pct exec 135 -- mysql -u root -p'<password do cofre>' -e "SHOW SLAVE STATUS\G"

# Master (CT235): binlog / posição
pct exec 235 -- mysql -u root -p'<password do cofre>' -e "SHOW MASTER STATUS\G"

# Stop/start réplica (no CT135, como root MySQL)
pct exec 135 -- mysql -u root -p'<password do cofre>' -e "STOP SLAVE;"
pct exec 135 -- mysql -u root -p'<password do cofre>' -e "START SLAVE;"
```

## Network Access

- AGLSRV5: Tailscale `100.119.223.113` (Proxmox host)
- CT135 (**slave** mysql5): Tailscale `100.98.1.119`, LAN `172.2.2.135/24` (secundária)
- FGSRV7: Tailscale `100.109.181.93` (Proxmox host)
- CT235 (**master** mysql7): Tailscale `100.83.7.16`, LAN `192.168.70.135`

## Grants admin a partir da tailnet (VPS / `100.%`)

Para permitir `root` (ou password alinhada às apps) a ligar ao MySQL do CT235 a partir de IPs Tailscale e ter **`*.*` + `GRANT OPTION`** (criar bases, gerir utilizadores), executar **no FGSRV7** como root:

```bash
cd /caminho/para/agl-hostman   # ou copiar só o script
export MYSQL_ROOT_PASSWORD='...'   # password atual do root no CT235
# opcional: password que fgsrv4/fgsrv5 usam nas apps (default = a de cima)
# export MYSQL_REMOTE_PASSWORD='...'
# opcional: restringir host (default = 100.% — muito largo)
# export MYSQL_HOST_PATTERN='100.71.%'
./scripts/mysql-ha/grant-vps-tailscale-admin.sh
```

O script usa `pct exec 235` e cria/atualiza **`root`@`<MYSQL_HOST_PATTERN>`** com `ALL PRIVILEGES ON *.*` e `WITH GRANT OPTION`. **DDL** (criar bases) deve ser planeada no **master (CT235)**; o **CT135** permanece **read_only** como slave. Ver comentários no script sobre risco de `100.%` (mais amplo que a tailnet `/10`).
