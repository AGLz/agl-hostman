# Container Inventory

> **Last Updated**: 2026-06-11 | **Version**: 1.4.0
> **Reference**: Complete inventory of containers across all Proxmox hosts

---

## 📊 Container Summary by Host

| Host | Total CTs | Running | Stopped | Key Services |
|------|-----------|---------|---------|--------------|
| **AGLSRV1** | 70 | 44 | 26 | Development, AI, DNS, Monitoring, Database |
| **AGLSRV3** | 2+ | 2 | 1+ | DNS (Pi-hole clone), Cloudflare |
| **AGLSRV5** | 8 | 7 | 1 | Media, File Server, Cloudflare |
| **AGLSRV6** | 11 | - | - | NFS, Development, PBS |

---

## 🖥️ AGLSRV1 Containers (69 Total, 43 Running)

### Infrastructure & Network

| ID | Name | Purpose | Status | Key Services |
|----|------|---------|--------|--------------|
| CT102 | pihole | DNS/DHCP | ✅ | Pi-hole DNS server |
| CT162 | meshcentral | Remote Management | ✅ | MeshCentral |
| CT132 | observium | Monitoring | ✅ | Network monitoring |

### Development

| ID | Name | Purpose | Status | Resources |
|----|------|---------|--------|-----------|
| **CT179** | agldv03 | Main Development | ✅ | 48GB RAM, SuperClaude, TS 100.94.221.87 (PRIMARY), WG 10.6.0.19 (legacy) |
| **CT180** | dokploy | Deployment Platform | ✅ | 8 cores, 16GB RAM, WG 10.6.0.47 (legacy), https://dok.aglz.io |
| **CT181** | agldv04 | Secondary Development | ✅ | 48GB RAM, SuperClaude ✨, 13 MCPs, TS 100.113.9.98 (PRIMARY), WG 10.6.0.24 (legacy) |

### AI & Machine Learning

| ID | Name | Purpose | Status | Key Services |
|----|------|---------|--------|--------------|
| **CT183** | archon | AI Command Center | ✅ | Archon MCP server (28 tools), WG 10.6.0.21, API: http://192.168.0.183:8051/mcp |
| **CT184** | supabase | Self-Hosted Database | ✅ | Supabase stack (13 containers), PostgreSQL, Kong API, http://192.168.0.184:8000 |
| **CT186** | agl-litellm | LiteLLM Gateway | ✅ | Docker `/opt/agl-litellm`, TS `100.125.249.8:4000`, LAN `192.168.0.186:4000` |
| **CT187** | agl-openclaw | OpenClaw (Jarvis) | ✅ | Gateway produção; modelos via CT186 |
| **CT200** | ollama | GPU Inference | ⏸️ | **Descontinuado** — substituído por VM110/VM310 |
| **VM110** | agl-ollama | Ollama (legado) | ⏸️ | GTX 1650, `192.168.0.200` — **parada** (GPU D3cold) |
| **CT202** | n8n | Workflow Automation | ✅ | n8n workflows |

### Media Services

| ID | Name | Purpose | Status |
|----|------|---------|--------|
| CT113 | plexmediaserver | Media Server (Plex) | ✅ |
| CT121 | qbittorrent | Torrent client | ✅ |
| CT122 | jackett | Indexer (legado) | ✅ |
| CT123 | radarr | Movies | ✅ |
| CT124 | sonarr | TV Shows | ✅ |
| CT172 | prowlarr | Indexer Manager | ✅ |

Ver [`MEDIA-ARR-STACK-AGL.md`](MEDIA-ARR-STACK-AGL.md) para o stack completo (Overseerr, Bazarr, SABnzbd, Autobrr, etc.).

---

## 🖥️ AGLSRV3 Containers (site AGLFG — LAN 192.168.15.0/24)

| ID | Name | Purpose | Status | Networks | Notes |
|----|------|---------|--------|----------|-------|
| **317** | **pihole3** | **DNS (Pi-hole)** | ✅ | LAN **192.168.15.117**, TS **`aglsrv3-pihole`** | Clone AGLSRV1 CT102 |
| **304** | **cloudflared3a** | Cloudflare Tunnel | ✅ | `.15.104` + `.30.104` | Túnel `aglsrv3` (HA) |
| **306** | **cloudflared3b** | Cloudflare Tunnel | ✅ | `.15.106` + `.30.106` | Túnel `aglsrv3` (HA) |
| **318** | **aglsrv3-pbs** | PBS | ✅ | `.15.118` + `.30.118` | Backups locais |
| **338** | **aglfs3** | File server | ✅ | `.15.138` + `.30.138` | NFS/SMB |

**Host DNS:** `192.168.15.117` (CT317) → `1.1.1.1` / `8.8.8.8` — ver `HOSTS.md`.

### VMs (AGLSRV3)

| ID | Name | Purpose | Status | Networks | Notes |
|----|------|---------|--------|----------|-------|
| **310** | **agl-ollama** | **Ollama primário** | ✅ | LAN `192.168.15.210`, TS **`100.67.253.52:11434`** | 2× RX580, Vulkan; ver [`AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md) |

---

## 🌐 AGLSRV5 Containers (8 Total, 7 Running)

| ID | Name | Purpose | Status | Networks | Notes |
|----|------|---------|--------|----------|-------|
| CT130 | cloudflared5 | Cloudflare Tunnel | ✅ | - | Remote access |
| CT132 | plex5 | Media Server | ✅ | - | Local media streaming |
| CT133 | mesh5 | Remote Management | ✅ | - | MeshCentral |
| **CT138** | **fileserver5** | **NFS Server** | ✅ | **LAN 192.168.15.100, Internal 172.2.2.138, WG 10.6.0.51** | **NFS exports to 3 networks** |
| CT139 | pihole5 | DNS/DHCP | ✅ | - | Local DNS |

---

## 📦 AGLSRV6 Containers (11 Total)

### Key Containers

| ID | Name | Purpose | Status | Networks (Priority Order) |
|----|------|---------|--------|---------------------------|
| **CT111** | aluzdivina | NFS Server | ✅ | TS 100.65.189.83 (PRIMARY), WG 10.6.0.20 (legacy) |
| **CT608** | agldv06 | Development | ✅ | Tailscale only (ex.108) |
| **CT113** | - | Proxmox Backup | ✅ | WG 10.6.0.14 (legacy) |
| **CT172** | - | Proxmox Backup | ⚠️ | Host AGLSRV6B offline |

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md`
- **Hosts Details**: `HOSTS.md`
- **Storage Configuration**: `STORAGE.md`
- **Network Topology**: `TOPOLOGY.md`

---

**Document Version**: 1.4.0
**Last Updated**: 2026-06-11
**Maintainer**: Claude Code (agl-hostman project)

**Recent Changes:**
- ✅ VM310 `agl-ollama` — Ollama primário AGLSRV3 (2× RX580, TS `100.67.253.52`)
- ✅ CT186/187 LiteLLM + OpenClaw canónico; CT200/VM110 Ollama legado offline
- ✅ Added CT184 (supabase) - Self-hosted Supabase with 13 containers
- ✅ CT183 (archon) - Fully operational with MCP connected to CT184
- ✅ Integration complete: Archon MCP + Supabase self-hosted
