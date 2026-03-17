# Cloudflare Tunnels - AGL Infrastructure

> **Last Updated**: 2026-02-21 | **Version**: 1.2.0
> **Reference**: Documentação completa dos túneis Cloudflare

---

## 📋 Resumo dos Túneis

| Tunnel ID | Name | Host | Location | Status | Auto-Start |
|-----------|------|------|----------|--------|------------|
| `f7ab6239-5cbd-44ef-83b9-ee8bfb4965ce` | aglsrv1 | ? | - | ✅ 4 conexões | ? |
| `f1fe0665-f7f6-4ce1-9877-b23e9e3e7853` | aglsrv2 | ? | - | ❌ Offline | ? |
| `ca4eeb4f-a40c-4c2e-8e6f-de65406d75fd` | aglsrv3 | ? | - | ❌ Offline | ? |
| `1d44ad9b-987d-474e-a50f-3b03ea7db97e` | aglsrv4 | ? | - | ❌ Offline | ? |
| `02d57187-83ba-4042-a5cc-8bb752a6b65a` | aglsrv5 | AGLSRV5 (CT130) | gig08, gru17, gru21 | ✅ 4 conexões | ✅ systemd |
| `863fd93d-73c5-4c3e-90b5-7cbd37643f70` | **aglsrv5e** | **FGSRV6** (Docker) | gru08, gru13, gru20, gru21 | ✅ 4 conexões | ✅ Docker |
| `a00590ff-2177-48c0-ad13-3abf90b765b9` | aglsrv6 | ? | - | ✅ 8 conexões | ? |
| `908b1097-e182-4725-9960-626ecc003375` | archon | AGLSRV1 (CT117) | gru02, gru07, gru17 | ✅ 4 conexões | ✅ systemd |
| `513cec7b-754d-4dd8-a69d-d15942180fe4` | **fgsrv7** | **FGSRV7** (Host) | gru07, gru20, gru21 | ✅ 4 conexões | ✅ systemd |

---

## 🏗️ Detalhes por Host

### FGSRV7 - fgsrv7 (systemd no CT170)

**Tunnel ID**: `513cec7b-754d-4dd8-a69d-d15942180fe4`

**Localização**: Cloud VPS (vps64306) - 191.252.93.227

**Host FGSRV7**:
- **Proxmox**: 9.1.5 (Kernel 6.17.9-1-pve)
- **Cluster**: aglsrv5 + fgsrv7 + QDevice
- **Tailscale**: 100.109.181.93
- **Public IP**: 191.252.93.227

**Container CT170 (cloudflared7)**:
- **VMID**: 170
- **Hostname**: cloudflared7
- **Network**: vmbr70 (OVS) - 192.168.70.170/24
- **Gateway**: 192.168.70.1 (vmbr70 no host)
- **Resources**: 1 core, 1GB RAM
- **Storage**: bkp:vm-170-disk-0 (4GB)

**Configuração cloudflared**:
- **Tipo**: systemd service (CT170)
- **Service**: `cloudflared.service`
- **Config Path**: `/etc/cloudflared/config.yml`
- **Credentials**: `/etc/cloudflared/513cec7b-754d-4dd8-a69d-d15942180fe4.json`
- **Restart Policy**: `on-failure`

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
  - hostname: man7.aglz.io
    service: https://191.252.93.227:8006
    originRequest:
      noTLSVerify: true
      disableChunkedEncoding: true
  - hostname: man7a.aglz.io
    service: https://191.252.93.227:8006
    originRequest:
      noTLSVerify: true
      disableChunkedEncoding: true
  - service: http_status:404
```

**Endpoints**:
- man7.aglz.io → Proxmox Web UI (porta 8006)
- man7a.aglz.io → Proxmox Web UI (porta 8006)

**Comandos Úteis**:
```bash
# Verificar status do container
ssh root@100.109.181.93 'pct status 170'

# Verificar status do cloudflared
ssh root@100.109.181.93 'pct exec 170 -- systemctl status cloudflared'

# Ver logs
ssh root@100.109.181.93 'pct exec 170 -- journalctl -u cloudflared -f'

# Reiniciar túnel
ssh root@100.109.181.93 'pct exec 170 -- systemctl restart cloudflared'

# Ver config
ssh root@100.109.181.93 'pct exec 170 -- cat /etc/cloudflared/config.yml'

# Verificar tunnel connections
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel info fgsrv7'
```

**Troubleshooting**:
```bash
# Se container perder rede após boot
ssh root@100.109.181.93 '
  ip link set veth170i0 nomaster
  ovs-vsctl add-port vmbr70 veth170i0
  pct exec 170 -- ip addr add 192.168.70.170/24 dev eth0
  pct exec 170 -- ip route add default via 192.168.70.1
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

## 🔧 Configuração de Novo Túnel

### Método 1: Token (Recomendado)

1. **Obter token** via Cloudflare Zero Trust Dashboard:
   - Acesse: https://one.dash.cloudflare.com/
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

- **Cloudflare Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **Zero Trust Dashboard**: https://one.dash.cloudflare.com/
- **INFRA.md**: `docs/INFRA.md`
- **Archon Config**: `docs/cloudflare-archon-config.md`

---

**Document Version**: 1.0.0
**Last Updated**: 2026-02-20
**Maintainer**: Claude Code (agl-hostman project)
