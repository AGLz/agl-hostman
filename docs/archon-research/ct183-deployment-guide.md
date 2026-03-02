# CT183 Archon Deployment - Quick Start Guide

> **Target**: AGLSRV1 (192.168.0.245)
> **Container ID**: 183
> **Hostname**: archon
> **IP**: 192.168.0.183 (LAN), 10.6.0.183 (WireGuard optional)

---

## Prerequisites Checklist

- [ ] Supabase account created (https://supabase.com)
- [ ] OpenAI API key obtained (or Ollama installed for local models)
- [ ] AGLSRV1 access verified (`ssh root@192.168.0.245`)
- [ ] Reviewed comprehensive analysis document

---

## Deployment Steps

### 1. Create LXC Container (on AGLSRV1)

```bash
# SSH to AGLSRV1
ssh root@192.168.0.245

# Create CT183
pct create 183 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname archon \
  --cores 4 \
  --memory 8192 \
  --swap 4096 \
  --rootfs local-zfs:50 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.0.183/24,gw=192.168.0.1 \
  --nameserver 192.168.0.102 \
  --features keyctl=1,nesting=1 \
  --unprivileged 1

# Add nested container support
cat >> /etc/pve/lxc/183.conf <<EOF
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF

# Start container
pct start 183
```

### 2. Base System Setup (inside CT183)

```bash
# Enter container
pct enter 183

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker

# Install Docker Compose plugin
apt install docker-compose-plugin -y

# Install tools
apt install -y git curl wget nano htop net-tools

# Set timezone
timedatectl set-timezone America/Sao_Paulo
```

### 3. Deploy Archon

```bash
# Clone repository
git clone -b stable https://github.com/coleam00/archon.git /opt/archon
cd /opt/archon

# Configure environment
cp .env.example .env
nano .env
```

**Edit `.env`** with your credentials:
```env
# REQUIRED
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here  # NOT anon key!

# OPTIONAL (defaults shown)
ARCHON_UI_PORT=3737
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_AGENTS_PORT=8052
HOST=192.168.0.183
LOG_LEVEL=INFO
```

**Deploy services**:
```bash
# Standard deployment
docker compose up -d

# OR with ML agents (requires 16 GB RAM)
docker compose --profile agents up -d

# Verify
docker compose ps
docker compose logs -f
```

### 4. Database Setup

1. Open Supabase Dashboard: https://supabase.com/dashboard
2. Navigate to **SQL Editor**
3. Copy contents of `/opt/archon/migration/complete_setup.sql`
4. Execute script
5. Verify tables created (projects, tasks, knowledge_base, etc.)

### 5. Configure Systemd Service

```bash
cat > /etc/systemd/system/archon.service <<'EOF'
[Unit]
Description=Archon AI Command Center
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/archon
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable archon.service
systemctl start archon.service
```

### 6. Access & Configure

**Local Access**:
- UI: http://192.168.0.183:3737
- MCP: http://192.168.0.183:8051

**Complete onboarding wizard**:
1. Set OpenAI API key (Settings → API Keys)
2. Select default model (gpt-4 recommended)
3. Configure RAG strategy (hybrid recommended)

---

## WireGuard Integration (Optional)

**For remote MCP access via WireGuard mesh**:

```bash
# Install WireGuard
apt install wireguard -y

# Generate keys
wg genkey | tee /tmp/privatekey | wg pubkey > /tmp/publickey

# Configure interface
cat > /etc/wireguard/wg0.conf <<'EOF'
[Interface]
PrivateKey = <PASTE_PRIVATE_KEY_FROM_/tmp/privatekey>
Address = 10.6.0.183/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
EOF

# Update hub (FGSRV6) with public key from /tmp/publickey
# SSH to hub and add peer:
ssh root@10.6.0.5
# Add to /etc/wireguard/wg0.conf:
# [Peer]
# PublicKey = <PASTE_PUBLIC_KEY_FROM_CT183>
# AllowedIPs = 10.6.0.183/32

# Restart hub
wg-quick down wg0 && wg-quick up wg0

# Start WireGuard on CT183
wg-quick up wg0
systemctl enable wg-quick@wg0

# Verify
ping 10.6.0.5  # Hub
wg show
```

**Access MCP via WireGuard**:
- From CT179: http://10.6.0.183:8051
- From other mesh nodes: http://10.6.0.183:8051

---

## AI Client Configuration

### Claude Code (from AGLHQ11 WSL2)

**Option 1: Via LAN** (if on same network):
```json
// ~/.config/claude/mcp_servers.json
{
  "mcpServers": {
    "archon": {
      "transport": "sse",
      "url": "http://192.168.0.183:8051/sse"
    }
  }
}
```

**Option 2: Via WireGuard** (from CT179):
```json
// ~/.config/claude/mcp_servers.json
{
  "mcpServers": {
    "archon": {
      "transport": "sse",
      "url": "http://10.6.0.183:8051/sse"
    }
  }
}
```

**Option 3: Via Tailscale** (from anywhere):
```json
// ~/.config/claude/mcp_servers.json
{
  "mcpServers": {
    "archon": {
      "transport": "sse",
      "url": "http://100.x.x.x:8051/sse"  // Replace with Tailscale IP
    }
  }
}
```

### Cursor

**Settings → MCP Servers → Add Server**:
```json
{
  "archon": {
    "url": "http://192.168.0.183:8051",  // or WireGuard/Tailscale IP
    "protocol": "mcp"
  }
}
```

### Windsurf

**Windsurf MCP Config**:
```json
{
  "servers": {
    "archon": {
      "endpoint": "http://192.168.0.183:8051/mcp",
      "transport": "http"
    }
  }
}
```

---

## Verification Steps

**Health Checks**:
```bash
# API server
curl http://192.168.0.183:8181/health
# Expected: {"status":"healthy"}

# Frontend
curl http://192.168.0.183:3737
# Expected: HTML content

# MCP server
curl http://192.168.0.183:8051/
# Expected: MCP server info
```

**Docker Status**:
```bash
docker compose ps
# Expected: 3 containers running (server, mcp, frontend)
# OR 4 if using --profile agents
```

**Logs**:
```bash
# Real-time logs
docker compose logs -f

# Specific service
docker compose logs -f archon-server
```

---

## Maintenance

### Update Archon

```bash
cd /opt/archon
git fetch origin stable
git pull origin stable
docker compose down
docker compose up --build -d
```

### Backup

**Automated backup script** (saves to WireGuard NFS):
```bash
cat > /usr/local/bin/archon-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR=/mnt/pve/fgsrv6-wg/backups/archon
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup environment
cp /opt/archon/.env $BACKUP_DIR/env_$DATE.bak

# Backup Docker volumes (if using local volumes)
docker run --rm -v archon_documents:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/documents_$DATE.tar.gz -C /data .

# Keep last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.bak" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x /usr/local/bin/archon-backup.sh

# Add cron job (daily at 2 AM)
echo "0 2 * * * /usr/local/bin/archon-backup.sh" | crontab -
```

### Reset Database

**If needed** (clears all data):
```bash
# 1. Execute in Supabase SQL Editor:
#    /opt/archon/migration/RESET_DB.sql

# 2. Re-run setup:
#    /opt/archon/migration/complete_setup.sql

# 3. Restart services
docker compose restart
```

---

## Troubleshooting

### Issue: Containers won't start

**Check**:
```bash
docker compose logs
journalctl -u docker -n 50
```

**Common fixes**:
- Verify `keyctl=1,nesting=1` in `/etc/pve/lxc/183.conf`
- Restart Docker: `systemctl restart docker`
- Check disk space: `df -h`

### Issue: "Permission denied" on save operations

**Cause**: Using anon key instead of service role key

**Fix**:
1. Get correct key from Supabase Dashboard → Settings → API → Service Role Key
2. Update `.env`: `SUPABASE_SERVICE_KEY=<service-role-key>`
3. Restart: `docker compose restart`

### Issue: MCP connection fails from AI client

**Check**:
```bash
# Verify MCP server is listening
curl http://192.168.0.183:8051/
netstat -tlnp | grep 8051
```

**Common fixes**:
- Check firewall: `iptables -L | grep 8051`
- Verify network connectivity: `ping 192.168.0.183`
- Check MCP logs: `docker compose logs archon-mcp`

### Issue: High memory usage

**If using agents service**:
- Increase RAM to 16 GB: `pct set 183 -memory 16384`
- Monitor: `htop` or `docker stats`

**If not using agents**:
- Remove agents profile: `docker compose down` then `docker compose up -d`

---

## Performance Tuning

**For high-volume usage**:

```bash
# Increase Docker ulimits
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

systemctl restart docker
docker compose up -d
```

**Nginx reverse proxy** (optional - for SSL/caching):
```bash
apt install nginx -y

cat > /etc/nginx/sites-available/archon <<'EOF'
server {
    listen 80;
    server_name archon.agl.local;

    location / {
        proxy_pass http://localhost:3737;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;
    }

    location /mcp {
        proxy_pass http://localhost:8051;
        proxy_http_version 1.1;
        proxy_buffering off;
    }
}
EOF

ln -s /etc/nginx/sites-available/archon /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
```

---

## Next Steps After Deployment

1. **Populate Knowledge Base**:
   - Upload documentation (UI → Knowledge → Upload)
   - Crawl websites (UI → Knowledge → Crawl)
   - Add code examples

2. **Create Projects**:
   - UI → Projects → New Project
   - Add features and tasks
   - Configure AI-assisted task generation

3. **Test MCP Integration**:
   - Connect AI client (Claude Code, Cursor, etc.)
   - Query knowledge base from AI
   - Verify search results

4. **Monitor Performance**:
   - Check Docker stats: `docker stats`
   - Review logs: `docker compose logs -f`
   - Monitor disk usage: `df -h`

5. **Scale Resources** (if needed):
   - Increase RAM: `pct set 183 -memory 16384`
   - Add CPU cores: `pct set 183 -cores 8`
   - Expand storage: `pct resize 183 rootfs +50G`

---

## Resources

- **Comprehensive Analysis**: `docs/archon-research/archon-comprehensive-analysis.md`
- **Official Repo**: https://github.com/coleam00/Archon
- **Supabase Docs**: https://supabase.com/docs
- **MCP Protocol**: https://modelcontextprotocol.io

---

**Deployment Checklist**:

- [ ] CT183 created on AGLSRV1
- [ ] Docker installed and running
- [ ] Archon deployed via Docker Compose
- [ ] Supabase database configured
- [ ] UI accessible at http://192.168.0.183:3737
- [ ] MCP server responding at http://192.168.0.183:8051
- [ ] Systemd service enabled
- [ ] AI client configured and connected
- [ ] Knowledge base populated with test documents
- [ ] Backup cron job configured
- [ ] (Optional) WireGuard mesh integration complete
- [ ] (Optional) Tailscale configured for remote access

**End of Quick Start Guide**
