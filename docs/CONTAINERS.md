# Container Inventory

> **Last Updated**: 2026-05-28 | **Version**: 1.3.0
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
| **CT200** | ollama | GPU Inference | ✅ | Ollama with GPU passthrough |
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
| **117** | **pihole3** | **DNS (Pi-hole)** | ✅ | LAN **192.168.15.102**, TS **`aglsrv3-pihole`** (NeedsLogin) | Clone vzdump AGLSRV1 CT102 (2026-05-28); ver [`AGLSRV3-PIHOLE-CLONE.md`](AGLSRV3-PIHOLE-CLONE.md) |
| 106 | cloudflared3 | Cloudflare Tunnel | ✅ | — | Running |
| 104 | cloudflared | Cloudflare Tunnel | ⏸️ | — | Stopped |

**Host DNS:** `192.168.15.102` (CT117) → `1.1.1.1` / `8.8.8.8` — ver `HOSTS.md`.

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

**Document Version**: 1.3.0
**Last Updated**: 2026-05-28
**Maintainer**: Claude Code (agl-hostman project)

**Recent Changes:**
- ✅ AGLSRV3 CT117 `pihole3` — clone Pi-hole cross-site (2026-05-28)
- ✅ Added CT184 (supabase) - Self-hosted Supabase with 13 containers
- ✅ CT183 (archon) - Fully operational with MCP connected to CT184
- ✅ Integration complete: Archon MCP + Supabase self-hosted
