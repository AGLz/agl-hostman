# AGL Infrastructure Map

> **Last Updated**: 2026-05-13 | **Version**: 3.0.1
> **Reference**: Always read this document for infrastructure queries
> **Maintainer**: Jarvis (AI Butler) + Sr.Big

---

## 🤖 AI Systems Overview

### Jarvis (AI Butler)

- **Host**: **CT187** (LXC `agl-openclaw`, Proxmox **AGLSRV1**; OpenClaw em Docker, ver [`docs/LITELLM-OPENCLAW-DEDICATED-LXC.md`](LITELLM-OPENCLAW-DEDICATED-LXC.md))
- **Software**: OpenClaw (stack em `/opt/agl-openclaw` no CT)
- **Resources** (defaults do `pct-create`): 8GB RAM, 4 vCPU por CT — ajustável no `agl-litellm-openclaw-lxc.env`
- **Role**: Infrastructure management, monitoring, automation
- **Access (LAN)**: `192.168.0.187` — **Gateway (healthz)**: `http://192.168.0.187:28789/healthz` (porta publicada no compose CT187; dentro do contentor ver runbook)
- **Tailscale (CT187)**: hostname típico `agl-openclaw-ct187`; IP com `pct exec 187 -- tailscale ip -4`
- **Workspace**: volume em `/opt/agl-openclaw/workspace` (montado no contentor OpenClaw)
- **Model**: via **LiteLLM no CT186** — LAN `http://192.168.0.186:4000` (Tailscale do CT186: `pct exec 186 -- tailscale ip -4`)

**Nota (legado):** Jarvis correu no passado em **AGLWK45 (VM104)** com Windows; o cutover canónico para LXC **186/187** está documentado em [`docs/OPENCLAW.md`](OPENCLAW.md).

### OpenClaw Configuration

| Setting | Value |
|---------|-------|
| **Agents** | main (default), infra, storage, harbor, net |
| **Max Concurrent** | 4 agents, 8 subagents |
| **Telegram** | Enabled (allowlist: 1272190248) |
| **Compaction** | Safeguard mode |

### LiteLLM Gateway

- **Host**: **CT186** (LXC `agl-litellm`, Proxmox **AGLSRV1**; Docker em `/opt/agl-litellm`)
- **URL (LAN)**: <http://192.168.0.186:4000> — readiness: `/health/readiness`
- **URL (Tailscale, CT186)**: `http://100.125.249.8:4000` (`aglsrv1-litellm`)
- **Versão (2026-06-11)**: LiteLLM **1.82.6**; `request_timeout: 240`; deploy: `bash scripts/litellm/deploy-litellm-callbacks-ct186.sh`
- **Providers** (config em repo): zai, anthropic, openai, google, deepseek, moonshot, ollama, etc. — ver [`config/litellm/config.yaml`](../config/litellm/config.yaml)
- **Descontinuado (2026-06-05):** LiteLLM no **agldv03 CT179** — stack Docker removida. Ver [`docs/LITELLM-OPENCLAW-DEDICATED-LXC.md`](LITELLM-OPENCLAW-DEDICATED-LXC.md)
- **Ollama primário (VM310, AGLSRV3)**: **Tailscale** `http://100.67.253.52:11434` · **LAN** `http://192.168.15.210:11434` — 2× RX580, Vulkan
- **LiteLLM → Ollama**: `agl-primary` = `qwen3:8b`; aliases `ollama-gemma4-qat-final`, `ollama-gemma3-4b` (~46 tok/s JSON), `ollama-qwen3-4b-fast`, `ollama-llama31-8b` — ver [`docs/AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md)
- **Legado AGLSRV1:** CT200 / VM110 (`192.168.0.200`, TS `100.116.57.111`) **offline** — ver [`docs/AGL-OLLAMA-VM110.md`](AGL-OLLAMA-VM110.md)

### Agentes dedicados (CT188–190, AGLSRV1)

| VMID | Hostname | IP LAN | Função | Runbook |
|------|----------|--------|--------|---------|
| **188** | agl-hermes | `192.168.0.188` | Hermes Agent (Docker `/opt/agl-hermes`, gateway `:8642`) | [`HERMES-EVONEXUS-OPENHUMAN-DEDICATED-LXC.md`](HERMES-EVONEXUS-OPENHUMAN-DEDICATED-LXC.md) |
| **189** | agl-evonexus | `192.168.0.189` | EvoNexus hub (Docker `/opt/evonexus`; cutover desde **CT548** fgsrv7, ex.242) | idem + `scripts/evonexus/` |
| **190** | agl-openhuman | `192.168.0.190` | OpenHuman (install `/opt/openhuman`; UI/desktop) | idem |
| **191** | agl-gstack | `192.168.0.191` | **Jarvis O** — OpenClaw + GStack (legado agência; ver [`AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md)) | [`AGL-GSTACK-CT191-DEDICATED-LXC.md`](AGL-GSTACK-CT191-DEDICATED-LXC.md) |
| **192** | agl-honcho | `192.168.0.192` | Honcho self-hosted (memória AGLz Agency) | [`HONCHO-CT192-DEDICATED-LXC.md`](HONCHO-CT192-DEDICATED-LXC.md) |

**Nota:** usar IP **estático** `.188–.191` — DHCP pode colidir (ex. `.187` com OpenClaw). Gateway LLM: **CT186** `http://192.168.0.186:4000`. **CT191** ≠ **CT187** (produção vs. agência GStack).

**Perfil LXC (CT179):** `mp0`–`mp9` (`/mnt/overpower`, `/mnt/shares`, `/mnt/power`, `/mnt/storage`, …), `lxc.mount.entry` `/dev/net/tun`, cgroup `10:200` + `226:*`, **`unprivileged: 1`** (não privileged). Aplicar/reaplicar: `scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor 188 189 190 191`.

**Tailscale (CT188–191):** CTs na **LAN AGLSR1** — usar **`--accept-routes=false`** para não desviar `192.168.0.0/24` para `tailscale0` (table 52). Sem isto, serviços LAN (Pi-hole `.102`, LiteLLM `.186`, Honcho `.192`) ficam inacessíveis embora a tailnet funcione. Ver [`troubleshooting/CT181-DNS-ROUTING-FIX.md`](troubleshooting/CT181-DNS-ROUTING-FIX.md), [`MEDIA-ARR-STACK-AGL.md`](MEDIA-ARR-STACK-AGL.md) (CT117).

**Join inicial** (AGLSRV1):

```bash
printf '%s' 'tskey-auth-…' > /root/.tailscale-authkey && chmod 600 /root/.tailscale-authkey
bash scripts/proxmox/pct-tailscale-up-agency-cts.sh
bash scripts/proxmox/pct-install-agl-lan-routes.sh    # systemd agl-lan-routes.service
# Verificar prep: bash scripts/proxmox/pct-tailscale-verify-agency-cts.sh
```

Parâmetros canónicos (`tailscale up`):

```bash
tailscale up \
  --auth-key=tskey-auth-… \
  --hostname=agl-hermes-ct188 \
  --accept-dns=false \
  --accept-routes=false \
  --ssh \
  --accept-risk=lose-ssh   # só se SSH ao Proxmox for via Tailscale
```

**Correcção imediata** (sem rejoin): `tailscale set --accept-routes=false` dentro do CT.

### Tailscale — cluster AGLSRV6 (man6 / man6c / man6d)

> Runbook completo (cloudflared6 + eth2 + table 52): [`troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md`](troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md)

| Host | TS IP | Interface LAN | Script de alinhamento |
|------|-------|---------------|------------------------|
| man6 (AGLSRV6) | 100.98.108.66 | vmbr0 + vmbr2 (192.168.1.202) | `scripts/proxmox/pct-tailscale-align-aglsrv6.sh` |
| man6c (AGLSRV6C) | 100.124.53.91 | vmbr0 + vmbr2 (192.168.1.233) | `LAN_IF=vmbr0 TS_HOSTNAME=aglsrv6c scripts/proxmox/tailscale-align-proxmox-host.sh` |
| man6d (AGLSRV6D) | 100.76.201.83 | enp2s0 (192.168.0.234); anuncia 192.168.0.0/24 | `LAN_IF=enp2s0 TS_HOSTNAME=aglsrv6d scripts/proxmox/tailscale-align-proxmox-host.sh` |

CTs cloudflared (101, 114) com **eth2** em `192.168.1.0/24`: `agl-lan-routes.conf` **não** deve listar `192.168.1.202/233` — tráfego inter-host usa eth2 directamente.

**Verificação:**

```bash
tailscale debug prefs | grep RouteAll          # deve ser false
ip route show table 52 | grep 192.168           # não deve haver 192.168.0.0/24 via tailscale0
curl -sf http://192.168.0.186:4000/health/liveliness
```

| CT | Hostname TS | IP Tailscale (ref.) |
|----|-------------|---------------------|
| 188 | agl-hermes-ct188 | `100.81.225.22` |
| 189 | agl-evonexus-ct189 | ver `tailscale ip -4` |
| 190 | agl-openhuman-ct190 | ver `tailscale ip -4` |
| 191 | agl-gstack-ct191 | ver `tailscale ip -4` |

CT186/187 já na tailnet (`aglsrv1-litellm` `100.125.249.8`, `aglsrv1-openclaw` `100.123.184.125`) — **também** `--accept-routes=false` na LAN; não repetir join sem necessidade.

### Daily Memory System (agl-hostman)

- **Dashboard**: /daily-memory
- **API**: /api/daily-memory
- **Purpose**: Track all work sessions and discussions
- **Integration**: Jarvis auto-logs via API

---

## 📋 Table of Contents

1. [AI Systems Overview](#-ai-systems-overview)
2. [Network Overview](#-network-overview)
3. [Hosts and Servers](#-hosts-and-servers)
4. [WireGuard Mesh](#-wireguard-mesh)
5. [Storage Configuration](#-storage-configuration)
6. [Container Inventory](#-container-inventory)
7. [Connection Matrix](#-connection-matrix)

---

## 🌐 Network Overview

### Network Segments

| Network | CIDR | Purpose | Status |
|---------|------|---------|--------|
| WireGuard Mesh | 10.6.0.0/24 | Encrypted inter-site connectivity | ✅ Active (14 nodes) |
| Local LAN | 192.168.0.0/24 | Primary local network | ✅ Active |
| Local LAN Alt | 192.168.1.0/24 | Secondary local network | ✅ Active |
| Tailscale | 100.64.0.0/10 | Cross-site VPN overlay | ✅ Active |

### Network Infrastructure Devices

| Device | Model | IP | MAC | Purpose | Status |
|--------|-------|-----|-----|---------|--------|
| **SWT-AGLSRV1** | ZX-SWTG124AS | 192.168.0.242 | 1C:2A:A3:1E:86:77 | Network Switch (AGLSRV1 LAN) | ✅ Active |

**ZX-SWTG124AS Details**:

- **Firmware**: V1.9 (Jan 03 2024)
- **Hardware**: V1.0
- **Manufacturer**: 联果 (Lianguo) / Similar to LG-SWTG1224AS
- **Ports**: 24x 2.5G RJ-45 + 2x 10G SFP+ (estimated)
- **Network Standard**: IEEE 802.3af/at (PoE support)
- **Gateway**: 192.168.0.1
- **Netmask**: 255.255.255.0
- **Web Management**: <http://192.168.0.242>
- **Material**: Metal chassis (~3.2kg)

**Management Access**:

```bash
# Web UI access from LAN
http://192.168.0.242

# Check connectivity
ping 192.168.0.242

# View ARP entry
arp -a | grep 1c:2a:a3:1e:86:77
```

### Tailscale Network (CGNAT Overlay)

**Address Range**: 100.64.0.0/10 (Carrier-Grade NAT per RFC6598)

**Key Features**:

- **NAT Traversal**: ~98% P2P penetration success rate behind CGNAT
- **Protocol**: WireGuard-based with DERP relay fallback
- **No Public IP Required**: Works through ISP CGNAT restrictions

**Connected Devices** — 44 hosts total (31 active, 5 idle, 8 offline):

### AGLSRV1 Group (10 hosts)

| Tailscale IP | Hostname | OS | Status | Purpose |
|---|---|---|---|---|
| 100.107.113.33 | aglsrv1 | linux | Active | Proxmox host node (bare metal) |
| 100.94.221.87 | aglsrv1-agldv03 | linux | Active | Dev container CT179 (agldv03) — primary dev |
| 100.113.9.98 | aglsrv1-agldv04 | linux | Idle | Dev container agldv04 |
| 100.69.187.105 | aglsrv1-aglfs1 | linux | Active | File server / NFS (CT178) |
| 100.117.146.21 | aglsrv1-aglwk45 | windows | Active | Windows workstation VM |
| 100.80.30.59 | aglsrv1-archon | linux | Active (direct) | Archon AI Command Center (CT183) — 8181 (API), 8051 (MCP), 3737 (UI) |
| 100.72.66.106 | aglsrv1-dokploy | linux | Active | Dokploy deployment manager (CT180) |
| 100.105.133.18 | aglsrv1-haos | linux | Offline 158d | Home Assistant OS VM |
| 100.67.253.52 | aglsrv3-ollama | linux | Active | **Ollama primário** — VM310 AGLSRV3 (2× RX580) |
| 100.116.57.111 | aglsrv1-ollama | linux | Offline | Legado VM110/CT200 AGLSRV1 — descontinuado |
| 100.114.66.80 | aglsrv1-pihole | linux | Active | Pi-hole DNS (CT102) |

### AGLSRV5 Group (7 hosts)

| Tailscale IP | Hostname | OS | Status | Purpose |
|---|---|---|---|---|
| 100.119.223.113 | aglsrv5 | linux | Idle | Proxmox host node |
| 100.119.41.63 | aglsrv5-agldv05 | linux | Idle | Dev container agldv05 |
| 100.92.46.119 | aglsrv5-aglwk79 | windows | Active | Windows workstation VM |
| 100.66.136.84 | aglsrv5-fileserver5 | linux | Active | File server / NFS |
| 100.82.254.91 | aglsrv5-mesh5 | linux | Active | WireGuard mesh node |
| 100.98.1.119 | aglsrv5-mysql5 | linux | Active | MySQL slave read_only (CT135); ver `docs/maint/MYSQL-HA-POST-RESET-2026-04.md` |
| 100.68.158.60 | aglsrv5-unraid | linux | Active | Unraid NAS storage |

### AGLSRV6 Group (11 hosts)

| Tailscale IP | Hostname | OS | Status | Purpose |
|---|---|---|---|---|
| 100.98.108.66 | aglsrv6 | linux | Active | Proxmox host node |
| 100.71.229.12 | aglsrv6-agldv06 | linux | Idle | Dev container **CT608** agldv06 (ex.108) |
| 100.120.94.42 | aglsrv6-aglhq26 | windows | Active | Windows workstation |
| 100.65.189.83 | aglsrv6-aluzdivina | linux | Active | NFS server (CT111) |
| 100.121.95.88 | aglsrv6-cloudflared6 | linux | Active | Cloudflare Tunnel primary (CT101) |
| 100.115.195.128 | aglsrv6-cloudflared6b | linux | Active | Cloudflare Tunnel secondary (CT114) |
| 100.70.155.60 | aglsrv6-pbs | linux | Active | Proxmox Backup Server (CT113) |
| 100.102.182.100 | aglsrv6-sspadld01 | windows | Offline 26d | Windows server |
| 100.113.15.100 | aglsrv6-wireguard | linux | Active | WireGuard hub container (CT121) |
| 100.69.29.38 | aglsrv6b-pbs | linux | Offline 131d | PBS secondary (decommissioned?) |
| 100.98.119.51 | aglsrv6b | linux | Offline 131d | AGLSRV6B host (decommissioned?) |

### AGLSRV6C/D + AGLSRV3 (3 hosts)

| Tailscale IP | Hostname | OS | Status | Purpose |
|---|---|---|---|---|
| 100.124.53.91 | aglsrv6c | linux | Active | AGLSRV6C extension node |
| 100.76.201.83 | aglsrv6d | linux | Active | AGLSRV6D extension node |
| 100.123.5.81 | aglsrv3 | linux | Active | Proxmox host AGLFG (`192.168.15.247`) |
| *(pendente)* | aglsrv3-pihole | linux | **NeedsLogin** | CT317 Pi-hole @ LAN `192.168.15.117` — [`AGLSRV3-PIHOLE-CLONE.md`](AGLSRV3-PIHOLE-CLONE.md) + `scripts/proxmox/pct-tailscale-up-aglsrv3-pihole.sh` |

> **AGLSRV3 DNS:** Pi-hole local CT317 @ `192.168.15.117`. Host `resolv.conf` e CTs apontam para este IP.

### FGSRV Group (7 hosts)

| Tailscale IP | Hostname | OS | Status | Purpose |
|---|---|---|---|---|
| 100.67.99.115 | fgsrv03 | linux | Active | Cloud VPS 03 |
| 100.111.79.2 | fgsrv04 | linux | Active | Cloud VPS 04 |
| 100.71.107.26 | fgsrv05 | linux | Active | Cloud VPS 05 / NFS server |
| 100.83.51.9 | fgsrv06 | linux | Idle | Cloud VPS 06 / WireGuard hub |
| 100.72.240.65 | fgsrv07-cloudflared7 | linux | Active | Cloudflare Tunnel (**CT570**; ex.170) |
| *(após login no CT171)* | fgsrv07-cloudflared7b | linux | Reauth pendente | CT171 `cloudflared7b` — reset Tailscale: `scripts/maint/fgsrv07/pct-tailscale-reset-after-clone.sh`; depois `pct exec 171 -- tailscale ip -4` e actualizar esta linha |
| 100.83.7.16 | fgsrv07-mysql7 | linux | Active | MySQL master / GTID (**CT561**; ex.235) |
| 100.64.139.79 | fgsrv07-agldv07 | linux | **NeedsLogin** (CT547 running) | Dev **agldv07** (**CT547**; ex.241) — LAN `192.168.70.241`; **≠ CT183 archon** — reauth Tailscale após restore disco |
| 100.109.181.93 | fgsrv07 | linux | Active | Cloud VPS 07 / Proxmox |

### Endpoints & Dispositivos Pessoais (6 hosts)

| Tailscale IP | Hostname | OS | Status | Purpose |
|---|---|---|---|---|
| 100.75.205.122 | aglhq11 | windows | Active | AGL HQ workstation (WSL2) |
| 100.105.84.8 | aglnb11 | windows | Active | AGL notebook |
| 100.111.113.102 | aglmac08 | macOS | Active | AGL Mac workstation |
| 100.102.187.120 | aglmac07 | windows | Offline 36d | AGL Mac (Boot Camp) |
| 100.80.84.69 | aglcel10 | android | Offline 46d | Celular Android |
| 100.64.43.53 | xiaomi-21121210g | android | Offline 134d | Xiaomi device |

**Subnet Router Configuration** (if needed):

```bash
# Advertise LAN routes via Tailscale
tailscale up --advertise-routes=192.168.0.0/24,10.6.0.0/24
```

### WireGuard Hub

- **Server**: FGSRV6 (vps41772)
- **Public IP**: 186.202.57.120
- **WireGuard IP**: 10.6.0.5
- **Port**: 51823/UDP
- **Type**: Hub-and-spoke + mesh hybrid

---

## 🖥️ Hosts and Servers

### AGLSRV1 (Main Production Host)

**Hostname**: algsrv1
**Type**: Proxmox VE Host
**Location**: Local (192.168.0.0/24)

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN | 192.168.0.245 | vmbr0 | ✅ Primary |
| WireGuard | 10.6.0.10 | wg0 | ✅ Port 51810 |
| Tailscale | 100.107.113.33 | tailscale0 | ✅ Active |

**Resources**:

- Total VMs/CTs: 68 (42 running, 26 stopped)
- Primary Dev Container: CT179 (agldv03) - 48GB RAM
- AI Infrastructure: CT183 (archon), CT200 (ollama)
- Storage: local-zfs (1.7TB), spark (7.1TB), overpower (9.8TB)

**Key Services**:

- DNS/DHCP: CT102 (pihole)
- Media: CT113 (plex), CT121-124 (arr stack)
- Development: CT179 (agldv03), CT180 (dokploy)
- AI: CT183 (archon), CT200 (ollama), CT202 (n8n)
- Monitoring: CT132 (observium), CT162 (meshcentral)

**Archon Stack (CT183)** — hostname **archon** / `aglsrv1-archon`; **não** é **agldv07** (agldv07 = **CT547** @ FGSRV7):

- **Tailscale IP**: 100.80.30.59 | **LAN IP**: 192.168.0.183 | **WireGuard**: 10.6.0.21
- **Services**: archon-server (8181), archon-mcp (8051), archon-ui (3737)
- **Network**: `network_mode: host` — containers share CT's network namespace
- **Domain**: archon.aglz.io (Cloudflare Tunnel)
- **Config**: `VITE_ALLOWED_HOSTS=archon.aglz.io,localhost,127.0.0.1`
- **Health**: `curl http://100.80.30.59:8181/health`
- **MCP**: `http://100.80.30.59:8051/mcp` (Streamable HTTP)
- **Docs**: `patches/archon/README.md`

---

### AGLSRV6 (Secondary Host)

**Hostname**: AGLSRV6 (formerly man6)
**Type**: Proxmox VE Host
**Location**: Remote (behind WireGuard/Tailscale)

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| WireGuard | 10.6.0.12 | wg0 | ✅ Port 51812 (PRIMARY) |
| Tailscale | 100.98.108.66 | tailscale0 | ✅ Fallback |
| LAN externa | 192.168.0.202/24 | vmbr0 | ✅ Active |
| LAN interna | 192.168.60.202/24 | vmbr1 | ✅ Active |
| **LAN inter-host** | **192.168.1.202/24** | **vmbr2** | ✅ **PRIMARY cluster** (man6 ↔ man6c ↔ CTs eth2) |

**Resources**:

- Containers: CT101–114, CT117, CT121 (+ CT116 parado, CT107/104 parados)
- VMs: 6 (VM100, VM103, VM105-106, VM112, VM200)
- Storage: 954GB (bb), 3.9TB (usb4tb), 1.2TB (PBS)

**Key Services**:

- DNS: **CT117 (pihole6)** — LAN **192.168.0.117** (migrado de CT115 em 2026-04-04; evita conflito com equipamento TP-LINK em `.115`)
- Storage: CT111 (aluzdivina) - NFS server (10.6.0.20)
- Backup: CT113 (PBS), CT172 (PBS)
- Development: **CT608** (agldv06; ex.108)
- Infrastructure: CT101 (cloudflared), CT102 (meshcentral)

---

### FGSRV7 (Cloud VPS - Cluster Node)

**Location**: Cloud VPS (vps64306)
**Type**: Proxmox VE Host
**Role**: Cluster node with AGLSRV5, Cloudflare Tunnel host
**Last Optimized**: 2026-02-23

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.93.227 | - | ✅ Internet |
| Tailscale | 100.109.181.93 | - | ✅ Active |
| WireGuard | 10.6.0.24 | 51824/UDP | 🔄 Pending |

**Proxmox**:

- Version: 9.1.5
- Kernel: 6.17.9-1-pve
- Storage: ~200GB local (bkp)
- Cluster: aglsrv5 + fgsrv7 + QDevice

**Resources** (Optimized 2026-02-23):

- RAM: 7.8GB total, ~5.2GB available
- **Swap: 32GB file** (`/swapfile`, swappiness=10)
- Disk: 195GB (28% used after swap creation)

**Network Bridges**:

| Bridge | Type | IP | Purpose |
|--------|------|-----|---------|
| vmbr0 | Linux Bridge | 191.252.93.227/24 | Public network |
| vmbr70 | OVS Bridge | 192.168.70.1/24 | Internal container network |

**DNS**:

- Servers: 8.8.8.8, 1.1.1.1
- Search: aglz.io

**/etc/hosts**:

```
127.0.0.1 localhost
191.252.93.227 vps64306.publiccloud.com.br vps64306
100.109.181.93 fgsrv7.tailscale fgsrv7
192.168.70.1 fgsrv7.aglz.io fgsrv7
```

**Containers**:

| VMID | Name | Status | Network | Purpose |
|------|------|--------|---------|---------|
| 545 | fgsrv7-pbs | running | WAN | Proxmox Backup Server |
| 546 | fileserver7 | stopped | vmbr70 | Partilha ficheiros (ex.240) |
| 547 | agldv07 | running | vmbr70 (192.168.70.241) | Dev satélite (ex.241); TS **`fgsrv07-agldv07`** `100.64.139.79` — **NeedsLogin** após restore |
| 548 | evonexus | running | vmbr70 (192.168.70.242) | EvoNexus (ex.242); **https://evo.aglz.io** |
| 549 | fg-legacy | running | vmbr70 (192.168.70.243) | Legado (ex.243) |
| 550 | fg-ngrok | running | vmbr70 (192.168.70.244) | ngrok (ex.244) |
| 561 | mysql7 | running | vmbr70 (192.168.70.235) | MySQL Master HA (ex.535) |
| 562 | pihole7 | running | vmbr70 (192.168.70.139) | DNS (ex.539) |
| 570 | cloudflared7 | running | vmbr70 (192.168.70.170) | Cloudflare Tunnel fgsrv7 (ex.170) |
| 571 | cloudflared7b | running | vmbr70 (192.168.70.171) | Túnel **fgsrv7b** (ex.171) |

**Renumeração VMID (2026-06):** ver `docs/PROXMOX-VMID-RENUMBER-2026-06.md`.

**EvoNexus CT548 (SQLite única):** dashboard, scheduler, telegram e agentes no volume `workspace` devem usar **`/workspace/dashboard/data/evonexus.db`**. Unificação: `scripts/evonexus/unify-single-sqlite-evonexus-db.sh`. Tailscale: `lxc.mount.entry` em `548.conf`.

**EvoNexus — Claude no terminal e LiteLLM:** o `claude-bridge` não herda o `.env` do contentor; injeta apenas `env_vars` do `providers.json` que passam na whitelist em `terminal-server/src/provider-config.js`. No upstream, **`ANTHROPIC_BASE_URL` e `ANTHROPIC_AUTH_TOKEN` não estão na lista** — se o perfil `anthropic` tiver gateway LiteLLM nesses campos, são ignorados e o `claude` arranca sem API key efetiva (mensagem tipo «não estás logado»). Mitigação: montar o overlay **`scripts/evonexus/overlays/terminal-server-provider-config.js`** em `/workspace/dashboard/terminal-server/src/provider-config.js` (ver cabeçalho do ficheiro) e no `providers.json` preencher `env_vars` com `ANTHROPIC_BASE_URL`, **`ANTHROPIC_AUTH_TOKEN`** (Bearer = `LITELLM_MASTER_KEY` no proxy), `DISABLE_LOGIN_COMMAND=1` quando aplicável; reiniciar o serviço `dashboard`. **Claude Code 2.1+:** não definir **`ANTHROPIC_API_KEY` e `ANTHROPIC_AUTH_TOKEN` em simultâneo** para hosts que não sejam `api.anthropic.com` — o cliente avisa *Auth conflict* e o comportamento fica ambíguo; o script **`scripts/evonexus/sync-providers-anthropic-from-env.py`** remove `ANTHROPIC_API_KEY` nesse caso após o merge. O perfil **litellm** com `openclaude` usa `OPENAI_*` (já permitidos); o problema costuma aparecer ao usar o binário **`claude`** com Anthropic + proxy.

**EvoNexus — root, DSP e modelo por defeito:** o bridge original não aplicava `global_settings.dangerouslySkipPermissions` e **nunca** passava `--dangerously-skip-permissions` como root. Overlay **`scripts/evonexus/overlays/claude-bridge.js`** lê o `providers.json`, combina com `IS_SANDBOX=1` no compose do dashboard e repassa `IS_SANDBOX` ao PTY; injeta `--model` a partir de `ANTHROPIC_MODEL` (sync: **`scripts/evonexus/sync-providers-anthropic-from-env.py`**, omissão **`qwen3.5-plus`** quando `.env` não define modelo). Índice: **`scripts/evonexus/overlays/README-evonexus-overlays.md`**.

**EvoNexus — backup antes de reiniciar o CT548:** pasta `/root/backups/evonexus-jarvis-*` no CT; espelho no FGSRV7 em `/root/backups-ct242-evonexus/` (nome histórico). Restauro: `scripts/proxmox/RESTORE-CT242-EVONEXUS.md` + sync **CT189 → CT548** via `pct-sync-evonexus-189-to-242.sh`.

**MySQL HA Replication**:

- Master: **CT561** (FGSRV7) — doc: `docs/maint/MYSQL-HA-POST-RESET-2026-04.md`
- Slave (read_only): **CT535** (AGLSRV5; ex.135)
- Replication User: repl / Repl@123456
- Status: ✅ Active via Tailscale (Master-Slave async)

**NAT Configuration**:

```bash
iptables -t nat -A POSTROUTING -s 192.168.70.0/24 -o vmbr0 -j MASQUERADE
# Persisted via /etc/systemd/system/iptables-restore.service
```

**Cloudflare Tunnel — par HA (FGSRV7):**

| CT | Túnel | Gestão | Conta CF |
|----|-------|--------|----------|
| **570** `cloudflared7` | **fgsrv7** `513cec7b-…` | UI web Zero Trust | aglz.io (`cert.pem` agldv03) |
| **571** `cloudflared7b` | **fgsrv7b** `850f2d28-…` | CLI / API / AI | falg.* (token API dedicado) |

Um túnel por CT; em backup PBS parar um CT — o outro assume se o hostname existir nos **dois** túneis. Detalhe: `docs/CLOUDFLARE-TUNNELS.md` (secção FGSRV7 HA).

- **fgsrv7:** `man7.aglz.io`, `evo.aglz.io`, `www5.aglz.io`, MySQL TCP, etc.
- **fgsrv7b:** `falg.com.br` → CT549; pendente espelhar `falgimoveis.com` / `www.*` — `scripts/cloudflare/update-fgsrv7b-tunnel-fg-legacy-ingress.sh`
- Provisionamento CT571: `scripts/maint/fgsrv07/provision-cloudflared7b-from-170.sh`

> **Padrão Proxmox:** `cloudflared` só em **CT dedicado** (AGLSRV1 CT117, AGLSRV5 CT530, AGLSRV6 CT101/114, FGSRV7 CT570/571).

**Access**:

- Web UI: <https://man7.aglz.io> ✅
- SSH (Tailscale): `ssh root@100.109.181.93` (chave conforme agente / `~/.ssh/config` Host `fgsrv7`)
- SSH (IP público): `ssh FGSRV07` ou `ssh -i ~/.ssh/id_rsa root@191.252.93.227` (Host `FGSRV07` em `~/.ssh/config` usa `id_rsa`)

---

### FGSRV6 (Cloud VPS - WireGuard Hub)

**Location**: Cloud VPS (vps41772)
**Type**: Proxmox VE Host
**Role**: WireGuard mesh hub, NFS server, Cloudflare Tunnel host

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 186.202.57.120 | - | ✅ Internet |
| WireGuard | 10.6.0.5 | 51823/UDP | ✅ Hub |
| Tailscale | 100.83.51.9 | - | ✅ Active |

**NFS Exports**:

- Export: 197GB NFSv4.2
- Mounted on: AGLSRV1 as `fgsrv6-wg` (10.6.0.5)

**Cloudflare Tunnel (aglsrv5e)**:

- Tunnel ID: `863fd93d-73c5-4c3e-90b5-7cbd37643f70`
- Container: `cloudflared-tunnel` (Docker)
- Endpoints: n8n5e.aglz.io, portainer5e.aglz.io
- Auto-start: ✅ `restart: unless-stopped`

---

### FGSRV5 (Cloud VPS)

**Location**: Cloud VPS (191.252.200.20)
**Type**: Proxmox VE Host
**Role**: NFS server, storage backend

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.200.20 | - | ✅ Internet |
| WireGuard | 10.6.0.11 | 51811/UDP | ✅ Active |
| Tailscale | 100.71.107.26 | - | ✅ Active |

**NFS Exports**:

- Export: 77GB NFSv4.2
- Mounted on: AGLSRV1 as `fgsrv5-wg` (10.6.0.11)
- **Notes**: SSH timeout issues reported

---

### FGSRV4 (Cloud VPS)

**Location**: Cloud VPS (vps22826.publiccloud.com.br)
**Type**: Ubuntu 22.04 VPS (legado PHP/Nginx — **não** é host Proxmox; ver auditoria 2026-06-11)
**Descomissionamento**: [`docs/maint/FGSRV04-DECOMMISSION-INVENTORY.md`](maint/FGSRV04-DECOMMISSION-INVENTORY.md) — `www5` migrado para FGSRV07 CT549; domínios principais ainda neste host até cutover DNS.

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.201.108 | - | ✅ Internet |
| WireGuard | 10.6.0.16 | 51816/UDP | ✅ Active |
| Tailscale | 100.111.79.2 | - | ✅ Active |

**User**: sysadmin (público) / root (Tailscale)

---

### FGSRV3 (Cloud VPS)

**Location**: Cloud VPS (191.252.201.205)
**Type**: Proxmox VE Host

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.201.205 | - | ✅ Internet |
| WireGuard | 10.6.0.18 | 51818/UDP | ✅ Active |
| Tailscale | 100.67.99.115 | - | ✅ Active |

---

## 🔗 WireGuard Mesh

### Active Nodes (14 Total)

| Node | IP | Port | Type | Host | Status |
|------|-----|------|------|------|--------|
| **FGSRV6** | 10.6.0.5 | 51823 | Hub | Cloud VPS | ✅ Hub |
| CT120 | 10.6.0.1 | 51820 | Container | AGLSRV1 | ✅ |
| CT121 | 10.6.0.3 | 51821 | Container | AGLSRV6 | ✅ |
| AGLSRV1 | 10.6.0.10 | 51810 | Host | Local | ✅ |
| FGSRV5 | 10.6.0.11 | 51811 | Host | Cloud VPS | ✅ |
| **AGLSRV6** | 10.6.0.12 | 51812 | Host | Remote | ✅ PRIMARY |
| AGLSRV6B | 10.6.0.13 | 51813 | Host | Remote | ✅ |
| CT113 | 10.6.0.14 | 51814 | Container | AGLSRV6 | ✅ |
| CT172 | 10.6.0.15 | 51815 | Container | AGLSRV6B | ✅ |
| FGSRV4 | 10.6.0.16 | 51816 | Host | Cloud VPS | ✅ |
| AGLSRV5 | 10.6.0.17 | 51817 | Host | Remote | ✅ |
| FGSRV3 | 10.6.0.18 | 51818 | Host | Cloud VPS | ✅ |
| **CT179** | 10.6.0.19 | 51819 | Container | AGLSRV1 | ✅ Dev |
| **CT111** | 10.6.0.20 | 51820 | Container | AGLSRV6 | ✅ NFS |

### Configuration Standards

**Containers (No PresharedKey)**:

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24  # Only mesh network
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

**Hosts (With PresharedKey)**:

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
PresharedKey = DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk=
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

### LXC Container Requirements

```ini
# Perfil agldv03 (CT179) — também CT188–191 após pct-apply-agldv03-lxc-profile.sh
features: keyctl=1,nesting=1,fuse=1,mknod=1
unprivileged: 1
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
lxc.mount.entry: /proc/sys/net/ipv4/ip_unprivileged_port_start proc/sys/net/ipv4/ip_unprivileged_port_start none bind,create=file,ro 0 0
# Docker-in-LXC (CT186/187/188–191): lxc.apparmor.profile: unconfined
```

### WireGuard Performance Best Practices

**Topology Notes**:

- **Hub-and-Spoke**: Central hub (FGSRV6) routes all traffic - simpler but adds latency
- **Full Mesh**: P2P connections between all nodes - lower latency, more complex
- **Hybrid** (current): Hub for external, mesh for local - balanced approach

**Performance Optimization**:

```bash
# Check handshake status (should be recent, < 3 min)
wg show wg0 latest-handshakes

# Monitor transfer rates
watch -n 1 'wg show wg0 transfer'

# Check MTU (1420 recommended for WireGuard)
ip link show wg0

# Performance test between peers
iperf3 -c 10.6.0.5  # Test to hub
```

**MTU Considerations**:

- Default MTU: 1420 (accommodates WireGuard overhead)
- WireGuard overhead: ~60 bytes per packet
- Path MTU discovery: Automatic, but may need adjustment on some networks

**Keepalive Tuning**:

- `PersistentKeepalive = 25` - Maintains NAT mappings (recommended)
- Lower values (15-20) for unstable connections
- Higher values (60-120) to reduce bandwidth usage

**Troubleshooting**:

```bash
# No handshake - check firewall
iptables -L -n | grep 51823

# Intermittent connectivity - check MTU
ping -M do -s 1372 10.6.0.5  # Test with DF bit

# High latency - check route
traceroute 10.6.0.5
```

---

## 💾 Storage Configuration

### AGLSRV1 Storage Mounts

| Storage | Size | Type | Source | Path | Status |
|---------|------|------|--------|------|--------|
| local | 77GB | Local | Disk | - | ✅ |
| local-zfs | 1.7TB | ZFS | Pool | - | ✅ |
| fgsrv5-wg | 77GB | NFS | 10.6.0.11:/ | /mnt/pve/fgsrv5-wg | ✅ |
| fgsrv6-wg | 197GB | NFS | 10.6.0.5:/ | /mnt/pve/fgsrv6-wg | ✅ |
| ct111-shares | 66GB | NFS | 10.6.0.20:/mnt/shares | /mnt/pve/ct111-shares | ⚠️ CT111 offline bloqueia `pvedaemon` — ver [AGLSRV1-WEBUI-LOGIN-NFS-BLOCK-2026-05-25.md](AGLSRV1-WEBUI-LOGIN-NFS-BLOCK-2026-05-25.md) |
| ct111-sistema | 818GB | NFS | 10.6.0.20:/mnt/sistema | /mnt/pve/ct111-sistema | ⚠️ idem |
| aglsrv6-bb | 954GB | SSHFS | 10.6.0.12:/mnt/pve/bb | /mnt/pve/aglsrv6-bb | ✅ |
| aglsrv6-usb4tb | 3.9TB | SSHFS | 10.6.0.12:/mnt/usb4tb-direct | /mnt/pve/aglsrv6-usb4tb | ✅ |
| aglsrv6-pbs | 1.2TB | PBS | - | - | ✅ |
| aglsrv6b-pbs | 1.0TB | PBS | - | - | ✅ |
| spark | 7.1TB | Local | Disk | - | ✅ 91.54% used |
| overpower | 9.8TB | Local | Disk | - | ✅ 92.54% used |

**Total WireGuard Storage**: 6.0 TB

- NFS: 1.2TB (fgsrv5-wg + fgsrv6-wg + ct111-shares + ct111-sistema)
- SSHFS: 4.8TB (aglsrv6-bb + aglsrv6-usb4tb)

### AGLSRV5 Storage Mounts

| Storage | Type | Source | Path | Status |
|---------|------|--------|------|--------|
| fileserver5-nfs | NFS | 10.6.0.21 (CT138 fileserver5) | /mnt/pve/fileserver5-nfs | ✅ |

**Rename**: `ct138-nfs` → `fileserver5-nfs` (ver [STORAGE-RENAME-CT138-TO-FILESERVER5](wireguard/STORAGE-RENAME-CT138-TO-FILESERVER5.md))

### CT111 (aluzdivina) NFS Server

**WireGuard**: 10.6.0.20 (Port 51820)
**Tailscale**: 100.65.189.83
**Host**: AGLSRV6

**Storage**:

- /mnt/shares: 66GB XFS (NFS exported)
- /mnt/sistema: 819GB ZFS (NFS exported)
- /mnt/bb: CIFS from 192.168.0.203
- /mnt/bkp: 3.9TB ExFAT

**NFS Exports**:

- 192.168.0.0/24 (Local LAN)
- 10.6.0.0/24 (WireGuard mesh)

**Performance**:

- Latency to hub: 15-22ms
- Mounted on AGLSRV1 as ct111-shares (66GB) and ct111-sistema (818GB)

### NFS v4.2 Optimization

**Recommended Mount Options**:

```bash
# Optimized NFSv4.2 mount command
mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,timeo=600,retrans=2,hard,noatime 10.6.0.20:/mnt/shares /mnt/pve/ct111-shares
```

**Key Parameters**:

| Option | Value | Purpose |
|--------|-------|---------|
| `vers` | 4.2 | NFS v4.2 (sparse files, session trunking) |
| `rsize/wsize` | 1048576 | 1MB read/write blocks - maximizes throughput |
| `timeo` | 600 | 60s timeout - handles WireGuard latency |
| `retrans` | 2 | Retry attempts |
| `hard` | - | Data integrity over responsiveness |
| `noatime` | - | Disable access time updates |

**/etc/fstab Entry Example**:

```fstab
# NFS mounts via WireGuard
10.6.0.5:/ /mnt/pve/fgsrv6-wg nfs4 vers=4.2,rsize=1048576,wsize=1048576,timeo=600,retrans=2,hard,noatime,_netdev 0 0
10.6.0.11:/ /mnt/pve/fgsrv5-wg nfs4 vers=4.2,rsize=1048576,wsize=1048576,timeo=600,retrans=2,hard,noatime,_netdev 0 0
10.6.0.20:/mnt/shares /mnt/pve/ct111-shares nfs4 vers=4.2,rsize=1048576,wsize=1048576,timeo=600,retrans=2,hard,noatime,_netdev 0 0
10.6.0.20:/mnt/sistema /mnt/pve/ct111-sistema nfs4 vers=4.2,rsize=1048576,wsize=1048576,timeo=600,retrans=2,hard,noatime,_netdev 0 0
```

**Multiple Connections (Kernel 5.3+)**:

```bash
# Use nconnect for parallel TCP connections
mount -t nfs -o vers=4.2,nconnect=8,rsize=1048576,wsize=1048576 ...
```

**Client-Side Kernel Tuning** (`/etc/sysctl.conf`):

```bash
# Network buffer optimization for NFS
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
net.ipv4.tcp_rmem = 1048576 8388608 16777216
net.ipv4.tcp_wmem = 1048576 8388608 16777216
net.core.somaxconn = 65535
```

Apply with: `sudo sysctl -p`

### SSHFS Optimization

**Recommended Mount Command**:

```bash
sshfs root@10.6.0.12:/mnt/pve/bb /mnt/pve/aglsrv6-bb \
    -o reconnect \
    -o cache_timeout=120 \
    -o attr_timeout=120 \
    -o uid=$(id -u),gid=$(id -g) \
    -o max_readahead=524288 \
    -o kernel_cache \
    -o big_writes \
    -o compression=no  # For high-speed WireGuard
```

**Performance Options**:

| Option | Value | Purpose |
|--------|-------|---------|
| `reconnect` | - | Auto-reconnect on disconnect |
| `cache_timeout` | 120 | Cache timeout (seconds) |
| `kernel_cache` | - | Use kernel page cache |
| `max_readahead` | 524288 | Read-ahead buffer (512KB) |
| `big_writes` | - | Enable large packet writes |
| `compression` | no | Disable on fast networks |

**/etc/fstab Entry Example**:

```fstab
# SSHFS mounts via WireGuard
root@10.6.0.12:/mnt/pve/bb /mnt/pve/aglsrv6-bb fuse.sshfs reconnect,cache_timeout=120,attr_timeout=120,kernel_cache,big_writes,max_readahead=524288,compression=no,_netdev 0 0
root@10.6.0.12:/mnt/usb4tb-direct /mnt/pve/aglsrv6-usb4tb fuse.sshfs reconnect,cache_timeout=120,attr_timeout=120,kernel_cache,big_writes,max_readahead=524288,compression=no,_netdev 0 0
```

**SSH Config Optimization** (`~/.ssh/config`):

```
Host aglsrv6-wg
    HostName 10.6.0.12
    User root
    ServerAliveInterval 15
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
    Compression no
    Ciphers aes128-ctr
```

### ZFS Storage Best Practices

**Current Pools on AGLSRV1**:

- `local-zfs`: 1.7TB - Proxmox VM/CT storage
- `spark`: 7.1TB (91.54% used) - Data storage
- `overpower`: 9.8TB (92.54% used) - Primary storage

**RAIDZ Disk Count Recommendations**:

| RAIDZ Level | Optimal Disk Counts | Formula |
|-------------|---------------------|---------|
| RAIDZ1 | 3, 5, 9, 17 | 2^n + 1 |
| RAIDZ2 | 4, 6, 10, 18 | 2^n + 2 |
| RAIDZ3 | 5, 7, 11, 19 | 2^n + 3 |

**Performance Optimization**:

```bash
# Add L2ARC cache (SSD)
zpool add poolname cache /dev/sdX

# Add ZIL/SLOG (SSD for sync writes)
zpool add poolname log /dev/sdY

# Enable compression (usually default)
zfs set compression=lz4 poolname

# Check compression ratio
zfs get compressratio poolname

# Schedule regular scrub
zpool scrub poolname
```

**Maintenance Commands**:

```bash
# Check pool health
zpool status

# Check pool capacity
zpool list

# Run scrub (monthly recommended)
zpool scrub local-zfs

# Check scrub progress
zpool status -v local-zfs
```

**Memory Requirements**:

- Rule of thumb: ~1GB RAM per TB of storage
- For ZFS with dedup: ~5GB RAM per TB
- ARC cache: Uses available RAM automatically

---

## 📦 Container Inventory

### AGLSRV1 Containers (Running - 42 Total)

#### Infrastructure & Network

| VMID | Name | IP (LAN) | IP (WG/TS) | Purpose |
|------|------|----------|------------|---------|
| 102 | pihole | 192.168.0.102 | TS: 100.114.66.80 | DNS/DHCP |
| 117 | cloudflared | 192.168.0.117 | - | Cloudflare tunnel |
| 120 | wireguard | 192.168.0.120 | WG: 10.6.0.1 | WireGuard node |
| 126 | guac | 192.168.0.126 | - | Guacamole remote |
| 159 | nginxproxy | 192.168.0.159 | - | Nginx reverse proxy |
| 162 | meshcentral | 192.168.0.162 | - | Remote management |
| 176 | iventoy | 192.168.0.176 | - | Network boot |

#### Media & Automation

| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 111 | tautulli | 192.168.0.111 | Plex monitoring |
| 112 | bazarr | 192.168.0.112 | Subtitle automation |
| 113 | plexmediaserver | 192.168.0.113 | Media server |
| 121 | qbittorrent | 192.168.0.121 | Torrent client |
| 122 | jackett | 192.168.0.122 | Torrent indexer |
| 123 | radarr | 192.168.0.123 | Movie automation |
| 124 | sonarr | 192.168.0.124 | TV automation |
| 141 | sabnzbd | 192.168.0.141 | Usenet client |
| 144 | autobrr | 192.168.0.144 | Torrent automation |
| 157 | deluge | 192.168.0.157 | Torrent client |
| 165 | aria2 | 192.168.0.165 | Download manager |
| 170 | homarr | 192.168.0.170 | Dashboard |
| 171 | overseerr | 192.168.0.171 | Media requests |
| 172 | prowlarr | 192.168.0.172 | Indexer manager |

**Stack *arr (operação):** [`MEDIA-ARR-STACK-AGL.md`](MEDIA-ARR-STACK-AGL.md). **Grabs activos, downloads parados** (2026-05-29) — [`MEDIA-ARR-MAINTENANCE.md`](MEDIA-ARR-MAINTENANCE.md), `scripts/media/arr-freeze-downloads.sh`.

#### Development & DevOps

| VMID | Name | IP (LAN) | IP (WG/TS) | RAM | Purpose |
|------|------|----------|------------|-----|---------|
| 103 | portainer | 192.168.0.103 | - | - | Docker mgmt |
| 178 | aglfs1 | 192.168.0.178 | - | - | File server |
| 179 | agldv03 | 192.168.0.179 | WG: 10.6.0.19, TS: 100.94.221.87 | 48GB | **Primary Dev** |
| **193** | **agl-obsidian** | **192.168.0.193** | **100.125.112.35** (`agl-obsidian-ct193`) | 2GB | **Obsidian hub 24/7** + CouchDB LiveSync + Git bridge llm-wiki — [`OBSIDIAN-CT-AGL.md`](OBSIDIAN-CT-AGL.md) |
| 185 | agldv12 | 192.168.0.185 | TS: 100.71.217.115 | - | Turbo Flow v4.0 (clone agldv03) |
| 180 | dokploy | 192.168.0.180 | - | - | Deployment |
| 202 | n8n-docker | 192.168.0.202 | - | - | Workflow automation |

#### AI & Machine Learning

| VMID | Name | IP (LAN) | IP (TS) | GPU | Purpose |
|------|------|----------|---------|-----|---------|
| 183 | archon | 192.168.0.183 | - | - | **AI Command Center** |
| 200 | ollama | 192.168.0.200 | 100.116.57.111 | — | **Descontinuado** (CT200) |
| 110 | agl-ollama | 192.168.0.200 | 100.116.57.111 | GTX 1650 | **Parada** — GPU D3cold; ver VM310 |
| 310 | agl-ollama | 192.168.15.210 | 100.67.253.52 | 2× RX580 | **Ollama primário** (AGLSRV3) |

#### Databases & Services

| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 131 | mysql | 192.168.0.131 | MySQL DB |
| 137 | redis | 192.168.0.137 | Redis cache |
| 139 | aldsys4 | 192.168.0.139 | System mgmt |
| 149 | postgresql | 192.168.0.149 | PostgreSQL |

#### Monitoring & Security

| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 132 | observium | 192.168.0.132 | Network monitoring |
| 133 | aping | 192.168.0.133 | Network testing |

#### Game Servers

| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 161 | gameserver | 192.168.0.161 | Game hosting |
| 163 | gameserver2 | 192.168.0.163 | Game hosting |
| 201 | amp-server | 192.168.0.201 | AMP game panel |

#### Caching & Performance

| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 173 | cacheng | 192.168.0.173 | Cache engine |

---

### AGLSRV6 Containers

#### Infrastructure

| VMID | Name | IP (WG/TS) | Purpose |
|------|------|------------|---------|
| 101 | cloudflared6 | TS: 100.121.95.88 · eth0 .101 · eth1 .60.101 · eth2 .1.101 | Cloudflare tunnel (aglsrv6) |
| 102 | meshcentral6 | - | Remote management |
| 114 | cloudflared6b | TS: 100.115.195.128 · eth0 .114 · eth1 .60.114 · eth2 .1.114 | Cloudflare tunnel (aglsrv6) |
| **117** | **pihole6** | **LAN: 192.168.0.117** | **Pi-hole DNS** (ex-CT115, 2026-04-04) |
| 121 | wireguard | WG: 10.6.0.3 | WireGuard node |

#### Storage & Backup

| VMID | Name | IP (WG/TS) | Purpose |
|------|------|------------|---------|
| 111 | aluzdivina | WG: 10.6.0.20, TS: 100.65.189.83 | **NFS Server** |
| 113 | pbs | WG: 10.6.0.14, TS: 100.70.155.60 | PBS backup |

#### Development

| VMID | Name | IP (TS) | Purpose |
|------|------|---------|---------|
| 108 | agldv06 | 100.71.229.12 | Development |

#### Services

| VMID | Name | Purpose |
|------|------|---------|
| 104 | luzdivina | - |
| 109 | redis6 | Redis server |
| 110 | mssql6 | SQL Server |

#### Kubernetes (Stopped)

| VMID | Name | Status | Purpose |
|------|------|--------|---------|
| 107 | kuber601 | Stopped | Kubernetes |

---

## 🔀 Connection Matrix

### From WSL2 (AGLHQ11)

**Available Networks**: Tailscale only
**Not Available**: WireGuard, Local LAN

| Target | Method | Address | Example |
|--------|--------|---------|---------|
| AGLSRV1 Host | Tailscale | 100.107.113.33 | `ssh root@100.107.113.33` |
| CT179 Dev | Tailscale | 100.94.221.87 | `ssh root@100.94.221.87` |
| CT183 Archon | SSH Jump | Via AGLSRV1 | `ssh -J root@100.107.113.33 root@192.168.0.183` |
| AGLSRV6 Host | Tailscale | 100.98.108.66 | `ssh root@100.98.108.66` |
| FGSRV6 Hub | Tailscale | 100.83.51.9 | `ssh root@100.83.51.9` |

---

### From CT179 (agldv03)

**Available Networks**: LAN, WireGuard, Tailscale (triple-stack)
**Network Priority**: WireGuard > LAN > Tailscale

| Target | Method | Address | Example |
|--------|--------|---------|---------|
| AGLSRV1 Host | LAN | 192.168.0.245 | `ssh root@192.168.0.245` |
| AGLSRV1 Host | WireGuard | 10.6.0.10 | `ssh root@10.6.0.10` |
| CT183 Archon | LAN | 192.168.0.183 | `ssh root@192.168.0.183` |
| AGLSRV6 Host | WireGuard | 10.6.0.12 | `ssh root@10.6.0.12` (FASTEST) |
| AGLSRV6 Host | Tailscale | 100.98.108.66 | `ssh root@100.98.108.66` |
| FGSRV6 Hub | WireGuard | 10.6.0.5 | `ssh root@10.6.0.5` |
| CT111 NFS | WireGuard | 10.6.0.20 | `ls /mnt/pve/ct111-shares` |

**Storage Access**:

```bash
ls /mnt/pve/fgsrv6-wg      # FGSRV6 NFS
ls /mnt/pve/ct111-shares   # CT111 NFS
ls /mnt/pve/aglsrv6-bb     # AGLSRV6 SSHFS
df -h | grep wg            # All WireGuard mounts
```

---

### From CT608 (agldv06; ex.108)

**Available Networks**: Tailscale only
**Not Available**: WireGuard (not configured)

| Target | Method | Address | Example |
|--------|--------|---------|---------|
| CT179 Dev | Tailscale | 100.94.221.87 | `ssh root@100.94.221.87` |
| AGLSRV1 Host | Tailscale | 100.107.113.33 | `ssh root@100.107.113.33` |
| AGLSRV6 Host | Local | 10.6.0.12 | Via host WireGuard |

---

### From Proxmox Hosts

**From AGLSRV1 Host**:

- Direct LAN access: 192.168.0.x
- Container console: `pct enter <VMID>`
- WireGuard mesh: 10.6.0.x
- Tailscale: 100.x.x.x

**From AGLSRV6 Host**:

- Container console: `pct enter <VMID>`
- WireGuard mesh: 10.6.0.x (PRIMARY)
- Tailscale: 100.x.x.x (fallback)

---

## 🔍 Quick Commands

### Infrastructure Status

```bash
# From any Proxmox host
pct list                    # List all containers
qm list                     # List all VMs
pvesm status               # Storage status

# From CT179 or remote
ssh root@192.168.0.245 'pct list'         # AGLSRV1
ssh root@10.6.0.12 'pct list'             # AGLSRV6 via WireGuard
```

### Network Testing

```bash
# WireGuard status
wg show                     # Show WireGuard status
wg show wg0 latest-handshakes  # Check peer connectivity

# Ping tests
ping 10.6.0.5              # FGSRV6 hub
ping 10.6.0.12             # AGLSRV6 host
ping 10.6.0.20             # CT111 NFS

# Route verification
ip route | grep wg         # WireGuard routes
ip route | grep tailscale  # Tailscale routes
```

### Storage Operations

```bash
# Check mounts
df -h | grep wg            # WireGuard storage
df -h | grep nfs           # NFS mounts
showmount -e 10.6.0.5      # FGSRV6 exports
showmount -e 10.6.0.20     # CT111 exports

# Remount if stale
umount -f /mnt/pve/fgsrv6-wg && mount -a
```

### Service Management

```bash
# Check container status
pct status <VMID>
pct enter <VMID>           # Console access

# Docker containers (from CT with Docker)
docker ps                  # List running containers
docker logs <container>    # View logs
docker-compose ps          # Compose stack status
```

---

## ☁️ Cloudflare Tunnels

### Túneis Ativos

| Tunnel | ID | Host | Status | Endpoints |
|--------|-----|------|--------|-----------|
| aglsrv1 | `f7ab6239-...` | ? | ✅ 4 conn | - |
| aglsrv5 | `02d57187-...` | AGLSRV5 (CT130) | ✅ 4 conn | - |
| **aglsrv5e** | `863fd93d-...` | **FGSRV6** (Docker) | ✅ 4 conn | n8n5e, portainer5e |
| aglsrv6 | `a00590ff-...` | ? | ✅ 8 conn | - |
| archon | `908b1097-...` | AGLSRV1 (CT117) | ✅ 4 conn | archon.aglz.io |
| **fgsrv7** | `513cec7b-...` | **FGSRV7** (CT570) | ✅ 4 conn | man7, evo, mysql-slave |
| **fgsrv7b** | `850f2d28-...` | **FGSRV7** (CT571) | ✅ 4 conn | **falg.com.br** → CT549 |

### Túneis Inativos

| Tunnel | ID | Status |
|--------|-----|--------|
| aglsrv2 | `f1fe0665-...` | ❌ Offline |
| aglsrv3 | `ca4eeb4f-...` | ❌ Offline |
| aglsrv4 | `1d44ad9b-...` | ❌ Offline |

### Comandos Rápidos

```bash
# Listar túneis (via CT117)
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel list'

# Status FGSRV6 (aglsrv5e)
ssh root@100.83.51.9 'docker ps --filter name=cloudflared'

# Status AGLSRV5 CT130 (aglsrv5)
ssh root@100.119.223.113 'pct exec 130 -- systemctl status cloudflared'

# Status AGLSRV1 CT117 (archon)
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel info archon'
```

**Documentação Completa**: `docs/CLOUDFLARE-TUNNELS.md`

---

## 📚 Related Documentation

- **PegaProx**: `docs/PEGAPROX.md` - Multi-cluster Proxmox management (CT210)
- **Main Config**: `CLAUDE.md` - Claude Code configuration
- **Archon**: `docs/archon-integration.md` - AI Command Center
- **OpenClaw**: `docs/OPENCLAW.md` - AI agent platform, multi-model config, versões
- **Claude-Flow + LiteLLM**: `docs/CLAUDE-FLOW-LITELLM.md` - Multi-model gateway, fallbacks, Claude Code
- **LiteLLM Multi-Host**: `docs/LITELLM-MULTI-HOST-DEPLOYMENT.md` - Deploy local em agldv03/04/12, fgsrv06
- **LiteLLM + OpenClaw LXC dedicados (CT186/187)**: `docs/LITELLM-OPENCLAW-DEDICATED-LXC.md` — Proxmox AGLSRV1, scripts `scripts/proxmox/` (VMIDs 150/151 no nó costumam ser VMs QEMU)
- **Ruflo Advanced**: `docs/RUFLO-ADVANCED.md` - 3-tier router, RuVector, Hive Mind, ReasoningBank (agldv03)
- **Docker in LXC**: `docs/docker-in-lxc-apparmor-solution.md`
- **WireGuard**: Various host-specific docs

---

**Document Version**: 3.0.1
**Last Updated**: 2026-05-13
**Maintainer**: Claude Code (agl-hostman project)
**Always Read**: This document should ALWAYS be read for infrastructure queries
