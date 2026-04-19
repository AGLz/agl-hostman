# Dokploy Quick Reference

One-page reference for common Dokploy operations.

---

## 🔗 URLs

| Service | URL | Access |
|---------|-----|--------|
| Dokploy UI | https://dok.aglz.io | Admin login |
| Dokploy Local | http://192.168.0.180:3000 | LAN only |
| Harbor Registry | https://harbor.aglz.io | admin/SecurePass2025! |
| Harbor API | https://harbor.aglz.io:5000 | Registry endpoint |

---

## 🚀 Quick Commands

### Test Deployment
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/examples/dokploy
./test-deployment.sh
```

### Check Harbor Status
```bash
./deploy.sh check-harbor
curl -k https://harbor.aglz.io/api/v2.0/health
```

### Login to Harbor
```bash
./deploy.sh login
# Or manually:
docker login harbor.aglz.io:5000
```

### Build and Deploy
```bash
./deploy.sh build    # Build image
./deploy.sh push     # Push to Harbor
./deploy.sh deploy   # Build + Push
```

### Monitor Application
```bash
./deploy.sh status   # Container status
./deploy.sh logs     # View logs
```

---

## 📦 Image Management

### Pull Image
```bash
docker pull harbor.aglz.io:5000/dev/agl-hostman:latest
```

### Tag Image
```bash
docker tag agl-hostman:latest harbor.aglz.io:5000/dev/agl-hostman:v1.0.0
```

### Push Image
```bash
docker push harbor.aglz.io:5000/dev/agl-hostman:latest
```

### List Images
```bash
docker images | grep agl-hostman
```

---

## 🐳 Container Operations

### List Containers
```bash
docker ps --filter label=com.dokploy.managed=true
```

### View Logs
```bash
docker logs -f agl-hostman-dev
docker logs --tail 100 agl-hostman-dev
```

### Restart Container
```bash
docker restart agl-hostman-dev
```

### Check Resources
```bash
docker stats agl-hostman-dev --no-stream
```

### Exec into Container
```bash
docker exec -it agl-hostman-dev sh
```

---

## 🔧 Troubleshooting

### Dokploy Not Accessible
```bash
# Check CT180 status
ssh root@192.168.0.245 'pct status 180'

# Check Dokploy container
ssh root@192.168.0.180 'docker ps | grep dokploy'

# Restart if needed
ssh root@192.168.0.245 'pct restart 180'
```

### Harbor Connection Issues
```bash
# Test connectivity
ping harbor.aglz.io
curl -I https://harbor.aglz.io

# Check Docker login
cat ~/.docker/config.json | grep harbor

# Force re-login
docker logout harbor.aglz.io:5000
docker login harbor.aglz.io:5000
```

### Container Won't Start
```bash
# View full logs
docker logs agl-hostman-dev

# Check last exit code
docker inspect agl-hostman-dev --format='{{.State.ExitCode}}'

# Test image manually
docker run -it --rm harbor.aglz.io:5000/dev/agl-hostman:latest sh
```

### Health Check Failing
```bash
# Test health endpoint
curl http://localhost:3001/health

# Check if port is accessible
netstat -tlnp | grep 3001

# View health check logs
docker inspect agl-hostman-dev | grep -A 10 Health
```

---

## 📝 Environment Variables

### Required Variables
```bash
NODE_ENV=development
PROXMOX_API_URL=https://192.168.0.245:8006/api2/json
PROXMOX_API_TOKEN_ID=your-token-id@pam!your-token-name
PROXMOX_API_TOKEN=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
WIREGUARD_INTERFACE=wg0
```

### Set in Dokploy UI
1. Go to application → Settings
2. Click Environment Variables
3. Add/Edit variables
4. Save and redeploy

---

## 🔄 Deployment Workflow

### Manual Deployment
1. Build image locally
2. Push to Harbor
3. In Dokploy UI: Click "Redeploy"
4. Monitor logs

### Automated (Webhook)
1. Push code to Git
2. CI builds and pushes to Harbor
3. Harbor webhook triggers Dokploy
4. Auto-deployment happens
5. Monitor via Dokploy UI

---

## 📊 Resource Limits

### Development
```yaml
CPU: 0.5 (50%)
Memory: 512MB
```

### Production
```yaml
CPU: 1.0 (100%)
Memory: 1GB
```

### Adjust in Docker Compose
```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
```

---

## 🔍 Health Checks

### Default Configuration
```yaml
Path: /health
Port: 3000
Interval: 30s
Timeout: 5s
Retries: 3
```

### Test Manually
```bash
curl http://localhost:3000/health
```

### Expected Response
```json
{
  "status": "ok",
  "timestamp": "2025-10-28T12:00:00Z"
}
```

---

## 📂 Volume Paths

### Development
```
Host: /var/lib/dokploy/data/agl-hostman-dev/logs
Container: /app/logs

Host: /var/lib/dokploy/data/agl-hostman-dev/data
Container: /app/data
```

### Access Logs
```bash
# From CT180
tail -f /var/lib/dokploy/data/agl-hostman-dev/logs/app.log

# Via Docker
docker logs agl-hostman-dev
```

---

## 🌐 Network Configuration

### Port Mapping
```
Container: 3000
Host: 3001 (development)
Host: 3000 (production)
```

### Access Application
```bash
# From CT179
curl http://192.168.0.180:3001

# From anywhere
curl https://hostman.aglz.io  # (when configured)
```

---

## 🔐 Security

### Secrets Management
- Store in Dokploy UI environment variables
- Never commit .env file to git
- Use Harbor registry credentials securely

### SSL/TLS
- Cloudflare handles SSL for dok.aglz.io
- Traefik can provide Let's Encrypt certs
- See docker-compose.production.yml

---

## 📖 Full Documentation

**Complete Guide**: `/docs/DOKPLOY.md`
**Examples**: `/examples/dokploy/`
**Summary**: `/docs/DOKPLOY-SUMMARY.md`

---

**Version**: 1.0.0
**Last Updated**: 2025-10-28
