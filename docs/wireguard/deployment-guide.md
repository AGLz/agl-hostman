# WireGuard Mesh Network - Deployment Guide
**Date**: 2025-10-15
**Status**: Ready for Phase 1 Deployment
**Expected Performance Gain**: 4-6x (10-14 MB/s → 40-60 MB/s)

## 📋 Executive Summary

Successfully prepared pure WireGuard kernel mesh network to replace Tailscale. All keys generated, scripts ready, and deployment plan validated.

### Current Status
- ✅ CT120 analyzed (already has WireGuard configured)
- ✅ Mesh architecture designed
- ✅ Deployment scripts created
- ✅ Keys generated for all 3 new nodes
- ⏳ Ready for Phase 1: AGLSRV6 deployment

### Performance Target
- **Current**: 10-14 MB/s (SSHFS/NFS over Tailscale)
- **Target**: 40-60 MB/s (NFS over WireGuard kernel)
- **Improvement**: 4-6x faster throughput

## 🔑 Generated Keys

### AGLSRV6-CT (10.6.0.3)
```
Public Key:  tAq3Ec660PsqijieBEBUyIEidsacrdAQNzealHfRfBM=
Private Key: /root/wireguard-keys/aglsrv6-ct/private.key
PSK:         /root/wireguard-keys/aglsrv6-ct/preshared.key
Port:        51821
```

### FGSRV5 (10.6.0.4)
```
Public Key:  H4ENZ3PkJ0fNGpo0mM4AfB4rh+g5MI+ogz8DQQnZLwk=
Private Key: /root/wireguard-keys/fgsrv5/private.key
PSK:         /root/wireguard-keys/fgsrv5/preshared.key
Port:        51822
```

### FGSRV6 (10.6.0.5)
```
Public Key:  Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
Private Key: /root/wireguard-keys/fgsrv6/private.key
PSK:         /root/wireguard-keys/fgsrv6/preshared.key
Port:        51823
```

## 🚀 Quick Start - Phase 1: AGLSRV6

### Prerequisites
1. Access to AGLSRV6 Proxmox host (100.98.108.66 via Tailscale)
2. Create new LXC container on AGLSRV6 for WireGuard
3. SSH access configured

### Option 1: Automated Deployment (Recommended)

```bash
# Run from AGLDV03 (current host)
cd /root/host-admin/scripts/wireguard

# Deploy to AGLSRV6 (after creating CT)
./deploy-wireguard-mesh.sh setup-aglsrv6
```

This script will:
1. Install WireGuard on the new CT
2. Apply kernel tuning for performance
3. Configure WireGuard interface
4. Start the service
5. Provide configuration to add to CT120

### Option 2: Manual Deployment

#### Step 1: Create CT on AGLSRV6

On AGLSRV6 Proxmox host:
```bash
# Create new container
pct create 121 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
    --hostname wireguard-aglsrv6 \
    --memory 2048 \
    --swap 512 \
    --cores 2 \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --storage local-zfs \
    --rootfs local-zfs:8 \
    --features nesting=1,fuse=1 \
    --unprivileged 1 \
    --onboot 1

# Start container
pct start 121

# Get IP address
pct exec 121 -- ip addr show eth0
```

#### Step 2: Install WireGuard

On the new CT121:
```bash
# Update and install
apt-get update
apt-get install -y wireguard wireguard-tools

# Enable IP forwarding
cat > /etc/sysctl.d/99-wireguard-forward.conf << 'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
EOF

sysctl -p /etc/sysctl.d/99-wireguard-forward.conf
```

#### Step 3: Apply Kernel Tuning

```bash
cat > /etc/sysctl.d/99-wireguard-tuning.conf << 'EOF'
# WireGuard Performance Tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
EOF

sysctl -p /etc/sysctl.d/99-wireguard-tuning.conf
```

#### Step 4: Configure WireGuard

Copy the private key from AGLDV03:
```bash
# On AGLDV03
cat /root/wireguard-keys/aglsrv6-ct/private.key
cat /root/wireguard-keys/aglsrv6-ct/preshared.key
```

On CT121 (AGLSRV6):
```bash
# Create config
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
PrivateKey = <paste private key here>
Address = 10.6.0.3/24
MTU = 1420
ListenPort = 51821
PostUp = sysctl -w net.ipv4.ip_forward=1

# CT120 Hub
[Peer]
PublicKey = Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=
PresharedKey = <paste preshared key here>
AllowedIPs = 10.6.0.0/24
Endpoint = 192.168.0.120:51820
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf
```

#### Step 5: Start WireGuard

```bash
# Enable and start
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Verify
wg show wg0
ip addr show wg0

# Should see wg0 interface with IP 10.6.0.3
```

#### Step 6: Configure CT120 Hub

On CT120 (AGLSRV1 - 192.168.0.120):
```bash
# Get PSK from AGLDV03
# cat /root/wireguard-keys/aglsrv6-ct/preshared.key

# Edit config
nano /etc/wireguard/wg0.conf

# Add this peer block at the end:
### begin aglsrv6-ct ###
[Peer]
PublicKey = tAq3Ec660PsqijieBEBUyIEidsacrdAQNzealHfRfBM=
PresharedKey = <paste preshared key here>
AllowedIPs = 10.6.0.3/32
Endpoint = 100.98.108.66:51821
PersistentKeepalive = 25
### end aglsrv6-ct ###

# Restart WireGuard
systemctl restart wg-quick@wg0

# Verify peer
wg show wg0
```

### Step 7: Test Connectivity

From CT121 (AGLSRV6):
```bash
# Ping hub
ping -c 4 10.6.0.1

# Should get responses
```

From CT120 (AGLSRV1):
```bash
# Ping AGLSRV6
ping -c 4 10.6.0.3

# Should get responses
```

### Step 8: Performance Test

Install iperf3 on both nodes:
```bash
apt-get install -y iperf3
```

On CT121 (server):
```bash
iperf3 -s
```

On CT120 (client):
```bash
iperf3 -c 10.6.0.3 -t 30 -i 5

# Expected: 40-60 MB/s (vs 10-14 MB/s with Tailscale)
```

## 🔄 Phase 2: FGSRV5 Deployment

After Phase 1 is successful:

```bash
cd /root/host-admin/scripts/wireguard
./deploy-wireguard-mesh.sh setup-fgsrv5
```

Manual steps:
1. SSH to FGSRV5 (100.71.107.26)
2. Install WireGuard
3. Apply kernel tuning
4. Configure with generated keys
5. Add peer to CT120
6. Test connectivity
7. Update NFS mounts to use 10.6.0.4

## 🔄 Phase 3: FGSRV6 Deployment

After Phase 2 is successful:

```bash
cd /root/host-admin/scripts/wireguard
./deploy-wireguard-mesh.sh setup-fgsrv6
```

Manual steps:
1. SSH to FGSRV6 (100.83.51.9)
2. Install WireGuard
3. Apply kernel tuning
4. Configure with generated keys
5. Add peer to CT120
6. Test connectivity
7. Update NFS mounts to use 10.6.0.5

## 📊 Expected Results

### Performance Comparison

| Metric | Tailscale (Current) | WireGuard (Target) | Improvement |
|--------|--------------------|--------------------|-------------|
| Throughput | 10-14 MB/s | 40-60 MB/s | 4-6x |
| Latency | 8-12ms | 2-5ms | 2-3x |
| CPU Usage | 15-25% | 5-10% | 2-3x |
| Protocol | Userspace | Kernel | Native |

### NFS Performance Impact

| Host | Current (Tailscale) | Target (WireGuard) | Improvement |
|------|--------------------|--------------------|-------------|
| FGSRV5 | 14.0 MB/s | 50-70 MB/s | 3.5-5x |
| FGSRV6 | 12.6 MB/s | 45-65 MB/s | 3.5-5x |

## 🛠️ Troubleshooting

### WireGuard Interface Not Starting
```bash
# Check logs
journalctl -u wg-quick@wg0 -n 50

# Check config syntax
wg-quick strip wg0

# Verify firewall
ufw status
```

### No Connectivity Between Peers
```bash
# Check if interface is up
ip addr show wg0

# Check peer status
wg show wg0

# Check if listening
ss -ulnp | grep 51820

# Test UDP connectivity
nc -u 192.168.0.120 51820
```

### Poor Performance
```bash
# Check MTU
ip link show wg0 | grep mtu

# Check kernel tuning
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.rmem_max

# Check NIC offloading
ethtool -k eth0 | grep -E "(gso|gro)"

# Monitor bandwidth
iperf3 -c <peer_ip> -t 60
```

### Firewall Blocking
```bash
# Allow WireGuard ports
ufw allow 51820/udp
ufw allow 51821/udp
ufw allow 51822/udp
ufw allow 51823/udp

# Reload firewall
ufw reload
```

## 📁 Files and Locations

### Generated Keys (AGLDV03)
```
/root/wireguard-keys/
├── aglsrv6-ct/
│   ├── private.key
│   ├── public.key
│   └── preshared.key
├── fgsrv5/
│   ├── private.key
│   ├── public.key
│   └── preshared.key
└── fgsrv6/
    ├── private.key
    ├── public.key
    └── preshared.key
```

### Configuration Files
```
# CT120 (Hub)
/etc/wireguard/wg0.conf

# AGLSRV6-CT
/etc/wireguard/wg0.conf

# FGSRV5
/etc/wireguard/wg0.conf

# FGSRV6
/etc/wireguard/wg0.conf
```

### Scripts
```
/root/host-admin/scripts/wireguard/deploy-wireguard-mesh.sh
```

### Documentation
```
/root/host-admin/docs/wireguard/
├── mesh-architecture-plan.md
├── deployment-guide.md (this file)
└── performance-results.md (to be created)
```

## 🔒 Security Considerations

1. **Key Management**
   - Private keys stored with 600 permissions
   - Never commit keys to git
   - Pre-shared keys (PSK) provide quantum-resistance
   - Rotate keys every 6 months

2. **Network Isolation**
   - WireGuard subnet (10.6.0.0/24) isolated from internet
   - AllowedIPs restricts traffic
   - No routing to public internet through VPN

3. **Firewall Rules**
   - Only WireGuard ports exposed
   - Drop invalid packets
   - Rate limiting on ports

4. **Monitoring**
   - Log connection attempts
   - Alert on peer disconnections
   - Track bandwidth per peer

## 📝 Migration Checklist

### Phase 1: AGLSRV6 (Week 1)
- [ ] Create CT121 on AGLSRV6
- [ ] Install WireGuard on CT121
- [ ] Configure WireGuard interface
- [ ] Add peer to CT120
- [ ] Test connectivity (ping)
- [ ] Performance test (iperf3)
- [ ] Document results

### Phase 2: FGSRV5 (Week 2)
- [ ] Install WireGuard on FGSRV5
- [ ] Configure WireGuard interface
- [ ] Add peer to CT120
- [ ] Test connectivity
- [ ] Performance test
- [ ] Update NFS mount to use 10.6.0.4
- [ ] Verify NFS performance improvement

### Phase 3: FGSRV6 (Week 3)
- [ ] Install WireGuard on FGSRV6
- [ ] Configure WireGuard interface
- [ ] Add peer to CT120
- [ ] Test connectivity
- [ ] Performance test
- [ ] Update NFS mount to use 10.6.0.5
- [ ] Verify NFS performance improvement

### Phase 4: Validation (Week 4)
- [ ] Monitor for 1 week
- [ ] Verify PBS backups work
- [ ] Verify container transfers work
- [ ] Document final performance
- [ ] Create runbooks

### Phase 5: Tailscale Decommission (Week 5)
- [ ] Verify all services migrated
- [ ] Stop Tailscale on all nodes
- [ ] Remove Tailscale packages
- [ ] Update documentation

## 🎯 Success Criteria

- ✅ All nodes connected to mesh
- ✅ Throughput ≥40 MB/s between any two nodes
- ✅ Latency <5ms
- ✅ 99.9% uptime over 1 week
- ✅ NFS performance improved 3-5x
- ✅ PBS backups completing successfully
- ✅ No connectivity issues for 7 days

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review WireGuard logs: `journalctl -u wg-quick@wg0`
3. Test basic connectivity: `wg show wg0`
4. Verify kernel tuning: `sysctl -a | grep -E "(rmem|wmem|bbr)"`

## 📚 References

- [WireGuard Official Documentation](https://www.wireguard.com/)
- [WireGuard Performance Optimization](https://www.wireguard.com/performance/)
- [BBR Congestion Control](https://github.com/google/bbr)
- [Previous Research](/root/host-admin/docs/vpn-alternatives-research-2025.md)

---

**Status**: Ready for Phase 1 Deployment
**Next Action**: Create CT121 on AGLSRV6, then run `./deploy-wireguard-mesh.sh setup-aglsrv6`
**Expected Timeline**: 4 weeks for full migration
**Risk Level**: Low (parallel operation with Tailscale during transition)
