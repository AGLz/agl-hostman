# Infrastructure Service Status Report
**Date**: 2026-02-07
**Updated**: 2026-02-09
**Host**: AGLSRV1 (192.168.0.245)
**Verified by**: Hive Mind Swarm

## Executive Summary

All 5 target containers are **RUNNING** on AGLSR1, but several services require attention:

**NEW HOST ADDED**: FGSRV07 - VPS Locaweb with Debian 13 and Proxmox

| Service | Container | Status | Health | Action Required |
|---------|-----------|--------|--------|-----------------|
| **Archon** | CT183 | ⚠️ PARTIAL | Degraded | **HIGH** - Fix startup service |
| **Dokploy** | CT180 | ✅ HEALTHY | OK | None |
| **Harbor** | CT182 | ❌ DOWN | Critical | **HIGH** - Restart core services |
| **Supabase** | CT184 | ✅ HEALTHY | Minor | **MEDIUM** - Fix realtime |
| **Cacheng** | CT173 | ✅ HEALTHY | OK | None |

---

## Detailed Status

### 1. Archon (CT183) - PARTIAL

**Container**: Running (16 cores, 16GB RAM, 192.168.0.183)

**Docker Containers Status**:
```
archon-mcp (port 8051):     ✅ Up 5 days (healthy)
archon-ui (port 3737):      ⚠️ Up 5 days (unhealthy)
archon-server:              ❌ Exited (3) 5 days ago
```

**Issue**: `archon-startup.service` failed due to AppArmor permissions
```
Error: apparmor_parser: Access denied. You need policy admin privileges.
Failed: 5 days ago (2026-02-02)
```

**Fix Required**:
```bash
ssh root@192.168.0.245
pct exec 183 -- systemctl restart archon-startup.service
# OR fix AppArmor:
pct exec 183 -- aa-complain /etc/apparmor.d/*  # Set to complain mode
```

**MCP Endpoint**: http://192.168.0.183:8051 ✅

---

### 2. Dokploy (CT180) - HEALTHY

**Container**: Running (8 cores, 16GB RAM, 192.168.0.180)

**Health Check**: ✅ `{"ok":true}`

**Web UI**: https://dok.aglz.io

**Status**: Fully operational, no action required.

---

### 3. Harbor (CT182) - CRITICAL

**Container**: Running but services degraded

**Docker Containers Status**:
```
Running (2):
  - harbor-log:        ✅ Up 4 days (healthy)
  - harbor-postgres:   ✅ Up 4 days (healthy)

Stopped (8):
  - harbor-core:       ❌ Exited (128) 10 days ago
  - harbor-registry:  ❌ Exited (128) 10 days ago
  - harbor-jobservice: ❌ Exited (128) 10 days ago
  - nginx:             ❌ Exited (128) 10 days ago
  - harbor-portal:    ❌ Exited (128) 10 days ago
  - redis:            ❌ Exited (128) 10 days ago
  - registryctl:      ❌ Exited (128) 10 days ago
  - trivy-adapter:    ❌ Exited (128) 10 days ago
```

**Fix Required**:
```bash
ssh root@192.168.0.245
pct exec 182 -- cd /root/harbor && docker compose up -d
# OR if using install:
pct exec 182 -- systemctl restart harbor
```

**Impact**: Container registry NOT FUNCTIONAL

---

### 4. Supabase (CT184) - HEALTHY

**Container**: Running with full Supabase stack

**Docker Containers (13 total)**:
```
✅ supabase-storage:      Up 5 days (healthy)
✅ supabase-meta:         Up 5 days (healthy)
✅ supabase-pooler:       Up 5 days (healthy)
✅ supabase-studio:       Up 5 days (healthy)
⚠️ realtime-dev:          Up 5 days (unhealthy)
✅ supabase-auth:         Up 5 days (healthy)
✅ supabase-edge-functions: Up 27 seconds
✅ supabase-kong:         Up 5 days (healthy)
✅ supabase-rest:         Up 5 days
✅ supabase-analytics:    Up 5 days (healthy)
✅ supabase-db:           Up 5 days (healthy)
✅ supabase-vector:       Up 5 days (healthy)
✅ supabase-imgproxy:     Up 5 days (healthy)
```

**Minor Issue**: `realtime-dev.supabase-realtime` unhealthy

**Fix** (if needed):
```bash
ssh root@192.168.0.245
pct exec 184 -- docker restart realtime-dev.supabase-realtime
```

**Web UI**: http://192.168.0.184:8000 (Studio)

---

### 5. Cacheng (CT173) - HEALTHY

**Container**: Running (4 cores, 2GB RAM, 192.168.0.173)

**Service**: **apt-cacher-ng** (NOT Redis!)

**Description**: Debian/Ubuntu package cache proxy
- Port: 3142
- Purpose: Accelerates APT package downloads for other containers
- Configuration: Used as proxy for `apt-get` operations

**Listening Ports**:
```
PORT     SERVICE
3142/tcp  apt-cacher-ng  ✅
12321/tcp  perl           (unknown service)
22/tcp    ssh
```

**Status**: Fully operational, no action required.

---

## Recommended Actions

### Priority 1 (Today)

1. **Fix Harbor Registry** (CT182)
   ```bash
   ssh root@192.168.0.245 'pct exec 182 -- docker compose up -d'
   ```
   - Restores container registry functionality
   - Estimated time: 5 minutes

2. **Fix Archon Server** (CT183)
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- systemctl restart archon-startup.service'
   ```
   - Restores full Archon functionality
   - If fails, fix AppArmor: `pct exec 183 -- aa-complain /etc/apparmor.d/*`

### Priority 2 (This Week)

3. **Fix Supabase Realtime** (CT184)
   ```bash
   ssh root@192.168.0.245 'pct exec 184 -- docker restart realtime-dev.supabase-realtime'
   ```

4. **Verify AppArmor Policies** (CT183)
   - Consider setting AppArmor to complain mode for Docker in LXC
   - Update container security profiles if needed

---

## 6. FGSRV07 - NEW HOST (2026-02-09)

**Host Type**: VPS Locaweb
**OS**: Debian 13 (Trixie)
**IP Public**: 191.252.93.227
**IP Tailscale**: 100.109.181.93
**MagicDNS**: fgsrv07.degu-chromatic.ts.net
**Role**: Proxmox host with Tailscale

**Status**: ✅ **OPERATIONAL**

**Configuration**:
- Proxmox VE 9.1.0: Installed and operational
- Kernel: 6.17.9-1-pve
- Tailscale v1.94.1: Installed and connected
- Exit Node: Enabled
- Accept Routes: Enabled
- IP Forwarding: Enabled
- Role: Virtualization host for VM/LXC deployments

**Access Methods**:
- Public IP: 191.252.93.227
- Tailscale: 100.109.181.93 ✅
- MagicDNS: fgsrv07.degu-chromatic.ts.net ✅
- SSH: Standard port 22 (key authorized)

**Services**:
- Tailscale: 100.109.181.93 ✅
- Proxmox VE 9.1.0: ✅ Running
- Proxmox Web UI: https://191.252.93.227:8006 ✅
  - Alternative: https://100.109.181.93:8006 (Tailscale)
  - Alternative: https://fgsrv07.degu-chromatic.ts.net:8006
- Login: root (SSH password)

**Notes**:
- Added to infrastructure on 2026-02-09
- Running Debian 13 (Trixie) - Kernel 6.12.63
- Hostname: vps64306
- Part of Locaweb VPS fleet
- Designated as Proxmox virtualization host
- Tailscale connected to 39 peers in the network

---

## Network Access

**Primary Access Methods**:
- LAN: 192.168.0.0/24 ✅
- WireGuard: 10.6.0.10 ❌ (not connected from current host)
- Tailscale: 100.107.113.33 ❌ (not connected from current host)

**Service Endpoints**:
- Archon MCP: http://192.168.0.183:8051
- Dokploy: https://dok.aglz.io
- Supabase Studio: http://192.168.0.184:8000
- Harbor: http://192.168.0.182 (NOT accessible - services down)
- FGSRV07 (Public): 191.252.93.227
- FGSRV07 (Tailscale): 100.109.181.93
- FGSRV07 (MagicDNS): fgsrv07.degu-chromatic.ts.net

---

## Hosts Summary

| Host | Type | OS | IP | Role | Status |
|------|------|-----|----|----|--------|
| **AGLSRV1** | Bare Metal | Proxmox | 192.168.0.245 | Host for CTs | ✅ Operational |
| **FGSRV07** | VPS Locaweb | Debian 13 (Trixie) | 191.252.93.227 (Public) | Proxmox + Tailscale | ✅ Operational (NEW) |
| | | | 100.109.181.93 (Tailscale) | | |

## Notes

- **Cacheng** is **apt-cacher-ng**, a package cache proxy, NOT a Redis server
- All containers are LXC-based with Docker running inside
- Status verified via direct SSH to AGLSRV1 (192.168.0.245)
- Last verified: 2026-02-07
- FGSRV07 added: 2026-02-09

---

**Generated by**: Hive Mind Swarm
**Report Version**: 1.0
