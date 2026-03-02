# MySQL HA Failover System

Automatic MySQL failover with Cloudflare Tunnel DNS integration.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AGLSRV5 (100.119.223.113 Tailscale)       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT130 (cloudflared5) - Tunnel: aglsrv5                   │    │
│  │ Tunnel ID: 02d57187-83ba-4042-a5cc-8bb752a6b65a         │    │
│  │ Ingress:                                                │    │
│  │   mysql-ha.falg.com.br → CT135:3306 (Master)           │    │
│  │   db-ha.falg.com.br → CT135:3306 (Master)              │    │
│  │   mysql-master.falg.com.br → CT135:3306                │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT135 (mysql5) - MASTER                                  │    │
│  │ Tailscale: 100.98.1.119                                 │    │
│  │ Local: 192.168.15.135                                   │    │
│  │ Role: Primary MySQL server                              │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                    MySQL Replication
                    (via Tailscale)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FGSRV7 (100.109.181.93 Tailscale)         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT170 (cloudflared7) - Tunnel: fgsrv7                    │    │
│  │ Tunnel ID: 513cec7b-754d-4dd8-a69d-d15942180fe4         │    │
│  │ Ingress:                                                │    │
│  │   mysql-slave.falg.com.br → CT235:3306 (Slave)         │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CT235 (mysql7) - SLAVE                                  │    │
│  │ Tailscale: 100.83.7.16                                  │    │
│  │ Local: 192.168.70.135 (vmbr70)                          │    │
│  │ Role: Replica + Failover Monitor                        │    │
│  │                                                          │    │
│  │ [mysql-failover.sh] ──► Monitors Master                 │    │
│  │         │                                                │    │
│  │         ▼ On failure:                                    │    │
│  │    1. Promote to Master                                  │    │
│  │    2. Update CNAME to slave tunnel                       │    │
│  │    3. Send notification                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## DNS Flow (Tunnel-based)

```
Static Endpoints:
  mysql-master.falg.com.br → aglsrv5 tunnel → CT135:3306 (Master)
  mysql-slave.falg.com.br  → fgsrv7 tunnel → CT235:3306 (Slave)

Failover Endpoints:
  mysql-ha.falg.com.br → CNAME (switched on failover)
  db-ha.falg.com.br    → CNAME (switched on failover)

Before Failover:
  mysql-ha.falg.com.br → CNAME → aglsrv5 tunnel (Master)
  db-ha.falg.com.br    → CNAME → aglsrv5 tunnel (Master)

After Failover:
  mysql-ha.falg.com.br → CNAME → fgsrv7 tunnel (Promoted Slave)
  db-ha.falg.com.br    → CNAME → fgsrv7 tunnel (Promoted Slave)
```

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

Deployed on CT235 (FGSRV7):
- Script: `/usr/local/bin/mysql-failover.sh`
- Config: `/etc/mysql-ha/mysql-failover.conf`
- State: `/var/lib/mysql-ha/failover.state`
- Logs: `/var/log/mysql-failover.log`
- Cron: Every minute (`* * * * *`)

## Manual Operations

### Check Failover Status
```bash
# On FGSRV7
ssh root@100.109.181.93
pct exec 235 -- cat /var/lib/mysql-ha/failover.state
pct exec 235 -- tail -50 /var/log/mysql-failover.log
```

### Manual Failover Test
```bash
# Run script manually
pct exec 235 -- /usr/local/bin/mysql-failover.sh
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
```bash
# Check slave status
pct exec 235 -- mysql -u root -p"power@123" -e "SHOW SLAVE STATUS\G"

# Stop/start replication
pct exec 235 -- mysql -u root -p"power@123" -e "STOP SLAVE;"
pct exec 235 -- mysql -u root -p"power@123" -e "START SLAVE;"
```

## Network Access

- AGLSRV5: Tailscale `100.119.223.113` (Proxmox host)
- CT135 (Master): Tailscale `100.98.1.119`
- FGSRV7: Tailscale `100.109.181.93` (Proxmox host)
- CT235 (Slave): Tailscale `100.83.7.16`
