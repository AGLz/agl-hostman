# CT183 Startup Guide - Supabase + Archon

**Host**: CT183 (192.168.0.183)
**Last Updated**: 2025-01-05
**Status**: ✅ Production Ready

## 🚨 CRITICAL: Startup Order

**Supabase MUST start BEFORE Archon**

Archon depends on Supabase services:
- PostgreSQL database (port 5432)
- PostgREST API (port 3000)
- Kong API Gateway (port 8000)

### Why This Order Matters

1. **Archon needs Supabase at startup**: Archon tries to connect to Supabase immediately when it starts
2. **Database schema required**: Archon expects the database schema to be present
3. **API connectivity**: Archon MCP server requires Supabase API to be responsive

## 📋 Scripts Available

Three scripts are provided in `./scripts/`:

### 1. `ct183-startup.sh` - Start Services

**Purpose**: Start all containers in correct order with health checks

```bash
# Normal startup
sudo ./scripts/ct183-startup.sh

# Force restart (stop + start)
sudo ./scripts/ct183-startup.sh --force-restart
```

**What it does**:
1. Checks Docker installation
2. Verifies required directories exist
3. Starts Supabase containers (13 containers)
4. Waits for Supabase to be healthy (8+ containers healthy)
5. Starts Archon containers (3 containers)
6. Waits for Archon to be healthy (2+ containers healthy)
7. Verifies connectivity between services
8. Shows final status and endpoints

**Timeouts**:
- Supabase startup: 120 seconds
- Archon startup: 60 seconds
- Health check interval: 5 seconds

### 2. `ct183-stop.sh` - Stop Services

**Purpose**: Stop containers in reverse order

```bash
# Normal stop
sudo ./scripts/ct183-stop.sh

# Verbose mode
sudo ./scripts/ct183-stop.sh --verbose
```

**Order**:
1. Stops Archon first (depends on Supabase)
2. Stops Supabase second

### 3. `ct183-health.sh` - Health Check

**Purpose**: Check health status of all services

```bash
# Basic health check
sudo ./scripts/ct183-health.sh

# Detailed status with logs
sudo ./scripts/ct183-health.sh --detailed
```

**What it checks**:
- Container health status (healthy/unhealthy/starting)
- Supabase containers (8 critical services)
- Archon containers (3 services)
- Connectivity between Archon and Supabase
- Service endpoints and ports

## 🏗️ Architecture

### Container Layout

```
CT183 (192.168.0.183)
│
├─ Supabase Containers (13 total)
│  ├─ supabase-db          (PostgreSQL)
│  ├─ supabase-auth        (Authentication)
│  ├─ supabase-rest        (PostgREST API)
│  ├─ supabase-kong        (API Gateway :8000)
│  ├─ supabase-storage     (File storage)
│  ├─ supabase-realtime    (WebSocket/Realtime)
│  ├─ supabase-studio      (Web UI :3000)
│  ├─ supabase-meta        (Metadata)
│  ├─ supabase-pooler      (Connection pooler)
│  ├─ supabase-edge-functions (Serverless)
│  ├─ supabase-analytics   (Analytics)
│  ├─ supabase-imgproxy    (Image proxy)
│  └─ supabase-vector      (Vector search)
│
└─ Archon Containers (3 total)
   ├─ archon-server        (FastAPI backend :8181)
   ├─ archon-mcp           (MCP server :8051)
   └─ archon-ui            (Web UI :3737)
```

### Service Dependencies

```
┌─────────────────┐
│   Supabase      │
│  (must start    │◄──── START FIRST
│   first!)       │
└────────┬────────┘
         │
         │  Docker Network
         │  host.docker.internal
         │
         ▼
┌─────────────────┐
│    Archon       │
│  (depends on    │◄──── START SECOND
│   Supabase)     │
└─────────────────┘
```

## 🔌 Service Endpoints

### Supabase

| Service | URL | Description |
|---------|-----|-------------|
| API Gateway | http://192.168.0.183:8000 | Main API entry point |
| PostgREST | http://192.168.0.183:3000 | Direct REST API |
| PostgreSQL | postgres://postgres:***@192.168.0.183:5432/postgres | Database |
| Studio | http://192.168.0.183:3000 | Web UI (if exposed) |

### Archon

| Service | URL | Description |
|---------|-----|-------------|
| Web UI | http://192.168.0.183:3737 | Archon dashboard |
| MCP Server | http://192.168.0.183:8051/mcp | MCP endpoint |
| API Backend | http://192.168.0.183:8181 | FastAPI backend |

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Copy scripts to CT183
scp ./scripts/ct183-*.sh root@192.168.0.183:/root/

# 2. SSH into CT183
ssh root@192.168.0.183

# 3. Make scripts executable
chmod +x /root/ct183-*.sh

# 4. Run startup script
/root/ct183-startup.sh
```

### Daily Operations

```bash
# Start services
/root/ct183-startup.sh

# Check health
/root/ct183-health.sh

# Stop services
/root/ct183-stop.sh
```

## 🔧 Troubleshooting

### Issue: Archon fails to start

**Symptoms**: Archon containers exit immediately or show connection errors

**Solution**:
```bash
# 1. Check if Supabase is running
docker ps | grep supabase

# 2. If Supabase is not running, start it first
cd /root/supabase-self-hosted/supabase/docker
docker compose up -d

# 3. Wait for Supabase to be healthy
docker ps --filter "name=supabase" --filter "health=healthy"

# 4. Then start Archon
cd /root/Archon
docker compose up -d
```

### Issue: Health check timeout

**Symptoms**: Script reports timeout but containers are running

**Solution**:
```bash
# Check container logs
docker logs supabase-kong --tail 50
docker logs archon-server --tail 50

# Manually verify connectivity
docker exec archon-server curl http://host.docker.internal:8000/rest/v1/

# If needed, increase timeout in ct183-startup.sh
```

### Issue: Cannot access services from LAN

**Symptoms**: Services work on localhost but not from other machines

**Solution**:
```bash
# Check firewall rules
iptables -L -n | grep -E "8000|8051|3737|8181"

# Verify ports are exposed
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Check if ports are bound to 0.0.0.0 (not 127.0.0.1)
netstat -tulpn | grep -E "8000|8051|3737|8181"
```

## 📊 Health Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | All services healthy | None required |
| 1 | Some services degraded | Check logs |
| 2 | Services not running | Run startup script |

## 📝 Maintenance

### Regular Checks

```bash
# Daily health check
/root/ct183-health.sh

# Weekly detailed check
/root/ct183-health.sh --detailed
```

### Log Rotation

```bash
# View recent logs
docker logs --tail 100 archon-server
docker logs --tail 100 supabase-kong

# Export logs for analysis
docker logs archon-server > /tmp/archon-$(date +%Y%m%d).log
```

### Backup

```bash
# Backup Supabase database
docker exec supabase-db pg_dump -U postgres postgres > backup.sql

# Backup Archon data
docker exec archon-server tar czf /tmp/archon-data.tar.gz /app/data
```

## 🔐 Security Notes

- All services run on internal LAN (192.168.0.x)
- Supabase JWT tokens must match between `.env` files
- Change default passwords before production deployment
- Use firewall rules to restrict access to necessary ports only

## 📚 Related Documentation

- `docs/updates/archon-supabase-integration-success.md` - Integration details
- `docs/ARCHON.md` - Archon system documentation
- `docs/INFRA.md` - Infrastructure overview

## 🆘 Support

If you encounter issues:

1. Run health check: `/root/ct183-health.sh --detailed`
2. Check container logs
3. Verify Supabase is running before Archon
4. Review this guide's troubleshooting section

---

**Maintainer**: AGL Team
**Last Updated**: 2025-01-05
**Version**: 1.0
