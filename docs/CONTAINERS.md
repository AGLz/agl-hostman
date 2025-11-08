# Container Inventory

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0
> **Reference**: Complete inventory of containers across all Proxmox hosts

---

## 📊 Container Summary by Host

| Host | Total CTs | Running | Stopped | Key Services |
|------|-----------|---------|---------|--------------|
| **AGLSRV1** | 68 | 42 | 26 | Development, AI, DNS, Monitoring |
| **AGLSRV5** | 8 | 7 | 1 | Media, File Server, Cloudflare |
| **AGLSRV6** | 11 | - | - | NFS, Development, PBS |

---

## 🖥️ AGLSRV1 Containers (68 Total, 42 Running)

### Infrastructure & Network

| ID | Name | Purpose | Status | Key Services |
|----|------|---------|--------|--------------|
| CT102 | pihole | DNS/DHCP | ✅ | Pi-hole DNS server |
| CT162 | meshcentral | Remote Management | ✅ | MeshCentral |
| CT132 | observium | Monitoring | ✅ | Network monitoring |

### Development

| ID | Name | Purpose | Status | Resources |
|----|------|---------|--------|-----------|
| **CT179** | agldv03 | Main Development | ✅ | 48GB RAM, WireGuard mesh |
| **CT180** | dokploy | Deployment Platform | ✅ | https://dok.aglz.io |

### AI & Machine Learning

| ID | Name | Purpose | Status | Key Services |
|----|------|---------|--------|--------------|
| **CT183** | archon | AI Command Center | ✅ | Archon MCP server, WG 10.6.0.21 |
| **CT200** | ollama-gpu | GPU Inference | ✅ | Ollama with GPU passthrough |
| **CT202** | n8n | Workflow Automation | ✅ | n8n workflows |

### Media Services

| ID | Name | Purpose | Status |
|----|------|---------|--------|
| CT113 | plex | Media Server | ✅ |
| CT121 | sonarr | TV Shows | ✅ |
| CT122 | radarr | Movies | ✅ |
| CT123 | prowlarr | Indexer Manager | ✅ |
| CT124 | jellyfin | Media Server | ✅ |

---

## 🌐 AGLSRV5 Containers (8 Total, 7 Running)

| ID | Name | Purpose | Status | Notes |
|----|------|---------|--------|-------|
| CT130 | cloudflared5 | Cloudflare Tunnel | ✅ | Remote access |
| CT132 | plex5 | Media Server | ✅ | Local media streaming |
| CT133 | mesh5 | Remote Management | ✅ | MeshCentral |
| CT138 | fileserver5 | File Server | ✅ | Shared storage |
| CT139 | pihole5 | DNS/DHCP | ✅ | Local DNS |

---

## 📦 AGLSRV6 Containers (11 Total)

### Key Containers

| ID | Name | Purpose | Status | Networks |
|----|------|---------|--------|----------|
| **CT111** | aluzdivina | NFS Server | ✅ | WG 10.6.0.20, TS 100.65.189.83 |
| **CT108** | agldv06 | Development | ✅ | Tailscale only |
| **CT113** | - | Proxmox Backup | ✅ | WG 10.6.0.14 |
| **CT172** | - | Proxmox Backup | ⚠️ | Host AGLSRV6B offline |

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md`
- **Hosts Details**: `HOSTS.md`
- **Storage Configuration**: `STORAGE.md`
- **Network Topology**: `TOPOLOGY.md`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)
