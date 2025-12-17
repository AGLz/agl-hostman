# n8n Native Installation - Success Report

**Date**: 2025-12-14
**Container**: CT202 (n8n-docker)
**Status**: ✅ **OPERATIONAL**

## Summary

Successfully recovered n8n from corrupted container state by pivoting from Docker deployment to native Node.js installation. This approach bypassed LXC /proc/sys read-only limitations that prevented Docker containers from starting.

## Problem Background

- **Original Issue**: CT202 filesystem corruption, loop device mount failures
- **Docker Deployment**: 8 failed attempts due to OCI runtime sysctl permission denied
- **Root Cause**: LXC mounts /proc/sys as read-only, preventing Docker's OCI runtime from accessing sysctl
- **Solution**: Native n8n installation using npm, bypassing Docker entirely

## Implementation Details

### 1. Container Rebuild

**Before**:
- Storage: RAW disk on spark (98% full)
- State: Corrupted filesystem, cannot start
- Data: 38MB n8n workflows and database

**After**:
- Storage: ZFS subvolume on local-zfs (64GB)
- OS: Fresh Debian 12.12 installation
- Mode: Privileged container (unprivileged caused UID mapping issues)

```bash
# Destroyed old container
pct destroy 202

# Created new container on ZFS
pct create 202 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname n8n-docker \
  --memory 8192 \
  --cores 4 \
  --rootfs local-zfs:64 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.0.202/24,gw=192.168.0.1 \
  --features nesting=1,keyctl=1 \
  --unprivileged 0
```

### 2. Data Recovery and Migration

**Backup locations**:
```
/var/lib/vz/dump/ct202-recovery-20251212/
├── n8n-config-20251212-154146.tar.gz (1.5KB)
├── n8n-volumes-20251212-154147.tar.gz (44MB)
└── traefik-data-20251212-154156.tar.gz (2.8KB)
```

**Data migration**:
```bash
# Extracted data from Docker volume
VOLUME_PATH=$(docker volume inspect n8n_data --format '{{.Mountpoint}}')
cp -av $VOLUME_PATH/* /root/.n8n/

# Total migrated: 38MB
# Key files:
#   - database.sqlite (20MB) - All workflows and credentials
#   - config - Instance settings with encryption key
#   - binaryData/ - Workflow binary data
#   - nodes/ - Custom nodes with dependencies
```

### 3. Native Installation Stack

**Node.js 20 LTS**:
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
# Installed: v20.19.6 with npm 10.8.2
```

**n8n Global Installation**:
```bash
npm install -g n8n
# Installed: n8n 1.123.5
```

**systemd Service** (`/etc/systemd/system/n8n.service`):
```ini
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/.n8n
Environment="N8N_HOST=n8n.aglz.io"
Environment="N8N_PORT=5678"
Environment="N8N_PROTOCOL=https"
Environment="N8N_ENCRYPTION_KEY=1Lduq4XQO3493qMGLpPfco09Ko035gnV"
Environment="N8N_USER_MANAGEMENT_JWT_SECRET=UvTOAHcTZX2MSRcMZt3jjokWiG3WB5H8hVAjn57oCrU="
Environment="GENERIC_TIMEZONE=America/Sao_Paulo"
Environment="WEBHOOK_URL=https://n8n.aglz.io/"
Environment="N8N_DIAGNOSTICS_ENABLED=false"
Environment="N8N_PERSONALIZATION_ENABLED=false"
Environment="N8N_SECURE_COOKIE=false"
Environment="NODE_ENV=production"
Environment="N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false"
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Nginx Reverse Proxy** (`/etc/nginx/sites-available/n8n`):
```nginx
server {
    listen 80;
    server_name n8n.aglz.io;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

### 4. Critical Fix: Encryption Key Mismatch

**Problem**: n8n failed to start with encryption key mismatch error

**Root Cause**: Generated new encryption key instead of using existing key from config file

**Solution**: Extracted encryption key from `/root/.n8n/config` and used it in systemd service

```bash
# Config file contained:
{"encryptionKey": "1Lduq4XQO3493qMGLpPfco09Ko035gnV"}

# Updated systemd service to use existing key
Environment="N8N_ENCRYPTION_KEY=1Lduq4XQO3493qMGLpPfco09Ko035gnV"
```

## Current Status

### ✅ Services Running

**n8n**:
```
● n8n.service - n8n - Workflow Automation Tool
     Loaded: loaded (/etc/systemd/system/n8n.service; enabled)
     Active: active (running)
   Main PID: 169933
```

**Nginx**:
```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled)
     Active: active (running)
```

### ✅ Network Access

- **Internal**: http://127.0.0.1:5678 (n8n listening)
- **LAN**: http://192.168.0.202/ (Nginx proxy)
- **Public**: https://n8n.aglz.io (Cloudflare SSL)

### ✅ Workflows Loaded

```
Start Active Workflows:
Activated workflow "AutoRespond" (ID: vvYSVS8nTYy05yhC)
```

### ✅ Database Migrations

Successfully ran 4 database migrations on first startup:
- AddActiveVersionIdColumn1763047800000
- ChangeOAuthStateColumnToUnboundedVarchar1763572724000
- CreateBinaryDataTable1763716655000
- CreateWorkflowPublishHistoryTable1764167920585

## SSL/TLS Configuration

**Current**: Cloudflare SSL (working)
- Domain: https://n8n.aglz.io
- Certificate: Cloudflare-managed
- Status: HTTP/2 200 OK responses

**Attempted**: Let's Encrypt with certbot
- Result: Failed (domain behind Cloudflare prevents HTTP-01 challenge)
- Note: Let's Encrypt not needed since Cloudflare SSL is active

**Alternative** (if needed):
```bash
# Use DNS-01 challenge with Cloudflare API
certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d n8n.aglz.io
```

## Architecture Benefits

### Why Native Installation Works

**Docker Approach** (Failed):
```
n8n Container
  └─→ OCI Runtime (runc)
      └─→ Needs sysctl access
          └─→ /proc/sys mounted read-only in LXC ❌
```

**Native Approach** (Success):
```
n8n Native (Node.js)
  └─→ Direct process
      └─→ No OCI runtime layer
          └─→ No sysctl requirements ✅
```

### Performance Comparison

| Metric | Docker (Failed) | Native (Success) |
|--------|----------------|------------------|
| Memory Usage | N/A (didn't start) | 139MB |
| Startup Time | N/A (didn't start) | ~5 seconds |
| Container Layers | 3 (n8n + Traefik + network) | 2 (n8n + Nginx) |
| Complexity | High (Docker + LXC) | Low (systemd) |
| Maintenance | Docker updates | npm updates |

## Maintenance Commands

### Service Management
```bash
# Check status
systemctl status n8n
systemctl status nginx

# Restart
systemctl restart n8n

# View logs
journalctl -u n8n -f
```

### n8n Updates
```bash
# Update to latest version
npm update -g n8n

# Restart service
systemctl restart n8n
```

### Backup
```bash
# Backup n8n data directory
tar -czf /var/lib/vz/dump/n8n-backup-$(date +%Y%m%d).tar.gz \
  -C /root .n8n

# Backup includes:
#   - database.sqlite (workflows, credentials)
#   - config (instance settings)
#   - binaryData/ (workflow files)
#   - nodes/ (custom nodes)
```

### Restore
```bash
# Stop service
systemctl stop n8n

# Restore data
tar -xzf /var/lib/vz/dump/n8n-backup-YYYYMMDD.tar.gz -C /root

# Start service
systemctl start n8n
```

## Troubleshooting

### Check if n8n is listening
```bash
netstat -tlnp | grep 5678
# Should show: tcp6 :::5678 LISTEN
```

### Check active workflows
```bash
journalctl -u n8n --no-pager | grep "Activated workflow"
```

### Test local access
```bash
curl -I http://localhost:5678
# Should return: HTTP/1.1 200 OK
```

### Test external access
```bash
curl -I https://n8n.aglz.io
# Should return: HTTP/2 200
```

## Lessons Learned

1. **LXC /proc/sys Limitation**: Docker containers requiring sysctl access cannot run in LXC (even privileged mode)

2. **Native Installation Advantages**:
   - No OCI runtime layer
   - Simpler systemd service management
   - Lower resource overhead
   - Easier troubleshooting

3. **Encryption Key Preservation**: Must use existing encryption key from config file to access existing workflows

4. **ZFS Migration**: Moving from RAW disk to ZFS provides better reliability and snapshot capabilities

5. **Cloudflare SSL**: Domains behind Cloudflare already have SSL, making Let's Encrypt unnecessary

## Next Steps

- ✅ n8n operational and accessible
- ✅ Workflows loaded and active
- ✅ SSL working via Cloudflare
- ⏸️ Monitor n8n performance and stability
- ⏸️ Set up automated backups (cron job)
- ⏸️ Document workflow migration guide for other users

## Related Documentation

- Initial troubleshooting: `docs/updates/n8n-troubleshooting-notes.md`
- Container configuration: `/etc/pve/lxc/202.conf`
- Service configuration: `/etc/systemd/system/n8n.service`
- Nginx configuration: `/etc/nginx/sites-available/n8n`

## Timeline

- **2025-12-12**: Initial corruption discovered, data recovery completed
- **2025-12-12**: 8 Docker deployment attempts (all failed)
- **2025-12-14**: Pivoted to native installation
- **2025-12-14**: ✅ n8n successfully deployed and operational

---

**Status**: 🟢 **PRODUCTION READY**
**Priority**: 🔴 **CRITICAL** (automation workflows restored)
**Deployment Method**: Native Node.js installation
**Access**: https://n8n.aglz.io
