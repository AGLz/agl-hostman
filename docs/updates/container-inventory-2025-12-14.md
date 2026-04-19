# Container Inventory and Update Status - 2025-12-14

## Summary Statistics

- **Total Containers**: 44
- **Running**: 41
- **Stopped**: 3 (CT167, CT168, CT169 - Azure agents)
- **Containers with Docker**: 7 containers
- **Total Docker Services**: 32 services across 7 containers

## Containers by Status

### ✅ Running and Healthy (38 containers)

| CTID | Name | Docker Services | Notes |
|------|------|-----------------|-------|
| CT102 | pihole | - | DNS/DHCP |
| CT103 | portainer | 1 | Management interface |
| CT111 | tautulli | - | Plex monitoring |
| CT112 | bazarr | - | Subtitle management |
| CT113 | plexmediaserver | - | Media server |
| CT117 | cloudflared | - | Cloudflare tunnel |
| CT120 | wireguard | - | VPN mesh hub |
| CT121 | qbittorrent | - | Torrent client |
| CT122 | jackett | - | Torrent indexer |
| CT123 | radarr | - | Movie automation |
| CT124 | sonarr | - | TV automation |
| CT126 | guac | 4 | Guacamole remote desktop |
| CT131 | mysql | - | Database server |
| CT132 | observium | - | Network monitoring |
| CT133 | aping | - | API monitoring |
| CT137 | redis | - | Cache server |
| CT139 | aldsys4 | - | Legacy system |
| CT141 | sabnzbd | - | Usenet client |
| CT144 | autobrr | - | Torrent automation |
| CT149 | postgresql | - | Database server |
| CT157 | deluge | - | Torrent client |
| CT159 | nginxproxy | - | Reverse proxy |
| CT161 | gameserver | 4 | Game hosting |
| CT162 | meshcentral | - | Remote management |
| CT163 | gameserver2 | - | Game hosting |
| CT165 | aria2 | - | Download manager |
| CT170 | homarr | - | Dashboard |
| CT171 | overseerr | - | Media requests |
| CT172 | prowlarr | - | Indexer manager |
| CT173 | cacheng | - | ✅ **FIXED** - apt-cacher-ng restored |
| CT176 | iventoy | - | PXE boot server |
| CT178 | aglfs1 | - | File server |
| CT179 | agldv03 | - | Development environment |
| CT181 | agldv04 | - | Development environment |
| CT174 | agldv02 | - | Development (stopped) |
| CT201 | amp-server | - | Game panel |
| CT202 | n8n-docker | - | ✅ **RECOVERED** - Native installation |

### 🔴 Running with Known Issues (3 containers)

#### CT180 (dokploy)
- **Status**: Running
- **Docker Services**: 6 containers
- **Issue**: Portainer agent version 2.16.2 (needs update)
- **Priority**: Medium
- **Action**: Update Portainer agent to latest version

#### CT182 (harbor)
- **Status**: Running
- **Docker Services**: 2 containers
- **Issue**: PostgreSQL password authentication failed
- **Priority**: Medium
- **Action**: Reset database or clean reinstall
- **Reference**: `docs/updates/harbor-troubleshooting-notes.md`

#### CT183 (archon)
- **Status**: Running
- **Docker Services**: 13 containers
- **Issues**:
  1. Missing Supabase backend (critical)
  2. Portainer agent version 2.16.2 (needs update)
- **Priority**: High (Archon MCP tools unavailable)
- **Actions**:
  1. Deploy Supabase (cloud or self-hosted)
  2. Update Portainer agent
- **Reference**: `docs/updates/archon-troubleshooting-notes.md`

#### CT200 (ollama)
- **Status**: Running
- **Docker Services**: 2 containers (Open WebUI + removed LiteLLM)
- **Issues**:
  1. LiteLLM removed (required PostgreSQL)
  2. Portainer agent version 2.16.2 (needs update)
- **Priority**: Low (Open WebUI working as alternative)
- **Actions**:
  1. Optional: Deploy PostgreSQL and restore LiteLLM
  2. Update Portainer agent
- **Reference**: `docs/updates/litellm-troubleshooting-notes.md`

### ⏸️ Stopped Containers (3 containers)

| CTID | Name | Reason | Action Needed |
|------|------|--------|---------------|
| CT167 | az-agent1 | Azure DevOps agent | Review if still needed |
| CT168 | az-agent2 | Azure DevOps agent | Review if still needed |
| CT169 | az-agent3 | Azure DevOps agent | Review if still needed |

## Portainer Agent Update Plan

**Containers with Portainer Agent**:
- CT180 (dokploy) - Version 2.16.2
- CT183 (archon) - Version 2.16.2
- CT200 (ollama) - Version 2.16.2

**Latest Portainer Agent**: Check portainer/agent:latest tag

**Update Command** (for each container):
```bash
# CT180
ssh root@192.168.0.245 'pct exec 180 -- docker pull portainer/agent:latest && docker restart portainer_agent'

# CT183
ssh root@192.168.0.245 'pct exec 183 -- docker pull portainer/agent:latest && docker restart portainer_agent'

# CT200
ssh root@192.168.0.245 'pct exec 200 -- docker pull portainer/agent:latest && docker restart portainer_agent'
```

## Priority Actions

### 🔴 High Priority

1. **Deploy Supabase for Archon (CT183)**
   - Options:
     - Cloud: https://supabase.com (free tier available)
     - Self-hosted: Docker Compose deployment
   - Impact: Restores Archon MCP tools for task management
   - Effort: 1-2 hours

### 🟡 Medium Priority

2. **Fix Harbor PostgreSQL Authentication (CT182)**
   - Options:
     - Reset PostgreSQL password
     - Clean reinstall (loses current registry data)
   - Impact: Restores private container registry
   - Effort: 30 minutes - 2 hours

3. **Update Portainer Agents** (CT180, CT183, CT200)
   - Action: Pull latest images and restart
   - Impact: Security updates, new features
   - Effort: 15 minutes

### 🟢 Low Priority

4. **Restore LiteLLM with PostgreSQL (CT200)**
   - Optional: Deploy PostgreSQL + LiteLLM
   - Alternative: Continue using Open WebUI directly
   - Impact: Additional proxy layer (not critical)
   - Effort: 1 hour

5. **Review Azure DevOps Agents** (CT167-169)
   - Action: Determine if still needed, remove if not
   - Impact: Free up resources
   - Effort: 15 minutes

## Recent Successes

### ✅ n8n (CT202) - OPERATIONAL
- **Date**: 2025-12-14
- **Solution**: Native Node.js installation (bypassed Docker/LXC limitation)
- **Status**: Running, accessible via https://n8n.aglz.io
- **Workflows**: "AutoRespond" active
- **Documentation**: `docs/updates/n8n-native-installation-success.md`

### ✅ CacheNG (CT173) - RESTORED
- **Date**: 2025-12-14
- **Issue**: Service failed after optimization attempt
- **Solution**: Removed invalid configuration, restored to defaults
- **Status**: Running, responding on port 3142

## Container Distribution by Function

**Media Automation** (9 containers):
- CT113 (plexmediaserver), CT111 (tautulli), CT171 (overseerr)
- CT123 (radarr), CT124 (sonarr), CT112 (bazarr), CT172 (prowlarr)
- CT121 (qbittorrent), CT141 (sabnzbd), CT157 (deluge), CT165 (aria2)
- CT122 (jackett), CT144 (autobrr)

**Development** (4 containers):
- CT179 (agldv03), CT181 (agldv04), CT174 (agldv02 - stopped)
- CT180 (dokploy)

**AI/Automation** (3 containers):
- CT183 (archon), CT200 (ollama), CT202 (n8n-docker)

**Infrastructure** (8 containers):
- CT102 (pihole), CT120 (wireguard), CT117 (cloudflared)
- CT103 (portainer), CT159 (nginxproxy), CT173 (cacheng)
- CT176 (iventoy), CT178 (aglfs1)

**Databases** (3 containers):
- CT131 (mysql), CT149 (postgresql), CT137 (redis)

**Monitoring** (3 containers):
- CT132 (observium), CT133 (aping), CT162 (meshcentral)

**Registry/CI** (1 container):
- CT182 (harbor)

**Gaming** (3 containers):
- CT161 (gameserver), CT163 (gameserver2), CT201 (amp-server)

**Remote Access** (1 container):
- CT126 (guac)

**Dashboard** (1 container):
- CT170 (homarr)

**Legacy** (1 container):
- CT139 (aldsys4)

**Azure Agents** (3 containers - stopped):
- CT167, CT168, CT169

## Next Steps

1. ✅ **Complete CacheNG fix** - DONE
2. ⏸️ **Update Portainer agents** (CT180, CT183, CT200)
3. ⏸️ **Deploy Supabase for Archon** (CT183)
4. ⏸️ **Fix Harbor PostgreSQL** (CT182) or decide on clean reinstall
5. ⏸️ **Review Azure agent containers** (CT167-169)
6. ⏸️ **Optional: Deploy PostgreSQL + LiteLLM** (CT200)

## Resource Utilization

**Docker-Heavy Containers**:
- CT183 (archon): 13 services
- CT180 (dokploy): 6 services
- CT126 (guac): 4 services
- CT161 (gameserver): 4 services
- CT200 (ollama): 2 services
- CT182 (harbor): 2 services
- CT103 (portainer): 1 service

**Total Docker Services**: 32 across 7 containers

## Maintenance Schedule Recommendation

**Weekly**:
- Check Portainer agent status
- Review Docker container health
- Check disk usage on Docker-heavy containers

**Monthly**:
- Update Portainer agents
- Review and update Docker images
- Clean up unused Docker volumes/images
- Review stopped containers for removal

**Quarterly**:
- Comprehensive security updates
- Review and update all service configurations
- Backup and disaster recovery testing

---

**Generated**: 2025-12-14 23:33 UTC
**Total Containers Reviewed**: 44
**Status**: Current and accurate
**Next Review**: 2025-12-21
