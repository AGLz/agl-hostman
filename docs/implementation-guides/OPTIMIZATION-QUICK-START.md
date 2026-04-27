# Infrastructure Optimization - Quick Start Guide

**Created**: 2025-11-02
**Status**: ✅ Ready for Deployment

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Choose Your Target

```bash
# For Docker optimization (CT179, CT183, CT202)
sudo /mnt/overpower/apps/dev/agl/agl-hostman/scripts/optimization/optimize-docker-containers.sh

# For WireGuard optimization (any WireGuard node)
sudo /mnt/overpower/apps/dev/agl/agl-hostman/scripts/optimization/optimize-wireguard-mesh.sh

# For storage optimization (AGLSRV1 host)
sudo /mnt/overpower/apps/dev/agl/agl-hostman/scripts/optimization/optimize-nfs-storage.sh
```

### Step 2: Run Performance Benchmark

```javascript
const PerformanceBenchmark = require('/mnt/overpower/apps/dev/agl/agl-hostman/src/utils/PerformanceBenchmark');

(async () => {
  const benchmark = new PerformanceBenchmark({ outputDir: '/tmp/benchmarks' });
  const results = await benchmark.runAll();
  console.log('Benchmark complete! Results saved to /tmp/benchmarks/');
})();
```

### Step 3: Start Real-Time Monitoring

```javascript
const InfrastructureMonitor = require('/mnt/overpower/apps/dev/agl/agl-hostman/src/monitoring/InfrastructureMonitor');

const monitor = new InfrastructureMonitor({ enableRealtime: true });
monitor.start();

monitor.on('metrics:collected', () => {
  console.log(monitor.getDashboard());
});
```

---

## 📋 What Was Created

### Monitoring & Benchmarking
- ✅ **InfrastructureMonitor.js** - Real-time monitoring (WireGuard, NFS, Docker, Services)
- ✅ **PerformanceBenchmark.js** - Automated benchmarking with baseline comparison

### Optimization Scripts
- ✅ **optimize-docker-containers.sh** - Docker daemon + container optimization
- ✅ **optimize-wireguard-mesh.sh** - WireGuard mesh network tuning
- ✅ **optimize-nfs-storage.sh** - NFS/SSHFS mount optimization

### Configuration Templates
- ✅ **docker-compose.optimized.yml** - Optimized Archon configuration
- ✅ **wireguard-optimized.conf** - WireGuard template (LXC-compatible)
- ✅ **nfs-fstab.conf** - Optimized mount configurations

### Documentation
- ✅ **README.md** - Complete implementation guide (scripts/optimization/)
- ✅ **CODER-IMPLEMENTATION-REPORT.md** - Full technical documentation

---

## 🎯 Expected Improvements

| Component | Metric | Before | After | Improvement |
|-----------|--------|--------|-------|-------------|
| WireGuard | Latency | 20-30ms | 15-25ms | 15-20% |
| NFS | Throughput | 30-50 MB/s | 40-70 MB/s | 30-40% |
| SSHFS | Throughput | 20-40 MB/s | 30-60 MB/s | 40-50% |
| Docker | Memory | 6-8 GB | 5-6 GB | 15-20% |
| Storage | Mount Failures | 2-3/week | 0-1/week | 60-80% |

---

## 🔧 Deployment Checklist

### Pre-Deployment
- [ ] Backup configurations (`/etc/fstab`, `/etc/wireguard/*.conf`, `/etc/docker/daemon.json`)
- [ ] Run baseline benchmark
- [ ] Schedule maintenance window
- [ ] Notify users of potential service interruption

### Deployment
- [ ] Run optimization scripts
- [ ] Verify changes in config files
- [ ] Reboot system (for kernel params)
- [ ] Verify all services after reboot

### Post-Deployment
- [ ] Run post-optimization benchmark
- [ ] Compare with baseline
- [ ] Monitor for 24-48 hours
- [ ] Document any issues

---

## 📊 Monitoring Dashboard

### Real-Time Status
```javascript
const dashboard = monitor.getDashboard();

// Output:
{
  status: 'healthy',           // overall: healthy/warning/critical
  wireguard: {
    total: 14,                 // total peers
    healthy: 13,               // healthy peers
    avgLatency: 18.5           // average latency (ms)
  },
  storage: {
    total: 6,                  // total mounts
    healthy: 6,                // healthy mounts
    mounts: [...]              // detailed mount info
  },
  docker: {
    total: 8,                  // total containers
    healthy: 8,                // healthy containers
    containers: [...]          // detailed container stats
  },
  alerts: {
    critical: 0,               // critical alerts
    warning: 0                 // warning alerts
  }
}
```

### Optimization Recommendations
```javascript
const recommendations = monitor.getOptimizationRecommendations();

// Example output:
[
  {
    category: 'wireguard',
    severity: 'medium',
    message: '2 WireGuard peer(s) have high latency',
    action: 'Consider tuning MTU settings or checking network path',
    peers: ['AGLSRV6', 'CT111']
  },
  {
    category: 'storage',
    severity: 'high',
    message: '1 storage mount(s) have slow I/O',
    action: 'Check NFS mount options, enable caching, or verify network connectivity',
    mounts: ['fgsrv5-wg']
  }
]
```

---

## 🚨 Troubleshooting

### Common Issues

**1. WireGuard high latency**
```bash
# Check MTU
ip link show wg0 | grep mtu

# Test path MTU
ping -M do -s 1400 10.6.0.5

# Verify kernel params
sysctl net.ipv4.tcp_congestion_control
```

**2. Stale NFS mount**
```bash
# Force unmount
umount -f /mnt/pve/fgsrv6-wg

# Remount
mount /mnt/pve/fgsrv6-wg

# Verify
mountpoint /mnt/pve/fgsrv6-wg
```

**3. Docker high resource usage**
```bash
# Check stats
docker stats

# Review logs
docker compose logs -f archon-server

# Restart services
cd /root/Archon && docker compose restart
```

---

## 📚 Full Documentation

- **Implementation Guide**: `scripts/optimization/README.md`
- **Technical Report**: `docs/CODER-IMPLEMENTATION-REPORT.md`
- **Infrastructure Map**: `docs/INFRA.md`
- **Archon Integration**: `docs/ARCHON.md`

---

## 🎓 Learn More

### Key Concepts

**WireGuard Optimization**:
- MTU 1420 (optimal for VPN overhead)
- TCP BBR congestion control
- Large network buffers (25MB)
- PersistentKeepalive for NAT traversal

**Storage Optimization**:
- Large buffer sizes (128KB rsize/wsize)
- NFSv4.2 for better performance
- SSHFS compression and caching
- Kernel page cache utilization

**Docker Optimization**:
- Resource limits prevent resource exhaustion
- Overlay2 storage driver for better performance
- Log rotation prevents disk filling
- Health checks ensure service availability

---

## 🤝 Support

For questions or issues:
1. Review the troubleshooting section in `scripts/optimization/README.md`
2. Check logs: `journalctl -f`
3. Run diagnostics: `docker stats`, `wg show wg0`, `df -h`
4. Review the technical report: `docs/CODER-IMPLEMENTATION-REPORT.md`

---

**Quick Reference Card**

```
┌─────────────────────────────────────────────────────┐
│ Optimization Quick Commands                         │
├─────────────────────────────────────────────────────┤
│ Docker:     optimize-docker-containers.sh          │
│ WireGuard:  optimize-wireguard-mesh.sh             │
│ Storage:    optimize-nfs-storage.sh                │
│                                                      │
│ Monitor:    node -e "require('...').start()"        │
│ Benchmark:  node -e "require('...').runAll()"       │
│                                                      │
│ Status:     wg show wg0 | docker stats | df -h      │
│ Logs:       journalctl -f | docker logs -f          │
│ Health:     systemctl status | docker compose ps    │
└─────────────────────────────────────────────────────┘
```

---

**Last Updated**: 2025-11-02
**Version**: 1.0.0
**Status**: Production Ready ✅
