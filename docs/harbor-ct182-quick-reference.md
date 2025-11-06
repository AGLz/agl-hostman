# Harbor CT182 Quick Reference Guide

**Full Research Document:** `/mnt/overpower/apps/dev/agl/agl-hostman/docs/harbor-ct182-research.md`
**Target:** Proxmox CT182 on aglsrv1 (IP: x.x.x.182)
**Research Date:** 2025-10-22

---

## Recommended Specifications for CT182

### Hardware Resources
- **CPU:** 4 cores (minimum 2)
- **RAM:** 8GB (minimum 4GB)
- **Root Disk:** 16GB
- **Data Volume:** 200GB mounted at `/data/registry`

### LXC Configuration
```bash
CT ID: 182
Features: nesting=1, keyctl=1
Unprivileged: Yes
Network: Static IP x.x.x.182/24
```

---

## Installation Quick Steps

### 1. Create LXC Container
```bash
pct create 182 local:vztmpl/ubuntu-22.04-standard_*.tar.zst \
  --hostname harbor-registry \
  --cores 4 --memory 8192 --swap 2048 \
  --net0 name=eth0,bridge=vmbr0,ip=x.x.x.182/24,gw=x.x.x.1 \
  --features nesting=1,keyctl=1 \
  --unprivileged 1 --rootfs local-lvm:16

pct set 182 -mp0 /mnt/storage/harbor-data,mp=/data/registry
pct start 182
```

### 2. Install Docker
```bash
apt update && apt upgrade -y
apt install -y ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 3. Install Harbor
```bash
cd /root
wget https://github.com/goharbor/harbor/releases/download/v2.12.2/harbor-online-installer-v2.12.2.tgz
tar xzvf harbor-online-installer-v2.12.2.tgz
cd harbor

cp harbor.yml.tmpl harbor.yml
# Edit harbor.yml (set hostname, passwords, data_volume)

./install.sh --with-trivy
```

### 4. Configure Auto-Restart (CRITICAL for LXC)
```bash
cat > /root/restart-harbor-containers.sh << 'EOF'
#!/bin/bash
for container in $(docker ps -a --filter "status=exited" --format "{{.Names}}" | grep -E "harbor|nginx|registry"); do
    docker restart $container
done
EOF

chmod +x /root/restart-harbor-containers.sh
crontab -e
# Add: */10 * * * * /root/restart-harbor-containers.sh >> /var/log/harbor-restart.log 2>&1
```

---

## Critical Security Settings

### SSL/TLS (Required for Production)
```bash
mkdir -p /data/secrets/cert
# Copy corporate certificates or generate self-signed (testing only)
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout /data/secrets/cert/server.key \
  -x509 -days 365 -out /data/secrets/cert/server.crt
```

### harbor.yml Key Settings
```yaml
hostname: harbor.yourdomain.com
https:
  certificate: /data/secrets/cert/server.crt
  private_key: /data/secrets/cert/server.key
harbor_admin_password: [CHANGE_ME]
data_volume: /data/registry
```

### Firewall Ports
- **80:** HTTP (redirect to HTTPS)
- **443:** HTTPS (required)
- **4443:** Docker Content Trust (optional)

---

## Key Findings Summary

### ✅ LXC vs VM Decision: **USE LXC**
- 2.8-4.4x performance improvement
- Near bare-metal efficiency
- Modern unprivileged LXC handles Docker well
- Proven success in production (2025 implementations)

### ✅ System Requirements
| Component | Minimum | Recommended | Production |
|-----------|---------|-------------|------------|
| CPU | 2 cores | 4 cores | 8+ cores |
| RAM | 4GB | 8GB | 16GB+ |
| Storage | 40GB | 160GB | 500GB+ |

### ✅ Security Best Practices
1. **Enable Trivy vulnerability scanning** (automatic on push)
2. **Use corporate certificates** (not self-signed)
3. **Configure LDAP/OIDC** for authentication
4. **Implement RBAC** with least privilege
5. **Enable audit logging**
6. **Set up image retention policies**

### ✅ Common Use Cases
- **Private registry** for proprietary images
- **Docker Hub proxy cache** (reduce bandwidth, bypass rate limits)
- **CI/CD integration** (automated scanning and deployment)
- **Multi-datacenter replication** (HA and DR)
- **Kubernetes registry** (integrated with K8s clusters)

### ⚠️ Critical Pitfalls to Avoid
1. **Installing Docker on Proxmox host** (causes conflicts)
2. **Insufficient storage planning** (implement retention policies)
3. **Using self-signed certs in production** (use corporate CA)
4. **Not enabling LXC nesting/keyctl** (Docker won't start)
5. **Missing user permissions on /data** (must be writable by user 10000)
6. **No automated restart in LXC** (containers fail after reboot)
7. **Strict vulnerability blocking in production** (can break auto-scaling)

---

## Backup Strategy

### What to Back Up
1. **PostgreSQL database** (users, projects, configs)
2. **Configuration files** (`harbor.yml`, `common/config/`)
3. **Image storage** (`/data/registry/`)
4. **SSL certificates** (`/data/secrets/`)

### Backup Script
```bash
#!/bin/bash
BACKUP_DIR="/mnt/backup/harbor/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

docker exec harbor-db pg_dumpall -U postgres > "$BACKUP_DIR/harbor-db.sql"
cp -r /root/harbor/harbor.yml "$BACKUP_DIR/"
rsync -av /data/registry/ "$BACKUP_DIR/registry/"
cp -r /data/secrets "$BACKUP_DIR/"

tar czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
find /mnt/backup/harbor/ -name "*.tar.gz" -mtime +30 -delete
```

---

## Quick Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Containers exit after reboot | Dependency issues | Auto-restart cron job |
| Permission denied on /data | User mapping mismatch | `chown -R 10000:10000 /data/registry` |
| Cannot access via hostname | DNS not configured | Create A record for .182 IP |
| Certificate warnings | Self-signed cert | Use corporate certificate |
| Scanning not working | Trivy DB update failed | Check connectivity, manual update |
| High memory usage | Large concurrent ops | Increase RAM or limit operations |

---

## Management Commands

```bash
# Harbor control
cd /root/harbor
docker compose ps              # Status
docker compose logs -f         # Logs
docker compose down            # Stop
docker compose up -d           # Start

# Backup/restore
docker exec harbor-db pg_dumpall -U postgres > backup.sql
docker exec -i harbor-db psql -U postgres < backup.sql

# Monitoring
docker stats --no-stream       # Resource usage
du -sh /data/registry/*        # Storage usage
df -h /data/registry           # Disk space
```

---

## Next Steps for Implementation

1. ✅ **Research completed** - See full document for details
2. ⏳ **Create CT182** with recommended specs
3. ⏳ **Configure networking** with static IP .182
4. ⏳ **Install Docker** and dependencies
5. ⏳ **Deploy Harbor** with Trivy scanning
6. ⏳ **Configure SSL/TLS** with certificates
7. ⏳ **Set up authentication** (LDAP/OIDC)
8. ⏳ **Implement backups** and auto-restart
9. ⏳ **Test integration** with Kubernetes
10. ⏳ **Document and train** users

---

## Resources

- **Full Research:** `/mnt/overpower/apps/dev/agl/agl-hostman/docs/harbor-ct182-research.md` (1040 lines, 30KB)
- **Official Docs:** https://goharbor.io/docs/
- **Harbor GitHub:** https://github.com/goharbor/harbor
- **Proxmox Wiki:** https://pve.proxmox.com/wiki/Linux_Container

**Document Version:** 1.0
**Last Updated:** 2025-10-22
