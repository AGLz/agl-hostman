# FGSRV6 WireGuard Web UI Network Analysis

**Analysis Date**: 2025-10-22 02:07 UTC
**Source Environment**: CT179 (agldv03) - Triple Network Stack
**Analyst**: Hive-Mind Swarm (Network Diagnostics Agent)

---

## Executive Summary

**Status**: 🟡 DEGRADED - Network connectivity excellent, WireGuard web UI down due to port conflict

**Key Findings**:
- ✅ All network paths operational (WireGuard/Tailscale/Public)
- ❌ wg-easy container exited (port conflict with wg-quick@wg0)
- ✅ Alternative access available via Portainer and direct SSH
- 🔧 Fix: Change WG_PORT from 51823 to 51824 in docker-compose.yml

---

## Environment Context

**Source**: CT179 (agldv03)
- **LAN**: 192.168.0.179, 192.168.1.179
- **WireGuard**: 10.6.0.19
- **Tailscale**: 100.94.221.87
- **Capabilities**: Full triple network stack (optimal testing platform)

---

## Connectivity Matrix

### FGSRV6 Reachability (All Paths Tested)

| Network Path | IP Address | Status | Latency | Packet Loss |
|--------------|------------|--------|---------|-------------|
| **WireGuard** | 10.6.0.5 | ✅ ACTIVE | 13-17ms | 0% |
| **Tailscale** | 100.83.51.9 | ✅ ACTIVE | 10-40ms | 0% |
| **Public IP** | 186.202.57.120 | ✅ ACTIVE | 14-18ms | 0% |

**Verdict**: Network layer fully operational on all paths.

---

## Port Scan Results

### Accessible Services (All Networks)

| Port | Protocol | Service | Status | Details |
|------|----------|---------|--------|---------|
| 80 | TCP | Nginx | ✅ OPEN | HTTP 200 OK - Default welcome page |
| 8000 | TCP | Portainer | ✅ OPEN | Docker management UI |

### Blocked/Refused Ports

| Port | Protocol | Expected Service | Status | Reason |
|------|----------|------------------|--------|--------|
| 51821 | TCP | wg-easy Web UI | ❌ REFUSED | Container exited (port conflict) |
| 5000 | TCP | Alternative UI | ❌ REFUSED | Not configured |
| 8080 | TCP | Alternative UI | ❌ REFUSED | Not configured |
| 443 | TCP | HTTPS | ❌ REFUSED | Not configured |

---

## Critical Finding: wg-easy Container Failure

### Container Status
```
Container: wg-easy
Image: ghcr.io/wg-easy/wg-easy
Status: EXITED
Exit Code: 128
Last Activity: 2025-10-18 02:47:02 UTC (SIGTERM received)
```

### Root Cause Analysis

**PORT CONFLICT DETECTED**:
- **Issue**: wg-easy container attempts to bind UDP port 51823
- **Conflict**: Port already owned by `wg-quick@wg0.service` (systemd)
- **Error**: `failed to bind host port for 0.0.0.0:51823:172.19.0.2:51823/udp: address already in use`

**Current Port Usage**:
```bash
# wg-quick@wg0 (systemd service)
UDP 0.0.0.0:51823 (WireGuard mesh hub)

# wg-easy (Docker container - ATTEMPTING)
UDP 0.0.0.0:51823 (CONFLICT!)
```

### Container Configuration

**File**: `/opt/wg-easy/docker-compose.yml`

```yaml
version: "3.8"
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    restart: unless-stopped
    environment:
      - WG_HOST=186.202.57.120
      - PASSWORD_HASH=$2a$12$.pyRlYHQeP/jNtOuuSIbsOQw4JGnm5z8DPJcH9T2B.Bfi2yHUYCDi
      - WG_DEVICE=wg0
      - WG_PORT=51823          # ⚠️ CONFLICT HERE
      - WG_DEFAULT_ADDRESS=10.6.0.x
      - WG_DEFAULT_DNS=1.1.1.1
      - WG_ALLOWED_IPS=0.0.0.0/0
      - WG_PERSISTENT_KEEPALIVE=25
      - WG_MTU=1420
    volumes:
      - /opt/wg-easy/config:/etc/wireguard
    ports:
      - "51823:51823/udp"      # ⚠️ CONFLICT HERE
      - "51821:51821/tcp"      # Web UI port (OK)
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
```

---

## Services Analysis

### Running Services on FGSRV6

| Service | Port | Type | Status | Notes |
|---------|------|------|--------|-------|
| nginx | 80/tcp | System | ✅ Running | 5 worker processes |
| docker-proxy | 8000/tcp | Container | ✅ Running | Portainer |
| wg-quick@wg0 | 51823/udp | System | ✅ Running | WireGuard hub |
| portainer | 9443/tcp | Container | ✅ Running | Management UI |
| n8n-n8n-1 | 5679/tcp | Container | ✅ Running | Workflow automation |
| n8n-traefik-1 | 4080,4443/tcp | Container | ✅ Running | Reverse proxy |
| cloudflared-tunnel | - | Container | ✅ Running | Cloudflare tunnel |
| **wg-easy** | **51821/tcp** | **Container** | **❌ EXITED** | **Port conflict** |

### WireGuard Interface Status

```bash
interface: wg0
  public key: Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
  listening port: 51823  # ⚠️ Owned by wg-quick@wg0
```

---

## Firewall Status

**Analysis**: No blocking rules detected

```bash
# iptables check for WG UI ports
Result: No specific rules found for ports 51821, 5000, 8080
```

**Conclusion**:
- No firewall blocking web UI access
- Port 80 accessible confirms permissive policy
- Issue is service-level (container exit), not network-level

---

## DNS Resolution

| IP Address | DNS Status | Result |
|------------|------------|--------|
| 186.202.57.120 | ✅ SUCCESS | vps41772.publiccloud.com.br |
| 10.6.0.5 | ❌ NO PTR | Expected (private WireGuard mesh) |
| 100.83.51.9 | N/A | Tailscale managed |

---

## Recommended Solutions

### Option 1: Fix Port Conflict (RECOMMENDED)

**Steps**:
```bash
# 1. Edit docker-compose configuration
ssh root@10.6.0.5
cd /opt/wg-easy
nano docker-compose.yml

# 2. Change these lines:
# FROM:
      - WG_PORT=51823
    ports:
      - "51823:51823/udp"

# TO:
      - WG_PORT=51824
    ports:
      - "51824:51824/udp"

# 3. Restart container
docker-compose down
docker-compose up -d

# 4. Verify
docker ps | grep wg-easy
curl -I http://10.6.0.5:51821
```

**Expected Result**: Web UI accessible at `http://10.6.0.5:51821`

---

### Option 2: Reconfigure wg-easy to Manage Existing Interface

**Use Case**: Single WireGuard management point

**Steps**:
```bash
# 1. Stop systemd service
systemctl stop wg-quick@wg0
systemctl disable wg-quick@wg0

# 2. Backup config
cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.backup

# 3. Migrate config to wg-easy
# Manual peer migration required

# 4. Start wg-easy
cd /opt/wg-easy
docker-compose up -d
```

**Caution**: This approach requires careful migration of all existing peers.

---

### Option 3: Nginx Reverse Proxy (SSL Termination)

**Use Case**: HTTPS access via standard ports

**Configuration**:
```nginx
# /etc/nginx/sites-available/wireguard
server {
    listen 443 ssl;
    server_name wireguard.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:51821;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Access**: `https://wireguard.yourdomain.com` or `https://10.6.0.5`

---

## Immediate Next Steps

1. **Fix Port Conflict** (Priority: HIGH)
   - Change WG_PORT to 51824 in docker-compose.yml
   - Restart wg-easy container
   - Verify web UI accessibility

2. **Test Web UI Access** (Priority: MEDIUM)
   - From CT179: `curl http://10.6.0.5:51821`
   - From browser: Navigate to `http://10.6.0.5:51821`
   - Login with configured password

3. **Configure SSL** (Priority: LOW)
   - Set up nginx reverse proxy
   - Obtain SSL certificate (Let's Encrypt or self-signed)
   - Enable HTTPS access

4. **Update Documentation** (Priority: MEDIUM)
   - Document web UI access URL
   - Add credentials to password manager
   - Update CLAUDE.md with web UI details

---

## Accessibility Summary

### Current State
| Component | Status | Access Method |
|-----------|--------|---------------|
| WireGuard Web UI | ❌ DOWN | Port conflict (fix pending) |
| Portainer | ✅ UP | `http://10.6.0.5:8000` |
| SSH Access | ✅ UP | `ssh root@10.6.0.5` (WG) |
| SSH Access | ✅ UP | `ssh root@100.83.51.9` (TS) |
| WireGuard Mesh | ✅ UP | 14 active peers |

### Health Metrics
- **Network Health**: 🟢 EXCELLENT (all paths operational)
- **Service Health**: 🟡 DEGRADED (web UI down, core services up)
- **Overall Status**: 🟡 OPERATIONAL (manual management available)

---

## Analysis Metadata

**Tool Used**: Network diagnostics from CT179 (agldv03)
**Commands Executed**:
- `ping` (connectivity tests)
- `nc -zv` (port scans)
- `curl` (HTTP probes)
- `ssh` + `docker logs/inspect` (container analysis)
- `ss -tlnp` (listening ports)
- `wg show` (WireGuard status)

**Storage Location**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/fgsrv6-network-diagnostics.md`

**Memory Key**: `network/diagnostics` (Hive-Mind collective memory)

---

*End of Analysis Report*
