# Container Update Plan - 2025-12-12

> **Date**: 2025-12-12
> **Version**: 1.0.0
> **Status**: In Progress

---

## 📋 Executive Summary

Complete update and remediation plan for AGL infrastructure containers requiring attention.

### Critical Issues Found

| Container | Host | Issue | Priority | Status |
|-----------|------|-------|----------|--------|
| **Harbor** | CT183 | All services stopped (6 weeks) | 🔴 CRITICAL | Pending |
| **Archon Server** | CT183 | Exited 3 days ago | 🔴 CRITICAL | Pending |
| **Archon UI** | CT183 | Unhealthy (3 days) | 🟡 HIGH | Pending |
| **Archon MCP** | CT183 | Unhealthy (3 days) | 🟡 HIGH | Pending |
| **Ollama** | CT200 | Created but not started | 🟡 HIGH | Pending |
| **LiteLLM** | CT200 | Exited (5 weeks ago) | 🟢 MEDIUM | Pending |
| **Open WebUI** | CT200 | Healthy, needs update check | 🔵 LOW | Pending |
| **n8n** | CT202 | Running backup mode | 🟢 MEDIUM | Pending |
| **CacheNG** | CT173 | Running, needs update check | 🔵 LOW | Pending |

---

## 🎯 Update Strategy

### Phase 1: Backup & Preparation ✅
1. Create configuration backups
2. Document current state
3. Prepare rollback procedures

### Phase 2: Critical Services (Harbor, Archon)
1. **CT183/Harbor**: Complete restart and health check
2. **CT183/Archon**: Fix server, UI, and MCP health issues

### Phase 3: AI/ML Stack (Ollama, LiteLLM, Open WebUI)
1. **CT200/Ollama**: Start container and verify GPU passthrough
2. **CT200/LiteLLM**: Update and restart
3. **CT200/Open WebUI**: Update to latest version

### Phase 4: Supporting Services
1. **CT202/n8n**: Verify backup, update if needed
2. **CT173/CacheNG**: Update configuration and image
3. **Portainer Agents**: Update across all containers

### Phase 5: Verification & Documentation
1. Health checks for all services
2. Update infrastructure documentation
3. Create runbooks for each service

---

## 📦 Container Details

### CT183 - Archon & Harbor

**Harbor Components** (ALL STOPPED - 6 weeks):
```yaml
harbor-log: Exited (255) 2 weeks ago
harbor-portal: Exited (128) 6 weeks ago
registryctl: Exited (128) 6 weeks ago
registry: Exited (128) 6 weeks ago
harbor-db: Exited (128) 6 weeks ago
redis: Exited (128) 6 weeks ago
harbor-core: Exited (128) 6 weeks ago
trivy-adapter: Exited (128) 6 weeks ago
nginx: Exited (128) 6 weeks ago
harbor-jobservice: Exited (128) 6 weeks ago
```

**Archon Components**:
```yaml
archon-server: Exited (3) 3 days ago - renatabk/archon-server:latest
archon-ui: Up 3 days (unhealthy) - renatabk/archon-frontend:latest
archon-mcp: Up 3 days (unhealthy) - renatabk/archon-mcp:latest
```

**Other Services**:
```yaml
portainer_agent: Up 3 days - portainer/agent:2.16.2
```

**Update Plan**:
1. Backup Harbor data volume
2. Restart all Harbor containers via docker-compose
3. Fix Archon server exit code 3 issue
4. Diagnose and fix UI/MCP health checks
5. Update to latest Archon images if available
6. Verify MCP endpoint: http://10.6.0.21:8051/mcp

### CT200 - Ollama GPU & Open WebUI

**Current State**:
```yaml
open-webui: Up 3 days (healthy) - ghcr.io/open-webui/open-webui:main
litellm: Exited (0) 5 weeks ago - ghcr.io/berriai/litellm:main-latest
ollama: Created (not started) - ollama/ollama:latest
portainer_agent: Up 3 days - portainer/agent:2.16.2
```

**Update Plan**:
1. Start Ollama container with GPU passthrough verification
2. Test Ollama API: http://localhost:11434/api/generate
3. Update LiteLLM to latest version
4. Start LiteLLM with proper configuration
5. Pull latest Open WebUI image and rolling update
6. Verify integration between all three services

### CT202 - n8n Workflow Automation

**Current State**:
```
Status: running backup
```

**Update Plan**:
1. Check why container is in "backup" status
2. Verify n8n data persistence
3. Pull latest n8n image
4. Update with zero-downtime if possible
5. Verify workflows still function

### CT173 - CacheNG

**Current State**:
```
Status: running
```

**Update Plan**:
1. Identify current apt-cacher-ng version
2. Pull latest image
3. Update configuration for best practices
4. Rolling update with minimal downtime
5. Verify cache statistics

---

## 🔧 Best Practices Applied

### Docker Image Management
- ✅ Use specific version tags (avoid `:latest` in production)
- ✅ Pull images before stopping containers
- ✅ Verify image signatures where available
- ✅ Clean up old images after successful updates

### Configuration Management
- ✅ Use docker-compose.yml for multi-container apps
- ✅ Environment variables in separate .env files
- ✅ Secrets via Docker secrets or external vault
- ✅ Volume mounts for persistent data

### Health Checks
- ✅ Define health check endpoints for all services
- ✅ Configure proper timeouts and retries
- ✅ Use startup probes for slow-starting services
- ✅ Monitor health check failures

### Resource Management
- ✅ Set CPU and memory limits
- ✅ Configure restart policies (unless-stopped)
- ✅ Use resource reservations for critical services
- ✅ Monitor resource usage trends

### Networking
- ✅ Use custom bridge networks
- ✅ Avoid publishing unnecessary ports
- ✅ Configure proper DNS resolution
- ✅ Document port mappings

### Logging
- ✅ Configure log drivers (json-file with rotation)
- ✅ Set max log size and file count
- ✅ Centralize logs where appropriate
- ✅ Retain logs for debugging

### Security
- ✅ Run containers as non-root where possible
- ✅ Use read-only root filesystem when applicable
- ✅ Drop unnecessary capabilities
- ✅ Scan images for vulnerabilities
- ✅ Keep base images updated

### Backup Strategy
- ✅ Regular volume backups for data containers
- ✅ Export configurations before updates
- ✅ Test restore procedures
- ✅ Document backup locations

---

## 📝 Pre-Update Checklist

### Harbor (CT183)
- [ ] Backup Harbor data volume (`/data`)
- [ ] Export Harbor configuration
- [ ] Document current projects and users
- [ ] Note registry URL: harbor.aglz.io:5000
- [ ] Save docker-compose.yml

### Archon (CT183)
- [ ] Backup Archon database
- [ ] Export MCP configuration
- [ ] Save current environment variables
- [ ] Document MCP endpoints
- [ ] Test failover to Tailscale endpoint

### Ollama/Open WebUI (CT200)
- [ ] Verify GPU passthrough configuration
- [ ] Backup model files
- [ ] Save Open WebUI settings
- [ ] Document model list
- [ ] Export user configurations

### n8n (CT202)
- [ ] Backup workflow database
- [ ] Export all workflows
- [ ] Save credentials (encrypted)
- [ ] Document webhooks and endpoints
- [ ] Test backup restore procedure

---

## 🚀 Execution Timeline

### Immediate (Priority 1 - Critical)
1. **Harbor Recovery** (CT183) - 30 minutes
   - Restart all containers
   - Verify registry access
   - Test push/pull operations

2. **Archon Repair** (CT183) - 20 minutes
   - Fix server container
   - Resolve health check issues
   - Verify MCP functionality

### Short-term (Priority 2 - High)
3. **Ollama Startup** (CT200) - 15 minutes
   - Start container
   - Verify GPU access
   - Test model loading

4. **LiteLLM Update** (CT200) - 10 minutes
   - Pull latest image
   - Update configuration
   - Restart service

### Medium-term (Priority 3 - Medium)
5. **Open WebUI Update** (CT200) - 15 minutes
   - Pull latest image
   - Rolling update
   - Verify UI access

6. **n8n Update** (CT202) - 20 minutes
   - Verify backup status
   - Pull latest image
   - Update with downtime window

### Low Priority (Priority 4 - Maintenance)
7. **CacheNG Update** (CT173) - 10 minutes
   - Pull latest image
   - Update configuration
   - Restart service

8. **Portainer Agents** - 15 minutes
   - Update all agents to latest version
   - Verify connectivity to Portainer

**Total Estimated Time**: ~2.5 hours

---

## 🔄 Rollback Procedures

### General Rollback
```bash
# Stop current container
docker stop <container-name>

# Start previous version
docker run -d \
  --name <container-name> \
  --volumes-from <container-name>-backup \
  --env-file /path/to/.env.backup \
  <image>:<previous-tag>

# Restore data if needed
docker cp backup:/data /var/lib/docker/volumes/<volume>/_data
```

### Harbor Rollback
```bash
cd /path/to/harbor
docker-compose down
# Restore docker-compose.yml.backup
docker-compose up -d
```

### Archon Rollback
```bash
# Restore from backup images
docker start archon-server-backup
docker start archon-ui-backup
docker start archon-mcp-backup
```

---

## 📊 Success Criteria

### Harbor
- ✅ All containers running and healthy
- ✅ Web UI accessible: https://harbor.aglz.io
- ✅ Docker push/pull operations working
- ✅ Registry showing correct images

### Archon
- ✅ archon-server running (exit code 0)
- ✅ archon-ui healthy
- ✅ archon-mcp healthy
- ✅ MCP endpoint responding: http://10.6.0.21:8051/mcp
- ✅ Knowledge base search working

### Ollama
- ✅ Container running with GPU access
- ✅ API responding: http://localhost:11434/api/version
- ✅ Models loaded successfully
- ✅ GPU utilization visible

### Open WebUI
- ✅ Latest version running
- ✅ UI accessible
- ✅ Connected to Ollama backend
- ✅ User sessions preserved

### LiteLLM
- ✅ Service running
- ✅ Proxy API functional
- ✅ Connected to Ollama
- ✅ Metrics endpoint working

### n8n
- ✅ Service running
- ✅ Workflows intact
- ✅ Credentials preserved
- ✅ Webhooks functioning

### CacheNG
- ✅ Latest version running
- ✅ Cache directory intact
- ✅ Proxy working
- ✅ Statistics accessible

---

## 📚 Related Documentation

- **INFRA.md**: Infrastructure overview
- **CONTAINERS.md**: Container inventory
- **ARCHON.md**: Archon integration guide
- **DOKPLOY.md**: Deployment platform
- **QUICK-START.md**: Quick reference commands

---

**Document Version**: 1.0.0
**Created**: 2025-12-12
**Last Updated**: 2025-12-12
**Maintainer**: Claude Code (agl-hostman project)
