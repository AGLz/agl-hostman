# Cloudflare Tunnels - AGL Infrastructure

> **Last Updated**: 2026-06-03 | **Version**: 1.3.0
> **Reference**: Documentação completa dos túneis Cloudflare

---

## 📋 Resumo dos Túneis

| Tunnel ID | Name | Host | Location | Status | Auto-Start |
|-----------|------|------|----------|--------|------------|
| `f7ab6239-5cbd-44ef-83b9-ee8bfb4965ce` | aglsrv1 | ? | - | ✅ 4 conexões | ? |
| `f1fe0665-f7f6-4ce1-9877-b23e9e3e7853` | aglsrv2 | ? | - | ❌ Offline | ? |
| `ca4eeb4f-a40c-4c2e-8e6f-de65406d75fd` | aglsrv3 | ? | - | ❌ Offline | ? |
| `1d44ad9b-987d-474e-a50f-3b03ea7db97e` | aglsrv4 | ? | - | ❌ Offline | ? |
| `02d57187-83ba-4042-a5cc-8bb752a6b65a` | aglsrv5 | AGLSRV5 (**CT530** cloudflared5; ex.130) | gig08, gru17, gru21 | ✅ 4 conexões | ✅ systemd |
| `863fd93d-73c5-4c3e-90b5-7cbd37643f70` | **aglsrv5e** | **FGSRV6** (Docker) | gru08, gru13, gru20, gru21 | ✅ 4 conexões | ✅ Docker |
| `a00590ff-2177-48c0-ad13-3abf90b765b9` | aglsrv6 | AGLSRV6 CT101+114 | gru05, gru08, gru17 | ✅ 8 conexões (2 CTs) | ✅ systemd (token) |
| `908b1097-e182-4725-9960-626ecc003375` | archon | AGLSRV1 (CT117) | gru02, gru07, gru17 | ✅ 4 conexões | ✅ systemd |
| `513cec7b-754d-4dd8-a69d-d15942180fe4` | **fgsrv7** | **FGSRV7** (Host) | gru07, gru20, gru21 | ✅ 4 conexões | ✅ systemd |
| `850f2d28-367f-4bd2-a887-6998240828e3` | **fgsrv7b** | **FGSRV7** (**CT571** `cloudflared7b`; ex.171) | gru11, gru18, gru19, gru20 | ✅ 4 conexões | ✅ systemd (token) |

---

## 🏗️ Detalhes por Host

### FGSRV7 - fgsrv7 (systemd no CT570; ex.170)

**Tunnel ID**: `513cec7b-754d-4dd8-a69d-d15942180fe4`

**Localização**: Cloud VPS (vps64306) - 191.252.93.227

**Host FGSRV7**:

- **Proxmox**: 9.1.5 (Kernel 6.17.9-1-pve)
- **Cluster**: aglsrv5 + fgsrv7 + QDevice
- **Tailscale**: 100.109.181.93
- **Public IP**: 191.252.93.227

**Container CT570 (cloudflared7; ex.170)**:

- **VMID**: 570 (legado 170)
- **Hostname**: cloudflared7
- **Network**: vmbr70 (OVS) - 192.168.70.170/24
- **Gateway**: 192.168.70.1 (vmbr70 no host)
- **Resources**: 1 core, 1GB RAM

**Container CT571 (`cloudflared7b`; ex.171)** — segundo connector (túnel **fgsrv7b**)

- **Tunnel ID**: `850f2d28-367f-4bd2-a887-6998240828e3`
- **Network**: vmbr70 — **192.168.70.171/24**
- **Provisionamento**: clone CT570 → CT571 — `scripts/maint/fgsrv07/provision-cloudflared7b-from-170.sh` (`SOURCE_VMID=570`)

**Configuração cloudflared**:

- **CT571 / túnel `fgsrv7b`**: token Zero Trust (config remota).
- **CT570 (`cloudflared7`)**: systemd; config em `/etc/cloudflared/config.yml`

**Configuração de Rede (Host)**:

```
vmbr0  - Linux Bridge - 191.252.93.227/24 (public)
vmbr70 - OVS Bridge   - 192.168.70.1/24   (internal)
```

**NAT para containers**:

```bash
iptables -t nat -A POSTROUTING -s 192.168.70.0/24 -o vmbr0 -j MASQUERADE
```

**Ingress Rules**:

```yaml
tunnel: 513cec7b-754d-4dd8-a69d-d15942180fe4
credentials-file: /etc/cloudflared/513cec7b-754d-4dd8-a69d-d15942180fe4.json

ingress:
  - hostname: cbapp.aglz.io
    service: http://100.94.221.87:8077
  - hostname: man7.aglz.io
    service: https://192.168.70.1:8006
    originRequest:
      noTLSVerify: true
      disableChunkedEncoding: true
  - hostname: man7a.aglz.io
    service: https://192.168.70.1:8006
    originRequest:
      noTLSVerify: true
      disableChunkedEncoding: true
  # EvoNexus: SPA/API no Flask :8080; WebSocket do terminal em :32352 (path /terminal/*)
  - hostname: evo.aglz.io
    path: ^/terminal
    service: http://192.168.70.242:32352
    originRequest:
      httpHostHeader: evo.aglz.io
      connectTimeout: 120s
      noTLSVerify: true
  - hostname: evo.aglz.io
    service: http://192.168.70.242:8080
    originRequest:
      httpHostHeader: evo.aglz.io
      connectTimeout: 120s
      noTLSVerify: true
  - hostname: mysql-ha.falg.com.br
    service: tcp://192.168.70.135:3306
  - hostname: db-ha.falg.com.br
    service: tcp://192.168.70.135:3306
  - hostname: mysql-slave.falg.com.br
    service: tcp://192.168.70.135:3306
  - hostname: mysql-slave.aglz.io
    service: tcp://192.168.70.135:3306
  - service: http_status:404
```

**Endpoints**:

- cbapp.aglz.io → backend remoto (Tailscale)
- man7.aglz.io / man7a.aglz.io → Proxmox Web UI no host (`192.168.70.1:8006`)
- **evo.aglz.io** → **EvoNexus** (**CT548**; IP `192.168.70.242`): path **`/terminal*`** → `:32352`; resto → `:8080`
- mysql-ha.falg.com.br, db-ha.falg.com.br, mysql-slave.* → MySQL CT235 (`192.168.70.135:3306`)

> **Nota (2026-06):** VMIDs renumerados — master **CT561** (ex.535/235), slave **CT535** AGLSRV5 (ex.135). Ver `docs/PROXMOX-VMID-RENUMBER-2026-06.md`.

**Comandos Úteis**:

```bash
ssh root@100.109.181.93 'pct status 570'
ssh root@100.109.181.93 'pct exec 570 -- systemctl status cloudflared'
ssh root@100.109.181.93 'pct exec 570 -- journalctl -u cloudflared -f'
ssh root@100.109.181.93 'pct exec 570 -- systemctl restart cloudflared'
ssh root@100.109.181.93 'pct exec 570 -- cat /etc/cloudflared/config.yml'
```

**Troubleshooting**:

```bash
# Se container perder rede após boot
ssh root@100.109.181.93 '
  ip link set veth170i0 nomaster
  ovs-vsctl add-port vmbr70 veth170i0
  pct exec 570 -- ip addr add 192.168.70.170/24 dev eth0
  pct exec 570 -- ip route add default via 192.168.70.1
'
```

---

### FGSRV6 - aglsrv5e (Docker)

**Tunnel ID**: `863fd93d-73c5-4c3e-90b5-7cbd37643f70`

**Localização**: Cloud VPS (vps41772) - 186.202.57.120

**Configuração**:

- **Tipo**: Docker container
- **Container**: `cloudflared-tunnel`
- **Imagem**: `cloudflare/cloudflared:latest`
- **Restart Policy**: `unless-stopped` ✅
- **Network**: `host`
- **Config Path**: `/opt/docker/cloudflared/`

**Ingress Rules**:

```yaml
- hostname: n8n5e.aglz.io
  service: https://186.202.57.120:4443
  originRequest:
    disableChunkedEncoding: true
    noTLSVerify: true

- hostname: portainer5e.aglz.io
  service: https://186.202.57.120:9443
  originRequest:
    disableChunkedEncoding: true
    noTLSVerify: true
```

**Comandos Úteis**:

```bash
# Verificar status
ssh root@100.83.51.9 'docker ps --filter name=cloudflared'

# Ver logs
ssh root@100.83.51.9 'docker logs cloudflared-tunnel -f --tail 50'

# Reiniciar túnel
ssh root@100.83.51.9 'docker restart cloudflared-tunnel'

# Verificar config
ssh root@100.83.51.9 'cat /opt/docker/cloudflared/docker-compose.yml'
```

---

### AGLSRV5 (CT130) - aglsrv5 (systemd)

**Tunnel ID**: `02d57187-83ba-4042-a5cc-8bb752a6b65a`

**Localização**: AGLSRV5 - CT130 (cloudflared5)

**Configuração**:

- **Tipo**: systemd service
- **Service**: `cloudflared.service`
- **Status**: `enabled` ✅
- **Restart**: `on-failure`

**Comandos Úteis**:

```bash
# Verificar status
ssh root@100.119.223.113 'pct exec 130 -- systemctl status cloudflared'

# Ver logs
ssh root@100.119.223.113 'pct exec 130 -- journalctl -u cloudflared -f'

# Reiniciar túnel
ssh root@100.119.223.113 'pct exec 130 -- systemctl restart cloudflared'
```

---

### AGLSRV1 (CT117) - archon (systemd)

**Tunnel ID**: `908b1097-e182-4725-9960-626ecc003375`

**Localização**: AGLSRV1 - CT117 (cloudflared)

**Configuração**:

- **Tipo**: systemd service / cloudflared run
- **Config Path**: `/root/.cloudflared/config.yml`
- **Backend**: archon.aglz.io → CT183 (192.168.0.183:8080)

**Ingress Rules**:

```yaml
- hostname: archon.aglz.io
  service: http://192.168.0.183:8080
- hostname: mysql-master.aglz.io
  service: tcp://192.168.0.131:3306
- hostname: mesh.aglz.io
  service: https://192.168.0.162
  originRequest:
    noTLSVerify: true
    disableChunkedEncoding: true
- service: http_status:404
```

**Endpoints**:

- archon.aglz.io → Archon AI (CT183:8080)
- mysql-master.aglz.io → MySQL HA Master (CT131:3306)
- mesh.aglz.io → MeshCentral (CT162)

**Comandos Úteis**:

```bash
# Verificar status
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel list'

# Ver info do túnel
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel info archon'

# Ver config
ssh root@192.168.0.245 'pct exec 117 -- cat /root/.cloudflared/config.yml'
```

---

### AGLSRV6 (CT101 + CT114) - aglsrv6 (systemd, token remoto)

**Tunnel ID**: `a00590ff-2177-48c0-ad13-3abf90b765b9`

**Localização**: AGLSRV6 (man6) — CT101 `cloudflared6`, CT114 `cloudflared6b`

| CT | Hostname | Tailscale | eth0 (vmbr0) | eth1 (vmbr1) | eth2 (vmbr2) |
|----|----------|-----------|--------------|--------------|--------------|
| 101 | cloudflared6 | 100.121.95.88 | 192.168.0.101/24 | 192.168.60.101/24 | 192.168.1.101/24 |
| 114 | cloudflared6b | 100.115.195.128 | 192.168.0.114/24 | 192.168.60.114/24 | 192.168.1.114/24 |

**Configuração**:

- **Tipo**: systemd `cloudflared.service` — `Type=notify`, `After=network-online.target`
- **Modo**: token remoto (`cloudflared tunnel run --token …`) — ingress gerido na Zero Trust (sem `config.yml` local)
- **Restart**: `on-failure`, `RestartSec=5s`

**Origins Proxmox (remoto, exemplos):**

| Hostname | Origin |
|----------|--------|
| man6.aglz.io | `https://192.168.60.202:8006` |
| man6c.aglz.io | `https://192.168.1.233:8006` |
| man6d.aglz.io | `https://192.168.0.234:8006` |

> **eth2 (2026-06):** CTs em `192.168.1.0/24` via vmbr2 para alcançar man6c na LAN inter-host. Requer `agl-lan-routes` **sem** forçar `192.168.1.x` via eth0 — ver runbook abaixo.

**Comandos úteis**:

```bash
HOST=100.98.108.66   # man6 Tailscale

ssh root@$HOST 'pct exec 101 -- systemctl status cloudflared'
ssh root@$HOST 'pct exec 101 -- journalctl -u cloudflared -f'
ssh root@$HOST 'pct exec 101 -- systemctl restart cloudflared'

# Teste origin man6c a partir do CT
ssh root@$HOST 'pct exec 101 -- curl -sk -o /dev/null -w "%{http_code}\n" https://192.168.1.233:8006/'
```

**Troubleshooting (boot lento / túnel down após reboot):**

Runbook completo: [`docs/troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md`](troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md)

Causas típicas:

1. `eth3–eth5` órfãos em `/etc/network/interfaces` dentro do CT
2. `ip6=dhcp` em `net0` no Proxmox → falha `ifup eth0`
3. `agl-lan-routes` a enviar `192.168.1.233` via eth0/table 52 com eth2 activo

**Alinhamento Tailscale (cluster man6 / man6c / man6d):**

```bash
bash scripts/proxmox/pct-tailscale-align-aglsrv6.sh          # no man6
LAN_IF=vmbr0 TS_HOSTNAME=aglsrv6c bash scripts/proxmox/tailscale-align-proxmox-host.sh   # man6c
LAN_IF=enp2s0 TS_HOSTNAME=aglsrv6d bash scripts/proxmox/tailscale-align-proxmox-host.sh   # man6d
```

---

## 🔧 Configuração de Novo Túnel

### Método 1: Token (Recomendado)

1. **Obter token** via Cloudflare Zero Trust Dashboard:
   - Acesse: <https://one.dash.cloudflare.com/>
   - Networks → Tunnels → Create a tunnel
   - Escolha "Cloudflared connector"
   - Copie o token

2. **Criar container/systemd**:

   ```bash
   # Docker
   docker run -d --name cloudflared-tunnel \
     --restart unless-stopped \
     --network host \
     -e TUNNEL_TOKEN=<TOKEN> \
     cloudflare/cloudflared:latest tunnel run

   # systemd
   cloudflared service install <TOKEN>
   systemctl enable --now cloudflared
   ```

### Método 2: Credenciais

1. **Login**:

   ```bash
   cloudflared tunnel login
   ```

2. **Criar túnel**:

   ```bash
   cloudflared tunnel create <NAME>
   ```

3. **Configurar ingress** em `~/.cloudflared/config.yml`:

   ```yaml
   tunnel: <TUNNEL_ID>
   credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

   ingress:
     - hostname: exemplo.aglz.io
       service: http://localhost:8080
     - service: http_status:404
   ```

4. **Criar DNS**:

   ```bash
   cloudflared tunnel route dns <NAME> exemplo.aglz.io
   ```

5. **Iniciar**:

   ```bash
   cloudflared tunnel run <NAME>
   ```

---

## 📊 Monitoramento

### Verificar Todos os Túneis

```bash
# A partir de CT117 (tem credenciais)
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel list'
```

### Verificar Conectividade

```bash
# Testar endpoint
curl -I https://n8n5e.aglz.io
curl -I https://portainer5e.aglz.io
curl -I https://archon.aglz.io
```

### Logs em Tempo Real

```bash
# FGSRV6
ssh root@100.83.51.9 'docker logs -f cloudflared-tunnel'

# AGLSRV5 CT130
ssh root@100.119.223.113 'pct exec 130 -- journalctl -u cloudflared -f'

# AGLSRV1 CT117
ssh root@192.168.0.245 'pct exec 117 -- journalctl -u cloudflared -f'
```

---

## 🚨 Troubleshooting

### Túnel Offline

1. Verificar conectividade com Cloudflare edge:

   ```bash
   ping 198.41.192.27
   ```

2. Verificar logs:

   ```bash
   # Docker
   docker logs cloudflared-tunnel --tail 100

   # systemd
   journalctl -u cloudflared -n 100
   ```

3. Reiniciar serviço:

   ```bash
   # Docker
   docker restart cloudflared-tunnel

   # systemd
   systemctl restart cloudflared
   ```

### Erro de Token

Se o token expirar ou for inválido:

1. Obter novo token via Cloudflare Dashboard
2. Atualizar `.env` ou systemd service
3. Reiniciar serviço

### Problemas de DNS

```bash
# Verificar DNS
dig n8n5e.aglz.io

# Deve retornar CNAME para o túnel
# <TUNNEL_ID>.cfargotunnel.com
```

---

## 📚 Referências

- **Cloudflare Docs**: <https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/>
- **Zero Trust Dashboard**: <https://one.dash.cloudflare.com/>
- **INFRA.md**: `docs/INFRA.md`
- **Archon Config**: `docs/cloudflare-archon-config.md`
- **AGLSRV6 runbook (eth2 / boot / Tailscale)**: `docs/troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md`

---

**Document Version**: 1.3.0
**Last Updated**: 2026-06-03
**Maintainer**: Claude Code (agl-hostman project)
