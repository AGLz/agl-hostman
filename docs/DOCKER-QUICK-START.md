# Docker Quick Start Guide

> **Fast reference for common Docker operations in agl-hostman**

---

## 🚀 5-Minute Quick Start

```bash
# 1. Clone and configure
cd /root/agl-hostman
cp .env.example .env
vim .env  # Add your Proxmox credentials

# 2. Start development environment
docker-compose up -d

# 3. View logs
docker-compose logs -f dashboard-dev

# 4. Access dashboard
open http://localhost:3000

# 5. Health check
curl http://localhost:3000/health
```

---

## 📝 Common Commands

### Start/Stop Services

```bash
# Start development
docker-compose up -d

# Start production (test)
docker-compose --profile production up -d

# Stop all
docker-compose down

# Restart service
docker-compose restart dashboard-dev
```

### Logs & Debugging

```bash
# Follow logs
docker-compose logs -f dashboard-dev

# Last 100 lines
docker-compose logs --tail 100 dashboard-dev

# Filter errors
docker-compose logs dashboard-dev | grep -i error

# Shell access
docker-compose exec dashboard-dev sh
```

### Build & Deploy

```bash
# Build production image
npm run docker:build

# Rebuild without cache
docker-compose build --no-cache dashboard-dev

# Push to Harbor
docker tag agl-hostman:latest harbor.aglz.io/agl/hostman:latest
docker push harbor.aglz.io/agl/hostman:latest
```

### Health & Monitoring

```bash
# Health check
curl http://localhost:3000/health

# Container stats
docker stats agl-hostman-dev

# Inspect container
docker inspect agl-hostman-dev

# View environment
docker-compose exec dashboard-dev env
```

---

## 🔧 Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs dashboard-dev

# Check port conflicts
sudo lsof -i :3000

# Rebuild
docker-compose build --no-cache dashboard-dev
docker-compose up -d
```

### Health check failing
```bash
# Manual test
curl http://localhost:3000/health

# Check Proxmox connectivity
docker-compose exec dashboard-dev curl -k https://192.168.0.245:8006/api2/json/version
```

### Reset everything
```bash
# Stop and remove containers
docker-compose down -v

# Remove images
docker rmi agl-hostman-dev agl-hostman-prod

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d
```

---

## 📦 Environment Variables

**Minimal .env for testing:**
```bash
NODE_ENV=development
PORT=3000
PROXMOX_HOST=192.168.0.245
PROXMOX_TOKEN_ID=your-token-id
PROXMOX_TOKEN_SECRET=your-token-secret
```

---

## 🔗 More Information

- **Full Guide**: `docs/DOCKER-DEPLOYMENT.md`
- **API Documentation**: `docs/API.md`
- **Infrastructure Map**: `docs/INFRA.md`

---

**Quick Start Version**: 1.0.0 | Last Updated: 2025-10-28
