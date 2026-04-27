# Docker Infrastructure - agl-hostman

Complete Docker infrastructure for the AGL Infrastructure Management Dashboard.

---

## 📁 Directory Structure

```
docker/
├── README.md                      # This file
├── production/
│   └── Dockerfile                # Production multi-stage build
└── development/
    └── Dockerfile.dev            # Development with hot reloading

docker-compose.yml                # Development orchestration
.dockerignore                     # Build context exclusions
.env.example                      # Environment template

src/dashboard/
├── server.js                     # Express server
├── api/
│   ├── proxmox.js               # Proxmox VE API client
│   └── network.js               # Network monitoring (WireGuard/Tailscale)
├── utils/
│   └── logger.js                # Winston logging
└── public/
    └── index.html               # Dashboard UI

config/
├── dashboard.config.js          # Central configuration
└── dokploy.json                 # Dokploy deployment config

tests/docker/
├── health.test.js               # Health endpoint tests
└── build.test.sh                # Docker build tests
```

---

## 🚀 Quick Start

### 1. Development Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your Proxmox credentials
vim .env

# Start development stack
docker-compose up -d

# View logs
docker-compose logs -f dashboard-dev

# Access dashboard
open http://localhost:3000
```

### 2. Production Testing

```bash
# Build production image
docker build -t agl-hostman:latest -f docker/production/Dockerfile .

# Or start with compose
docker-compose --profile production up -d dashboard-prod

# Access on different port
open http://localhost:3001
```

---

## 🏗️ Architecture

### Production Build (Multi-Stage)

**Stage 1: Builder**
- Base: `node:20-alpine`
- Installs dependencies
- Builds application
- Prunes dev dependencies

**Stage 2: Production**
- Base: `node:20-alpine`
- Minimal runtime
- Non-root user (appuser:1001)
- Tini init system
- Health checks

**Result**: ~150 MB optimized image

### Development Build

**Features:**
- Hot reloading with nodemon
- Node.js debugger (port 9229)
- Volume mounts for instant updates
- Debug logging

**Result**: ~180 MB with dev tools

---

## 🔧 Configuration

### Environment Variables

**Required:**
```bash
NODE_ENV=production
PORT=3000
PROXMOX_HOST=192.168.0.245
PROXMOX_TOKEN_ID=<token-id>
PROXMOX_TOKEN_SECRET=<token-secret>
```

**Optional:**
```bash
# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Network
WIREGUARD_ENABLED=true
TAILSCALE_ENABLED=true

# Secondary Proxmox
PROXMOX_SECONDARY_HOST=10.6.0.12
```

See `.env.example` for complete list.

---

## 📊 Monitoring

### Health Check

```bash
# Container health
docker inspect --format='{{.State.Health.Status}}' agl-hostman-dev

# Endpoint test
curl http://localhost:3000/health

# Expected response:
{
  "status": "healthy",
  "timestamp": "2025-10-28T...",
  "uptime": 123.45,
  "environment": "development",
  "version": "1.0.0"
}
```

### Logs

```bash
# Follow logs
docker-compose logs -f dashboard-dev

# Filter errors
docker-compose logs dashboard-dev | grep -i error

# Export to file
docker-compose logs dashboard-dev > logs/export.log
```

### Metrics

```bash
# Container stats
docker stats agl-hostman-dev

# Resource usage
docker-compose exec dashboard-dev top

# Disk usage
docker system df
```

---

## 🧪 Testing

### Run Tests

```bash
# Jest tests (health endpoint)
npm test

# Docker build tests
./tests/docker/build.test.sh

# Full test suite
npm test && ./tests/docker/build.test.sh
```

### Manual Testing

```bash
# Test API endpoints
curl http://localhost:3000/api/overview
curl http://localhost:3000/api/containers
curl http://localhost:3000/api/network
curl http://localhost:3000/api/storage

# Test Proxmox connectivity
docker-compose exec dashboard-dev curl -k https://192.168.0.245:8006/api2/json/version
```

---

## 🚢 Deployment

### Dokploy (CT180)

```bash
# 1. Configure in Dokploy UI
open http://192.168.0.180:3000

# 2. Import config/dokploy.json

# 3. Set secrets:
PROXMOX_TOKEN_ID=<token>
PROXMOX_TOKEN_SECRET=<secret>

# 4. Deploy
```

### Harbor Registry

```bash
# Login
docker login harbor.aglz.io

# Tag
docker tag agl-hostman:latest harbor.aglz.io/agl/hostman:latest
docker tag agl-hostman:latest harbor.aglz.io/agl/hostman:1.0.0

# Push
docker push harbor.aglz.io/agl/hostman:latest
docker push harbor.aglz.io/agl/hostman:1.0.0
```

### Manual Deployment

```bash
# Pull from Harbor
docker pull harbor.aglz.io/agl/hostman:latest

# Run container
docker run -d \
  --name agl-hostman \
  -p 3000:3000 \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/data:/app/data \
  --env-file .env \
  --restart unless-stopped \
  harbor.aglz.io/agl/hostman:latest
```

---

## 🔒 Security

### Best Practices Implemented

✅ **Non-root user** (appuser:1001)
✅ **Minimal base image** (Alpine Linux)
✅ **No secrets in image** (environment variables)
✅ **Health checks** (automatic restart)
✅ **Tini init system** (proper signal handling)
✅ **Read-only volumes** (source code)
✅ **Security headers** (helmet.js)
✅ **CORS configuration** (restricted origins)

### Security Checklist

- [ ] Rotate Proxmox API tokens regularly
- [ ] Use Docker secrets in production
- [ ] Enable TLS for dashboard
- [ ] Restrict network access
- [ ] Monitor container logs
- [ ] Scan images for vulnerabilities
- [ ] Keep base images updated

---

## 🐛 Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs dashboard-dev

# Check port conflicts
sudo lsof -i :3000

# Rebuild
docker-compose build --no-cache dashboard-dev
```

### Health check failing

```bash
# Manual test
curl http://localhost:3000/health

# Check Proxmox connectivity
docker-compose exec dashboard-dev curl -k https://192.168.0.245:8006
```

### Permission issues

```bash
# Fix log directory permissions
sudo chown -R 1001:1001 logs/

# Check volume mounts
docker-compose config
```

---

## 📚 Documentation

- **Full Deployment Guide**: `docs/DOCKER-DEPLOYMENT.md`
- **Quick Start**: `docs/DOCKER-QUICK-START.md`
- **API Documentation**: `docs/API.md`
- **Infrastructure Map**: `docs/INFRA.md`

---

## 🔗 Related Files

- `docker-compose.yml` - Development orchestration
- `.dockerignore` - Build context exclusions
- `.env.example` - Environment template
- `package.json` - Node.js dependencies
- `config/dashboard.config.js` - Application config

---

## 📝 Changelog

### v1.0.0 (2025-10-28)
- ✨ Initial Docker infrastructure
- 🏗️ Multi-stage production build
- 🔧 Development environment with hot reloading
- 📊 Health checks and monitoring
- 🚢 Dokploy and Harbor integration
- 📚 Complete documentation

---

**Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintainer**: AGL Infrastructure Team
