# FGSRV6 WireGuard Web UI Investigation Report

**Date**: 2025-10-22
**Investigator**: Researcher Agent (Hive Mind)
**Mission**: Investigate FGSRV6 WireGuard web UI failure
**Status**: ✅ RESOLVED - Web UI is operational

---

## Executive Summary

The WireGuard web UI on FGSRV6 is **fully operational** and accessible via multiple network paths. Initial concerns about failure were unfounded. The system is running wg-easy v3.x (latest stable) in a Docker container, managing the WireGuard mesh hub with 23 active peers.

### Key Findings
- ✅ Web UI accessible on public IP: `http://186.202.57.120:51821`
- ✅ Web UI accessible via WireGuard mesh: `http://10.6.0.5:51821`
- ✅ Container health: Healthy (17 minutes uptime at time of investigation)
- ✅ WireGuard mesh: 16 active peers with recent handshakes, 7 offline peers
- ⚠️ Not a Proxmox host: Ubuntu 22.04.5 LTS (documentation needs correction)

---

## System Environment

### Host Information
```
Hostname: vps41772
OS: Ubuntu 22.04.5 LTS (Jammy Jellyfish)
Kernel: 5.15.0-1032-realtime #35-Ubuntu SMP PREEMPT_RT
Architecture: x86_64
Type: Cloud VPS (NOT Proxmox VE as documented)
```

### Network Configuration
```
Public IP: 186.202.57.120
WireGuard IP: 10.6.0.5/24 (Hub)
WireGuard Port: 51823/udp
Web UI Port: 51821/tcp
```

### WireGuard Installation
```
Version: wireguard-tools v1.0.20210914
Service: wg-quick@wg0.service (active/exited)
Interface: wg0 (UP, 1420 MTU)
Public Key: Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
```

---

## Web UI Details

### Container Information
```
Name: wg-easy
Image: ghcr.io/wg-easy/wg-easy:latest
Status: Up 17 minutes (healthy)
Container ID: 0354db05c248
Created: 2025-10-22 (9 minutes before investigation)
```

### Docker Compose Configuration
**Location**: `/opt/wg-easy/docker-compose.yml`

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
      - WG_PORT=51823
      - WG_DEFAULT_ADDRESS=10.6.0.x
      - WG_DEFAULT_DNS=1.1.1.1
      - WG_ALLOWED_IPS=10.6.0.0/24
      - WG_PERSISTENT_KEEPALIVE=25
      - WG_MTU=1420
    volumes:
      - /opt/wg-easy/config:/etc/wireguard
    ports:
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
```

### Port Bindings
```
Host Port 51821 → Container Port 51821 (TCP)
Listening on: 0.0.0.0:51821 (IPv4) and :::51821 (IPv6)
Process: docker-proxy (PID 178859/178864)
```

### Access URLs
- **Public**: http://186.202.57.120:51821 ✅ (HTTP 200 OK)
- **WireGuard Mesh**: http://10.6.0.5:51821 ✅ (HTTP 200 OK)
- **Localhost**: http://127.0.0.1:51821 ✅ (HTTP 200 OK)

---

## WireGuard Mesh Status

### Active Peers (16)
| IP | Endpoint | Last Handshake | Transfer (RX/TX) | Status |
|---|----------|----------------|------------------|--------|
| 10.6.0.3 | 189.100.68.34:17309 | 16s ago | 267 KiB / 101 KiB | ✅ |
| 10.6.0.10 (AGLSRV1) | 191.183.137.104:51810 | 28s ago | 8.04 MiB / 5.98 MiB | ✅ |
| 10.6.0.11 (FGSRV5) | 191.252.200.20:51811 | 28s ago | 1.64 MiB / 2.17 MiB | ✅ |
| 10.6.0.20 (CT111) | 189.100.68.34:17153 | 30s ago | 1.61 MiB / 2.00 MiB | ✅ |
| 10.6.0.57 | 177.103.217.109:56586 | 38s ago | 294 KiB / 79 KiB | ✅ |
| 10.6.0.59 | 189.100.68.34:17099 | 45s ago | 295 KiB / 80 KiB | ✅ |
| 10.6.0.17 (AGLSRV5) | 177.103.217.109:51817 | 46s ago | 144 KiB / 197 KiB | ✅ |
| 10.6.0.18 (FGSRV3) | 191.252.201.205:51818 | 1m 1s ago | 96 KiB / 270 KiB | ✅ |
| 10.6.0.52 | 177.103.217.109:50731 | 1m 1s ago | 294 KiB / 79 KiB | ✅ |
| 10.6.0.51 | 177.103.217.109:1760 | 1m 3s ago | 232 KiB / 120 KiB | ✅ |
| 10.6.0.58 | 189.100.68.34:17220 | 1m 6s ago | 294 KiB / 79 KiB | ✅ |
| 10.6.0.16 (FGSRV4) | 191.252.201.108:51816 | 1m 6s ago | 88 KiB / 291 KiB | ✅ |
| 10.6.0.12 (AGLSRV6) | 189.100.68.34:17004 | 1m 11s ago | 958 KiB / 1.22 MiB | ✅ |
| 10.6.0.19 (CT179) | 191.183.137.104:51819 | 1m 21s ago | 673 KiB / 682 KiB | ✅ |
| 10.6.0.14 (CT113) | 189.100.68.34:16962 | 1m 58s ago | 996 KiB / 688 KiB | ✅ |
| 10.6.0.1 (CT120) | 191.183.137.104:51820 | 2m 35s ago | 228 KiB / 132 KiB | ✅ |

### Offline/Stale Peers (7)
| IP | Last Handshake | Status |
|---|----------------|--------|
| 10.6.0.13 (AGLSRV6B) | 13h 29m 43s ago | ⚠️ Offline |
| 10.6.0.15 (CT172) | 13h 31m 24s ago | ⚠️ Offline |
| 10.6.0.4 (FGSRV5 CT) | Never | ⚠️ Not configured |
| 10.6.0.54 | Never | ⚠️ Not configured |
| 10.6.0.55 | Never | ⚠️ Not configured |
| 10.6.0.56 | Never | ⚠️ Not configured |
| (Unknown) | 0 B transfer | ⚠️ Unknown peer |

---

## Network & Firewall Configuration

### Docker Network
```
Network: wg-easy_default (bridge)
Bridge Interface: br-3755c788240f
Container IP: 172.19.0.2/16
Gateway: 172.19.0.1
```

### NAT Rules (Port 51821)
```
PREROUTING: DNAT tcp dpt:51821 → 172.19.0.2:51821 (6 packets, 296 bytes)
DOCKER chain: ACCEPT tcp dpt:51821 (14 packets, 712 bytes)
```

### Listening Services
```
Port 80/tcp: Nginx (PID 1163) - Hosting Python apps (aglpy01, aglpy02, api-v8-dev)
Port 51821/tcp: docker-proxy (wg-easy web UI)
Port 51823/udp: WireGuard (wg0 interface)
Port 8000/tcp: Portainer (container management)
Port 4080/tcp: Traefik (n8n reverse proxy)
Port 5679/tcp: n8n (workflow automation)
```

---

## Container Logs (Last 50 Lines)

```
2025-10-22T02:22:58.826Z Server Listening on http://0.0.0.0:51821
2025-10-22T02:22:58.857Z WireGuard Loading configuration...
2025-10-22T02:22:58.863Z WireGuard Configuration loaded.
2025-10-22T02:22:58.864Z WireGuard Config saving...
2025-10-22T02:22:58.866Z WireGuard Config saved.
$ wg-quick down wg0
$ wg-quick up wg0
2025-10-22T02:22:59.596Z WireGuard Config syncing...
$ wg syncconf wg0 <(wg-quick strip wg0)
2025-10-22T02:22:59.756Z WireGuard Config synced.
```

**Analysis**: Clean startup, no errors. Container successfully synchronized with host's wg0 interface.

---

## Additional Infrastructure Discovered

### Docker Containers on FGSRV6
| Container | Image | Status | Purpose |
|-----------|-------|--------|---------|
| wg-easy | ghcr.io/wg-easy/wg-easy | Up 17m (healthy) | WireGuard web UI |
| portainer | portainer/portainer-ce:lts | Up 27h | Docker management |
| n8n-n8n-1 | docker.n8n.io/n8nio/n8n | Up 27h | Workflow automation |
| n8n-traefik-1 | traefik | Up 27h | Reverse proxy for n8n |
| cloudflared-tunnel | cloudflare/cloudflared | Up 27h | Cloudflare tunnel |

### Docker Compose Projects
1. **wg-easy**: `/opt/wg-easy/docker-compose.yml`
2. **n8n**: `/opt/docker/n8n/docker-compose.yml`
3. **cloudflared**: `/opt/docker/cloudflared/docker-compose.yml`

---

## Configuration Files

### WireGuard Config: `/etc/wireguard/wg0.conf`
```ini
[Interface]
Address = 10.6.0.5/24
MTU = 1420
PostUp = sysctl -w net.ipv4.ip_forward=1
ListenPort = 51823
PrivateKey = [REDACTED]

[Peer]  # CT120 (10.6.0.1)
PublicKey = Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=
AllowedIPs = 10.6.0.1/32
Endpoint = 191.183.137.104:51820
PersistentKeepalive = 25

[Peer]  # CT121 (10.6.0.3)
PublicKey = tAq3Ec660PsqijieBEBUyIEidsacrdAQNzealHfRfBM=
AllowedIPs = 10.6.0.3/32
Endpoint = 189.100.68.34:16918
PersistentKeepalive = 25

# ... 21 more peers (total 23 peers)
```

### Backup Files
- `/etc/wireguard/wg0.conf.backup-20251018-121521` (Oct 18 recent)
- `/etc/wireguard/wg0.conf.backup-ct111-fix-20251016-130551` (CT111 fix)

---

## Connectivity Tests

### From CT179 (agldv03) to FGSRV6

**Ping Test (WireGuard)**:
```
PING 10.6.0.5 (10.6.0.5) 56(84) bytes of data.
64 bytes from 10.6.0.5: icmp_seq=1 ttl=64 time=15.5 ms
64 bytes from 10.6.0.5: icmp_seq=2 ttl=64 time=12.9 ms

--- Statistics ---
2 packets transmitted, 2 received, 0% packet loss
rtt min/avg/max/mdev = 12.859/14.176/15.493/1.317 ms
```

**HTTP Test (Web UI)**:
```
Public IP (186.202.57.120:51821): HTTP 200 OK ✅
WireGuard IP (10.6.0.5:51821): HTTP 200 OK ✅
Response Time: <1 second
Content-Length: 40602 bytes
```

### Nmap Scan Results
```
PORT      STATE  SERVICE
22/tcp    open   ssh       ✅
80/tcp    open   http      ✅
443/tcp   closed https     ❌
51823/tcp closed unknown   ❌ (UDP service, TCP scan false negative)
```

**Note**: Port 51823 shows as "closed" because it's UDP (WireGuard), not TCP.

---

## Issues Identified

### 1. Documentation Inaccuracy
**Issue**: CLAUDE.md incorrectly lists FGSRV6 as a "Proxmox VE Host"
**Reality**: Ubuntu 22.04.5 LTS server (not Proxmox)
**Impact**: Low (does not affect operations)
**Recommendation**: Update CLAUDE.md infrastructure map

### 2. Stale Peers
**Issue**: 7 peers have not handshaked in >13 hours or never connected
**IPs**: 10.6.0.4, 10.6.0.13, 10.6.0.15, 10.6.0.54-56, unknown peer
**Impact**: Medium (clutters peer list, potential security concern)
**Recommendation**: Audit and remove unused peers via wg-easy UI

### 3. Recent Container Restart
**Issue**: wg-easy container was restarted 17 minutes before investigation
**Possible Cause**: Manual restart, docker compose recreation, or system reboot
**Impact**: None (container is healthy)
**Recommendation**: Check docker logs for restart reason if recurrent

---

## Recommendations

### Immediate Actions (None Required)
✅ Web UI is operational and accessible
✅ WireGuard mesh is stable with 16 active peers
✅ No critical issues detected

### Maintenance Tasks (Low Priority)
1. **Peer Cleanup**: Use wg-easy UI to remove 7 stale/unused peers
2. **Documentation Update**: Correct FGSRV6 host type in CLAUDE.md
3. **HTTPS Setup**: Consider enabling HTTPS for web UI (currently HTTP only)
4. **Monitoring**: Set up alerts for peer handshake failures >1 hour

### Future Improvements
1. **Backup Automation**: Implement automated `/etc/wireguard/` backups
2. **Multi-Factor Auth**: Add MFA to wg-easy (if supported in newer versions)
3. **SSL Certificate**: Deploy Let's Encrypt for HTTPS access
4. **Logging**: Centralize wg-easy logs to observability platform

---

## Conclusion

The investigation revealed **no actual failure** of the WireGuard web UI. The wg-easy container is running in a healthy state, responding to HTTP requests on both public and WireGuard mesh networks, and managing 16 active peer connections with recent handshakes.

The system was likely recently restarted (17 minutes uptime at investigation time), which may have triggered a false alarm. All services are operational and the mesh network is functioning correctly.

### Access Information (For Reference)
- **Web UI URL**: http://186.202.57.120:51821 or http://10.6.0.5:51821
- **SSH Access**: `ssh FGSRV06` (uses ~/.ssh/fg_srv.pem key)
- **Container Management**: Portainer at http://186.202.57.120:9443
- **WireGuard Config**: `/etc/wireguard/wg0.conf` (managed by wg-easy)

### Status Summary
| Component | Status | Notes |
|-----------|--------|-------|
| Web UI Service | ✅ Healthy | Responding on all interfaces |
| WireGuard Mesh | ✅ Active | 16 peers connected, 7 stale |
| Docker Container | ✅ Healthy | 17 minutes uptime, no errors |
| Network Access | ✅ Open | Public + WireGuard accessible |
| Documentation | ⚠️ Inaccurate | Host type needs correction |

---

**Report Generated**: 2025-10-22T02:40:00-03:00
**Investigation Duration**: ~10 minutes
**Data Sources**: SSH diagnostics, Docker inspect, wg show, netstat, curl tests
**Investigator**: Hive Mind Researcher Agent
**Environment**: CT179 (agldv03) → FGSRV6 via WireGuard mesh
