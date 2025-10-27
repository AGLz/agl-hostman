# Cloudflare Configuration for Archon (archon.aglz.io)

> **Date**: 2025-10-27
> **Status**: DNS configured, HTTPS returns 502 Bad Gateway
> **Target**: CT183 (192.168.0.183) on AGLSRV1

---

## 🎯 Current Configuration

### DNS Record
```
A Record: archon.aglz.io → 192.168.0.183
Proxied: ✅ Enabled (Cloudflare proxy active)
Status: Active
```

### Service Endpoints (LAN Access)
```
UI:  http://192.168.0.183:3737
API: http://192.168.0.183:8181
MCP: http://192.168.0.183:8051/mcp
```

### Intended HTTPS Access
```
UI:  https://archon.aglz.io
API: https://archon.aglz.io/api
MCP: https://archon.aglz.io/mcp
```

---

## 🚨 Current Issue

**Error**: HTTP/2 502 Bad Gateway

```bash
$ curl -I https://archon.aglz.io
HTTP/2 502
date: Mon, 27 Oct 2025 23:25:53 GMT
content-type: text/plain; charset=UTF-8
cache-control: private, max-age=0, no-store, no-cache, must-revalidate
server: cloudflare
cf-ray: 9955f48bbbad0199-GRU
```

**Root Cause**: Cloudflare proxy cannot reach backend service

---

## 🔍 Diagnosis

### Network Path Analysis

```
Internet → Cloudflare Edge (CF Proxy) → ??? → 192.168.0.183:3737
                                         ↑
                                    MISSING LINK
```

**Problem**: `192.168.0.183` is a **private LAN IP** (RFC 1918) - Cloudflare's edge servers cannot directly reach it.

### Verification Tests

**From LAN** (works):
```bash
curl http://192.168.0.183:3737  # ✅ HTTP 200 OK
curl http://192.168.0.183:8181/health  # ✅ {"status": "ok"}
```

**From Internet via Cloudflare** (fails):
```bash
curl https://archon.aglz.io  # ❌ HTTP/2 502
```

---

## ✅ Solution Options

### Option 1: Cloudflare Tunnel (Recommended)

**Why**: Secure, no port forwarding, free for personal use

**Architecture**:
```
Internet → CF Edge → Cloudflare Tunnel → cloudflared (CT117) → CT183:3737
```

**Implementation**:

1. **Use existing cloudflared container (CT117)**:
   ```bash
   ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel list'
   ```

2. **Create new tunnel for Archon**:
   ```bash
   ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel create archon'
   ```

3. **Configure tunnel routing**:
   ```yaml
   # /root/.cloudflared/config.yml (in CT117)
   tunnel: <TUNNEL_ID>
   credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

   ingress:
     - hostname: archon.aglz.io
       service: http://192.168.0.183:3737
     - service: http_status:404
   ```

4. **Update DNS in Cloudflare**:
   - Change `A record` to `CNAME` pointing to `<TUNNEL_ID>.cfargotunnel.com`
   - Proxy status: ✅ Proxied

5. **Start tunnel**:
   ```bash
   ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel run archon'
   ```

**Pros**:
- ✅ No firewall changes needed
- ✅ Zero-trust security (authenticated tunnel)
- ✅ No public IP exposure
- ✅ Automatic HTTPS termination
- ✅ DDoS protection included

**Cons**:
- ⚠️ Requires cloudflared daemon running
- ⚠️ Additional latency (~10-30ms)

---

### Option 2: Reverse Proxy with Public IP

**Why**: Traditional setup if you have a public IP with port forwarding

**Architecture**:
```
Internet → CF Edge → Public IP:443 → Router → NGINXPROXY (CT159) → CT183:3737
```

**Requirements**:
- Public static IP or DDNS
- Port forwarding (443 → CT159:443)
- Nginx reverse proxy configuration

**Implementation**:

1. **Configure port forwarding** (router/firewall):
   ```
   Public IP:443 → 192.168.0.159:443 (NGINXPROXY)
   ```

2. **Nginx config** (on CT159):
   ```nginx
   # /etc/nginx/sites-available/archon.aglz.io
   server {
       listen 443 ssl http2;
       server_name archon.aglz.io;

       ssl_certificate /etc/letsencrypt/live/archon.aglz.io/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/archon.aglz.io/privkey.pem;

       location / {
           proxy_pass http://192.168.0.183:3737;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }

       location /api {
           proxy_pass http://192.168.0.183:8181;
       }

       location /mcp {
           proxy_pass http://192.168.0.183:8051;
       }
   }
   ```

3. **Update Cloudflare DNS**:
   - Change DNS to point to your public IP
   - **Disable** Cloudflare proxy (DNS only)

**Pros**:
- ✅ Full control over SSL/TLS
- ✅ No third-party tunnel dependency
- ✅ Lower latency

**Cons**:
- ❌ Requires public IP
- ❌ Port forwarding complexity
- ❌ SSL certificate management
- ❌ Direct exposure to internet

---

### Option 3: Tailscale + HTTPS (Simple for Personal Use)

**Why**: Quick setup for personal/team access without exposing to internet

**Architecture**:
```
Client (with Tailscale) → Tailscale Mesh → CT183:3737 (100.x.x.x)
```

**Implementation**:

1. **Authenticate Tailscale** (already started):
   ```bash
   # Visit this URL to authenticate:
   https://login.tailscale.com/a/140ac19a01f901
   ```

2. **Get Tailscale IP**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- tailscale status --peers=false'
   ```

3. **Access via Tailscale**:
   ```
   UI:  http://<TAILSCALE_IP>:3737
   API: http://<TAILSCALE_IP>:8181
   MCP: http://<TAILSCALE_IP>:8051/mcp
   ```

4. **Optional: Enable HTTPS** (self-signed cert):
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- tailscale cert <TAILSCALE_HOSTNAME>'
   ```

**Pros**:
- ✅ Zero configuration
- ✅ Encrypted automatically
- ✅ MagicDNS support
- ✅ No public exposure

**Cons**:
- ❌ Requires Tailscale on all clients
- ❌ Not publicly accessible
- ❌ Team/collaboration limited by Tailscale pricing

---

## 📋 Recommended Action Plan

**For Personal/Team Use** (Easiest):
```bash
# 1. Authenticate Tailscale (already available)
Visit: https://login.tailscale.com/a/140ac19a01f901

# 2. Access via Tailscale mesh
# No further configuration needed!
```

**For Public Access** (Production):
```bash
# 1. Set up Cloudflare Tunnel on CT117
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel create archon'

# 2. Configure tunnel ingress
# (Edit /root/.cloudflared/config.yml on CT117)

# 3. Update Cloudflare DNS to CNAME tunnel
# 4. Start tunnel daemon
```

---

## 🛠️ Quick Commands

### Verify Local Access
```bash
# From AGLSRV1 or same LAN
curl http://192.168.0.183:3737  # UI
curl http://192.168.0.183:8181/health  # API health check
```

### Check Cloudflare Status
```bash
curl -I https://archon.aglz.io
```

### Restart Archon Services
```bash
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && /usr/local/bin/docker-compose restart"'
```

### View Archon Logs
```bash
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-ui -f'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server -f'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp -f'
```

---

## 📚 Related Documentation

- **Archon Integration**: `docs/archon-integration.md`
- **Infrastructure Map**: `docs/INFRA.md`
- **Cloudflare Tunnel Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **Tailscale Docs**: https://tailscale.com/kb/1017/install/

---

**Document Version**: 1.0
**Last Updated**: 2025-10-27
**Created By**: Claude Code (agl-hostman project)
