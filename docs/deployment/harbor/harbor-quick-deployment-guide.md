# Harbor Quick Deployment Guide - Proxmox CT182

**Last Updated:** 2025-10-22
**Target Environment:** Proxmox LXC Container
**Harbor Version:** 2.12.2+

---

## 🚀 Quick Start (30-Minute Deployment)

### Prerequisites
- Proxmox VE 8.x
- Debian 12 or Ubuntu 22.04 LXC template
- Valid SSL certificate (Let's Encrypt recommended)
- NFS/storage mount for registry data

### Step 1: Create LXC Container (5 min)
```bash
pct create 182 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname harbor-ct182 \
  --memory 8192 \
  --cores 4 \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.182/24,gw=192.168.1.1 \
  --features nesting=1,keyctl=1 \
  --unprivileged 0

pct start 182
pct enter 182
```

### Step 2: Install Docker (5 min)
```bash
apt update && apt upgrade -y
apt install -y ca-certificates curl gnupg nfs-common
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin
```

### Step 3: Configure Storage (3 min)
```bash
mkdir -p /data/registry
# Mount your storage (adjust for your setup)
echo "192.168.1.100:/mnt/pool/harbor /data/registry nfs defaults 0 0" >> /etc/fstab
mount -a
chown -R 10000:10000 /data/registry
```

### Step 4: SSL Certificates (5 min)
```bash
# Let's Encrypt (recommended)
apt install -y certbot
certbot certonly --standalone -d harbor.yourdomain.com

# Certificates will be in:
# /etc/letsencrypt/live/harbor.yourdomain.com/fullchain.pem
# /etc/letsencrypt/live/harbor.yourdomain.com/privkey.pem
```

### Step 5: Install Harbor (10 min)
```bash
cd /root
wget https://github.com/goharbor/harbor/releases/download/v2.12.2/harbor-online-installer-v2.12.2.tgz
tar xzvf harbor-online-installer-v2.12.2.tgz
cd harbor
cp harbor.yml.tmpl harbor.yml
```

**Edit harbor.yml:**
```yaml
hostname: harbor.yourdomain.com

https:
  port: 443
  certificate: /etc/letsencrypt/live/harbor.yourdomain.com/fullchain.pem
  private_key: /etc/letsencrypt/live/harbor.yourdomain.com/privkey.pem

harbor_admin_password: CHANGE_THIS_PASSWORD_NOW

data_volume: /data/registry

database:
  password: CHANGE_THIS_TOO
```

**Run installer:**
```bash
./install.sh --with-trivy --with-chartmuseum
```

### Step 6: Enable Auto-Start (2 min)
```bash
cat > /etc/systemd/system/harbor.service <<'EOF'
[Unit]
Description=Harbor Container Registry
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/root/harbor
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable harbor.service
```

### Step 7: Verify (2 min)
```bash
docker compose ps  # All services should be "Up"
curl -k https://localhost  # Should return Harbor UI
```

**Access Harbor:**
- URL: https://harbor.yourdomain.com
- Username: admin
- Password: (what you set in harbor.yml)

---

## 📋 Post-Installation Configuration

### 1. Change Admin Password
```
Login → Admin → Change Password
Set strong password (12+ chars, mixed case, numbers, symbols)
```

### 2. Configure Authentication
```
Administration → Configuration → Authentication
- Choose: LDAP, OIDC, or UAA
- Test connection before saving
```

### 3. Create Projects
```
Projects → New Project
- Name: production
- Access Level: Private
- Storage Quota: 100 GB

Repeat for: staging, development
```

### 4. Set Retention Policies
```
Project → Policy → Tag Retention → Add Rule
- Repository: **/*
- Keep the most recently pushed # images: 10
- Keep images pushed within last # days: 30

Add → Dry Run → Run
```

### 5. Schedule Garbage Collection
```
Administration → Garbage Collection
- Schedule: 0 2 * * 0  (Sunday 2 AM)
- ☑ Delete untagged artifacts
Save
```

### 6. Enable Vulnerability Scanning
```
Administration → Interrogation Services → Scanners
- Default: Trivy
- ☑ Automatically scan images on push
```

### 7. Create Robot Account (for CI/CD)
```
Project → Robot Accounts → New Robot Account
- Name: gitlab-ci
- Expiration: 90 days
- Permissions: Push artifact, Pull artifact
- Copy token (save securely!)
```

---

## 🔒 Security Hardening (10 Minutes)

### Firewall
```bash
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### Fail2Ban
```bash
apt install -y fail2ban
systemctl enable fail2ban
```

### Auto-Updates
```bash
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

### Strong Password Policy
```
Administration → Configuration → System Settings
☑ Lowercase required
☑ Uppercase required
☑ Numbers required
☑ Special characters required
Minimum length: 12
```

---

## 📊 Monitoring Setup (15 Minutes)

### Prometheus Configuration
```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: 'harbor'
    static_configs:
      - targets: ['harbor.yourdomain.com:443']
    scheme: https
    metrics_path: '/metrics'
    scrape_interval: 30s
```

### Key Metrics to Monitor
- `harbor_up` - Service availability
- `harbor_quota_usage_bytes` - Storage usage
- `harbor_registry_image_pulled` - Pull operations
- `harbor_registry_image_pushed` - Push operations

### Grafana Dashboard
- Import Dashboard ID: 15684 (Harbor Overview)
- Configure alerts for storage >85%

---

## 💾 Backup Strategy

### Daily Database Backup
```bash
cat > /usr/local/bin/harbor-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/mnt/backup/harbor"
DATE=$(date +%Y%m%d)
mkdir -p ${BACKUP_DIR}

# Backup database
docker exec harbor-db pg_dumpall -U postgres | gzip > ${BACKUP_DIR}/harbor-db-${DATE}.sql.gz

# Backup config
tar czf ${BACKUP_DIR}/harbor-config-${DATE}.tar.gz -C /root harbor

# Delete old backups (keep 30 days)
find ${BACKUP_DIR} -type f -mtime +30 -delete
EOF

chmod +x /usr/local/bin/harbor-backup.sh

# Schedule daily at 3 AM
echo "0 3 * * * /usr/local/bin/harbor-backup.sh" | crontab -
```

---

## 🐳 Docker Client Setup

### One-Time Client Configuration
```bash
# On each Docker client/workstation
mkdir -p /etc/docker/certs.d/harbor.yourdomain.com

# If using Let's Encrypt (no CA needed)
# Just test login:
docker login harbor.yourdomain.com

# If using corporate CA:
scp root@harbor:/path/to/ca.crt \
  /etc/docker/certs.d/harbor.yourdomain.com/ca.crt
```

### Usage Examples
```bash
# Login
docker login harbor.yourdomain.com

# Tag and push
docker tag myapp:latest harbor.yourdomain.com/production/myapp:v1.0.0
docker push harbor.yourdomain.com/production/myapp:v1.0.0

# Pull
docker pull harbor.yourdomain.com/production/myapp:v1.0.0
```

---

## 🔧 Common Operations

### Restart Harbor
```bash
cd /root/harbor
docker compose restart
```

### View Logs
```bash
docker logs -f harbor-core
docker logs -f registry
```

### Check Disk Usage
```bash
df -h /data/registry
du -sh /data/registry/*
```

### Manual Garbage Collection
```bash
cd /root/harbor
docker compose stop
docker run -it --name gc --rm --volumes-from registry \
  goharbor/registry-photon:v2.8.3 \
  garbage-collect --dry-run /etc/registry/config.yml

# If dry-run looks good, remove --dry-run
docker compose start
```

### Update Harbor
```bash
cd /root/harbor
docker compose down

# Backup first!
cp harbor.yml harbor.yml.bak

# Download new version
cd /root
wget https://github.com/goharbor/harbor/releases/download/v2.13.0/harbor-online-installer-v2.13.0.tgz
tar xzvf harbor-online-installer-v2.13.0.tgz

# Copy config
cp harbor.yml.bak harbor/harbor.yml

# Run installer
cd harbor
./install.sh --with-trivy --with-chartmuseum
```

---

## 🚨 Troubleshooting

### Issue: Can't Login to Harbor
```bash
# Check services
docker compose ps

# Check logs
docker logs harbor-core
docker logs harbor-db

# Reset admin password
cd /root/harbor
docker compose stop
docker compose up -d
# Login with: admin / Harbor12345 (default)
# Change password immediately
```

### Issue: Image Push Fails
```bash
# Check disk space
df -h /data/registry

# Check permissions
ls -la /data/registry
# Should be owned by 10000:10000

# Check Harbor logs
docker logs registry
```

### Issue: Slow Performance
```bash
# Check database
docker exec harbor-db psql -U postgres -c "
  SELECT pid, query, state, query_start
  FROM pg_stat_activity
  WHERE state != 'idle';
"

# Check Redis
docker exec harbor-redis redis-cli INFO stats

# Check disk I/O
iostat -x 5
```

### Issue: Out of Disk Space
```bash
# Immediate: Run GC
cd /root/harbor
docker compose stop
docker run -it --name gc --rm --volumes-from registry \
  goharbor/registry-photon:v2.8.3 \
  garbage-collect /etc/registry/config.yml
docker compose start

# Long-term: Configure retention policies
# See "Post-Installation Configuration" section
```

---

## 📚 Resources

- **Full Research Report:** `/docs/harbor-comprehensive-research-2025.md`
- **Official Docs:** https://goharbor.io/docs/
- **GitHub:** https://github.com/goharbor/harbor
- **Community Slack:** https://cloud-native.slack.com #harbor

---

## ✅ Deployment Checklist

- [ ] LXC container created (4 CPU, 8GB RAM)
- [ ] Docker installed
- [ ] Storage mounted to /data/registry
- [ ] SSL certificates configured
- [ ] Harbor installed and running
- [ ] Admin password changed
- [ ] Authentication configured (LDAP/OIDC)
- [ ] Projects created (production, staging, dev)
- [ ] Retention policies configured
- [ ] Garbage collection scheduled
- [ ] Vulnerability scanning enabled
- [ ] Robot account created for CI/CD
- [ ] Firewall configured
- [ ] Auto-start service enabled
- [ ] Backup script configured
- [ ] Monitoring setup (Prometheus/Grafana)
- [ ] Docker clients configured and tested
- [ ] Documentation updated with hostnames/IPs

---

**Deployment Time:** 30-45 minutes (basic), 2 hours (with monitoring and hardening)
**Difficulty:** Intermediate
**Maintenance:** 1-2 hours/month (updates, monitoring, cleanup)
