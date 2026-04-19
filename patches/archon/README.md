# Archon MCP Server Patch

> CT 183 - Archon Stack com Host networking
> **Last Updated**: 2026-03-16

## Services
| Service | Port | Description |
|--------|------|-------------|
| archon-server | 8181 | Main API server with Supabase backend |
| archon-mcp | 8051 | MCP server (Streamable HTTP) |
| archon-ui | 3737 | Frontend UI (Vite) |

## Network Configuration
- Uses `network_mode: host` - containers share CT's network namespace
- Accessible via CT's Tailscale IP: `100.80.30.59`
- Also accessible via LAN IP: `192.168.0.183`

## Endpoints
| Endpoint | URL | Purpose |
|----------|-----|---------|
| Health | `http://100.80.30.59:8181/health` | API health check |
| API | `http://100.80.30.59:8181` | Main API |
| MCP | `http://100.80.30.59:8051/mcp` | MCP endpoint |
| UI | `http://100.80.30.59:3737` | Web interface |

## Environment Variables
| Variable | Service | Description |
|----------|---------|-------------|
| `SUPABASE_URL` | server, mcp | Supabase project URL |
| `SUPABASE_SERVICE_KEY` | server, mcp | Supabase service key |
| `VITE_API_URL` | ui | Backend API URL (`http://localhost:8181`) |
| `VITE_ALLOWED_HOSTS` | ui | Allowed hosts for Vite dev server (comma-separated) |

## Deployment

### Initial Setup
```bash
# On CT 183
cd /root/Archon
docker compose -f docker-compose-hostnet.yml up -d
```

### Adding Custom Domain
To allow a custom domain like `archon.aglz.io`, add it to `VITE_ALLOWED_HOSTS`:

```yaml
# In docker-compose-hostnet.yml
archon-ui:
  environment:
    - VITE_ALLOWED_HOSTS=archon.aglz.io,localhost,127.0.0.1
```

Then restart:
```bash
docker compose -f docker-compose-hostnet.yml up -d
```

## Troubleshooting

### Container Missing
If `archon-server` is not running:
```bash
docker compose -f docker-compose-hostnet.yml up -d
```

### MCP Connection Issues
- Verify health: `curl http://100.80.30.59:8181/health`
- Check MCP: `curl http://100.80.30.59:8051/mcp`
- Check logs: `docker logs archon-mcp --tail 50`

### Vite Blocked Host Error
If you see "This host is not allowed":
1. Add the domain to `VITE_ALLOWED_HOSTS` in docker-compose
2. Restart the ui container: `docker compose up -d archon-ui`

## Files
- `docker-compose-hostnet.yml` - Docker compose configuration
- `deploy.sh` - Deployment script (Wip)
- `README.md` - This documentation

## Recent Changes

### 2026-03-16: Vite Blocked Host Fix
**Problem**: Accessing `archon.aglz.io` returned Vite error:
```
Blocked request. This host ("archon.aglz.io") is not allowed.
```

**Solution**: Added `VITE_ALLOWED_HOSTS` environment variable to `archon-ui`:
```yaml
archon-ui:
  environment:
    - VITE_API_URL=http://localhost:8181
    - VITE_ALLOWED_HOSTS=archon.aglz.io,localhost,127.0.0.1
```

**Deployment**:
```bash
# Copy config to CT 183
ssh root@100.107.113.33 'mkdir -p /root/Archon'
scp docker-compose-hostnet.yml root@100.107.113.33:/root/Archon/
ssh root@100.107.113.33 'pct exec 183 -- mkdir -p /root/Archon'
ssh root@100.107.113.33 'pct push 183 /root/Archon/docker-compose-hostnet.yml /root/Archon/'

# Recreate containers
ssh root@100.80.30.59 'cd /root/Archon && docker compose -f docker-compose-hostnet.yml up -d --force-recreate'
```

**Verification**:
```bash
curl -s http://100.80.30.59:8181/health
# {"status":"healthy","service":"archon-backend"...}
```
