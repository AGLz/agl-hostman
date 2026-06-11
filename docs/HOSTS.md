# Proxmox Hosts Detailed Configuration

> **Last Updated**: 2026-06-11 | **Version**: 1.3.0
> **Reference**: Complete host configurations, resources, and network details

---

## 📊 Host Summary

| Host | Type | Location | Status | Proxmox | Containers | Networks |
|------|------|----------|--------|---------|------------|----------|
| **AGLSRV1** | Production | AGLHQ | ✅ Active | 8.4.14 | 68 (42 running) | LAN + WG + TS |
| **AGLSRV3** | Remote | AGLFG | ✅ Active | 8.4.14 | 2 CTs | LAN + WG + TS |
| **AGLSRV5** | Remote | AGLFG | ✅ Active | 8.4.14 | 8 (7 running) | LAN + WG + TS |
| **AGLSRV6** | Remote | AGLALD | ✅ Active | TBD | 11 containers | WG + TS |
| **AGLSRV6B** | Dead | AGLALD | ❌ Dead | - | CT172 offline | ❌ None |
| **AGLSRV6C** | Remote | AGLALD | ✅ Active | 9.0 | 0 (ready) | LAN + WG + TS |
| **AGLSRV6D** | Remote | AGLALD | ✅ Active | 9.0.11 | 0 (ready) | LAN + WG + TS |
| **FGSRV3** | Cloud VPS | AGLFG-VPS | ✅ Active | TBD | TBD | Public + WG + TS |
| **FGSRV4** | Cloud VPS | AGLFG-VPS | ✅ Active | TBD | TBD | WG + TS |
| **FGSRV5** | Cloud VPS | AGLFG-VPS | ✅ Active | TBD | TBD | Public + WG + TS |
| **FGSRV6** | Cloud VPS | AGLFG-VPS | ✅ **Hub** | TBD | TBD | Public + WG + TS |

---

## 🖥️ AGLSRV1 (Main Production Host)

**Hostname**: algsrv1
**Type**: Proxmox VE Host
**Physical Location**: **AGLHQ** (Headquarters)
**Network Location**: Local LAN (192.168.0.0/24)

### Network Configuration

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN | 192.168.0.245 | vmbr0 | ✅ Primary |
| WireGuard | 10.6.0.10 | wg0 | ✅ Port 51810 |
| Tailscale | 100.107.113.33 | tailscale0 | ✅ Active |

### Resources

- **Total VMs/CTs**: 68 (42 running, 26 stopped)
- **Primary Dev Container**: CT179 (agldv03) - 48GB RAM
- **AI Infrastructure**: CT183 (archon), **CT186** (LiteLLM), **CT187** (OpenClaw); Ollama primário **VM310** (AGLSRV3, TS `100.67.253.52`); legado CT200/VM110 offline
- **Storage**:
  - local-zfs: 1.7TB
  - spark: 7.1TB (91.54% used)
  - overpower: 9.8TB (92.54% used)

### Key Services

| Category | Containers | Notes |
|----------|------------|-------|
| DNS/DHCP | CT102 (pihole) | Primary DNS server |
| Media | CT113 (plex), CT121-124 (arr stack) | Media automation |
| Development | CT179 (agldv03), CT180 (dokploy) | 48GB dev container |
| AI | CT183 (archon), CT186 (LiteLLM), CT187 (OpenClaw), CT202 (n8n); Ollama → VM310 AGLSRV3 | Gateway LLM + OpenClaw; ver `LITELLM-MODEL-TIERS.md` |
| Monitoring | CT132 (observium), CT162 (meshcentral) | Infrastructure monitoring |

### Connection Commands

```bash
# Via Tailscale (PREFERRED - from anywhere)
ssh root@100.107.113.33

# From CT179 (prefer LAN)
ssh root@192.168.0.245  # Fastest (<1ms)

# Via WireGuard (fallback - legacy)
ssh root@10.6.0.10
```

---

## 🖥️ AGLSRV3 (Proxmox VE Host)

**Hostname**: aglsrv3
**Type**: Proxmox VE 8.4.14 (pve-manager 8.4.14) on Debian 12 (bookworm)
**Physical Location**: **AGLFG** (site remoto — segmento `192.168.15.0/24`, **não** co-localizado com AGLSRV1/AGLHQ)
**Status**: ✅ **Active**

### Network Configuration

| Network | Address | Interface | Status | Purpose |
|---------|---------|-----------|--------|---------|
| Local LAN | 192.168.15.247/24 | vmbr0 | ✅ Active | LAN principal (site remoto) |
| WireGuard | 10.6.0.24/24 | wg0 | ✅ Port 51824 | Mesh connectivity |
| Tailscale | 100.123.5.81 | tailscale0 | ✅ Active | Acesso remoto (host) |

**Additional Bridges** (vmbr0–vmbr3):

| Bridge | Subnet | Notas |
|--------|--------|--------|
| vmbr1 | 192.168.30.247/24 | OVS |
| vmbr2 | 192.168.80.247/24 | OVS |
| vmbr3 | 192.168.1.247/24 | VLAN-aware |

> **Nota histórica:** documentação anterior referia `192.168.0.247/24` (AGLHQ). O host está operacional em **`192.168.15.247/24`** — mesma faixa LAN que AGLSRV5 (AGLFG), **sem rota directa** para Pi-hole AGLHQ `192.168.0.102`.

### DNS (host Proxmox)

```text
nameserver 192.168.15.102   # CT117 pihole3 (Pi-hole local)
nameserver 1.1.1.1
nameserver 8.8.8.8
search aglz.io
```

- Tailscale no host: `CorpDNS: false` (`tailscale set --accept-dns=false`) — evita MagicDNS sobrescrever `/etc/resolv.conf`.

### Hardware Specifications

- **CPU**: Intel Xeon E5-2690 v3 @ 2.60GHz (12 cores, 24 threads)
- **RAM**: 16GB
- **Kernel**: 6.8.12-15-pve (x86_64)

### Storage Configuration

| Storage | Size | Type | Status |
|---------|------|------|--------|
| local | ~96GB | Directory | ✅ ~30% used |
| local-lvm | ~330GB thin | LVM-Thin | ✅ CTs/VMs (sdf SSD sistema) |
| *(planeado)* | 4×1TB + 1×2TB HDD | ZFS | Auditoria 2026-05-30 — ver mapa |

**Mapa completo de discos** (SMART, partições, wipe/ZFS, by-id): [`docs/AGLSRV3-DISKS.md`](AGLSRV3-DISKS.md).

NFS remoto para CT178 (AGLSRV1) documentado historicamente; confirmar mounts activos com `pvesm status` no host.

### Containers & VMs

**Containers**:

| VMID | Name | LAN | Tailscale | Notas |
|------|------|-----|-----------|--------|
| **117** | **pihole3** | **192.168.15.102/24** | **aglsrv3-pihole** (join pendente até auth) | Clone vzdump de AGLSRV1 CT102 (2026-05-28); DHCP desactivado |
| 106 | cloudflared3 | — | — | Running |
| 104 | cloudflared | — | — | Stopped (lock mounted) |

**Virtual Machines**: VM101–108 (Windows / Truenas / OPNsense — maior parte stopped); **VM310** `agl-ollama` (Ollama primário, 2× RX580, TS `100.67.253.52`, LAN `192.168.15.210`) — [`AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md)

**Clone Pi-hole (2026-05-28):** `vzdump 102` no AGLSRV1 → `rsync` via Tailscale → `pct restore 117` no AGLSRV3 (`--ignore-unpack-errors`, rootfs 12G). Runbook: [`docs/AGLSRV3-PIHOLE-CLONE.md`](AGLSRV3-PIHOLE-CLONE.md). Script Tailscale: `scripts/proxmox/pct-tailscale-up-aglsrv3-pihole.sh`.

### WireGuard Configuration

**Interface**: `10.6.0.24/24`, ListenPort `51824`, hub FGSRV6 `186.202.57.120:51823`.

### Connection Commands

```bash
# Via Tailscale (PREFERRED - from anywhere)
ssh root@100.123.5.81
ssh aglsrv3

# Via LAN (site AGLFG / 192.168.15.x)
ssh root@192.168.15.247

# Via WireGuard (fallback)
ssh root@10.6.0.24

# Proxmox Web UI
https://192.168.15.247:8006   # LAN
https://100.123.5.81:8006     # Tailscale (se firewall permitir)

# Pi-hole Web UI (CT117)
http://192.168.15.102/admin
```

### Notes

- Site físico **diferente** de AGLSRV1 (AGLHQ `192.168.0.0/24`); DNS local via **CT117** (não usar `192.168.0.102` directamente).
- CT117: reset Tailscale obrigatório após clone (`aglsrv3-pihole`); nunca reutilizar identidade `aglsrv1-pihole` (`100.114.66.80`).
- WireGuard legado dentro do CT117 (clone) deve permanecer **desactivado** (`wg-quick@wg0`).

---

## 🖥️ AGLSRV6 (Secondary Host)

**Hostname**: AGLSRV6 (formerly man6)
**Type**: Proxmox VE Host
**Physical Location**: **AGLALD** (Remote site)
**Network Location**: Remote (behind WireGuard/Tailscale)

### Network Configuration

| Network | Address | Interface | Status | Purpose |
|---------|---------|-----------|--------|---------|
| Local LAN | 192.168.0.202 | vmbr0 | ✅ Active | External access |
| Proxmox Internal | 192.168.60.202 | vmbr1 | ✅ Active | Corosync/cluster |
| **Inter-host LAN** | **192.168.1.202** | **vmbr2** | ✅ **PRIMARY** | **AGLSRV6 ↔ AGLSRV6C ↔ CTs** |
| WireGuard | 10.6.0.12 | wg0 | ✅ Port 51812 | Remote access |
| Tailscale | 100.98.108.66 | tailscale0 | ✅ Active | Fallback |

### Resources

- **Containers**: 11 (CT101-114, CT121)
- **VMs**: 6 (VM100, VM103, VM105-106, VM112, VM200)
- **Storage**:
  - bb: 954GB
  - usb4tb: 3.9TB
  - PBS: 1.2TB

### Key Services

| Service | Container | Details |
|---------|-----------|---------|
| Storage | CT111 (aluzdivina) | NFS server (10.6.0.20) |
| Backup | CT113 (PBS), CT172 (PBS) | Proxmox Backup Server |
| Development | **CT608** (agldv06; ex.108) | Tailscale-only dev container |
| Infrastructure | CT101 (cloudflared), CT102 (meshcentral) | Remote access |

### Connection Commands

```bash
# Via inter-host LAN (from AGLSRV6C or containers - RECOMMENDED)
ssh root@192.168.1.202  # PRIMARY for local communication

# Via external LAN (from same location)
ssh root@192.168.0.202

# From CT179 (prefer WireGuard)
ssh root@10.6.0.12

# From WSL2 (Tailscale only)
ssh root@100.98.108.66

# Proxmox Web Interface
https://192.168.0.202:8006  # External LAN
https://192.168.1.202:8006  # Inter-host LAN
```

---

## 🖥️ AGLSRV5 (Remote Proxmox Host)

**Hostname**: aglsrv5
**Type**: Proxmox VE 8.4.14 on Debian 12 (bookworm)
**Physical Location**: **AGLFG** (Remote standalone site)
**Network Location**: Remote location (different network segment - 192.168.15.0/24)

### Network Configuration

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| LAN (Primary) | 192.168.15.222/24 | vmbr0 | ✅ Active |
| LAN (Secondary) | 172.2.2.222/24 | vmbr1 | ✅ Active |
| WireGuard | 10.6.0.17/24 | wg0 | ✅ Port 51817 |
| Tailscale | 100.119.223.113 | tailscale0 | ✅ Active |

### Hardware

- **CPU**: Intel Xeon E3-1220 v6 @ 3.00GHz (4 cores, 4 threads)
- **RAM**: 62GB (32GB used, 24GB free, 7.2GB buffers/cache)
- **Storage**: 66GB root (37GB used, 30GB free - 56%)

### Proxmox Configuration

- **Version**: 8.4.14 (release 8.4)
- **Kernel**: 6.8.12-15-pve
- **OS**: Debian GNU/Linux 12 (bookworm)
- **Status**: ✅ Fully operational

### Storage Pools

| Storage | Type | Total | Used | Available | Usage |
|---------|------|-------|------|-----------|-------|
| base | zfspool | 1.75TB | 1.23TB | 533MB | 70% PRIMARY |
| bkp | dir | 593MB | 60MB | 533MB | 10% |
| **ct138-nfs** | **nfs** | **15GB** | **1.7GB** | **12GB** | **11% NFS** |
| games | dir | 65GB | 36GB | 29GB | 55% |
| local | dir | 65GB | 36GB | 29GB | 55% |
| local-lvm | lvmthin | 130GB | 12GB | 117GB | 9% |
| shares | dir | 65GB | 36GB | 29GB | 55% |

### Containers (AGLSRV5 — VMIDs 530–540 pós-renumber 2026-06)

| VMID | Name | Status |
|------|------|--------|
| CT530 | cloudflared5 | ✅ Running |
| CT532 | plex5 | ✅ Running |
| CT533 | mesh5 | ✅ Running |
| CT534 | ipmitool5 | ✅ Running |
| CT535 | mysql5 | ✅ Running |
| CT536 | agldv05 | ✅ Running |
| CT538 | fileserver5 | ✅ Running |
| CT539 | pihole5 | ✅ Running |
| CT540 | aglsrv5-pbs | ✅ Running |

Ver mapa legado: `docs/PROXMOX-VMID-RENUMBER-2026-06.md` (ex. CT130→530, CT136→536).

### Access Methods

```bash
# Via Tailscale (PREFERRED - 20-42ms latency)
ssh root@100.119.223.113

# Via LAN (only from same network segment)
ssh root@192.168.15.222

# Via WireGuard (SSH connection closes immediately - auth issue)
ssh root@10.6.0.17  # ⚠️ Known issue - NOT RECOMMENDED
```

### Network Configuration

- Connected to WireGuard mesh via FGSRV6 hub (10.6.0.5)
- Part of different LAN segment (192.168.15.x vs 192.168.0.x)
- Tailscale provides cross-site connectivity

### Role

- Remote Proxmox VE Host with significant storage capacity (1.75TB ZFS pool)
- Runs production services: Plex, Pi-hole, file server, Cloudflare tunnel
- Development container (agldv05) available
- Part of distributed infrastructure with independent network segment

### Known Issues

- ⚠️ **SSH via WireGuard**: Authentication issues (connection established but closes)
- ✅ **Workaround**: Use Tailscale access (100.119.223.113)
- ℹ️ **Storage**: Large ZFS storage pool (base) at 70% capacity - may need monitoring

---

## 🖥️ AGLSRV6C (New Proxmox Host)

**Hostname**: man6c (alias aglsrv6c)
**Type**: Proxmox VE 9.0 Host on Debian 13 (trixie) - **✅ Fully operational**
**Physical Location**: **AGLALD** (Remote site - same as AGLSRV6)
**Network Location**: Same network as AGLSRV6 (192.168.0.0/24)
**Setup Completed**: 2025-11-08

### Network Configuration

| Network | Address | Interface | Status | Purpose |
|---------|---------|-----------|--------|---------|
| Local LAN | 192.168.0.233 | vmbr0 | ✅ Active | External access |
| **Inter-host LAN** | **192.168.1.233** | **vmbr2** | ✅ **PRIMARY** | **AGLSRV6 ↔ AGLSRV6C ↔ CTs** |
| WireGuard | 10.6.0.22 | wg0 | ✅ Port 51822 | Remote access |
| Tailscale | 100.124.53.91 | tailscale0 | ✅ Active | Fallback |

**Tailscale (2026-06):** `accept-dns=false`, `accept-routes=false`, `--ssh`; `agl-lan-routes.service` com `LAN_IF=vmbr0`. Alinhar com `scripts/proxmox/tailscale-align-proxmox-host.sh`. Ver [`troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md`](troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md).

### Hardware

- **Physical Interfaces**: eno8303 (vmbr0), eno8403 (vmbr2)
- **Boot**: Triple EFI partitions (sdb, sdc, sdd) for redundancy
- **Bootloader**: systemd-boot with proxmox-boot-tool

### Current State

- **OS**: Debian GNU/Linux (Trixie) - Proxmox VE 9.0
- **Kernel**: 6.14.11-4-pve (updated during hardening)
- **Status**: ✅ Fully configured and operational
- **Timezone**: America/Sao_Paulo (-03)

### Configuration Details

**Persistent Interface Fix**:
- systemd service (`force-interfaces-up.service`) forces eno8303/eno8403 UP on boot
- Solves issue where interfaces start DOWN despite physical cable connection
- Service runs before `networking.service` using `WantedBy=sysinit.target`

**Dual-Network Setup**:
- vmbr0 (192.168.0.233) with gateway - Primary network
- vmbr2 (192.168.1.233) no gateway - Secondary network
- DNS: Google DNS (8.8.8.8, 8.8.4.4)

**Security**:
- fail2ban active for SSH protection
- SSH hardening applied (MaxAuthTries 3, X11Forwarding disabled)
- unattended-upgrades configured for automatic security updates
- UFW firewall installed (not activated - Proxmox manages via GUI)

**Monitoring Tools**: htop, iotop, ncdu installed

### Role

- Proxmox VE Host (same location as AGLSRV6)
- Additional compute/storage capacity
- Ready for container/VM deployment
- Full mesh network integration

### WireGuard Configuration

- **PublicKey**: `Ha57VYk9mTvUgfyl0GV7EZCdwxCzCXzEwGl4L+2jFQU=`
- **PresharedKey**: Configured (host pattern, not container)
- **Connected to**: hub FGSRV6 (10.6.0.5) at 186.202.57.120:51823
- **MTU**: 1420
- **PersistentKeepalive**: 25

**Mesh Connectivity** (verified with 0% packet loss):
- FGSRV6 (10.6.0.5): 14-16ms latency
- AGLSRV1 (10.6.0.10): 29-38ms latency
- AGLSRV6 (10.6.0.12): 34-41ms latency
- CT179 (10.6.0.19): 29-40ms latency

### Access Methods

```bash
# Via Tailscale (PREFERRED - from anywhere)
ssh root@100.124.53.91

# Via inter-host LAN (from AGLSRV6 or containers)
ssh root@192.168.1.233  # Primary for local communication

# Via external LAN
ssh root@192.168.0.233

# Via WireGuard (fallback - legacy)
ssh root@10.6.0.22
```

# Via Jump Host (AGLSRV6 Tailscale)
ssh -J root@100.98.108.66 root@192.168.1.233

# Via Jump Host (AGLSRV6 WireGuard)
ssh -J root@10.6.0.12 root@192.168.1.233

# Proxmox Web Interface
https://192.168.0.233:8006  # External LAN
https://192.168.1.233:8006  # Inter-host LAN
```

### Documentation

- Complete setup guide: `/tmp/AGLSRV6C-SETUP-COMPLETE.md`
- All configuration files documented
- Troubleshooting procedures included

---

## 🖥️ AGLSRV6D (Proxmox VE Host)

**Hostname**: man6d (alias aglsrv6d)
**Type**: Proxmox VE 9.0.11 on Debian 13 (trixie) - **✅ Fully operational**
**Physical Location**: **AGLALD** (Remote site - same as AGLSRV6 and AGLSRV6C)
**Network Location**: Same network as AGLSRV6 (192.168.0.0/24)

### Network Configuration

| Network | Address | Interface | Status | Priority |
|---------|---------|-----------|--------|----------|
| Tailscale | 100.76.201.83 | tailscale0 | ✅ Active | **PRIMARY** |
| Local LAN | 192.168.0.234 | enp2s0 | ✅ Active | Secondary |
| WireGuard | 10.6.0.23 | wg0 | ✅ Port 51823 | Legacy |

**Tailscale (2026-06):** `accept-dns=false`, `accept-routes=false` (não aceita rotas de peers); **anuncia** subnet `192.168.0.0/24` como subnet router. `agl-lan-routes.service` com `LAN_IF=enp2s0`. Script: `scripts/proxmox/tailscale-align-proxmox-host.sh`.

### Hardware

- **CPU**: Intel Core i5-4590 @ 3.30GHz (4 cores, 4 threads)
- **RAM**: 8GB (7.7GB usable)
- **Storage**: 465GB SSD (456GB root + 976MB boot + 8GB swap)

### Current State

- **OS**: Proxmox VE 9.0.11 on Debian 13 (trixie)
- **Kernel**: 6.14.11-4-pve (Proxmox kernel)
- **Status**: ✅ Fully operational
- **WireGuard**: ✅ Active and connected to mesh
- **Web Interface**: https://192.168.0.234:8006 (LAN)
- **Services**: pvedaemon, pveproxy, pve-cluster all running

### Role

- Proxmox VE Host (same location as AGLSRV6)
- Additional compute/storage capacity (8GB RAM, 465GB storage)
- Ready for container/VM deployment
- Backup/failover capabilities

### WireGuard Configuration

- **PublicKey**: `d9i/Izz71+3O4t2jMwt2L5N0m5mCVjph0GzplJGzXDM=`
- **Connected to**: hub FGSRV6 (10.6.0.5)
- **Latency**: ~15-30ms to mesh nodes
- **Status**: Full mesh connectivity established

### Access Methods

```bash
# Via Tailscale (PREFERRED - from anywhere)
ssh root@100.76.201.83

# Via LAN (local only)
ssh root@192.168.0.234

# Via WireGuard (fallback - legacy)
ssh root@10.6.0.23

# Proxmox Web Interface
https://192.168.0.234:8006
```

---

## ☁️ FGSRV6 (Cloud VPS - WireGuard Hub)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Cloud Provider**: vps41772.publiccloud.com.br
**Type**: Proxmox VE Host
**Role**: **CRITICAL** - WireGuard mesh hub, NFS server

### Network Configuration

| Network | Address | Port | Status | Priority |
|---------|---------|------|--------|----------|
| Tailscale | 100.83.51.9 | - | ✅ Active | **PRIMARY** |
| Public IP | 186.202.57.120 | - | ✅ Internet | Secondary |
| WireGuard | 10.6.0.5 | 51823/UDP | ✅ **Hub** | Legacy |

### NFS Exports

- **Export**: 197GB NFSv4.2
- **Mounted on**: AGLSRV1 as `fgsrv6-wg` (10.6.0.5)

### Critical Role

- **Central routing point** for entire WireGuard mesh
- **Failure affects entire mesh** - all nodes connect through this hub
- Acts as NFS server for distributed storage

---

## ☁️ FGSRV5 (Cloud VPS)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Public IP**: 191.252.200.20
**Type**: Proxmox VE Host
**Role**: NFS server, storage backend

### Network Configuration

| Network | Address | Port | Status | Priority |
|---------|---------|------|--------|----------|
| Tailscale | 100.71.107.26 | - | ✅ Active | **PRIMARY** |
| Public IP | 191.252.200.20 | - | ✅ Internet | Secondary |
| WireGuard | 10.6.0.11 | 51811/UDP | ✅ Active | Legacy |

### NFS Exports

- **Export**: 77GB NFSv4.2
- **Mounted on**: AGLSRV1 as `fgsrv5-wg` (10.6.0.11)

### Known Issues

- ⚠️ SSH timeout issues reported
- ✅ WireGuard connectivity working

---

## ☁️ FGSRV4 (Cloud VPS)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Cloud Provider**: vps22826.publiccloud.com.br
**Type**: Proxmox VE Host

### Network Configuration

| Network | Address | Port | Status | Priority |
|---------|---------|------|--------|----------|
| Tailscale | 100.111.79.2 | - | ✅ Active | **PRIMARY** |
| WireGuard | 10.6.0.16 | 51816/UDP | ✅ Active | Legacy |

### Access

- **User**: sysadmin

---

## ☁️ FGSRV3 (Cloud VPS)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Public IP**: 191.252.201.205
**Type**: Proxmox VE Host

### Network Configuration

| Network | Address | Port | Status | Priority |
|---------|---------|------|--------|----------|
| Tailscale | 100.67.99.115 | - | ✅ Active | **PRIMARY** |
| Public IP | 191.252.201.205 | - | ✅ Internet | Secondary |
| WireGuard | 10.6.0.18 | 51818/UDP | ✅ Active | Legacy |

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md` - Complete infrastructure overview
- **Network Topology**: `TOPOLOGY.md` - Physical locations and network architecture
- **Proxmox Installation**: `PROXMOX.md` - Installation standards and requirements
- **WireGuard Mesh**: `WIREGUARD.md` - Mesh configuration details
- **Containers**: `CONTAINERS.md` - Complete container inventory
- **Storage**: `STORAGE.md` - Storage configuration and NFS mounts
- **Connections**: `CONNECTIONS.md` - Connection priorities and access patterns

---

**Document Version**: 1.1.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)

**Version Notes**:
- **v1.1.0** (2025-11-08): Added complete network configurations for AGLSRV5 (dual LAN) and AGLSRV6 (triple network)
