# WireGuard Mesh Network Architecture Plan
**Date**: 2025-10-15
**Objective**: Replace Tailscale with pure WireGuard kernel for 4-6x performance improvement

## Current State

### CT120 (AGLSRV1) - Hub Node
- **Role**: Primary WireGuard hub
- **IPs**:
  - LAN: 192.168.0.120
  - WireGuard: 10.6.0.1/24
  - Tailscale: (to be determined)
- **Status**: ✓ Already configured with wg0 interface
- **Current Peers**: 1 (AGLHQ09 - 10.6.0.2)
- **ListenPort**: 51820
- **MTU**: 1420 (optimal for most networks)

### Existing Configuration
```ini
[Interface]
PrivateKey = (hidden)
Address = 10.6.0.1/24,fd11:5ee:bad:c0de::1/64
MTU = 1420
ListenPort = 51820
```

## Target Mesh Network

### Network Topology: Hub-and-Spoke with Peer-to-Peer

```
┌─────────────────────────────────────────────────────────────────┐
│                    WireGuard Mesh Network                        │
│                     10.6.0.0/24 Subnet                          │
└─────────────────────────────────────────────────────────────────┘

                        CT120 (Hub)
                      10.6.0.1/24
                   192.168.0.120:51820
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   AGLSRV6-CT         FGSRV5            FGSRV6
   10.6.0.3/24      10.6.0.4/24      10.6.0.5/24
   (new CT)         100.71.107.26    100.83.51.9
                    :51821           :51822
        │
    AGLSRV6b (optional)
    10.6.0.6/24
    (via AGLSRV6 LAN routing)
```

### Node Assignments

| Node | WireGuard IP | Public/LAN IP | Port | Role | Priority |
|------|-------------|---------------|------|------|----------|
| CT120 (AGLSRV1) | 10.6.0.1 | 192.168.0.120 | 51820 | Hub | High |
| AGLHQ09 (existing) | 10.6.0.2 | (existing peer) | - | Peer | - |
| AGLSRV6-CT (new) | 10.6.0.3 | 100.98.108.66 | 51821 | Spoke | High |
| FGSRV5 | 10.6.0.4 | 100.71.107.26 | 51822 | Spoke | Medium |
| FGSRV6 | 10.6.0.5 | 100.83.51.9 | 51823 | Spoke | Medium |
| AGLSRV6b (future) | 10.6.0.6 | 100.98.119.51 | 51824 | Spoke | Low |

## Implementation Phases

### Phase 1: AGLSRV6 Integration ⭐ (CURRENT)
**Goal**: Establish reliable connection between AGLSRV1 and AGLSRV6

**Steps**:
1. Create new LXC on AGLSRV6 for WireGuard
2. Install WireGuard kernel module
3. Generate keys for new peer
4. Configure CT120 to accept AGLSRV6-CT peer
5. Configure AGLSRV6-CT to connect to CT120
6. Test connectivity: `ping 10.6.0.1` from AGLSRV6-CT
7. Performance test: `iperf3` between nodes

**Expected Performance**:
- Current Tailscale: ~10-14 MB/s
- Target WireGuard: ~40-60 MB/s (4-6x improvement)

### Phase 2: FGSRV5 Integration
**Goal**: Add FGSRV5 NFS host to mesh

**Steps**:
1. Install WireGuard on FGSRV5 (already has NFS v4.2)
2. Generate keys
3. Configure as peer to CT120
4. Update NFS mounts to use WireGuard IPs (10.6.0.4)
5. Performance test NFS over WireGuard vs Tailscale

**Expected Benefit**:
- NFS performance: 14.0 MB/s → 50-70 MB/s

### Phase 3: FGSRV6 Integration
**Goal**: Add FGSRV6 NFS host to mesh

**Steps**:
1. Install WireGuard on FGSRV6 (already has NFS v4.2)
2. Generate keys
3. Configure as peer to CT120
4. Update NFS mounts to use WireGuard IPs (10.6.0.5)
5. Performance test

**Expected Benefit**:
- NFS performance: 12.6 MB/s → 45-65 MB/s

### Phase 4: AGLSRV6b (Optional)
**Goal**: Add AGLSRV6b via LAN routing through AGLSRV6

**Approach**: Two options
1. **Option A**: Install WireGuard directly on AGLSRV6b
2. **Option B**: Route through AGLSRV6-CT (NAT/routing)

## Configuration Templates

### CT120 Updated Configuration
```ini
[Interface]
PrivateKey = (existing)
Address = 10.6.0.1/24,fd11:5ee:bad:c0de::1/64
MTU = 1420
ListenPort = 51820
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = sysctl -w net.ipv4.conf.all.forwarding=1

# Existing peer
[Peer]
PublicKey = ftFamZZ4xWZM5uKi4E2MyT+dwjwM0DieOK4+G1RA828=
PresharedKey = aN9Rrf/2RoFDGO4OF49AXo9nD6d7giDBLMqWv8jDKxQ=
AllowedIPs = 10.6.0.2/32,fd11:5ee:bad:c0de::2/128

# AGLSRV6-CT peer (new)
[Peer]
PublicKey = (to be generated)
PresharedKey = (to be generated)
AllowedIPs = 10.6.0.3/32
Endpoint = 100.98.108.66:51821
PersistentKeepalive = 25

# FGSRV5 peer (new)
[Peer]
PublicKey = (to be generated)
PresharedKey = (to be generated)
AllowedIPs = 10.6.0.4/32
Endpoint = 100.71.107.26:51822
PersistentKeepalive = 25

# FGSRV6 peer (new)
[Peer]
PublicKey = (to be generated)
PresharedKey = (to be generated)
AllowedIPs = 10.6.0.5/32
Endpoint = 100.83.51.9:51823
PersistentKeepalive = 25
```

### AGLSRV6-CT Configuration (New Node)
```ini
[Interface]
PrivateKey = (to be generated)
Address = 10.6.0.3/24
MTU = 1420
ListenPort = 51821

[Peer]
PublicKey = Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=
PresharedKey = (to be generated)
AllowedIPs = 10.6.0.0/24
Endpoint = 192.168.0.120:51820
PersistentKeepalive = 25
```

### FGSRV5 Configuration Template
```ini
[Interface]
PrivateKey = (to be generated)
Address = 10.6.0.4/24
MTU = 1420
ListenPort = 51822

[Peer]
PublicKey = Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=
PresharedKey = (to be generated)
AllowedIPs = 10.6.0.0/24
Endpoint = 192.168.0.120:51820
PersistentKeepalive = 25
```

### FGSRV6 Configuration Template
```ini
[Interface]
PrivateKey = (to be generated)
Address = 10.6.0.5/24
MTU = 1420
ListenPort = 51823

[Peer]
PublicKey = Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=
PresharedKey = (to be generated)
AllowedIPs = 10.6.0.0/24
Endpoint = 192.168.0.120:51820
PersistentKeepalive = 25
```

## Performance Optimization

### Kernel Tuning (All Nodes)
```bash
# /etc/sysctl.d/99-wireguard-tuning.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.ip_forward = 1
```

### NIC Offloading
```bash
# Enable GSO/GRO for better performance
ethtool -K eth0 gso on gro on 2>/dev/null || true
```

### Firewall Rules
```bash
# Allow WireGuard ports
ufw allow 51820/udp comment 'WireGuard CT120'
ufw allow 51821/udp comment 'WireGuard AGLSRV6'
ufw allow 51822/udp comment 'WireGuard FGSRV5'
ufw allow 51823/udp comment 'WireGuard FGSRV6'
```

## Migration Strategy

### Parallel Operation Period
1. Keep Tailscale running during WireGuard deployment
2. Test WireGuard connectivity and performance
3. Gradually migrate services to WireGuard IPs
4. Monitor for issues
5. Decommission Tailscale after 1 week of stable operation

### Service Migration Order
1. **Week 1**: Basic connectivity testing
2. **Week 2**: Migrate NFS mounts (FGSRV5, FGSRV6)
3. **Week 3**: Migrate Proxmox Backup Server traffic
4. **Week 4**: Migrate container sync operations
5. **Week 5**: Final validation and Tailscale removal

## Success Metrics

### Performance Targets
- **Throughput**: ≥40 MB/s (4x current baseline)
- **Latency**: <5ms (hub-to-spoke)
- **Packet Loss**: <0.1%
- **Connection Stability**: 99.9% uptime

### Monitoring
```bash
# Throughput test
iperf3 -c 10.6.0.3 -t 60 -i 5

# Latency test
ping -c 100 10.6.0.3 | tail -1

# WireGuard stats
wg show wg0 transfer
```

## Rollback Plan

If WireGuard performance is worse than Tailscale:
1. Revert NFS mounts to Tailscale IPs
2. Disable WireGuard interfaces
3. Document issues encountered
4. Consider hybrid approach (Tailscale + WireGuard)

## Security Considerations

### Key Management
- Generate unique key pairs for each node
- Use pre-shared keys (PSK) for additional security
- Rotate keys every 6 months
- Never commit private keys to git

### Access Control
- AllowedIPs restricts traffic to WireGuard subnet only
- No internet routing through VPN (split-tunnel)
- Firewall rules on each node

### Monitoring
- Log connection attempts
- Alert on peer disconnections
- Track bandwidth usage per peer

## Next Steps

**Immediate** (Phase 1):
1. ✅ Analyze CT120 current configuration
2. 🔄 Generate keys for AGLSRV6-CT
3. 🔄 Create CT on AGLSRV6 (Proxmox host)
4. 🔄 Configure WireGuard on new CT
5. 🔄 Test connectivity
6. 🔄 Performance benchmark

**Short-term** (Phase 2-3):
1. Deploy WireGuard to FGSRV5
2. Deploy WireGuard to FGSRV6
3. Migrate NFS mounts
4. Performance testing

**Long-term** (Phase 4):
1. Evaluate AGLSRV6b integration approach
2. Full Tailscale migration
3. Documentation and runbooks

---

**Status**: Planning Complete ✓
**Next Action**: Generate keys and create AGLSRV6 CT
**Expected Performance Gain**: 4-6x (10-14 MB/s → 40-60 MB/s)
