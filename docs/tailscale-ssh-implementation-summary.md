# Tailscale SSH Implementation Summary

**Date:** 2025-02-11
**Session:** Fix duplicate Tailscale node keys and enable --ssh flag across infrastructure

---

## 🎯 Objectives Completed

### 1. Fixed Cloned Containers (CT101, CT114)
**Problem:** Both containers had duplicate Tailscale identities (same node key)

**Solution:**
- Generated unique SSH keys for each container
- Reset Tailscale with new identities
- Configured `--ssh` flag

**Results:**
| Container | Old IP | New IP | SSH Key Fingerprint |
|-----------|--------|--------|---------------------|
| CT101 (cloudflared6) | 100.120.181.108 | 100.121.95.88 | SHA256:8uTC/JtxloRw7KE9zt9eTP9YobN/bKsyRXDTgzGg1H0 |
| CT114 (cloudflared6b) | 100.120.181.108 | 100.115.195.128 | SHA256:1I5w+43kDgq5MU9mlhDAIGVoApk95qFb10oZoQSdSTk |

### 2. Fixed aglsrv5-unraid (VM127)
**Problem:** Unraid VM was offline for 111 days

**Discovery:** VM accessed via aglsrv5 (172.2.2.22:6022) with credentials root/lx4936@klfap

**Solution:**
- Restarted VM
- Installed/configured Tailscale
- Enabled `--ssh` flag
- Enabled IP forwarding

**Result:**
- Tailscale IP: 100.68.158.60
- SSH: `ssh root@100.68.158.60`

### 3. Enabled --ssh Flag on Multiple Hosts

| Host | Container/VM | Tailscale IP | Status |
|------|---------------|--------------|--------|
| aglsrv1-archon | CT183 | 100.80.30.59 | ✅ |
| dokploy | CT180 | 100.72.66.106 | ✅ |
| wireguard-aglsrv6 | CT121 | 100.113.15.100 | ✅ |

### 4. Configured Subnet Routes

| Container | Route Advertised | Purpose |
|-----------|------------------|---------|
| CT101 | 192.168.60.0/24 | Cloudflare subnet |
| CT114 | 192.168.60.0/24 | Cloudflare subnet |
| CT121 | 10.6.0.0/24 | WireGuard network |

---

## 🔍 Key Discoveries

### Unraid Access Method
- **VM:** 127 on aglsrv5
- **LAN IP:** 172.2.2.22
- **SSH Port:** 6022 (non-standard)
- **Credentials:** root/lx4936@klfap
- **Proxy Access:** Via aglsrv5 (100.119.223.113)

### TUN Device Configuration for Unprivileged LXC
For Tailscale to work in unprivileged containers, add to `/etc/pve/lxc/CTID.conf`:
```
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

### Subnet Routes Configuration
```bash
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo net.ipv4.ip_forward=1 >> /etc/sysctl.d/99-tailscale.conf

# Connect with subnet routes
tailscale up --ssh --accept-routes --advertise-routes=NETWORK
```

---

## 📝 Infrastructure Map

### AGLSRV6 (man6) - 100.98.108.66
| CTID | Name | Tailscale IP | Purpose |
|------|------|--------------|---------|
| 101 | cloudflared6 | 100.121.95.88 | Cloudflare Tunnel |
| 114 | cloudflared6b | 100.115.195.128 | Cloudflare Tunnel |
| 121 | wireguard-aglsrv6 | 100.113.15.100 | WireGuard Gateway |

### AGLSRV1 - 100.107.113.33
| CTID | Name | Tailscale IP | Purpose |
|------|------|--------------|---------|
| 180 | dokploy | 100.72.66.106 | Deployment Platform |
| 183 | archon | 100.80.30.59 | MCP Server |

### AGLSRV5 - 100.119.223.113
| VMID | Name | Tailscale IP | Purpose |
|------|------|--------------|---------|
| 127 | server (unraid) | 100.68.158.60 | NAS/Storage |

---

## 🔧 Quick Reference Commands

### Enable --ssh on existing Tailscale installation
```bash
tailscale up --ssh --accept-routes --hostname=HOSTNAME --accept-risk=lose-ssh
```

### Check advertised routes
```bash
tailscale status --json | jq '.Self.Routes'
```

### Fix duplicate node key (cloned container)
```bash
# Stop Tailscale
tailscale down --accept-risk=lose-ssh

# Remove state
rm -rf /var/lib/tailscale/*

# Restart with new identity
tailscale up --ssh --accept-routes --hostname=NEW_HOSTNAME
```

---

## ✅ Verification Commands

```bash
# Test SSH via Tailscale
ssh root@100.121.95.88  # CT101
ssh root@100.115.195.128 # CT114
ssh root@100.113.15.100 # CT121
ssh root@100.68.158.60  # unraid
ssh root@100.80.30.59   # archon
ssh root@100.72.66.106  # dokploy
```

---

## 📋 Pending Tasks

1. Approve subnet routes in Tailscale Admin Console
2. Configure ACLs for all new SSH-enabled nodes
3. Document SSH key fingerprints for each container
