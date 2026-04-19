# PROXMOX Cluster Implementation - AGLSRV5 & FGSRV7

> **Last Updated**: 2026-02-21 | **Version**: 1.5.0
> **Status**: ✅ IMPLEMENTED
> **Objective**: Create HA cluster with QDevice for 2-node quorum

---

## Overview

### Objective
Create a new PROXMOX VE cluster between AGLSRV5 and FGSRV7 with QDevice (Quorum Device) for high-availability quorum management.

### Current Status (2026-02-21)
- **AGLSRV5**: Cluster node (Nodeid 1)
- **FGSRV7**: Cluster node (Nodeid 2) - Fully configured
- **QDevice**: Active (Nodeid 0)

### Cluster Status
```
Nodeid      Votes    Qdevice Name
    1          1    A,V,NMW aglsrv5 (local)
    2          1    A,V,NMW fgsrv7
    0          1            Qdevice
```

---

## Host Inventory

### AGLSRV5 (Proxmox Host)

| Property | Value |
|----------|-------|
| **Hostname** | aglsrv5 |
| **Tailscale IP** | 100.119.223.113 |
| **WireGuard IP** | 10.6.0.17 |
| **LAN IP** | 192.168.15.222 |
| **Cluster Status** | ✅ Nodeid 1 |
| **Containers** | CT130-139 (8 running, 1 stopped) |
| **Cloudflare Tunnel** | aglsrv5 (CT130) |

**Containers on AGLSRV5**:
| VMID | Name | Status |
|------|------|--------|
| 130 | cloudflared5 | running |
| 132 | plex5 | stopped |
| 133 | mesh5 | running |
| 134 | ipmitool5 | running |
| 135 | mysql5 | running |
| 136 | agldv05 | running |
| 138 | fileserver5 | running |
| 139 | pihole5 | running |

---

### FGSRV7 (vps64306)

| Property | Value |
|----------|-------|
| **Hostname** | fgsrv7 |
| **Public IP** | 191.252.93.227 |
| **Tailscale IP** | 100.109.181.93 |
| **WireGuard IP** | 10.6.0.24 (pending) |
| **OS** | Debian GNU/Linux 13 (trixie) |
| **Proxmox Version** | pve-manager/9.1.5/80cf92a64bef6889 |
| **Kernel** | 6.17.9-1-pve |
| **Cluster Status** | ✅ Nodeid 2 |
| **Storage** | bkp (~200GB) |
| **Swap** | 32GB file (`/swapfile`, swappiness=10) |
| **Optimized** | 2026-02-23 |

**Network Bridges**:
| Bridge | Type | IP | Purpose |
|--------|------|-----|---------|
| vmbr0 | Linux Bridge | 191.252.93.227/24 | Public network |
| vmbr70 | OVS Bridge | 192.168.70.1/24 | Internal containers |

**DNS Configuration**:
- Servers: 8.8.8.8, 1.1.1.1
- Search: aglz.io

**/etc/hosts**:
```
127.0.0.1 localhost
191.252.93.227 vps64306.publiccloud.com.br vps64306
100.109.181.93 fgsrv7.tailscale fgsrv7
192.168.70.1 fgsrv7.aglz.io fgsrv7
```

**Containers on FGSRV7**:
| VMID | Name | Status | Network | Purpose |
|------|------|--------|---------|---------|
| 170 | cloudflared7 | running | vmbr70 (192.168.70.170) | Cloudflare Tunnel fgsrv7 |
| 235 | mysql7 | running | vmbr70 (192.168.70.135) | MySQL Slave (HA replication) |
| 239 | pihole7 | running | vmbr70 (192.168.70.139) | DNS/Ad-blocking (HA migrated from AGLSRV5 CT139) |

**Cloudflare Tunnel (fgsrv7)**:
- Tunnel ID: `513cec7b-754d-4dd8-a69d-d15942180fe4`
- Endpoint: man7a.aglz.io → Proxmox Web UI (8006)
- Access: https://man7a.aglz.io

---

## QDevice Architecture

### Why QDevice?
In a 2-node cluster, if one node fails, the surviving node only has 1 of 2 votes (50%), which is not enough for quorum (requires >50%). QDevice provides a 3rd vote to maintain quorum.

### QDevice Options

| Option | Server | IP | Pros | Cons |
|--------|--------|-----|------|------|
| **Option A** | FGSRV6 (hub) | 10.6.0.5 | Central location, already meshed | Single point of failure if hub down |
| **Option B** | AGLSRV1 | 192.168.0.245 | Main infrastructure | On same LAN as AGLSRV5 |
| **Option C** | Separate VPS | TBD | Complete independence | Additional cost/management |

**Recommended**: Option A (FGSRV6) - WireGuard hub already provides connectivity for all nodes.

---

## Network Requirements

### Corosync Ports
- **UDP 5405-5412**: Corosync cluster communication
- **TCP 22**: SSH for cluster management
- **TCP 5403**: QDevice communication (if using QNetd)

### Latency Requirements
- Recommended: **< 5ms** between cluster nodes
- Maximum acceptable: **< 10ms**
- Test with: `ping <peer-ip>`

### Connectivity Matrix

| Source | AGLSRV5 | FGSRV7 | QDevice |
|--------|---------|--------|---------|
| AGLSRV5 | - | Tailscale → WireGuard | WireGuard (10.6.0.5) |
| FGSRV7 | Tailscale | - | Configure WireGuard |
| QDevice | WireGuard | Configure | - |

### Latency Tests (2026-02-20)

| Route | Latency | Status |
|-------|---------|--------|
| AGLSRV5 → FGSRV7 (Tailscale) | avg 9.7ms | Acceptable |
| FGSRV7 → AGLSRV5 (Tailscale) | avg 7.6ms | Acceptable |
| FGSRV7 → WireGuard Hub | N/A | Needs WireGuard setup |

**Note**: Latency slightly above recommended <5ms but within acceptable <10ms range. WireGuard may improve latency.

---

## Implementation Plan

### Phase 1: Preparation

#### Step 1.1: Configure WireGuard on FGSRV7
```bash
# On FGSRV7 (100.109.181.93)
apt update && apt install wireguard -y

# Generate keys
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key

# Create config (assign 10.6.0.24)
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.6.0.24/24
ListenPort = 51824
PrivateKey = <FGSRV7_PRIVATE_KEY>

[Peer]
PublicKey = <HUB_PUBLIC_KEY>
Endpoint = 186.202.57.120:51823
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
EOF

# Start WireGuard
systemctl enable --now wg-quick@wg0
```

#### Step 1.2: Add FGSRV7 to Hub (FGSRV6)
```bash
# On FGSRV6 hub - add peer
wg set wg0 peer <FGSRV7_PUBLIC_KEY> endpoint 191.252.93.227:51824 allowed-ips 10.6.0.24/32
```

#### Step 1.3: Test Connectivity
```bash
# From AGLSRV5 to FGSRV7
ping 10.6.0.24  # After WireGuard setup
ping 100.109.181.93  # Via Tailscale

# Check latency
ping -c 10 100.109.181.93 | tail -1
```

---

### Phase 2: QDevice Deployment

#### Step 2.1: Install QNetd on FGSRV6 (Arbitrator)
```bash
# On FGSRV6 (10.6.0.5)
apt update
apt install corosync-qnetd -y

# Configure QNetd
systemctl enable --now corosync-qnetd
```

#### Step 2.2: Install QDevice on Cluster Nodes
```bash
# On AGLSRV5 and FGSRV7
apt update
apt install corosync-qdevice -y
```

---

### Phase 3: Cluster Creation

#### Step 3.1: Create Cluster on AGLSRV5
```bash
# On AGLSRV5
pvecm create agl-cluster

# Verify
pvecm status
```

#### Step 3.2: Join FGSRV7 to Cluster
```bash
# On FGSRV7 - join via WireGuard (preferred) or Tailscale
pvecm add 10.6.0.17 --link0 10.6.0.24

# Or via Tailscale if WireGuard not ready
pvecm add 100.119.223.113 --link0 100.109.181.93
```

#### Step 3.3: Verify Cluster
```bash
pvecm status
pvecm nodes
```

---

### Phase 4: QDevice Configuration

#### Step 4.1: Setup QDevice on Cluster
```bash
# On either cluster node
pvecm qdevice setup 10.6.0.5

# Verify QDevice
pvecm status | grep -A5 "QDevice"
```

#### Step 4.2: Expected Output
```
Quorum information
------------------
Votequorum Qdevice
  Qdevice information
    Algorithm:        _ffsplit
    Cast vote:         1
    Host vote:         1
    Master wins:       0
```

---

## Post-Implementation

### Verification Checklist
- [x] Cluster status shows both nodes
- [x] Corosync latency < 10ms (acceptable for WAN cluster)
- [x] QDevice providing 3rd vote
- [ ] HA resources can failover (pending testing)
- [x] Web UI accessible on both nodes

### HA Services
**Migrated to Cluster (2026-02-21)**:

| Service | Source | Destination | Status | Type |
|---------|--------|-------------|--------|------|
| Pi-hole DNS | AGLSRV5 CT139 | FGSRV7 CT239 | ✅ Running | Migration |
| MySQL | AGLSRV5 CT135 | FGSRV7 CT235 | ✅ Replicating | Master-Slave |

**MySQL HA Configuration**:
```
Master (CT135 on AGLSRV5):
  - Tailscale IP: 100.98.1.119
  - Binary Log: mysql-bin
  - Server-ID: 1

Slave (CT235 on FGSRV7):
  - Tailscale IP: 100.83.7.16
  - Server-ID: 2
  - Read-Only: ON
  - Replication: async (0s delay) via Tailscale direct
```

**Tailscale Configuration for LXC**:
```
# Add to /etc/pve/lxc/CTID.conf:
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

**Failover Procedure** (manual):
1. Verify master (CT135) is down
2. Stop slave on CT235: `STOP SLAVE;`
3. Promote to master: `SET GLOBAL read_only = OFF;`
4. Update application connection strings
5. Optional: Set up new slave on recovered CT135

### Monitoring Commands
```bash
# Cluster status
pvecm status

# Node list
pvecm nodes

# Corosync config
cat /etc/pve/corosync.conf

# QDevice status
pvecm qdevice status

# Logs
journalctl -u corosync -f
journalctl -u pve-cluster -f
```

---

## Rollback Procedures

### Remove QDevice
```bash
pvecm qdevice remove
```

### Separate Node from Cluster
```bash
# On node to remove
systemctl stop pve-cluster
systemctl stop corosync
pmxcfs -l
rm /etc/pve/corosync.conf
rm -r /etc/corosync/*
killall pmxcfs
systemctl start pve-cluster
```

### Remove Node from Cluster (from another node)
```bash
pvecm delnode <node-name>
pvecm delnode <node-name> --force  # If node offline
```

---

## References

- **Proxmox Cluster Manager**: https://pve.proxmox.com/wiki/Cluster_Manager
- **Proxmox QDevice**: https://pve.proxmox.com/wiki/Cluster_Manager#_corosync_external_vote_support
- **INFRA.md**: `docs/INFRA.md`
- **WireGuard Config**: `docs/INFRA.md#wireguard-mesh`

---

**Document Version**: 1.3.0
**Last Updated**: 2026-02-21
**Maintainer**: Claude Code (agl-hostman project)
