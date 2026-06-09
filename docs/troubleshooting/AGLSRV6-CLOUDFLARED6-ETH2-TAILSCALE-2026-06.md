# AGLSRV6 — cloudflared6/eth2 + Tailscale cluster (man6 / man6c / man6d)

> **Data**: 2026-06-03  
> **Estado**: ✅ Resolvido (boot ~2 s, túnel activo, man6c via eth2)  
> **Hosts**: AGLSRV6 (man6), AGLSRV6C (man6c), AGLSRV6D (man6d)  
> **CTs**: 101 (`cloudflared6`), 114 (`cloudflared6b`)

---

## Resumo executivo

Após adicionar **eth2** (`192.168.1.x` / **vmbr2**) nos CTs 101 e 114 e reiniciar os contentores, o **Cloudflare Tunnel deixou de subir no boot** (atraso ~5 min ou serviço parado). A causa **não** foi o eth2 em si, mas configuração de rede legada + conflito Tailscale na **table 52**.

Paralelamente, **man6c** e **man6d** tinham Tailscale desalinhado (`accept-routes` / `CorpDNS`), corrigido com os mesmos parâmetros canónicos do man6.

---

## Topologia relevante

### Host man6 (AGLSRV6)

| Interface | Bridge | IP | Função |
|-----------|--------|-----|--------|
| vmbr0 | LAN externa | 192.168.0.202/24 | Gateway default, CTs eth0 |
| vmbr1 | LAN interna | 192.168.60.202/24 | CTs eth1, serviços 60.x |
| vmbr2 | Inter-host | 192.168.1.202/24 | Cluster LAN man6 ↔ man6c ↔ CTs eth2 |
| wg0 | WireGuard | 10.6.0.12/24 | Mesh AGL |
| tailscale0 | Tailscale | 100.98.108.66 | Acesso remoto |

### CT101 / CT114 (cloudflared6 / cloudflared6b)

| NIC | Bridge | IP exemplo | Função |
|-----|--------|------------|--------|
| eth0 | vmbr0 | 192.168.0.101 / .114 | Default route, LAN 0.x |
| eth1 | vmbr1 | 192.168.60.101 / .114 | Origins 192.168.60.x |
| eth2 | vmbr2 | 192.168.1.101 / .114 | LAN inter-host 192.168.1.x |

**Proxmox** (`/etc/pve/lxc/101.conf`, `114.conf`):

```ini
net0: name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.101/24,type=veth
net1: name=eth1,bridge=vmbr1,ip=192.168.60.101/24,type=veth
net2: name=eth2,bridge=vmbr2,ip=192.168.1.101/24,type=veth
```

> **Importante:** não usar `ip6=dhcp` em `net0` — provoca falha do `ifup eth0` no boot.

### Túnel Cloudflare (aglsrv6)

| Campo | Valor |
|-------|--------|
| Tunnel ID | `a00590ff-2177-48c0-ad13-3abf90b765b9` |
| Gestão | Token remoto (`cloudflared tunnel run --token …`) — ingress na Zero Trust |
| CT101 TS | `100.121.95.88` (`aglsrv6-cloudflared6`) |
| CT114 TS | `100.115.195.128` (`aglsrv6-cloudflared6b`) |

**Origins Proxmox (ingress remoto, config version ~51):**

| Hostname | Service |
|----------|---------|
| man6.aglz.io | `https://192.168.60.202:8006` |
| man6c.aglz.io | `https://192.168.1.233:8006` |
| man6d.aglz.io | `https://192.168.0.234:8006` |
| man6b.aglz.io | `https://192.168.0.201:8006` (legado — verificar se ainda válido) |

---

## Problema 1 — cloudflared não arranca no boot (~5 min)

### Sintomas

- `systemctl is-active cloudflared` → `inactive` após reboot do CT
- `Startup finished in 5min …` no journal
- `ifupdown-wait-online.service` bloqueia `network-online.target`
- `cloudflared.service` tem `After=network-online.target`

### Causas (journal CT101)

1. **Interfaces fantasma** em `/etc/network/interfaces`: `eth3`, `eth4`, `eth5` (legado 192.168.100/200, 172.16.0) → `Cannot find device "eth3"` → `networking.service` falha.

2. **`ip6=dhcp` no `net0` Proxmox** → Proxmox reinjecta `iface eth0 inet6 dhcp` → `Could not get a link-local address` → `ifup: failed to bring up eth0`.

3. Conflito ocasional **systemd-networkd + ifupdown** no restart (`Address already assigned`) — no boot limpo, com (1) e (2) corrigidos, `networking.service` completa em ~1 s.

### Correção

```bash
# No host man6 — remover IPv6 DHCP do net0 Proxmox
sed -i 's/,ip6=dhcp//g' /etc/pve/lxc/101.conf /etc/pve/lxc/114.conf

# Dentro de cada CT — /etc/network/interfaces (apenas eth0–eth2)
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.0.101/24   # ou .114 no CT114
    gateway 192.168.0.1

auto eth1
iface eth1 inet static
    address 192.168.60.101/24

auto eth2
iface eth2 inet static
    address 192.168.1.101/24
```

**Verificação pós-reboot:**

```bash
ssh root@100.98.108.66 'pct reboot 101; sleep 30; pct exec 101 -- systemctl is-active cloudflared networking'
# Esperado: active / active, Startup finished in ~2s
```

---

## Problema 2 — man6c inacessível via eth2 (túnel UP mas origin falha)

### Sintomas

- `cloudflared` activo, mas `man6c.aglz.io` falha
- No CT101: `ip route get 192.168.1.233` → **dev eth0 table 52** (errado)
- Ping/curl para `192.168.1.233` timeout; host man6 ping OK na vmbr2

### Causa

`agl-lan-routes.service` forçava hosts `192.168.1.202` e `192.168.1.233` via **eth0** na **table 52** (Tailscale policy routing), mesmo com **eth2** ligado a `192.168.1.0/24`.

Isto era correcto **antes** do eth2; depois de eth2, o tráfego deve usar a rota kernel directa em **eth2**.

### Correção

1. Remover entradas `192.168.1.*` de `/etc/agl-lan-routes.conf` nos CTs com NIC local em 192.168.1.x.

2. Limpar rotas stale na table 52 (se necessário):

```bash
pct exec 101 -- ip route show table 52 | grep 192.168.1 | while read r; do
  pct exec 101 -- ip route del $r table 52
done
```

3. Script actualizado: `scripts/proxmox/agl-lan-routes.sh` — **ignora** IPs já alcançáveis noutra interface que não `LAN_IF`.

4. `scripts/proxmox/pct-tailscale-align-aglsrv6.sh` — **não** adiciona `192.168.1.202/233` ao conf quando o CT tem `192.168.1.x` local.

**Verificação:**

```bash
pct exec 101 -- ip route get 192.168.1.233
# Esperado: dev eth2 src 192.168.1.101

pct exec 101 -- curl -sk -o /dev/null -w '%{http_code}\n' https://192.168.1.233:8006/
# Esperado: 200
```

---

## Problema 3 — Tailscale desalinhado (man6c / man6d)

### Parâmetros canónicos AGL

| Flag | Valor | Motivo |
|------|-------|--------|
| `--accept-dns=false` | obrigatório | Não sobrescrever `resolv.conf` com MagicDNS |
| `--accept-routes=false` | obrigatório | Não injectar `192.168.0.0/24` (ou outras subnets) via `tailscale0` na table 52 |
| `--ssh` | hosts/CTs | Tailscale SSH (ACLs na consola) |

Ver também: [`CT181-DNS-ROUTING-FIX.md`](CT181-DNS-ROUTING-FIX.md)

### Estado antes / depois

| Host | TS IP | Antes | Depois |
|------|-------|-------|--------|
| man6 | 100.98.108.66 | já alinhado | `RouteAll=false`, `CorpDNS=false` |
| man6c | 100.124.53.91 | `RouteAll=true`, `CorpDNS=true`, table52: `192.168.0.0/24` + `10.6.0.0/24` via tailscale0 | `RouteAll=false`, `CorpDNS=false`, `agl-lan-routes` (`LAN_IF=vmbr0`) |
| man6d | 100.76.201.83 | `CorpDNS=true`; **anuncia** `192.168.0.0/24` (subnet router) | `CorpDNS=false`; anúncio mantido; `agl-lan-routes` (`LAN_IF=enp2s0`) |

> **man6d** continua **subnet router** de `192.168.0.0/24` para a tailnet — intencional. Só deixou de **aceitar** rotas/DNS de peers.

### Scripts de alinhamento

```bash
# man6 — host + CTs com tailscale (101, 108, 110, 111, 113, 114, 121)
ssh root@100.98.108.66
cd /root/agl-hostman   # ou path do clone NFS
bash scripts/proxmox/pct-tailscale-align-aglsrv6.sh
bash scripts/proxmox/pct-tailscale-align-aglsrv6.sh --check-only

# man6c
LAN_IF=vmbr0 TS_HOSTNAME=aglsrv6c bash scripts/proxmox/tailscale-align-proxmox-host.sh

# man6d
LAN_IF=enp2s0 TS_HOSTNAME=aglsrv6d bash scripts/proxmox/tailscale-align-proxmox-host.sh
```

**Remoto (a partir de agldv03 com repo):**

```bash
scp scripts/proxmox/{agl-lan-routes.sh,tailscale-align-proxmox-host.sh} root@100.124.53.91:/tmp/
ssh root@100.124.53.91 'LAN_IF=vmbr0 TS_HOSTNAME=aglsrv6c LAN_ROUTES_SRC=/tmp/agl-lan-routes.sh bash /tmp/tailscale-align-proxmox-host.sh'
```

### `agl-lan-routes.service`

- **Script:** `/usr/local/sbin/agl-lan-routes.sh` (fonte: `scripts/proxmox/agl-lan-routes.sh`)
- **Conf:** `/etc/agl-lan-routes.conf` — hosts LAN estáticos forçados via interface física na table 52
- **CTs com eth2 em 192.168.1.x:** conf **sem** linhas `192.168.1.202` / `192.168.1.233`
- **man6d (sem NIC 192.168.1.x):** conf **com** `192.168.1.202` e `192.168.1.233` via `enp2s0`

**Verificação Tailscale:**

```bash
tailscale debug prefs | grep -E 'RouteAll|CorpDNS|RunSSH'
ip route show table 52 | grep -E '192.168.0.0/24|10.6.0.0/24'   # não deve mostrar tailscale0
ping -c1 192.168.0.1
ping -c1 192.168.1.202    # man6c com vmbr2; man6d via gateway
ping -c1 10.6.0.12        # WG man6
```

---

## Comandos operacionais — cloudflared6

```bash
HOST=100.98.108.66

# Estado
ssh root@$HOST 'pct exec 101 -- systemctl status cloudflared'
ssh root@$HOST 'pct exec 114 -- systemctl status cloudflared'

# Logs boot / rede
ssh root@$HOST 'pct exec 101 -- journalctl -b -u networking -u cloudflared -u ifupdown-wait-online --no-pager'

# Reinício
ssh root@$HOST 'pct exec 101 -- systemctl restart cloudflared'

# Teste origins locais
ssh root@$HOST 'pct exec 101 -- curl -sk -o /dev/null -w "man6c: %{http_code}\n" https://192.168.1.233:8006/'
ssh root@$HOST 'pct exec 101 -- curl -sk -o /dev/null -w "man6: %{http_code}\n" https://192.168.60.202:8006/'
```

---

## Checklist — ao adicionar NIC / eth2 a CTs existentes

- [ ] Actualizar `netN` em `/etc/pve/lxc/VMID.conf` **sem** `ip6=dhcp` se IPv6 não for necessário
- [ ] Limpar `/etc/network/interfaces` dentro do CT (remover eth órfãos)
- [ ] Revisar `/etc/agl-lan-routes.conf` — remover subnets agora locais em eth2
- [ ] Correr `pct-tailscale-align-aglsrv6.sh` ou actualizar conf manualmente
- [ ] Reboot do CT e confirmar `Startup finished` < 10 s e `cloudflared` active
- [ ] Testar origins críticos (`man6c`, `man6`, Pi-hole, LiteLLM) a partir do CT tunnel

---

## Ficheiros e scripts (repo)

| Ficheiro | Função |
|----------|--------|
| `scripts/proxmox/pct-tailscale-align-aglsrv6.sh` | Alinha TS no man6 + CTs + instala `agl-lan-routes` |
| `scripts/proxmox/tailscale-align-proxmox-host.sh` | Alinha TS num host Proxmox (man6c, man6d) |
| `scripts/proxmox/agl-lan-routes.sh` | Fallback table 52 → interface LAN física |
| `scripts/proxmox/pct-install-agl-lan-routes.sh` | Instala `agl-lan-routes` em CTs agency (188–191) |
| `scripts/fix-man6c-ssh.sh` | Legado man6c — **corrigido** (`accept-routes=false`) |

---

## Referências cruzadas

- [`docs/CLOUDFLARE-TUNNELS.md`](../CLOUDFLARE-TUNNELS.md) — secção AGLSRV6
- [`docs/INFRA.md`](../INFRA.md) — Tailscale AGLSRV6 cluster
- [`docs/HOSTS.md`](../HOSTS.md) — IPs man6 / man6c / man6d
- [`docs/PROXMOX-CLUSTER-PLAN.md`](../PROXMOX-CLUSTER-PLAN.md) — cluster 3 nós (pré-requisitos rede)
- [`docs/troubleshooting/CT181-DNS-ROUTING-FIX.md`](CT181-DNS-ROUTING-FIX.md) — padrão `accept-routes=false`

---

## Segurança

- Units `cloudflared.service` nos CTs podem conter **token** em texto claro — rotacionar na consola Zero Trust se exposto; preferir ficheiro de ambiente ou credentials file com permissões restritas.
- Não commitar tokens no Git.

**Document Version**: 1.0.0  
**Maintainer**: agl-hostman / sessão 2026-06-03
