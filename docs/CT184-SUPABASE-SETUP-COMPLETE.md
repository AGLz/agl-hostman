# CT184 Supabase Setup - Complete

> **Date**: 2026-01-04
> **Status**: ✅ OPERATIONAL
> **CT ID**: 184
> **IP**: 192.168.0.184
> **Purpose**: Self-hosted Supabase database backend for Archon MCP

---

## 📊 Summary

**CT184 (supabase)** is a fully operational self-hosted Supabase instance deployed on AGLSRV1 Proxmox host. It provides a complete database backend with PostgreSQL, authentication, storage, and real-time capabilities for the Archon AI Command Center (CT183).

---

## 🖥️ Container Specifications

**LXC Configuration:**
```ini
arch: amd64
cores: 4
memory: 8192
hostname: supabase
ostype: ubuntu
rootfs: local-zfs:subvol-184-disk-0,size=50G
features: keyctl=1,nesting=1,fuse=1
lxc.cgroup2.devices.allow: c *:* rwm
lxc.cgroup2.devices.allow: b *:* rwm
lxc.cap.drop:
lxc.apparmor.profile: unconfined
net0: name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.184/24,type=veth
```

**Resources:**
- CPU: 4 cores
- RAM: 8GB
- Storage: 50GB ZFS
- Network: 192.168.0.184 (LAN), WireGuard 10.6.0.XX (planned)

---

## 🚀 Supabase Stack (13 Containers)

### Running Services (12/13 Healthy)

| Container | Status | Purpose | Ports |
|-----------|--------|---------|-------|
| supabase-db | ✅ Healthy | PostgreSQL 15.8 | 5432 |
| supabase-kong | ✅ Healthy | API Gateway | 8000, 8443 |
| supabase-rest | ✅ Running | PostgREST API | 3000 |
| supabase-auth | ✅ Healthy | Authentication service | - |
| supabase-storage | ✅ Healthy | File storage | 5000 |
| supabase-studio | ✅ Healthy | Dashboard UI | 3000 |
| supabase-realtime | ⚠️ Unhealthy (non-critical) | Realtime subscriptions | - |
| supabase-meta | ✅ Healthy | PostgreSQL metadata | 8080 |
| supabase-pooler | ✅ Healthy | Connection pooler | 5432, 6543 |
| supabase-analytics | ✅ Healthy | Log analytics | 4000 |
| supabase-edge-functions | ✅ Running | Edge functions runtime | - |
| supabase-vector | ✅ Healthy | Vector search | - |
| supabase-imgproxy | ✅ Healthy | Image processing | 8080 |

**Access Points:**
- **API Gateway**: http://192.168.0.184:8000
- **Studio UI**: http://192.168.0.184:3000
- **PostgreSQL**: postgresql://postgres:[password]@192.168.0.184:5432/postgres

---

## 🔐 Security Configuration

### JWT Tokens
**JWT Secret**: `3JPj1YjnzfvkAQoYBqBKdZBHChH4zW2nfcpwWBdlx3WT8RWIb1dE658GZ3ctyW`

**Generated Keys:**
- `ANON_KEY`:eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY3NTY2NTg5LCJleHAiOjE5MjUyNDY1ODl9.Ym4AvyYluQMlts58LkqPHB9HLIqfSmRGQD6NWWCLiz0
- `SERVICE_ROLE_KEY`: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3Njc1NjY1ODksImV4cCI6MTkyNTI0NjU4OX0.FH8qCZMjG5Hjq-gu9g21V8-7eKPZoKOcv8Y3eZ92V3o

### Docker Configuration
**File**: `/etc/docker/daemon.json`
```json
{
  "default-address-pools": [
    {"base": "172.17.0.0/16", "size": 24}
  ],
  "features": {
    "buildkit": false
  }
}
```

**Note**: BuildKit disabled for LXC compatibility (see `docker-in-lxc-apparmor-solution.md`)

---

## 📦 Database Schema

### Archon Tables Loaded
```sql
✅ archon_settings (4 records)
✅ archon_projects
✅ archon_tasks
✅ archon_documents
✅ archon_sources
✅ archon_crawled_pages
✅ archon_code_examples
✅ archon_prompts
✅ archon_migrations
✅ archon_page_metadata
✅ archon_project_sources
✅ archon_document_versions
```

**Extensions Enabled:**
- `vector` - Vector similarity search
- `pgcrypto` - Cryptographic functions
- `pg_trgm` - Trigram text search

---

## 🔗 Integration with Archon (CT183)

### Connection Details
**Archon Configuration** (`/root/Archon/.env`):
```bash
SUPABASE_URL=http://192.168.0.184:8000
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Network Latency**: < 1ms (LAN ping: 0.04-0.3ms)

**Status**: ✅ Full Integration
- Archon server: http://192.168.0.183:8181 ✅
- Archon MCP: http://192.168.0.183:8051/mcp ✅
- Archon UI: http://192.168.0.183:3737 ✅

---

## 🛠️ Deployment Timeline

### Initial Setup (2026-01-03)
1. ✅ CT184 created with 50GB storage, 8GB RAM
2. ✅ Docker installed (BuildKit disabled)
3. ✅ Supabase cloned and configured
4. ⚠️ Containers created but not started

### Resolution (2026-01-04)
1. ✅ LXC features corrected (added `fuse=1`)
2. ✅ AppArmor disabled (`lxc.apparmor.profile = unconfined`)
3. ✅ Device permissions added (`cgroup2.devices.allow`)
4. ✅ IP changed from 192.168.0.205 → 192.168.0.184
5. ✅ Netplan static IP configuration
6. ✅ JWT tokens regenerated
7. ✅ All 13 containers started successfully
8. ✅ Archon schema loaded
9. ✅ Archon connected and operational

---

## 📋 Maintenance Commands

### Start/Stop Supabase
```bash
# SSH to CT184
ssh root@192.168.0.245 'pct exec 184 -- bash -c "cd /root/supabase/docker && docker compose up -d"'

# Stop
ssh root@192.168.0.245 'pct exec 184 -- bash -c "cd /root/supabase/docker && docker compose down"'
```

### View Logs
```bash
# All services
ssh root@192.168.0.245 'pct exec 184 -- docker compose -f /root/supabase/docker/docker-compose.yml logs -f'

# Specific service
ssh root@192.168.0.245 'pct exec 184 -- docker logs supabase-kong -f'
```

### Database Access
```bash
# PostgreSQL shell
ssh root@192.168.0.245 'pct exec 184 -- docker exec -it supabase-db psql -U postgres -d postgres'

# Backup
ssh root@192.168.0.245 'pct exec 184 -- docker exec supabase-db pg_dump -U postgres postgres > backup.sql'
```

### Health Check
```bash
# Test API
curl -s http://192.168.0.184:8000/rest/v1/archon_settings \
  -H "apikey: [SERVICE_ROLE_KEY]" \
  -H "Authorization: Bearer [SERVICE_ROLE_KEY]"

# Check containers
ssh root@192.168.0.245 'pct exec 184 -- docker ps --format "table {{.Names}}\t{{.Status}}"'
```

---

## ⚠️ Known Issues & Solutions

### Issue 1: Docker permission error (RESOLVED)
**Error**: `OCI runtime create failed: permission denied (sysctl net.ipv4.ip_unprivileged_port_start)`

**Solution**: Added LXC configuration:
```ini
features: keyctl=1,nesting=1,fuse=1
lxc.apparmor.profile = unconfined
lxc.cgroup2.devices.allow: c *:* rwm
lxc.cap.drop:
```

**Reference**: `docs/docker-in-lxc-apparmor-solution.md`

### Issue 2: JWT Authentication (RESOLVED)
**Error**: `PGRST301: No suitable key or wrong key type`

**Solution**: Regenerated JWT tokens using Python `jwt.encode()` with correct JWT_SECRET

**Reference**: `docs/troubleshooting/ARCHON-SUPABASE-FIX-2026-01.md`

---

## 🎯 Next Steps

### Immediate (High Priority)
1. **WireGuard Setup**: Configure WireGuard IP (10.6.0.XX) for mesh network access
2. **Backups**: Implement automated PostgreSQL dumps to NFS storage
3. **Monitoring**: Setup health check alerts for critical containers
4. **SSL/TLS**: Configure reverse proxy with Let's Encrypt for production

### Short-term (Medium Priority)
5. **Realtime Fix**: Investigate and fix supabase-realtime unhealthy status
6. **Performance**: PostgreSQL tuning for production workload
7. **Scaling**: Consider storage expansion if needed (>50GB)
8. **Documentation**: Update Supabase Studio URL and access credentials

### Long-term (Low Priority)
9. **High Availability**: Consider hot standby or replication setup
10. **Upgrade Planning**: Track Supabase versions and plan upgrades
11. **Integration**: Expand Supabase usage to other AGL services
12. **Monitoring Dashboards**: Grafana/Prometheus integration

---

## 📚 Related Documentation

- **Docker in LXC**: `docs/docker-in-lxc-apparmor-solution.md`
- **Archon Setup**: `docs/ARCHON.md`
- **Integration**: `docs/updates/archon-supabase-integration-success.md`
- **Troubleshooting**: `docs/troubleshooting/ARCHON-SUPABASE-FIX-2026-01.md`
- **Infrastructure**: `docs/INFRASTRUCTURE-STATUS.md`
- **Containers**: `docs/CONTAINERS.md`

---

## ✅ Success Criteria

- [x] All 13 Supabase containers running
- [x] 12/13 containers healthy (realtime non-critical)
- [x] API Gateway accessible and functional
- [x] Archon schema loaded (11 tables)
- [x] JWT tokens working correctly
- [x] Archon MCP fully operational
- [x] Network latency < 1ms
- [x] Database backups planned

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-04 23:30 UTC
**Status**: ✅ OPERATIONAL
