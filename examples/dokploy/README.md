# Dokploy Deployment Examples

This directory contains example configurations for deploying agl-hostman on Dokploy.

## 📁 Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Development configuration |
| `docker-compose.production.yml` | Production configuration with Traefik |
| `.env.example` | Environment variables template |
| `test-deployment.sh` | Script to test deployment with nginx |
| `deploy.sh` | Helper script for manual deployment |

## 🚀 Quick Start

### 1. Test Deployment (nginx)

Test Dokploy setup with a simple nginx container:

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/examples/dokploy
./test-deployment.sh
```

### 2. Deploy Development Version

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
nano .env

# In Dokploy UI:
# 1. Create new application
# 2. Select "Docker Compose"
# 3. Paste contents of docker-compose.yml
# 4. Add environment variables from .env
# 5. Deploy
```

### 3. Deploy Production Version

```bash
# Use docker-compose.production.yml in Dokploy UI
# Configure Traefik reverse proxy
# Set production environment variables
# Deploy with version tag (not :latest)
```

## 📝 Configuration Options

### Development Configuration

**Resources**:
- CPU: 0.5 (50%)
- Memory: 512MB

**Ports**:
- Container: 3000
- Host: 3001

**Restart**: Always

**Health Check**: HTTP GET /health

### Production Configuration

**Resources**:
- CPU: 1.0 (100%)
- Memory: 1GB

**Ports**:
- Container: 3000
- Host: 3000

**Restart**: Unless stopped

**Health Check**: HTTP GET /health (stricter)

**Additional Features**:
- Traefik reverse proxy integration
- SSL/TLS via Let's Encrypt
- Logging configuration
- Update/rollback strategy

## 🔧 Environment Variables

See `.env.example` for all available variables. Key variables:

### Required
- `PROXMOX_API_URL`: Proxmox API endpoint
- `PROXMOX_API_TOKEN_ID`: Token ID for authentication
- `PROXMOX_API_TOKEN`: Token secret for authentication

### Optional
- `LOG_LEVEL`: Logging verbosity (info/warn/error)
- `WIREGUARD_INTERFACE`: WireGuard interface name (default: wg0)

## 🌐 Network Architecture

```
                    ┌─────────────────┐
                    │  Cloudflare     │
                    │  dok.aglz.io    │
                    └────────┬────────┘
                             │
                             │ HTTPS
                             │
                    ┌────────▼────────┐
                    │  CT180          │
                    │  Dokploy        │
                    │  192.168.0.180  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
      ┌───────▼───────┐ ┌───▼────┐ ┌──────▼──────┐
      │ agl-hostman   │ │ nginx  │ │ Other Apps  │
      │ :3001         │ │ :8080  │ │             │
      └───────────────┘ └────────┘ └─────────────┘
              │
              │ Bridge Network
              │
      ┌───────▼────────┐
      │  Docker Host   │
      │  Network       │
      └────────────────┘
```

## 📦 Volume Mounts

### Development
- `/var/lib/dokploy/data/agl-hostman-dev/logs` → `/app/logs`
- `/var/lib/dokploy/data/agl-hostman-dev/data` → `/app/data`

### Production
- Named volumes managed by Docker
- Automatic backups recommended

## 🔍 Troubleshooting

### Check Deployment Status

```bash
# From CT179 or CT180
docker ps --filter name=agl-hostman

# Check logs
docker logs agl-hostman-dev

# Check resource usage
docker stats agl-hostman-dev
```

### Common Issues

1. **Container exits immediately**
   - Check logs: `docker logs agl-hostman-dev`
   - Verify environment variables are set
   - Check health endpoint manually

2. **Cannot pull image from Harbor**
   - Verify Harbor is accessible
   - Check registry credentials in Dokploy
   - Try manual pull: `docker pull harbor.aglz.io:5000/dev/agl-hostman:latest`

3. **Health check failing**
   - Verify `/health` endpoint responds
   - Check if port 3000 is accessible
   - Increase `start_period` if app takes longer to start

## 📚 Related Documentation

- **DOKPLOY.md**: Complete Dokploy setup guide
- **INFRA.md**: Infrastructure overview
- **ARCHON.md**: Archon MCP integration

## 🎯 Next Steps

1. Test deployment with nginx
2. Build agl-hostman Docker image
3. Push image to Harbor
4. Deploy via Dokploy
5. Configure webhooks for CI/CD
6. Set up monitoring

## 📞 Support

- **Documentation**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/DOKPLOY.md`
- **Dokploy Docs**: https://docs.dokploy.com
- **Dokploy Discord**: https://discord.com/invite/2tBnJ3jDJc
