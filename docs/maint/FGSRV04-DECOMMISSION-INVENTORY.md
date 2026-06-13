# FGSRV04 — Inventário e descomissionamento

> **Auditoria live:** 2026-06-11 (via `ssh root@100.111.79.2`)  
> **Objectivo:** documentar todos os sites e serviços no **FGSRV04** (Locaweb `vps22826`) antes do shutdown e cancelamento do VPS (~1 semana).  
> **Migração já feita:** stack PHP 5.6 legado **`www5.falg.com.br`** → **FGSRV07 / CT549** (`fg-legacy`, `192.168.70.243`).

---

## Resumo executivo

| Item | Estado documentado (repo) | Estado real (2026-06-11) |
|------|---------------------------|---------------------------|
| Tipo de host | Proxmox VE VPS (`INFRA.md`, `HOSTS.md`) | **Ubuntu 22.04.5 LTS** — **sem** `pveversion` / `pct` / `qm` |
| Provider | `vps22826.publiccloud.com.br` | Locaweb cloud VPS (hypervisor Xen — `xe-daemon` activo) |
| IP público | *(não listado em INFRA)* | **191.252.201.108** |
| Tailscale | `100.111.79.2` (`fgsrv04`) | ✅ Running |
| WireGuard | `10.6.0.16:51816` | ✅ Peer do hub FGSRV6 (`186.202.57.120:51823`) |
| Disco `/` | — | **58 GB total, 44 GB usados (81%)** |
| RAM | — | **2 GB** |
| Uptime (audit) | — | ~45 dias |

### Riscos antes de desligar tudo

| Risco | Severidade | Notas |
|-------|------------|--------|
| **`falg.com.br` / `falgimoveis.com` ainda em produção neste host** | 🔴 Crítico | Origem HTTP(S) responde em `191.252.201.108`; tráfego Cloudflare activo nos logs (Jun 2026) |
| **`www5.falg.com.br` já no CT549** | 🟢 OK | DNS CNAME → túnel Cloudflare; Nginx+PHP5.6 activos no CT549 |
| **WireGuard mesh** | 🟡 Médio | Nó `10.6.0.16` — remover peer no hub **após** validar que nenhum fluxo depende dele |
| **NFS `/var/www/fg_antigo`** | 🟢 Baixo | `showmount -a` sem clientes activos; scripts de monitor em `scripts/monitoring/nfs-*` referem CT138 (pode estar obsoleto) |
| **Certificado Let's Encrypt** | 🟡 | `falg.com.br` expira **2026-07-08** (~27 dias) — irrelevante após cutover DNS |

**Conclusão:** só é seguro **parar Nginx/PHP principal** depois de migrar o tráfego de **`falg.com.br`**, **`www.falg.com.br`**, **`falgimoveis.com`** e domínios associados para o destino final (ex. alargar CT549 ou novo vhost no FGSRV07). O **`www5`** já não depende deste host.

---

## Identidade e acesso

| Campo | Valor |
|-------|--------|
| Hostname | `vps22826.publiccloud.com.br` |
| Tailscale DNS | `fgsrv04.degu-chromatic.ts.net` |
| SSH (preferido) | `ssh root@100.111.79.2` ou `ssh fgsrv4` |
| SSH (público) | `ssh sysadmin@vps22826.publiccloud.com.br` (`~/.ssh/fg_srv.pem`) |
| Locaweb API id | `vps22826` (`scripts/locaweb-api/config.sh`) |

---

## Sites e aplicações web (Nginx + PHP)

### Produção principal — vhost `fg_old`

| Campo | Valor |
|-------|--------|
| Ficheiro | `/etc/nginx/sites-enabled/fg_old` |
| Webroot | `/var/www/fg_antigo/public_html` (~**22 GB**) |
| PHP | **5.6 FPM** (`unix:/var/run/php/php5.6-fpm.sock`) |
| TLS | Let's Encrypt `falg.com.br` (incl. `www.falg.com.br`, `falgimoveis.com`, `www.falgimoveis.com`) |
| `server_name` | `falg.com.br`, `www.falg.com.br`, `falgimoveis.com`, `www.falgimoveis.com`, `falgimoveis.com.br`, `www.falgimoveis.com.br`, `eugenioedamatto.com`, `www.eugenioedamatto.com`, `eugenioedamatto.com.br`, `www.eugenioedamatto.com.br` |
| Portas | **80** (redirect) + **443** SSL |
| Estado Jun 2026 | **Ainda serve tráfego real** (ex.: `falgimoveis.com` dominante nos access logs) |

### Staging / cópias — vhosts `fg_old2`, `fg_old3`

| Vhost | Webroot | `server_name` | TLS | Uso |
|-------|---------|---------------|-----|-----|
| `fg_old2` | `/var/www/fg_antigo2/public_html` (~2.9 GB) | `www2.falg.com.br`, `www2.falgimoveis.com`, … | Só HTTP :80 | Cópia / testes |
| `fg_old3` | `/var/www/fg_antigo3/public_html` (~2.9 GB) | `www3.falg.com.br`, `www3.falgimoveis.com`, … | Só HTTP :80 | Cópia / testes |

**Acção recomendada:** desactivar `fg_old2` / `fg_old3` já na fase 1 do shutdown (sem impacto em produção principal).

### Migrado para FGSRV07 — não depende mais do FGSRV04

| Domínio | Destino actual | Túnel / CT | Notas |
|---------|----------------|------------|--------|
| **`falg.com.br`** | CT549 `fg-legacy` @ `192.168.70.243:80` | **fgsrv7b** / **CT571** `cloudflared7b` | Ingress remoto confirmado nos logs do CT571 (2026-06-11) |
| **`www5.falg.com.br`**, **`www5.aglz.io`** | Mesmo CT549 | **fgsrv7** / **CT570** (`www5.aglz.io` no ingress remoto) | `cloudflared` em **CT dedicado** — nunca no host Proxmox |
| **`falgimoveis.com`**, **`www.falgimoveis.com`** | CT549 (origin pronto) | **fgsrv7b** / **CT571** | DNS CNAME → túnel; ingress remoto 2026-06-11 |
| **`www.falg.com.br`** | CT549 (nginx actualizado) | **fgsrv7b** / **CT571** | 200 OK via túnel (2026-06-11) |

Referência: `docs/maint/FGSRV07-fg-antigo-ct-provisioning.md`, `docs/CLOUDFLARE-TUNNELS.md` (secção fgsrv7b).

### DNS público (amostra 2026-06-11)

| Nome | Resolução | Roteamento efectivo |
|------|-----------|---------------------|
| `falg.com.br` | A → IPs Cloudflare (proxied) | Túnel **fgsrv7b** (CT571) → CT549 |
| `falgimoveis.com` | CNAME → túnel **fgsrv7b** (proxied) | Túnel **fgsrv7b** (CT571) → CT549 |
| `www5.falg.com.br` | CNAME → `513cec7b-….cfargotunnel.com` | Túnel **fgsrv7** (CT570) ou fgsrv7b conforme hostname |

---

## PHP instalado

Versões em `/etc/php/`: **5.6, 7.0–7.4, 8.0–8.2** (legado de instalações antigas).

| Serviço systemd | Estado | Uso |
|-----------------|--------|-----|
| `php5.6-fpm` | **enabled / active** | `fg_antigo` (produção + cópias) |
| `php8.2-fpm` | enabled / active | Sem vhost dedicado detectado |
| `php7.4-fpm` | masked | — |

Checkpoint histórico: `docs/maint/FGSRV04-php-runtime-fg-antigo-checkpoint.md`.

---

## Base de dados

| Serviço | Estado no FGSRV04 |
|---------|-------------------|
| MySQL / MariaDB | **inactive** (app usa MySQL remoto — **CT561 `mysql7`** no FGSRV07) |

---

## NFS

| Export | Clientes permitidos | Tamanho (audit) |
|--------|---------------------|-----------------|
| `/storage/nfs-export` | `10.6.0.0/24`, `192.168.0.0/24`, `100.0.0.0/8` | ~8 KB (quase vazio) |
| `/var/www/fg_antigo` | Idem | ~22 GB (cópia do código) |

- Portas: **2049** + rpcbind/mountd.
- **Sem mounts activos** reportados por `showmount -a` na data da auditoria.
- Monitorização legada: `scripts/monitoring/nfs-tailscale-monitor.sh` (CT138 / FileServer5).

---

## Rede e VPN

| Componente | Detalhe |
|------------|---------|
| **Tailscale** | `100.111.79.2`, serviço `tailscaled` activo |
| **WireGuard** | `wg0` @ `10.6.0.16/24`, handshake recente com hub |
| **Docker** | `docker.service` activo, **0 contentores** |
| **Cloudflared** | **inactive** (túneis CF estão no FGSRV07) |

---

## Monitorização, segurança e mail

| Serviço | Função |
|---------|--------|
| `zabbix-agent` | `:10050` → `ec2-50-16-213-7.compute-1.amazonaws.com` |
| `meshagent.service` | Agente MeshCentral / gestão remota |
| `glances` | `:61209` localhost |
| `fail2ban` | Jails: nginx-*, sshd |
| `postfix` | MTA local (cron `logwatch` → `admin@falg.com.br`) |

### Cron (root)

| Schedule | Script |
|----------|--------|
| `5 6 * * *` | `/usr/local/bin/ssl-monitor.sh` |
| `10 */2 * * *` | `/usr/local/bin/disk-monitor.sh` |
| `3,18,33,48 * * * *` | `/usr/local/bin/service-monitor.sh` |
| `7,37 * * * *` | `/usr/local/bin/performance-monitor.sh` |
| `5 * * * *` | `/usr/local/bin/log-analyzer.sh` |
| `0 6 * * *` | `logwatch` |
| `0 7 * * 0` | `/usr/local/bin/weekly-health-report.sh` |

---

## Portas em escuta (principais)

| Porta | Processo |
|-------|----------|
| 22 | sshd |
| 25 | postfix |
| 80, 443 | nginx |
| 2049 | nfs |
| 10050 | zabbix_agentd |
| 51816 | wireguard (wg0) |
| 61209 | glances (127.0.0.1) |

---

## Dependências noutros hosts (checklist migração)

Antes do cancelamento Locaweb (`vps22826`):

- [x] **Cutover DNS/Cloudflare** `falg.*`, `falgimoveis.com`, `alphavilletambore.com.br`, `portalalphavilletambore.com.br` → fgsrv7b / CT549 (2026-06-11)
- ~~`eugenioedamatto.com`~~ — **fora de âmbito** (não migrar)
- ~~`portalalphaville.com.br`~~ — typo; canonical: **`portalalphavilletambore.com.br`**
- [ ] Confirmar CT549 (ou novo host) com capacidade para domínios principais se forem consolidados
- [ ] Remover peer **FGSRV4** (`10.6.0.16`) do `wg0.conf` no **hub FGSRV6** após 48h sem tráfego
- [ ] Actualizar `docs/INFRA.md`, `docs/HOSTS.md`, `docs/TOPOLOGY.md` (FGSRV4 não é Proxmox)
- [ ] Rever scripts `scripts/monitoring/nfs-*.sh` e alertas Zabbix hostname `vps22826`
- [ ] Backup final: `/var/www/fg_antigo`, `/etc/nginx`, `/etc/letsencrypt`, `wg0.conf`
- [ ] Cancelar VPS na Locaweb (`lw fgsrv04` / API `vps22826`)

---

## Plano de shutdown (fases)

**Causa do restart (Jun 2026):** `service-monitor.sh` em cron (15 min) relançava `nginx`/`php5.6-fpm` se parados. Fase 2 renomeia scripts `*.disabled-decommission`; fase 3 usa `systemctl mask`.

**Monitorização 1 semana:** `scripts/maint/fgsrv04/fgsrv04-decommission-watch.sh --install-cron` no agldv03 (08:05 diário) → `/var/log/fgsrv04-decommission-watch.log`.

| Fase | Acções | Impacto |
|------|--------|---------|
| **1** | Desactivar `fg_old2`, `fg_old3`; parar `nfs-server` | 🟢 Só staging / NFS sem clientes |
| **2** | Parar `php8.2-fpm`, Docker, cron monitors locais | 🟢 Baixo |
| **3** | Parar `nginx` + `php5.6-fpm` | 🔴 **Derruba sites principais** — só após cutover DNS |
| **4** | Parar `tailscaled`, `wg-quick@wg0`, `zabbix-agent`, `meshagent` | 🟡 Perde acesso VPN/monitorização |
| **5** | Shutdown/reboot ou cancelamento Locaweb | 🔴 Host offline |

### Comandos rápidos (fase 1 — já aplicável)

```bash
# No FGSRV04
ssh root@100.111.79.2 'bash -s' < scripts/maint/fgsrv04/fgsrv04-stop-services.sh --phase 1
```

### Fase 3 (após cutover DNS confirmado)

```bash
ssh root@100.111.79.2 'bash -s' < scripts/maint/fgsrv04/fgsrv04-stop-services.sh --phase 3 --confirm-production
```

---

## Relacionado

- `docs/maint/FGSRV07-fg-antigo-ct-provisioning.md` — CT549 / `www5`
- `docs/maint/FGSRV04-php-runtime-fg-antigo-checkpoint.md`
- `docs/maint/FGSRV04-fg-antigo-php-optimization.md`
- `docs/maint/FGSRV6-PRE-REINSTALL-INVENTORY.md` — modelo de inventário pré-format
- `docs/SSH-CONFIG.md` — acesso `fgsrv4` / `FGSRV04`

**Última actualização:** 2026-06-11
