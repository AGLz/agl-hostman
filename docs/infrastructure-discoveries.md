# Infrastructure Discoveries - Tailscale SSH Session

**Date:** 2025-02-11

---

## 🔍 New Access Methods Discovered

### aglsrv5-unraid (VM127)
- **Location:** VM on aglsrv5 (100.119.223.113)
- **LAN IP:** 172.2.2.22
- **SSH Port:** 6022
- **Access Method:** Via aglsrv5 using `sshpass`
- **Credentials:** root/lx4936@klfap
- **Tailscale IP:** 100.68.158.60

**Connection Command:**
```bash
ssh root@100.119.223.113 'sshpass -p "lx4936@klfap" ssh -p 6022 root@172.2.2.22'
```

### Direct Tailscale Access (after config):
```bash
ssh root@100.68.158.60
```

---

## 🗂️ Container Configuration Files

### Unprivileged LXC TUN Device
For Tailscale to work in unprivileged LXC containers, add to `/etc/pve/lxc/CTID.conf`:
```conf
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

**Affected Containers:**
- CT180 (dokploy)
- CT121 (wireguard-aglsrv6)

---

## 🌐 Network Topology

### AGLSRV6 (man6) Network
- **Tailscale IP:** 100.98.108.66
- **Local Networks:**
  - 192.168.0.0/24 (vmbr0)
  - 192.168.1.0/24 (vmbr2)
  - 192.168.60.0/24 (vmbr1)
  - 10.6.0.0/24 (wg0 - WireGuard)

### WireGuard Mesh (10.6.0.0/24)
| Host | WireGuard IP | Purpose |
|------|--------------|---------|
| aglsrv6 | 10.6.0.12 | Mesh member |
| CT111 (aluzdivina) | 10.6.0.20 | - |
| CT113 (man6-pbs) | 10.6.0.14 | - |
| CT115 (pihole6) | 10.6.0.58 | - |
| CT121 (wireguard-aglsrv6) | 10.6.0.3 | Gateway |

---

## 🔑 SSH Configuration

### New Hosts Added to SSH Config
```ssh
Host aglsrv5-unraid
  HostName 100.68.158.60
  User root
  StrictHostKeyChecking no

Host dokploy
  HostName 100.72.66.106
  User root
  StrictHostKeyChecking no
```

---

## 📊 Tailscale Status Summary

| Host | Type | Tailscale IP | --ssh | Subnet Routes |
|------|------|--------------|-------|---------------|
| aglsrv6-cloudflared6 | LXC | 100.121.95.88 | ✅ | 192.168.60.0/24 |
| aglsrv6-cloudflared6b | LXC | 100.115.195.128 | ✅ | 192.168.60.0/24 |
| aglsrv6-wireguard | LXC | 100.113.15.100 | ✅ | 10.6.0.0/24 |
| aglsrv1-archon | LXC | 100.80.30.59 | ✅ | - |
| aglsrv5-unraid | VM | 100.68.158.60 | ✅ | - |
| dokploy | LXC | 100.72.66.106 | ✅ | - |

---

## 🛠️ Troubleshooting Notes

### DNS Issues in Containers
Some containers couldn't resolve `tailscale.com`. Solution:
```bash
# Use Google DNS temporarily
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### Tailscale Not Starting After State Reset
```bash
# Remove all state
rm -rf /var/lib/tailscale/*

# Restart container for clean state
pct shutdown CTID
pct start CTID
```

### SSH Permission Denied on Unraid
- Standard port 22 was closed
- SSH running on port 6022
- Required password authentication (keys not configured)
