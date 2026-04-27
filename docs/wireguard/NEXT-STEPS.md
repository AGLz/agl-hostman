# WireGuard Deployment - Next Steps
**Date**: 2025-10-15
**Status**: ✅ Planning Complete - Ready for Phase 1

## 🎯 Immediate Next Action

### Create CT121 on AGLSRV6

**Location**: AGLSRV6 Proxmox host (100.98.108.66)

**Quick Command** (run on AGLSRV6):
```bash
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
    --onboot 1 \
    --description "WireGuard VPN Node - Pure Kernel Mode"

pct start 121
```

### Then Deploy WireGuard

**Option 1: Automated** (recommended)
```bash
# From AGLDV03
cd /root/host-admin/scripts/wireguard
./deploy-wireguard-mesh.sh setup-aglsrv6
```

**Option 2: Manual**
Follow step-by-step guide in `/root/host-admin/docs/wireguard/deployment-guide.md`

## 📋 What Has Been Completed

✅ **Planning & Architecture**
- Mesh network topology designed (hub-and-spoke)
- IP addressing scheme defined (10.6.0.0/24)
- Performance targets established (4-6x improvement)
- Security model validated (PSK + kernel mode)

✅ **Infrastructure Analysis**
- CT120 on AGLSRV1 verified (already has WireGuard)
- Current configuration documented
- Existing peer preserved (AGLHQ09)

✅ **Key Generation**
- AGLSRV6-CT keys generated (10.6.0.3, port 51821)
- FGSRV5 keys generated (10.6.0.4, port 51822)
- FGSRV6 keys generated (10.6.0.5, port 51823)
- All keys stored securely in `/root/wireguard-keys/`

✅ **Automation Scripts**
- Full deployment script created
- Automated installation, tuning, and configuration
- Built-in connectivity and performance testing

✅ **Documentation**
- Complete architecture plan
- Step-by-step deployment guide
- Troubleshooting procedures
- Migration checklist

## 🗺️ Deployment Roadmap

### Week 1: Phase 1 - AGLSRV6 Integration
**Goal**: Establish WireGuard mesh foundation

**Tasks**:
1. Create CT121 on AGLSRV6 ⏳ **NEXT**
2. Deploy WireGuard to CT121
3. Configure CT120 to accept new peer
4. Test connectivity (ping)
5. Performance test (iperf3)
6. Document baseline results

**Success Metrics**:
- CT121 ↔ CT120 connectivity: 100%
- Throughput: ≥40 MB/s
- Latency: <5ms

### Week 2: Phase 2 - FGSRV5 Integration
**Goal**: Add first NFS host to mesh

**Tasks**:
1. Deploy WireGuard to FGSRV5
2. Add peer to CT120
3. Test connectivity
4. Performance test (NFS over WireGuard)
5. Update NFS mount points (optional, parallel testing)
6. Document performance improvement

**Success Metrics**:
- FGSRV5 ↔ CT120 connectivity: 100%
- NFS throughput: ≥50 MB/s (vs 14 MB/s current)
- 3.5-5x performance improvement

### Week 3: Phase 3 - FGSRV6 Integration
**Goal**: Add second NFS host to mesh

**Tasks**:
1. Deploy WireGuard to FGSRV6
2. Add peer to CT120
3. Test connectivity
4. Performance test (NFS over WireGuard)
5. Update NFS mount points (optional, parallel testing)
6. Document performance improvement

**Success Metrics**:
- FGSRV6 ↔ CT120 connectivity: 100%
- NFS throughput: ≥45 MB/s (vs 12.6 MB/s current)
- 3.5-5x performance improvement

### Week 4: Phase 4 - Validation
**Goal**: Ensure production readiness

**Tasks**:
1. Monitor mesh stability (7 days)
2. Test PBS backups over WireGuard
3. Test container transfers
4. Document all services working
5. Create operational runbooks
6. Performance benchmarking report

**Success Metrics**:
- 99.9% uptime
- All services migrated
- Performance targets met
- Zero connectivity issues

### Week 5: Phase 5 - Tailscale Migration
**Goal**: Complete transition to WireGuard

**Tasks**:
1. Final validation of all services
2. Update all NFS mounts to WireGuard IPs
3. Update PBS configurations
4. Stop Tailscale services
5. Remove Tailscale packages
6. Final documentation

**Success Metrics**:
- All services on WireGuard
- Tailscale decommissioned
- Documentation complete

## 📊 Performance Expectations

### Current State (Tailscale)
```
SSHFS:         10.0 MB/s
NFS FGSRV5:    14.0 MB/s
NFS FGSRV6:    12.6 MB/s
Latency:       8-12ms
CPU Usage:     15-25%
```

### Target State (WireGuard)
```
NFS FGSRV5:    50-70 MB/s  (3.5-5x faster)
NFS FGSRV6:    45-65 MB/s  (3.5-5x faster)
Latency:       2-5ms       (2-3x better)
CPU Usage:     5-10%       (2-3x lower)
```

### Improvement Summary
- **Throughput**: 4-6x increase
- **Latency**: 2-3x reduction
- **CPU**: 2-3x more efficient
- **Stability**: Kernel-native (more reliable)

## 🔑 Key Information Summary

### Network Layout

```
CT120 (Hub)           AGLSRV1
  ├─ WG IP: 10.6.0.1/24
  ├─ LAN IP: 192.168.0.120
  ├─ Port: 51820
  └─ Public Key: Ap0K+tZFaRg16L0qinuAJYKW8iQPvC9qG2dYhWPzHBo=

CT121 (Spoke)         AGLSRV6 - TO CREATE
  ├─ WG IP: 10.6.0.3/24
  ├─ Tailscale: 100.98.108.66
  ├─ Port: 51821
  └─ Public Key: tAq3Ec660PsqijieBEBUyIEidsacrdAQNzealHfRfBM=

FGSRV5 (Spoke)
  ├─ WG IP: 10.6.0.4/24
  ├─ Tailscale: 100.71.107.26
  ├─ Port: 51822
  └─ Public Key: H4ENZ3PkJ0fNGpo0mM4AfB4rh+g5MI+ogz8DQQnZLwk=

FGSRV6 (Spoke)
  ├─ WG IP: 10.6.0.5/24
  ├─ Tailscale: 100.83.51.9
  ├─ Port: 51823
  └─ Public Key: Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
```

### Deployment Script Locations

```
Main Script:
  /root/host-admin/scripts/wireguard/deploy-wireguard-mesh.sh

Generated Keys:
  /root/wireguard-keys/aglsrv6-ct/
  /root/wireguard-keys/fgsrv5/
  /root/wireguard-keys/fgsrv6/

Documentation:
  /root/host-admin/docs/wireguard/mesh-architecture-plan.md
  /root/host-admin/docs/wireguard/deployment-guide.md
  /root/host-admin/docs/wireguard/NEXT-STEPS.md (this file)
```

## 🎬 Quick Start Commands

### 1. Create CT on AGLSRV6
```bash
# SSH to AGLSRV6 host
ssh root@100.98.108.66

# Create container
pct create 121 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
    --hostname wireguard-aglsrv6 --memory 2048 --swap 512 --cores 2 \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --storage local-zfs --rootfs local-zfs:8 \
    --features nesting=1,fuse=1 --unprivileged 1 --onboot 1

# Start it
pct start 121

# Get IP
pct exec 121 -- ip addr show eth0
```

### 2. Deploy WireGuard (Automated)
```bash
# From AGLDV03
cd /root/host-admin/scripts/wireguard
./deploy-wireguard-mesh.sh setup-aglsrv6
```

### 3. Add Peer to CT120
```bash
# The script will output the peer block to add
# SSH to CT120 (on AGLSRV1)
ssh root@192.168.0.120

# Edit config
nano /etc/wireguard/wg0.conf
# (add peer block shown by script)

# Restart
systemctl restart wg-quick@wg0
wg show wg0
```

### 4. Test Connectivity
```bash
# From CT121
ping -c 4 10.6.0.1

# From CT120
ping -c 4 10.6.0.3
```

### 5. Performance Test
```bash
# On CT121 (server)
apt-get install -y iperf3
iperf3 -s

# On CT120 (client)
iperf3 -c 10.6.0.3 -t 30 -i 5
```

## ⚠️ Important Reminders

1. **Parallel Operation**: Keep Tailscale running during WireGuard deployment
2. **No Downtime**: All changes are additive, no services disrupted
3. **Key Security**: Never commit `/root/wireguard-keys/` to git
4. **Firewall**: Ensure UDP ports are open on all nodes
5. **Testing**: Always test connectivity before migrating production traffic

## 📞 If Something Goes Wrong

### WireGuard Not Starting
```bash
journalctl -u wg-quick@wg0 -n 50
wg-quick strip wg0  # syntax check
```

### No Peer Connectivity
```bash
wg show wg0         # check peer status
ss -ulnp | grep wg  # check listening
ufw status          # check firewall
```

### Poor Performance
```bash
iperf3 -c <peer> -t 60  # benchmark
ethtool -k eth0 | grep -E "(gso|gro)"  # check offloading
sysctl net.ipv4.tcp_congestion_control  # check BBR
```

## 📚 Documentation References

- **Architecture Plan**: `/root/host-admin/docs/wireguard/mesh-architecture-plan.md`
- **Deployment Guide**: `/root/host-admin/docs/wireguard/deployment-guide.md`
- **VPN Research**: `/root/host-admin/docs/vpn-alternatives-research-2025.md`
- **NFS Guide**: `/root/host-admin/docs/proxmox-nfs-storage-guide.md`

## ✅ Checklist Before Starting

- [ ] Verified access to AGLSRV6 (100.98.108.66)
- [ ] Confirmed CT template available on AGLSRV6
- [ ] Keys generated and secured
- [ ] Scripts executable (`chmod +x`)
- [ ] Documentation reviewed
- [ ] Backup of CT120 config taken
- [ ] Monitoring tools ready (iperf3, ping)
- [ ] Ready to proceed with Phase 1

---

**Status**: ✅ Ready to Deploy
**Next Action**: Create CT121 on AGLSRV6
**Expected Duration**: 30-45 minutes for Phase 1
**Risk**: Low (non-disruptive, parallel to Tailscale)
**Support**: Full automation + detailed documentation available
